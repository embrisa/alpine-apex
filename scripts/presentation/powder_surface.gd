extends Node3D
## GPU local impressions reconstructed from the bounded track ring. No readback,
## mountain-wide vertex uploads, physics writes, or per-particle CPU simulation.
const EXTENT_M = 32.0
const RESOLUTION = 1024
const IMPRINT_RESOLUTION = 256 # filtered relief spans multiple mesh vertices
# 12.5 cm spacing on desktop GPUs. Apple's tile-based Metal GPUs pay heavily for
# the resulting micro-triangles (M4: 26.5 -> 24.9 ms per frame at 128, 24.0 at
# 64, with the whole patch hidden 21.5), so Metal uses 25 cm spacing.
static var SUBDIVISIONS: int = mesh_subdivisions(RenderingServer.get_current_rendering_driver_name())

static func mesh_subdivisions(driver: String) -> int:
	return 128 if driver=="metal" else 256
const SUPPORT_SIZE = 9 # 32 m / authoritative 4 m grid + both end vertices
const SUPPORT_BYTES = SUPPORT_SIZE*SUPPORT_SIZE*16
const FULL_RADIUS_M = 8.0
const FADE_RADIUS_M = 13.0
const COVER_RADIUS_M = 13.5 # zero-relief collar; at least .5 m inside storage
const Footprint = preload("res://scripts/world/mountain_footprint.gd")
const Presets = preload("res://scripts/presentation/graphics_presets.gd")
const LIVE_STROKES = 2
const STROKE_BYTES = 32
const GhostStack = preload("res://scripts/presentation/ghost_track_stack.gd")
const MAX_STROKES = Presets.MAX_TRACK_HISTORY+GhostStack.MAX_EXTRA_STROKES+LIVE_STROKES
const BUFFER_BYTES = MAX_STROKES*STROKE_BYTES
var track_history
var world
var patch: MeshInstance3D
var material: ShaderMaterial
var texture = Texture2DRD.new()
var support_texture = Texture2DRD.new()
var receivers: Array[ShaderMaterial] = []
var support_rid = RID()
var support_uploaded_bytes = 0
var support_upload_calls = 0
var support_cache_center = Vector2.INF
var support_cache_surface_id = 0
var support_cache = PackedFloat32Array()
var support_queries = 0
var support_reused_knots = 0
var presentations = 0
var visual_center = Vector2.INF
var last_position = Vector3.INF
var enabled = false
var available = false
var center = Vector2.INF
var last_revision = -1
var rd: RenderingDevice
var atlas_rid = RID()
var surface_rid = RID()
var buffer_rid = RID()
var shader_rid = RID()
var pipeline = RID()
var uniforms = RID()
var dispatches = 0
var uploaded_bytes = 0
var upload_calls = 0

func bind(history, alpine_world, profile) -> void:
	track_history = history
	world = alpine_world
	enabled = profile.snow_local_deformation
	if DisplayServer.get_name()=="headless": return
	material = world.snow_material.duplicate()
	material.shader = preload("res://assets/graphics/powder_surface.gdshader")
	world.cloud_lighting.register(material)
	world.assets.surface_materials.append(material)
	material.set_shader_parameter("powder_local_surface",true)
	for receiver in [material,world.snow_material,history.material]: register_receiver(receiver)
	material.set_shader_parameter("contact_heights",history.material.get_shader_parameter("surface_heights"))
	material.set_shader_parameter("contact_origin",history.material.get_shader_parameter("surface_origin"))
	material.set_shader_parameter("contact_size",history.material.get_shader_parameter("surface_size"))
	patch = MeshInstance3D.new()
	patch.mesh = _mesh()
	patch.material_override = material
	patch.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Logical visibility stays on; the server transaction plus fragment ownership
	# gates drawing. Parent visibility changes cannot resurrect an old surface.
	# Shader vertices follow the mountain; keep the tiny CPU plane from being
	# incorrectly culled while looking down a steep gully.
	patch.custom_aabb = AABB(Vector3(-16,-120,-16),Vector3(32,240,32))
	add_child(patch)
	RenderingServer.call_on_render_thread(_render_setup)

func register_receiver(receiver: ShaderMaterial) -> void:
	# Additional presentation histories (e.g. ghosts) share this one committed
	# mapping. Register before update_surface; never publish their centers alone.
	if receivers.has(receiver): return
	receivers.append(receiver)
	receiver.set_shader_parameter("powder_imprints",texture)
	receiver.set_shader_parameter("powder_support_data",support_texture)
	receiver.set_shader_parameter("powder_patch_enabled",false)
	receiver.set_shader_parameter("powder_bounds",Vector4(world.surface.X_MIN,world.surface.Z_MIN,
		world.surface.X_MIN+(world.surface.NX-1)*4.0,world.surface.Z_MIN+(world.surface.NZ-1)*4.0))
	receiver.set_shader_parameter("powder_footprint_enabled",Footprint.enabled(world.surface))
	receiver.set_shader_parameter("powder_footprint_shape",Footprint.SHAPE)
	last_revision = -1

func _receiver_rids() -> Array[RID]:
	var result: Array[RID] = []
	for receiver in receivers: result.append(receiver.get_rid())
	return result

static func storage_center(position_value: Vector2, origin: Vector2 = Vector2.ZERO) -> Vector2:
	return origin+(position_value-origin).snapped(Vector2.ONE*4.0)

static func influence(world_point: Vector2, visual: Vector2) -> float:
	return 1.0-smoothstep(FULL_RADIUS_M,FADE_RADIUS_M,world_point.distance_to(visual))

func _support_bytes(location: Vector2) -> PackedByteArray:
	# Terrain support is immutable within this world. Retain just the previous
	# 9x9 grid: a one-cell move needs 9 new knots (17 diagonally), not 81.
	# Reset, world replacement and non-overlapping moves rebuild all knots.
	var values = PackedFloat32Array()
	values.resize(SUPPORT_SIZE*SUPPORT_SIZE*4)
	var surface_id: int = world.surface.get_instance_id()
	var shift = Vector2i.ZERO
	var reuse = support_cache_surface_id==surface_id and support_cache.size()==values.size() and support_cache_center.is_finite()
	if reuse:
		var cells = (location-support_cache_center)/4.0
		shift = Vector2i(cells.round())
		reuse = cells==Vector2(shift) and absi(shift.x)<SUPPORT_SIZE and absi(shift.y)<SUPPORT_SIZE
	for z in SUPPORT_SIZE:
		for x in SUPPORT_SIZE:
			var at = (z*SUPPORT_SIZE+x)*4
			var previous = Vector2i(x,z)+shift
			if reuse and previous.x>=0 and previous.x<SUPPORT_SIZE and previous.y>=0 and previous.y<SUPPORT_SIZE:
				var old_at = (previous.y*SUPPORT_SIZE+previous.x)*4
				for component in 4: values[at+component] = support_cache[old_at+component]
				support_reused_knots += 1
				continue
			var p = location-Vector2.ONE*EXTENT_M*.5+Vector2(x,z)*4.0
			var normal: Vector3 = world.surface.render_normal(p.x,p.y) if world.surface.has_method("render_normal") else world.surface.contact_normal(p.x,p.y)
			var depth = clampf(world.surface.snow_depth_at(p.x,p.y),0.0,.35) if world.surface.has_method("snow_depth_at") else 0.0
			values[at] = normal.x; values[at+1] = normal.y; values[at+2] = normal.z; values[at+3] = depth
			support_queries += 1
	support_cache = values
	support_cache_center = location
	support_cache_surface_id = surface_id
	return values.to_byte_array()

static func _mesh() -> ArrayMesh:
	# Explicit diagonal matches HeightfieldSurface. A primitive's undocumented
	# diagonal must not cut across the authoritative 4 m triangle seams.
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	for z in range(SUBDIVISIONS+1):
		for x in range(SUBDIVISIONS+1):
			vertices.append(Vector3(float(x)/SUBDIVISIONS-.5,0,float(z)/SUBDIVISIONS-.5)*EXTENT_M)
			normals.append(Vector3.UP)
	# Terrain hands over only the 13.5 m disc around the visual centre, which sits
	# at most half a 4 m cell diagonal (2.83 m) from this storage-centred mesh.
	# Quads entirely outside that reach are always discarded by the fragment
	# ownership test, so they are not generated: fewer vertex evaluations, same image.
	var reach = COVER_RADIUS_M+4.0*sqrt(2.0)*.5+.1 # authoritative 4 m support cell
	var cell = EXTENT_M/SUBDIVISIONS
	for z in SUBDIVISIONS:
		for x in SUBDIVISIONS:
			var near_x = minf(absf((x+0.0)*cell-EXTENT_M*.5),absf((x+1.0)*cell-EXTENT_M*.5)) if not (x*cell<=EXTENT_M*.5 and (x+1)*cell>=EXTENT_M*.5) else 0.0
			var near_z = minf(absf((z+0.0)*cell-EXTENT_M*.5),absf((z+1.0)*cell-EXTENT_M*.5)) if not (z*cell<=EXTENT_M*.5 and (z+1)*cell>=EXTENT_M*.5) else 0.0
			if near_x*near_x+near_z*near_z>reach*reach: continue
			var a = z*(SUBDIVISIONS+1)+x
			indices.append_array(PackedInt32Array([a,a+1,a+SUBDIVISIONS+1,a+1,a+SUBDIVISIONS+2,a+SUBDIVISIONS+1]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _render_setup() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd==null: return
	# Import-independent source also works when unrelated DCC assets cannot be
	# imported on this machine. Compilation happens once, before the patch opens.
	var source = RDShaderSource.new()
	source.source_compute = preload("res://assets/graphics/powder_compute.gd").SOURCE
	var spirv = rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty():
		push_error(spirv.compile_error_compute)
		return
	shader_rid = rd.shader_create_from_spirv(spirv)
	if not shader_rid.is_valid(): return
	pipeline = rd.compute_pipeline_create(shader_rid)
	var format = RDTextureFormat.new()
	format.width = RESOLUTION
	format.height = RESOLUTION
	format.format = RenderingDevice.DATA_FORMAT_R32_UINT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	atlas_rid = rd.texture_create(format,RDTextureView.new())
	format.format = RenderingDevice.DATA_FORMAT_R16G16_SFLOAT
	format.width = IMPRINT_RESOLUTION
	format.height = IMPRINT_RESOLUTION
	surface_rid = rd.texture_create(format,RDTextureView.new())
	format.width = SUPPORT_SIZE
	format.height = SUPPORT_SIZE
	format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	support_rid = rd.texture_create(format,RDTextureView.new())
	buffer_rid = rd.storage_buffer_create(BUFFER_BYTES)
	var image_uniform = RDUniform.new()
	image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	image_uniform.binding = 0
	image_uniform.add_id(atlas_rid)
	var data_uniform = RDUniform.new()
	data_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	data_uniform.binding = 1
	data_uniform.add_id(buffer_rid)
	var surface_uniform = RDUniform.new()
	surface_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	surface_uniform.binding = 2
	surface_uniform.add_id(surface_rid)
	uniforms = rd.uniform_set_create([image_uniform,data_uniform,surface_uniform],shader_rid,0)
	texture.texture_rd_rid = surface_rid
	support_texture.texture_rd_rid = support_rid
	call_deferred("_ready_gpu")

func _ready_gpu() -> void:
	available = true
	last_revision = -1

func apply_quality(profile) -> void:
	enabled = profile.snow_local_deformation
	reset()

func reset() -> void:
	# Queued after earlier presentations. A following update rebuilds before
	# reopening; teleports/quality changes never interpolate stale atlas origins.
	last_revision = -1
	center = Vector2.INF
	visual_center = Vector2.INF
	last_position = Vector3.INF
	support_cache.clear()
	support_cache_center = Vector2.INF
	support_cache_surface_id = 0
	_visibility(false)

func is_active() -> bool: return enabled and available

func _visibility(value: bool) -> void:
	if not patch: return
	RenderingServer.call_on_render_thread(_render_visibility.bind(patch.get_instance(),_receiver_rids(),value))

func _render_visibility(instance: RID, materials: Array[RID], value: bool) -> void:
	RenderingServer.instance_set_visible(instance,value)
	for receiver in materials: RenderingServer.material_set_param(receiver,&"powder_patch_enabled",value)

func update_surface(sim, p: Vector3, responses: Array) -> void:
	if not is_active(): return
	if not p.is_finite():
		reset()
		return
	if track_history.capacity<0 or track_history.capacity>MAX_STROKES-LIVE_STROKES:
		_visibility(false)
		last_revision = -1
		push_error("Powder track history exceeds the allocated deformation buffer")
		return
	if last_position.is_finite() and p.distance_to(last_position)>EXTENT_M*.5: reset()
	last_position = p
	var next_visual = Vector2(p.x,p.z)
	var next = storage_center(next_visual,Vector2(world.surface.X_MIN,world.surface.Z_MIN))
	var moved = next!=center
	var support = _support_bytes(next) if moved else PackedByteArray()
	var visual_moved = next_visual!=visual_center
	center = next
	visual_center = next_visual
	# Match the live ribbons through the rendered tips, including the unsampled
	# tail remainder. The fixed ring and two-footprint GPU budget are unchanged.
	if not moved and track_history.revision==last_revision and not sim.grounded and not track_history.has_method("surface_materials"):
		if visual_moved: _queue_present([],support,p,false)
		return
	var updates: Array = track_history.take_gpu_updates(last_revision<0)
	updates.append({"offset":track_history.capacity*STROKE_BYTES,"bytes":track_history.live_gpu_strokes().to_byte_array()})
	if not valid_submission(updates,track_history.capacity+LIVE_STROKES):
		reset() # Retry support data AND complete history after a rejected upload.
		push_error("Powder deformation submission exceeds its buffer or stroke layout")
		return
	last_revision = track_history.revision
	dispatches += 1
	for update in updates:
		uploaded_bytes+=update.bytes.size()
		upload_calls+=1
	_queue_present(updates,support,p,true)

func _queue_present(updates: Array, support: PackedByteArray, p: Vector3, rebuild: bool) -> void:
	support_uploaded_bytes += support.size()
	if not support.is_empty(): support_upload_calls += 1
	presentations += 1
	RenderingServer.call_on_render_thread(_render_present.bind(updates,support,center,visual_center,
		p.y,track_history.capacity+LIVE_STROKES,rebuild,patch.get_instance(),_receiver_rids()))

func _render_present(updates: Array, support: PackedByteArray, location: Vector2, visual: Vector2,
		height: float, count: int, rebuild: bool, instance: RID, materials: Array[RID]) -> void:
	if not uniforms.is_valid(): return
	if (rebuild and not valid_submission(updates,count)) or (not support.is_empty() and support.size()!=SUPPORT_BYTES):
		_render_visibility(instance,materials,false)
		push_error("Rejected incoherent powder presentation")
		return
	if rebuild: _render_update(updates,location,count)
	if not support.is_empty(): rd.texture_update(support_rid,0,support)
	# Same render-thread transaction, AFTER reconstruction. Neither main-thread
	# masks nor deferred callbacks can expose new coordinates with an old atlas.
	for receiver in materials:
		RenderingServer.material_set_param(receiver,&"powder_center",location)
		RenderingServer.material_set_param(receiver,&"powder_visual_center",visual)
		RenderingServer.material_set_param(receiver,&"powder_patch_enabled",true)
	# Keep the instance transform fixed: moving it by 4 m invents terrain motion
	# vectors at every recenter. Vertex coordinates are explicitly world-locked.
	RenderingServer.instance_set_custom_aabb(instance,AABB(Vector3(location.x-16,height-120,location.y-16),Vector3(32,240,32)))
	RenderingServer.instance_set_visible(instance,true)

static func valid_submission(updates: Array, count: int) -> bool:
	# Reject the entire batch before any GPU mutation, including wrapped spans.
	if count<LIVE_STROKES or count>MAX_STROKES: return false
	for update in updates:
		if not update is Dictionary or not update.has("offset") or not update.has("bytes"): return false
		if not update.offset is int or not update.bytes is PackedByteArray: return false
		var offset: int = update.offset
		var byte_count: int = update.bytes.size()
		if offset<0 or offset%STROKE_BYTES!=0 or byte_count%STROKE_BYTES!=0: return false
		if offset>count*STROKE_BYTES or byte_count>count*STROKE_BYTES-offset: return false
	return true

func _render_update(updates: Array, location: Vector2, count: int) -> void:
	if not uniforms.is_valid(): return
	if not valid_submission(updates,count):
		push_error("Rejected out-of-bounds powder render submission")
		return
	for update in updates:
		rd.buffer_update(buffer_rid,update.offset,update.bytes.size(),update.bytes)
	var constants = PackedFloat32Array([location.x-EXTENT_M*.5,location.y-EXTENT_M*.5,EXTENT_M,RESOLUTION]).to_byte_array()
	constants.append_array(PackedInt32Array([count,0,0,0]).to_byte_array())
	var list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list,pipeline)
	rd.compute_list_bind_uniform_set(list,uniforms,0)
	rd.compute_list_set_push_constant(list,constants,32)
	rd.compute_list_dispatch(list,RESOLUTION/8,RESOLUTION/8,1)
	rd.compute_list_add_barrier(list)
	constants.encode_s32(20,1)
	rd.compute_list_set_push_constant(list,constants,32)
	rd.compute_list_dispatch(list,count,1,1)
	rd.compute_list_add_barrier(list)
	constants.encode_s32(20,2)
	rd.compute_list_set_push_constant(list,constants,32)
	rd.compute_list_dispatch(list,IMPRINT_RESOLUTION/8,IMPRINT_RESOLUTION/8,1)
	rd.compute_list_end()

func budget() -> Dictionary:
	return {"enabled":is_active(),"extent_m":EXTENT_M,"atlas_resolution":RESOLUTION,"imprint_resolution":IMPRINT_RESOLUTION,
		"support_texture_bytes":SUPPORT_BYTES if available else 0,"support_uploaded_bytes":support_uploaded_bytes,
		"support_upload_calls":support_upload_calls,"presentations":presentations,"visual_center":visual_center,"storage_center":center,
		"support_queries":support_queries,"support_reused_knots":support_reused_knots,"support_cache_bytes":support_cache.size()*4,
		"atlas_bytes":(RESOLUTION*RESOLUTION+IMPRINT_RESOLUTION*IMPRINT_RESOLUTION)*4 if available else 0,"contact_buffer_bytes":BUFFER_BYTES if available else 0,
		"vertices":(SUBDIVISIONS+1)*(SUBDIVISIONS+1) if is_active() else 0,"dispatch_frames":dispatches,
		"uploaded_bytes":uploaded_bytes,"upload_calls":upload_calls}

func _exit_tree() -> void:
	_visibility(false)
	if available: RenderingServer.call_on_render_thread(_render_free)

func _render_free() -> void:
	texture.texture_rd_rid = RID()
	support_texture.texture_rd_rid = RID()
	for rid in [uniforms,pipeline,shader_rid,buffer_rid,atlas_rid,surface_rid,support_rid]:
		if rid.is_valid(): rd.free_rid(rid)
	uniforms = RID()
