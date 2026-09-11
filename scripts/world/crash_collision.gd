extends Node3D
const Obstacles = preload("res://scripts/world/obstacle_access.gd")
## Reuses exact rendered terrain triangles and solver obstacle envelopes.
## Nearby collision is prepared during skiing; only ragdolls collide with it.
var world
var terrain: Dictionary = {}
var obstacles: Dictionary = {}
var mineral_bodies: Dictionary = {}
var mineral_shapes: Dictionary = {}
var last_center = Vector3.INF

func prepare(center: Vector3) -> void:
	if center.distance_to(last_center)<45.0: return
	last_center = center
	var p = Vector2(center.x,center.z)
	for i in range(world.terrain_chunks.size()):
		var chunk: MeshInstance3D = world.terrain_chunks[i]
		var distance_value: float = p.distance_to(chunk.get_meta("terrain_center"))
		if distance_value<240.0 and not terrain.has(i):
			terrain[i] = _static(chunk.mesh.create_trimesh_shape(),Vector3.ZERO)
		elif distance_value>350.0 and terrain.has(i):
			terrain[i].queue_free()
			terrain.erase(i)
	var nearby: Array=world.surface.nearby_obstacle_indices(center,240.0)
	# Include resident bodies to retire those left behind after a long teleport.
	var candidates: Dictionary={}
	for i in nearby: candidates[i]=true
	for i in obstacles: candidates[i]=true
	for i in candidates:
		var obstacle: Dictionary = Obstacles.record(world.surface,i)
		var distance_value = p.distance_to(Vector2(obstacle.position.x,obstacle.position.z))
		if distance_value<175.0 and not obstacles.has(i):
			var shape = CylinderShape3D.new()
			shape.radius = obstacle.radius
			shape.height = obstacle.height
			obstacles[i] = _static(shape,obstacle.position+Vector3.UP*obstacle.height*.5)
			obstacles[i].set_meta("audio_material",2 if obstacle.get("tree",false) else 1)
		elif distance_value>240.0 and obstacles.has(i):
			obstacles[i].queue_free()
			obstacles.erase(i)
	_prepare_minerals(center)

func _prepare_minerals(center: Vector3) -> void:
	if not "geology" in world.surface: return
	var geology=world.surface.geology
	var wanted: Dictionary={}
	for index in geology.collision.candidates(center,center,240):
		var entry: Dictionary=geology.collision.entries[index]
		var box: AABB=entry.aabb
		var closest=Vector3(clampf(center.x,box.position.x,box.end.x),clampf(center.y,box.position.y,box.end.y),clampf(center.z,box.position.z,box.end.z))
		var distance_m=center.distance_to(closest)
		if distance_m>240: continue
		wanted[entry.id]=true
		if mineral_bodies.has(entry.id) or distance_m>175: continue
		if not mineral_shapes.has(entry.record):
			mineral_shapes[entry.record]=[]
			for points in geology.catalog.records[entry.record].hull_points:
				var shape=ConvexPolygonShape3D.new()
				shape.points=points
				mineral_shapes[entry.record].append(shape)
		var body=StaticBody3D.new()
		body.name="Mineral_%d" % entry.id
		body.set_meta("audio_material",1)
		body.collision_layer=8; body.collision_mask=16
		# One owner holds all shared convex resources. Thousands of child Nodes
		# per cliff add no collision information and cause avoidable allocation spikes.
		var owner=body.create_shape_owner(body)
		for shape in mineral_shapes[entry.record]:
			body.shape_owner_add_shape(owner,shape)
		add_child(body); body.transform=entry.pose
		mineral_bodies[entry.id]=body
	for id in mineral_bodies.keys():
		if not wanted.has(id):
			mineral_bodies[id].queue_free(); mineral_bodies.erase(id)

func _static(shape: Shape3D, origin: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.set_meta("audio_material",0)
	body.collision_layer = 8
	body.collision_mask = 16
	var collider = CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	body.position = origin
	return body
