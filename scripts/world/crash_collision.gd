extends Node3D
## Reuses exact rendered terrain triangles and solver obstacle envelopes.
## Nearby collision is prepared during skiing; only ragdolls collide with it.
var world
var terrain: Dictionary = {}
var obstacles: Dictionary = {}
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
	for i in range(world.surface.obstacles.size()):
		var obstacle: Dictionary = world.surface.obstacles[i]
		var distance_value = p.distance_to(Vector2(obstacle.position.x,obstacle.position.z))
		if distance_value<175.0 and not obstacles.has(i):
			var shape = CylinderShape3D.new()
			shape.radius = obstacle.radius
			shape.height = obstacle.height
			obstacles[i] = _static(shape,obstacle.position+Vector3.UP*obstacle.height*.5)
		elif distance_value>240.0 and obstacles.has(i):
			obstacles[i].queue_free()
			obstacles.erase(i)

func _static(shape: Shape3D, origin: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.collision_layer = 8
	body.collision_mask = 16
	var collider = CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	body.position = origin
	return body
