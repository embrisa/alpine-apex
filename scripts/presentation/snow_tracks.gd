extends Node3D
## Distance-sampled paired ribbons. Rendering history never feeds ski contact.
const CAPACITY = 800
var capacity = CAPACITY
const SPACING_M = 0.70
const HALF_STANCE_M = 0.22
var tracks: MultiMesh
var live_tracks: MultiMesh
var live_transforms: Array[Transform3D] = [Transform3D.IDENTITY,Transform3D.IDENTITY]
var live_active: Array[bool] = [false,false]
var cursor: int = 0
var written: int = 0
var last_position = Vector3.INF
var last_right = Vector3.RIGHT
var foot_history: Array[Vector3] = [Vector3.INF,Vector3.INF]
var lighting
var material: ShaderMaterial
var surface_texture_bytes = 0
var gpu_stamps = PackedFloat32Array()
var revision = 0
var gpu_full_upload = true
var gpu_dirty_spans: Array[Vector2i] = []
var transforms: Array[Transform3D] = []
var corner_history: Array[Color] = []
var appearance_history: Array[Color] = []
const Response = preload("res://scripts/presentation/snow_response.gd")
var contact_responses: Array = [Response.new(),Response.new()]

func _ready() -> void:
	tracks = MultiMesh.new()
	tracks.transform_format = MultiMesh.TRANSFORM_3D
	tracks.use_custom_data = true
	tracks.use_colors = true
	var ribbon = PlaneMesh.new()
	ribbon.size = Vector2.ONE
	ribbon.subdivide_width = 15
	ribbon.subdivide_depth = 1
	material = ShaderMaterial.new()
	material.shader = preload("res://assets/graphics/ski_track.gdshader")
	lighting.register(material)
	ribbon.material = material
	tracks.mesh = ribbon
	tracks.instance_count = CAPACITY
	transforms.resize(capacity)
	corner_history.resize(capacity)
	appearance_history.resize(capacity)
	var instance = MultiMeshInstance3D.new()
	instance.multimesh = tracks
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 0.3
	add_child(instance)
	# Two bounded live sections bridge the distance-sampled history to the
	# visible tips. They update this frame without waiting for the next stamp.
	live_tracks = MultiMesh.new()
	live_tracks.transform_format = MultiMesh.TRANSFORM_3D
	live_tracks.use_custom_data = true
	live_tracks.use_colors = true
	var live_ribbon = ribbon.duplicate()
	live_ribbon.subdivide_depth = 15
	live_tracks.mesh = live_ribbon
	live_tracks.instance_count = 2
	var live_instance = MultiMeshInstance3D.new()
	live_instance.multimesh = live_tracks
	live_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	live_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	live_instance.extra_cull_margin = .3
	add_child(live_instance)
	reset()

func reset() -> void:
	gpu_stamps.resize(capacity*8)
	gpu_stamps.fill(0.0)
	gpu_full_upload = true
	gpu_dirty_spans.clear()
	revision += 1
	last_position = Vector3.INF
	foot_history = [Vector3.INF,Vector3.INF]
	cursor = 0
	written = 0
	if tracks:
		tracks.visible_instance_count = 0
	for i in 2: _hide_live(i)

func _hide_live(index: int) -> void:
	live_active[index] = false
	if live_tracks:
		live_tracks.set_instance_transform(index,Transform3D(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),Vector3.ZERO))

func update_contact(sim, field, p: Vector3, active: bool, responses: Array = []) -> void:
	if sim.contacts_initialized:
		if responses.is_empty():
			for i in range(2):
				contact_responses[i].sample(sim,sim.skis[i],field)
				contact_responses[i].contact_position += p-sim.position
		_independent_contacts(sim,field,p,active,contact_responses if responses.is_empty() else responses)
		return
	if not active or not sim.grounded or sim.crashed:
		last_position = Vector3.INF
		return
	var forward: Vector3 = sim.ski_forward
	var right: Vector3 = sim.surface_normal.cross(forward).normalized()
	# End the impression at the tails, where displaced snow becomes visible.
	var tail = p - forward * 0.65
	if not last_position.is_finite() or tail.distance_to(last_position)>8.0:
		last_position = tail
		last_right = right
		return
	var distance = tail.distance_to(last_position)
	if distance<SPACING_M: return
	var start = last_position
	var start_right = last_right
	var steps = mini(12,floori(distance / SPACING_M))
	for step in range(1,steps+1):
		var t = step * SPACING_M / distance
		var next = start.lerp(tail,t)
		var next_right = start_right.lerp(right,t).normalized()
		for side in [-1.0,1.0]:
			_stamp(field,last_position+last_right*side*HALF_STANCE_M,next+next_right*side*HALF_STANCE_M,sim)
		last_position = next
		last_right = next_right

func _stamp(field, a: Vector3, b: Vector3, sim, response = null, live_index: int = -1) -> void:
	# Check the swept tail segment too: snow cannot bridge a narrow rock strip.
	var TerrainMaterial = preload("res://scripts/core/terrain_material.gd")
	for t in [0.0,.5,1.0]:
		var point = a.lerp(b,t)
		if TerrainMaterial.at(field,point.x,point.z)==TerrainMaterial.Kind.ROCK:
			if live_index>=0: _hide_live(live_index)
			return
	var along = Vector3(b.x-a.x,0,b.z-a.z)
	var length_m = along.length()
	if length_m<0.01:
		if live_index>=0: _hide_live(live_index)
		return
	along /= length_m
	var across = Vector3.UP.cross(along)
	var slip: float = absf(sin(sim.slip_angle)) if response==null else response.slip
	var width: float = .22+slip*.9 if response==null else response.width_m
	if live_index>=0: width = response.contact_width_m
	var middle = (a+b)*0.5
	middle.y = field.sample(middle.x,middle.z).height
	var corners: Array[float] = []
	# Four corner offsets conform both sides to the actual triangle surface.
	for end in [-1.0,1.0]:
		for side in [-1.0,1.0]:
			var point = middle+along*end*length_m*0.5+across*side*width*0.5
			corners.append(field.sample(point.x,point.z).height-middle.y)
	var depth: float = clampf(sim.snow_penetration+absf(sim.edge_angle)*.012,0.001,.10) if response==null else response.depth_m
	var displaced_side: float = .5 if response==null else .5+.5*signf(response.throw_world.dot(across))
	if live_index>=0:
		var transform_value = Transform3D(Basis(across*width,Vector3.UP,along*length_m),middle)
		live_transforms[live_index] = transform_value
		live_active[live_index] = true
		live_tracks.set_instance_transform(live_index,transform_value)
		live_tracks.set_instance_custom_data(live_index,Color(corners[0],corners[1],corners[2],corners[3]))
		# Negative slip marks the live section for a soft end cap in the shared
		# shader; retained history/GPU stamps continue to store ordinary slip.
		live_tracks.set_instance_color(live_index,Color(depth,-1.0-slip,displaced_side,response.crystal_density))
		return
	transforms[cursor] = Transform3D(Basis(across*width,Vector3.UP,along*length_m),middle)
	corner_history[cursor] = Color(corners[0],corners[1],corners[2],corners[3])
	appearance_history[cursor] = Color(depth,slip,displaced_side,1.0 if response==null else response.crystal_density)
	_upload(cursor)
	cursor = (cursor+1)%capacity
	written = mini(written+1,capacity)
	tracks.visible_instance_count = written

func _independent_contacts(sim, field, p: Vector3, active: bool, responses: Array) -> void:
	for i in range(2):
		if not active or sim.crashed or not responses[i].snow_contact:
			_hide_live(i)
			foot_history[i] = Vector3.INF
			continue
		var response = responses[i]
		var tail: Vector3 = response.contact_position-response.contact_forward*sim.tuning.ski_length*.5
		var tip: Vector3 = response.contact_position+response.contact_forward*(sim.tuning.ski_length*.5+.12)
		if not foot_history[i].is_finite() or tail.distance_to(foot_history[i])>8.0:
			foot_history[i] = tail
		var distance: float = tail.distance_to(foot_history[i])
		var steps = mini(12,floori(distance/SPACING_M))
		var start = foot_history[i]
		for step in range(1,steps+1):
			var next: Vector3 = start.lerp(tail,step*SPACING_M/distance)
			_stamp(field,foot_history[i],next,sim,responses[i])
			foot_history[i] = next
		_stamp(field,foot_history[i],tip,sim,response,i)
	last_position = p if active and sim.grounded and not sim.crashed else Vector3.INF

func _upload(index: int) -> void:
	tracks.set_instance_transform(index,transforms[index])
	tracks.set_instance_custom_data(index,corner_history[index])
	tracks.set_instance_color(index,appearance_history[index])
	if gpu_stamps.size()!=capacity*8: gpu_stamps.resize(capacity*8)
	var t = transforms[index]
	var a = t*Vector3(0,0,-.5)
	var b = t*Vector3(0,0,.5)
	var style = appearance_history[index]
	var values = [a.x,a.z,b.x,b.z,t.basis.x.length(),style.r,style.g,style.b*2.0-1.0]
	for j in 8: gpu_stamps[index*8+j] = values[j]
	if not gpu_full_upload:
		if not gpu_dirty_spans.is_empty() and gpu_dirty_spans[-1].x+gpu_dirty_spans[-1].y==index:
			gpu_dirty_spans[-1].y+=1
		else:
			gpu_dirty_spans.append(Vector2i(index,1))
		# Bound metadata while the powder consumer is disabled. A later full
		# synchronization is cheaper than retaining arbitrarily many wraps.
		if gpu_dirty_spans.size()>8:
			gpu_full_upload = true
			gpu_dirty_spans.clear()
	revision += 1

func take_gpu_updates(force_full: bool = false) -> Array:
	# The powder surface is the sole GPU-buffer consumer. Returned bytes own
	# their storage and remain immutable until the render-thread command runs.
	var updates: Array = []
	if force_full or gpu_full_upload:
		updates.append({"offset":0,"bytes":gpu_stamps.to_byte_array()})
	else:
		for span in gpu_dirty_spans:
			updates.append({"offset":span.x*32,"bytes":gpu_stamps.slice(span.x*8,(span.x+span.y)*8).to_byte_array()})
	gpu_full_upload = false
	gpu_dirty_spans.clear()
	return updates

func bind_surface(field) -> void:
	if field.has_method("build_material_map"):
		field.build_material_map()
		material.set_shader_parameter("contact_material_enabled",true)
		material.set_shader_parameter("contact_material",ImageTexture.create_from_image(field.material_image))
		material.set_shader_parameter("contact_material_origin",Vector2(field.X_MIN,field.Z_MIN))
		material.set_shader_parameter("contact_material_size",Vector2(field.NX,field.NZ))
	# One immutable upload per mountain, never a GPU readback or per-frame mesh edit.
	var bytes: PackedByteArray = field.heights.to_byte_array()
	surface_texture_bytes = bytes.size()
	var heights = Image.create_from_data(field.NX,field.NZ,false,Image.FORMAT_RF,bytes)
	material.set_shader_parameter("surface_heights",ImageTexture.create_from_image(heights))
	material.set_shader_parameter("surface_origin",Vector2(field.X_MIN,field.Z_MIN))
	material.set_shader_parameter("surface_size",Vector2i(field.NX,field.NZ))
	material.set_shader_parameter("exact_surface",true)

func apply_quality(profile) -> void:
	material.set_shader_parameter("relief_enabled",profile.snow_track_relief)
	profile.apply_snow_material(material,.35)
	tracks.mesh.subdivide_width = 15 if profile.level==2 else 7
	live_tracks.mesh.subdivide_width = tracks.mesh.subdivide_width
	live_tracks.mesh.subdivide_depth = 15 if profile.level==2 else 7
	if capacity==profile.snow_track_capacity: return
	# Keep the newest history when resizing; CPU mirrors avoid GPU synchronization.
	var old_transforms = transforms.duplicate()
	var old_corners = corner_history.duplicate()
	var old_appearance = appearance_history.duplicate()
	var keep = mini(written,profile.snow_track_capacity)
	var first = posmod(cursor-keep,capacity)
	var old_capacity = capacity
	capacity = profile.snow_track_capacity
	transforms.resize(capacity)
	corner_history.resize(capacity)
	appearance_history.resize(capacity)
	tracks.instance_count = capacity
	gpu_stamps.resize(capacity*8)
	gpu_stamps.fill(0.0)
	gpu_full_upload = true
	gpu_dirty_spans.clear()
	for i in range(keep):
		var old = (first+i)%old_capacity
		transforms[i] = old_transforms[old]
		corner_history[i] = old_corners[old]
		appearance_history[i] = old_appearance[old]
		_upload(i)
	written = keep
	cursor = keep%capacity
	tracks.visible_instance_count = written
