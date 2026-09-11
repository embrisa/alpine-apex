extends Node3D
## GPU local impressions reconstructed from the bounded track ring. No readback,
## mountain-wide vertex uploads, physics writes, or per-particle CPU simulation.
const EXTENT_M = 32.0
const RESOLUTION = 1024
const IMPRINT_RESOLUTION = 256 # filtered relief spans multiple mesh vertices
const SUBDIVISIONS = 512
const Presets = preload("res://scripts/presentation/graphics_presets.gd")
const LIVE_STROKES = 2
const STROKE_BYTES = 32
const MAX_STROKES = Presets.MAX_TRACK_HISTORY+LIVE_STROKES
const BUFFER_BYTES = MAX_STROKES*STROKE_BYTES
var track_history
var world
var patch: MeshInstance3D
var material: ShaderMaterial
var texture = Texture2DRD.new()
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
var render_state = preload("res://scripts/presentation/render_state_cache.gd").new()

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
	material.set_shader_parameter("powder_imprints",texture)
	history.material.set_shader_parameter("powder_imprints",texture)
	material.set_shader_parameter("contact_heights",history.material.get_shader_parameter("surface_heights"))
	material.set_shader_parameter("contact_origin",history.material.get_shader_parameter("surface_origin"))
	material.set_shader_parameter("contact_size",history.material.get_shader_parameter("surface_size"))
	patch = MeshInstance3D.new()
	patch.mesh = _mesh()
	patch.material_override = material
	patch.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	patch.visible = false
	# Shader vertices follow the mountain; keep the tiny CPU plane from being
	# incorrectly culled while looking down a steep gully.
	patch.custom_aabb = AABB(Vector3(-16,-120,-16),Vector3(32,240,32))
	add_child(patch)
	RenderingServer.call_on_render_thread(_render_setup)

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
	for z in SUBDIVISIONS:
		for x in SUBDIVISIONS:
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
	call_deferred("_ready_gpu")

func _ready_gpu() -> void:
	available = true
	last_revision = -1

func apply_quality(profile) -> void:
	enabled = profile.snow_local_deformation
	last_revision = -1
	render_state.clear()
	if not enabled: _visibility(false)

func is_active() -> bool: return enabled and available

func _visibility(value: bool) -> void:
	if patch: render_state.assign(patch,&"visible",value)
	if world and world.snow_material:
		render_state.shader(world.snow_material,&"powder_patch_enabled",value)
	if track_history and track_history.material:
		render_state.shader(track_history.material,&"powder_patch_enabled",value)

func update_surface(sim, p: Vector3, responses: Array) -> void:
	if not is_active(): return
	if track_history.capacity<0 or track_history.capacity>Presets.MAX_TRACK_HISTORY:
		_visibility(false)
		last_revision = -1
		push_error("Powder track history exceeds the allocated deformation buffer")
		return
	var next = Vector2(snappedf(p.x,4.0),snappedf(p.z,4.0))
	var moved = next!=center
	center = next
	render_state.assign(patch,&"position",Vector3(center.x,p.y,center.y))
	var loose_depth = clampf(world.surface.snow_depth_at(p.x,p.z),0.0,.35) if world.surface.has_method("snow_depth_at") else 0.0
	render_state.shader(material,&"powder_loose_depth",loose_depth)
	render_state.shader(track_history.material,&"powder_loose_depth",loose_depth)
	for mat in [material,world.snow_material,track_history.material]:
		render_state.shader(mat,&"powder_center",center)
	_visibility(true)
	# Match the live ribbons through the rendered tips, including the unsampled
	# tail remainder. The fixed ring and two-footprint GPU budget are unchanged.
	if not moved and track_history.revision==last_revision and not sim.grounded: return
	var updates: Array = track_history.take_gpu_updates(last_revision<0)
	var data = PackedFloat32Array()
	data.resize(16)
	for i in 2:
		var response = responses[i]
		var a: Vector3 = response.contact_position-response.contact_forward*sim.tuning.ski_length*.5
		if track_history.foot_history[i].is_finite() and a.distance_to(track_history.foot_history[i])<2.0:
			a = track_history.foot_history[i]
		var b: Vector3 = response.contact_position+response.contact_forward*(sim.tuning.ski_length*.5+.12)
		var side = response.throw_world.dot(Vector3.UP.cross((b-a).normalized()))
		var offset = i*8
		var values = [a.x,a.z,b.x,b.z,response.contact_width_m,response.depth_m if response.snow_contact else 0.0,response.slip,signf(side)]
		for j in 8: data[offset+j] = values[j]
	updates.append({"offset":track_history.capacity*STROKE_BYTES,"bytes":data.to_byte_array()})
	if not valid_submission(updates,track_history.capacity+LIVE_STROKES):
		_visibility(false)
		last_revision = -1 # Retry with a complete history after a rejected upload.
		push_error("Powder deformation submission exceeds its buffer or stroke layout")
		return
	last_revision = track_history.revision
	dispatches += 1
	for update in updates:
		uploaded_bytes+=update.bytes.size()
		upload_calls+=1
	RenderingServer.call_on_render_thread(_render_update.bind(updates,center,track_history.capacity+LIVE_STROKES))

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
		"atlas_bytes":(RESOLUTION*RESOLUTION+IMPRINT_RESOLUTION*IMPRINT_RESOLUTION)*4 if available else 0,"contact_buffer_bytes":BUFFER_BYTES if available else 0,
		"vertices":(SUBDIVISIONS+1)*(SUBDIVISIONS+1) if is_active() else 0,"dispatch_frames":dispatches,
		"uploaded_bytes":uploaded_bytes,"upload_calls":upload_calls}

func _exit_tree() -> void:
	_visibility(false)
	if available: RenderingServer.call_on_render_thread(_render_free)

func _render_free() -> void:
	texture.texture_rd_rid = RID()
	for rid in [uniforms,pipeline,shader_rid,buffer_rid,atlas_rid,surface_rid]:
		if rid.is_valid(): rd.free_rid(rid)
	uniforms = RID()
