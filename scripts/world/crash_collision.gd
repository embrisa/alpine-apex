extends Node3D
const Obstacles = preload("res://scripts/world/obstacle_access.gd")
const WARM_RADIUS = 300.0
const WARM_BUDGET_US = 750
const WARM_PIECES_PER_FRAME = 8
## Reuses exact rendered terrain triangles and solver obstacle envelopes.
## Nearby collision is prepared during skiing; only ragdolls collide with it.
var world
var frame_costs
var terrain: Dictionary = {}
var obstacles: Dictionary = {}
var obstacle_centers: Dictionary = {}
var mineral_bodies: Dictionary = {}
var mineral_shapes: Dictionary = {}
var last_center = Vector3.INF
var warm_pending: Array = []
var warmed_shapes: Dictionary = {}
var warm_body: StaticBody3D
var warm_owner = 0
var warm_queue_peak = 0
var warm_piece_count = 0
var diagnostic_trees = true
var diagnostic_rocks = true

func set_diagnostic_filter(trees: bool, rocks: bool) -> void:
	if trees==diagnostic_trees and rocks==diagnostic_rocks: return
	diagnostic_trees = trees; diagnostic_rocks = rocks
	for body in obstacles.values(): _filter_body(body,body.get_meta("audio_material",2)==2)
	for body in mineral_bodies.values(): _filter_body(body,false)

func _filter_body(body: StaticBody3D, tree: bool) -> void:
	var enabled = diagnostic_trees if tree else diagnostic_rocks
	body.collision_layer = 8 if enabled else 0
	body.collision_mask = 16 if enabled else 0

func prepare(center: Vector3) -> void:
	if center.distance_to(last_center)<45.0:
		_warm_minerals()
		return
	last_center = center
	var p = Vector2(center.x,center.z)
	var started = frame_costs.begin() if frame_costs else 0
	for i in range(world.terrain_chunks.size()):
		var chunk: MeshInstance3D = world.terrain_chunks[i]
		var distance_value: float = p.distance_to(chunk.get_meta("terrain_center"))
		if distance_value<240.0 and not terrain.has(i):
			terrain[i] = _static(chunk.mesh.create_trimesh_shape(),Vector3.ZERO)
		elif distance_value>350.0 and terrain.has(i):
			terrain[i].queue_free()
			terrain.erase(i)
	if frame_costs: frame_costs.end(&"stream_collision_terrain",started)
	started = frame_costs.begin() if frame_costs else 0
	# Only new bodies need the inner publication query. Existing bodies already
	# have immutable horizontal positions and only need the retention check.
	# Preserve the exact strict 175/240 m boundaries and publication order.
	var nearby: Array = world.surface.nearby_obstacle_indices(center,175.0)
	for i in nearby:
		if obstacles.has(i): continue
		var position_value = Obstacles.position(world.surface,i)
		var horizontal = Vector2(position_value.x,position_value.z)
		if p.distance_to(horizontal)>=175.0: continue
		var obstacle: Dictionary = Obstacles.record(world.surface,i)
		var shape = CylinderShape3D.new()
		shape.radius = obstacle.radius
		shape.height = obstacle.height
		obstacles[i] = _static(shape,obstacle.position+Vector3.UP*obstacle.height*.5)
		obstacle_centers[i] = horizontal
		obstacles[i].set_meta("audio_material",2 if obstacle.get("tree",false) else 1)
		_filter_body(obstacles[i],obstacle.get("tree",false))
	for i in obstacles.keys():
		if p.distance_to(obstacle_centers[i])>240.0:
			obstacles[i].queue_free()
			obstacles.erase(i); obstacle_centers.erase(i)
	if frame_costs: frame_costs.end(&"stream_collision_obstacles",started)
	started = frame_costs.begin() if frame_costs else 0
	_prepare_minerals(center)
	if frame_costs: frame_costs.end(&"stream_collision_minerals",started)
	_queue_mineral_warmup(center)
	_warm_minerals()

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
		if not mineral_shapes.has(entry.record) or mineral_shapes[entry.record].size()<geology.catalog.records[entry.record].hull_points.size():
			var shape_started = frame_costs.begin() if frame_costs else 0
			if not mineral_shapes.has(entry.record): mineral_shapes[entry.record]=[]
			var pieces: Array = geology.catalog.records[entry.record].hull_points
			for piece in range(mineral_shapes[entry.record].size(),pieces.size()):
				var shape=ConvexPolygonShape3D.new()
				shape.points=pieces[piece]
				mineral_shapes[entry.record].append(shape)
			if frame_costs: frame_costs.end(&"stream_collision_convex_shapes",shape_started)
		var body=StaticBody3D.new()
		body.name="Mineral_%d" % entry.id
		body.set_meta("audio_material",1)
		_filter_body(body,false)
		# One owner holds all shared convex resources. Thousands of child Nodes
		# per cliff add no collision information and cause avoidable allocation spikes.
		var owner=body.create_shape_owner(body)
		for shape in mineral_shapes[entry.record]:
			body.shape_owner_add_shape(owner,shape)
		add_child(body); body.transform=entry.pose
		mineral_bodies[entry.id]=body
		warmed_shapes[entry.record]=mineral_shapes[entry.record].size()
	for id in mineral_bodies.keys():
		if not wanted.has(id):
			mineral_bodies[id].queue_free(); mineral_bodies.erase(id)

func _queue_mineral_warmup(center: Vector3) -> void:
	warm_pending.clear()
	if not "geology" in world.surface: return
	var started = frame_costs.begin() if frame_costs else 0
	var geology = world.surface.geology
	var distances: Dictionary = {}
	for index in geology.collision.candidates(center,center,WARM_RADIUS):
		var entry: Dictionary = geology.collision.entries[index]
		if warmed_shapes.get(entry.record,0)>=geology.catalog.records[entry.record].hull_points.size(): continue
		var box: AABB = entry.aabb
		var closest = Vector3(clampf(center.x,box.position.x,box.end.x),clampf(center.y,box.position.y,box.end.y),clampf(center.z,box.position.z,box.end.z))
		var distance_sq = center.distance_squared_to(closest)
		if distance_sq>WARM_RADIUS*WARM_RADIUS: continue
		distances[entry.record] = minf(distance_sq,distances.get(entry.record,INF))
	warm_pending = distances.keys()
	warm_pending.sort_custom(func(a,b): return distances[a]<distances[b])
	warm_queue_peak = maxi(warm_queue_peak,warm_pending.size())
	if frame_costs: frame_costs.end(&"stream_collision_prefetch_scan",started)

func _warm_minerals() -> void:
	if warm_pending.is_empty(): return
	var started = Time.get_ticks_usec()
	if warm_body==null:
		# The one reusable body has no collision layer or mask. Attaching an
		# individual shared shape asks Jolt to cook it on the supported main
		# thread; clearing the owner retains that cooked cache in the Shape3D.
		warm_body = StaticBody3D.new()
		warm_body.collision_layer = 0; warm_body.collision_mask = 0
		add_child(warm_body); warm_owner = warm_body.create_shape_owner(warm_body)
	var count = 0
	while not warm_pending.is_empty() and count<WARM_PIECES_PER_FRAME:
		var record: String = warm_pending[0]
		var points: Array = world.surface.geology.catalog.records[record].hull_points
		var piece: int = warmed_shapes.get(record,0)
		if piece>=points.size(): warm_pending.pop_front(); continue
		if not mineral_shapes.has(record): mineral_shapes[record]=[]
		if mineral_shapes[record].size()<=piece:
			var shape = ConvexPolygonShape3D.new(); shape.points = points[piece]
			mineral_shapes[record].append(shape)
		warm_body.shape_owner_add_shape(warm_owner,mineral_shapes[record][piece])
		warm_body.shape_owner_clear_shapes(warm_owner)
		warmed_shapes[record]=piece+1; count+=1; warm_piece_count+=1
		if piece+1==points.size(): warm_pending.pop_front()
		# A single native convex cook cannot be interrupted. The budget limits
		# subsequent work; required bodies still have the immediate path above.
		if Time.get_ticks_usec()-started>=WARM_BUDGET_US: break
	if frame_costs: frame_costs.end(&"stream_collision_prefetch_shapes",started)

func report() -> Dictionary:
	var pieces = 0; var point_bytes = 0
	for shapes in mineral_shapes.values():
		pieces += shapes.size()
		for shape in shapes: point_bytes += shape.points.size()*12
	return {"terrain_bodies":terrain.size(),"obstacle_bodies":obstacles.size(),"mineral_bodies":mineral_bodies.size(),"shape_records":mineral_shapes.size(),"shape_pieces":pieces,"shape_point_bytes":point_bytes,"pending_records":warm_pending.size(),"queue_peak_records":warm_queue_peak,"warmed_pieces":warm_piece_count}

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
