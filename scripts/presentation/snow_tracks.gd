extends Node3D
## Distance-sampled paired ribbons. Rendering history never feeds ski contact.
const CAPACITY = 800
const SPACING_M = 0.70
const HALF_STANCE_M = 0.22
var tracks: MultiMesh
var cursor: int = 0
var written: int = 0
var last_position = Vector3.INF
var last_right = Vector3.RIGHT
var foot_history: Array[Vector3] = [Vector3.INF,Vector3.INF]
var lighting

func _ready() -> void:
	tracks = MultiMesh.new()
	tracks.transform_format = MultiMesh.TRANSFORM_3D
	tracks.use_custom_data = true
	tracks.use_colors = true
	var ribbon = PlaneMesh.new()
	ribbon.size = Vector2.ONE
	ribbon.subdivide_width = 15
	ribbon.subdivide_depth = 1
	var material = ShaderMaterial.new()
	material.shader = preload("res://assets/graphics/ski_track.gdshader")
	lighting.register(material)
	ribbon.material = material
	tracks.mesh = ribbon
	tracks.instance_count = CAPACITY
	var instance = MultiMeshInstance3D.new()
	instance.multimesh = tracks
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 0.3
	add_child(instance)
	reset()

func reset() -> void:
	last_position = Vector3.INF
	foot_history = [Vector3.INF,Vector3.INF]
	cursor = 0
	written = 0
	if tracks:
		tracks.visible_instance_count = 0

func update_contact(sim, field, p: Vector3, active: bool) -> void:
	if sim.contacts_initialized:
		_independent_contacts(sim,field,p,active)
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

func _stamp(field, a: Vector3, b: Vector3, sim, depth_override: float = -1.0) -> void:
	var along = Vector3(b.x-a.x,0,b.z-a.z)
	var length_m = along.length()
	if length_m<0.01: return
	along /= length_m
	var across = Vector3.UP.cross(along)
	var slip: float = absf(sin(sim.slip_angle))
	var width = 0.24 + slip * 0.30
	var middle = (a+b)*0.5
	middle.y = field.sample(middle.x,middle.z).height
	var corners: Array[float] = []
	# Four corner offsets conform both sides to the actual triangle surface.
	for end in [-1.0,1.0]:
		for side in [-1.0,1.0]:
			var point = middle+along*end*length_m*0.5+across*side*width*0.5
			corners.append(field.sample(point.x,point.z).height-middle.y)
	tracks.set_instance_transform(cursor,Transform3D(Basis(across*width,Vector3.UP,along*length_m),middle))
	tracks.set_instance_custom_data(cursor,Color(corners[0],corners[1],corners[2],corners[3]))
	var depth: float = clampf((sim.snow_penetration if depth_override<0.0 else depth_override)+absf(sim.edge_angle)*0.012,0.008,0.085)
	tracks.set_instance_color(cursor,Color(depth,slip,0,1))
	cursor = (cursor+1)%CAPACITY
	written = mini(written+1,CAPACITY)
	tracks.visible_instance_count = written

func _independent_contacts(sim, field, p: Vector3, active: bool) -> void:
	for i in range(2):
		var ski = sim.skis[i]
		if not active or sim.crashed or not ski.grounded or ski.load_n<1.0:
			foot_history[i] = Vector3.INF
			continue
		var tail: Vector3 = ski.position+(p-sim.position)-ski.forward*.65
		if not foot_history[i].is_finite() or tail.distance_to(foot_history[i])>8.0:
			foot_history[i] = tail
			continue
		var distance: float = tail.distance_to(foot_history[i])
		var steps = mini(12,floori(distance/SPACING_M))
		var start = foot_history[i]
		for step in range(1,steps+1):
			var next: Vector3 = start.lerp(tail,step*SPACING_M/distance)
			_stamp(field,foot_history[i],next,sim,ski.penetration)
			foot_history[i] = next
	last_position = p if active and sim.grounded and not sim.crashed else Vector3.INF
