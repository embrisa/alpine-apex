extends RefCounted
## Test-only feasibility search. Every edge uses the retained survey's physical
## clearance, gradient and exposed-rock limits; never imported by generation.
const Survey = preload("res://tests/alpine_v13_route_survey.gd")
const OFFSETS = [Vector2i(-1,0),Vector2i(1,0),Vector2i(-2,-1),Vector2i(0,-1),Vector2i(2,-1),Vector2i(-2,1),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)]
static func survey(field, face_index: int, node_clearance: float = 1.8, edge_clearance: float = 1.5) -> Dictionary:
	var paths: Array = []; var visited = 0
	for side in [-1,1]:
		var result = _search(field,face_index,side,node_clearance,edge_clearance)
		if result.path.is_empty(): return Survey.survey(field,face_index,node_clearance,edge_clearance)
		paths.append(result.path); visited += result.visited
	return {"face":face_index,"paths":paths,"safe_samples":visited,"refinement":1,"search":"bounded feasibility"}

static func _search(field, face_index: int, side: int, node_clearance: float, edge_clearance: float) -> Dictionary:
	var face = field.faces[face_index]; var size = Survey.WIDTH*Survey.ROWS
	var heights = PackedFloat32Array(); heights.resize(size)
	var state = PackedByteArray(); state.resize(size)
	var closed = PackedByteArray(); closed.resize(size)
	var cost = PackedFloat32Array(); cost.resize(size); cost.fill(INF)
	var hard = PackedFloat32Array(); hard.resize(size)
	var parent = PackedInt32Array(); parent.resize(size); parent.fill(-1)
	var heap: Array[Vector2] = []
	for column in range(Survey.WIDTH/2-1,Survey.WIDTH/2+2):
		if not _valid(field,face,column,state,heights,node_clearance): continue
		cost[column] = 0; _push(heap,Vector2(_estimate(column,side),column))
	var visited = 0; var found = -1
	while not heap.is_empty() and visited<50000:
		var prior = int(_pop(heap).y)
		if closed[prior]: continue
		closed[prior] = 1; visited += 1
		var row = prior/Survey.WIDTH; var column = prior%Survey.WIDTH
		var q = Survey.position_at(column,row)
		if row==Survey.ROWS-1 and q.x*side>=250: found = prior; break
		var before: Vector2 = face.to_world(q)
		for offset in OFFSETS:
			var x = column+offset.x; var z = row+offset.y
			if x<0 or x>=Survey.WIDTH or z<0 or z>=Survey.ROWS: continue
			var id = z*Survey.WIDTH+x
			if closed[id] or not _valid(field,face,id,state,heights,node_clearance): continue
			var drop = heights[prior]-heights[id]
			if drop<.2: continue
			var p: Vector2 = face.to_world(Survey.position_at(x,z)); var distance_m = p.distance_to(before)
			if drop>distance_m*1.5: continue
			var exposed = Survey.edge_rock_distance(field,before,p,edge_clearance)
			if exposed<0: continue
			var run_length = hard[prior]+exposed if exposed>0 else 0.0
			if run_length>30: continue
			var candidate = cost[prior]+distance_m/Survey.STEP+pow(drop/distance_m-.58,2)*.4+exposed*.12
			if candidate>=cost[id]: continue
			cost[id] = candidate; parent[id] = prior
			hard[id] = run_length if field.rock_fraction_at(p.x,p.y)>.42 else 0.0
			_push(heap,Vector2(candidate+_estimate(id,side),id))
	var path: Array[Vector2] = []
	while found>=0:
		path.append(Survey.position_at(found%Survey.WIDTH,found/Survey.WIDTH)); found = parent[found]
	path.reverse(); return {"path":path,"visited":visited}

static func _valid(field, face, id: int, state: PackedByteArray, heights: PackedFloat32Array, node_clearance: float) -> bool:
	if state[id]: return state[id]==1
	state[id] = 2
	var q = Survey.position_at(id%Survey.WIDTH,id/Survey.WIDTH)
	if absf(q.x)>q.y*.68: return false
	var p: Vector2 = face.to_world(q); heights[id] = field.height_at(p.x,p.y)
	if field.contact_normal(p.x,p.y).y<.60 or not Survey.clear_at(field,p,node_clearance): return false
	state[id] = 1; return true

static func _estimate(id: int, side: int) -> float:
	var q = Survey.position_at(id%Survey.WIDTH,id/Survey.WIDTH)
	return Vector2(maxf(0,250-q.x*side),Survey.Z_MIN+(Survey.ROWS-1)*Survey.STEP-q.y).length()/Survey.STEP*1.25

static func _push(heap: Array[Vector2], item: Vector2) -> void:
	heap.append(item); var i = heap.size()-1
	while i>0:
		var parent = (i-1)/2
		if heap[parent].x<=item.x: break
		heap[i] = heap[parent]; i = parent
	heap[i] = item

static func _pop(heap: Array[Vector2]) -> Vector2:
	var result = heap[0]; var last: Vector2 = heap.pop_back()
	if heap.is_empty(): return result
	var i = 0
	while i*2+1<heap.size():
		var child = i*2+1
		if child+1<heap.size() and heap[child+1].x<heap[child].x: child += 1
		if last.x<=heap[child].x: break
		heap[i] = heap[child]; i = child
	heap[i] = last; return result
