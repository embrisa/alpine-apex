extends SceneTree
const Crash = preload("res://scripts/world/crash_collision.gd")
const Collision = preload("res://scripts/world/mineral_collision.gd")
var failures = []; var checks = 0
class Field:
	extends RefCounted
	var geology = {"collision":Collision.new(),"catalog":{"records":{}}}
	var obstacles: Array = []
	func nearby_obstacle_indices(p: Vector3, radius: float) -> Array:
		var ids = []
		for i in obstacles.size():
			if Vector2(p.x,p.z).distance_to(Vector2(obstacles[i].position.x,obstacles[i].position.z))<=radius: ids.append(i)
		return ids
class World:
	extends Node3D
	var surface = Field.new()
	var terrain_chunks: Array[MeshInstance3D] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = World.new(); root.add_child(world)
	var points = PackedVector3Array()
	for x in [-1,1]:
		for y in [-1,1]:
			for z in [-1,1]: points.append(Vector3(x,y,z))
	var record = {"id":"cube","aabb":AABB(-Vector3.ONE,Vector3.ONE*2),"hull_points":[points],"hull_axes":[{"normals":[[1,0,0],[0,1,0],[0,0,1]],"edges":[[1,0,0],[0,1,0],[0,0,1]]}]}
	world.surface.geology.catalog.records.cube = record
	var poses = [Transform3D(Basis(Vector3.UP,.7).scaled(Vector3(2,3,4)),Vector3(160,5,0)),Transform3D(Basis.IDENTITY,Vector3(340,5,0))]
	for i in poses.size(): world.surface.geology.collision.add({"id":i,"pose":poses[i],"solid":true},record)
	for x in [0.0,256.0]:
		var node = MeshInstance3D.new(); var mesh = ArrayMesh.new(); var arrays = []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(x-128,0,-128),Vector3(x+128,0,-128),Vector3(x-128,0,128),Vector3(x+128,0,128)])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,1,3,2]); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		node.mesh = mesh; node.set_meta("terrain_center",Vector2(x,0)); world.add_child(node); world.terrain_chunks.append(node)
	var crash = Crash.new(); crash.world = world; root.add_child(crash)
	crash.prepare(Vector3.ZERO)
	check(crash.terrain.keys()==[0],"Initial terrain window has the authoritative near chunk")
	check(crash.terrain[0].get_child(0).shape.get_faces()==world.terrain_chunks[0].mesh.get_faces(),"Ragdoll terrain preserves the exact authoritative triangles")
	check(crash.mineral_bodies.keys()==[0],"Initial mineral window has the required formation only")
	check(crash.mineral_bodies[0].transform.is_equal_approx(poses[0]),"Rotated nonuniform mineral pose is preserved")
	var body = crash.mineral_bodies[0]
	check(body.shape_owner_get_shape_count(body.get_shape_owners()[0])==record.hull_points.size(),"All authoritative convex pieces are published")
	check(body.shape_owner_get_shape(body.get_shape_owners()[0],0).points==points,"Convex point bytes are unchanged")
	check(body.collision_layer==8 and body.collision_mask==16,"Ragdoll layer and mask stay isolated from skiing")
	await physics_frame; await physics_frame
	var hit = root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(160,20,0),Vector3(160,-20,0),8))
	check(not hit.is_empty() and hit.collider==body,"Scaled mineral collision is immediately available to a crash")
	crash.prepare(Vector3(180,0,0))
	check(crash.terrain.size()==2 and crash.mineral_bodies.size()==2,"Crossing a preparation boundary supplies both neighborhoods")
	crash.prepare(Vector3(1000,0,0)); await process_frame
	check(crash.terrain.is_empty() and crash.mineral_bodies.is_empty(),"Fast travel retires all out-of-window bodies")
	for i in 3:
		crash.prepare(Vector3.ZERO); check(crash.mineral_bodies.size()==1 and crash.terrain.size()==1,"Reverse travel restores exact coverage without duplicates")
		crash.prepare(Vector3(1000,0,0)); await process_frame
	check(crash.mineral_shapes.size()==1,"Repeated entries retain only the shared catalog shape")
	crash.queue_free(); world.queue_free(); await process_frame
	world = World.new(); root.add_child(world)
	var composite = record.duplicate(true); composite.id = "prefetch"
	for i in 31:
		composite.hull_points.append(points); composite.hull_axes.append(record.hull_axes[0])
	world.surface.geology.catalog.records.prefetch = composite
	world.surface.geology.collision.add({"id":4,"pose":Transform3D(Basis.IDENTITY,Vector3(220,5,0)),"solid":true},composite)
	crash = Crash.new(); crash.world = world; root.add_child(crash)
	crash.prepare(Vector3.ZERO)
	check(crash.mineral_bodies.is_empty(),"Prefetch does not publish distant collision bodies")
	check(crash.warm_piece_count>0 and crash.warm_piece_count<=Crash.WARM_PIECES_PER_FRAME,"One prefetch update respects the piece ceiling")
	check(crash.warm_body.collision_layer==0 and crash.warm_body.collision_mask==0 and crash.warm_body.shape_owner_get_shape_count(crash.warm_owner)==0,"Warmup body has no collidable shapes or interaction layers")
	crash.prepare(Vector3(1000,0,0))
	check(crash.warm_pending.is_empty(),"Discontinuity cancels obsolete pending records")
	crash.prepare(Vector3.ZERO)
	for i in 40: crash.prepare(Vector3.ZERO)
	check(crash.warm_pending.is_empty() and crash.warmed_shapes.prefetch==32,"A stationary queue drains without starvation")
	check(crash.warm_queue_peak==1,"Shared records are queued only once")
	crash.prepare(Vector3(100,0,0))
	check(crash.mineral_bodies.size()==1 and crash.mineral_bodies[4].shape_owner_get_shape_count(crash.mineral_bodies[4].get_shape_owners()[0])==32,"Prepared boundary publishes every convex piece together")
	crash.queue_free(); await process_frame
	crash = Crash.new(); crash.world = world; root.add_child(crash)
	crash.prepare(Vector3.ZERO); crash.prepare(Vector3(100,0,0))
	check(crash.mineral_bodies[4].shape_owner_get_shape_count(crash.mineral_bodies[4].get_shape_owners()[0])==32,"Fast entry completes partially warmed collision immediately")
	crash.queue_free(); world.queue_free(); await process_frame
	# Exercise the position-only resident path, new publication and retirement.
	world = World.new(); root.add_child(world)
	world.surface.obstacles = [{"position":Vector3(160,2,0),"radius":.4,"height":12.0,"tree":true},{"position":Vector3(340,3,0),"radius":1.2,"height":3.0,"tree":false}]
	crash = Crash.new(); crash.world = world; root.add_child(crash)
	crash.prepare(Vector3.ZERO)
	var first = crash.obstacles[0]
	check(crash.obstacles.keys()==[0] and first.position==Vector3(160,8,0),"Obstacle publication keeps the original 175 m window and centered cylinder")
	check(is_equal_approx(first.get_child(0).shape.radius,.4) and first.get_child(0).shape.height==12.0 and first.get_meta("audio_material")==2,"Tree radius, height and audio identity are unchanged")
	crash.prepare(Vector3(180,0,0))
	check(crash.obstacles.size()==2 and crash.obstacles[0]==first and crash.obstacles[1].get_meta("audio_material")==1,"Resident bodies are reused while new rock envelopes retain their identity")
	crash.set_diagnostic_filter(false,true)
	check(first.collision_layer==0 and crash.obstacles[1].collision_layer==8,"Diagnostic tree/rock filters remain independent")
	crash.prepare(Vector3(1000,0,0)); await process_frame
	check(crash.obstacles.is_empty(),"Discontinuous travel retires resident obstacles outside the query window")
	crash.prepare(Vector3.ZERO)
	check(crash.obstacles.keys()==[0] and crash.obstacles[0].collision_layer==0,"Reverse entry restores exact filtered coverage without duplicates")
	crash.queue_free(); world.queue_free(); await process_frame
	print("STREAMING_COLLISION ",JSON.stringify({"checks":checks,"failures":failures})); quit(0 if failures.is_empty() else 1)
