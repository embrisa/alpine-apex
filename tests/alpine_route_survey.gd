extends RefCounted
## Test-only coarse downhill graph, sampled from final support/material/obstacles.
## The generator and game never import this planner or its paths.
const STEP = 24.0
const X_STEP = 12.0
const WIDTH = 241
const ROWS = 116
const X_MIN = -1440.0
const Z_MIN = 24.0

static func position_at(column: int,row: int) -> Vector2:
	return Vector2(X_MIN+column*X_STEP,Z_MIN+row*STEP)

static func survey(field,face_index: int) -> Dictionary:
	var face = field.faces[face_index]
	var size = WIDTH*ROWS
	var h = PackedFloat32Array(); h.resize(size)
	var valid = PackedByteArray(); valid.resize(size)
	var cost = PackedFloat32Array(); cost.resize(size); cost.fill(INF)
	var parent = PackedInt32Array(); parent.resize(size); parent.fill(-1)
	var reachable = PackedByteArray(); reachable.resize(size)
	var hard_run = PackedFloat32Array(); hard_run.resize(size)
	var rock_values = PackedFloat32Array(); rock_values.resize(size)
	var safe_count = 0
	for row in ROWS:
		for column in WIDTH:
			var q = position_at(column,row)
			if absf(q.x)>q.y*.68: continue
			var p: Vector2 = face.to_world(q)
			var id = row*WIDTH+column
			h[id] = field.sample(p.x,p.y).height
			rock_values[id] = field.rock_fraction_at(p.x,p.y)
			if field.contact_normal(p.x,p.y).y<.60: continue
			if not clear_at(field,p,3.0): continue
			valid[id] = 1
			safe_count += 1
	# Multiple summit launch headings are valid; no generator centreline is used.
	for column in WIDTH:
		if valid[column]: cost[column] = absf(position_at(column,0).x)*.01
	# Order by actual height, not face-local Z: a downhill traverse may cross
	# a row or briefly move back toward the summit in plan without going uphill.
	var ordered: Array[int] = []
	var predecessors = PackedInt32Array(); predecessors.resize(size)
	for id in size:
		if valid[id]: ordered.append(id)
	ordered.sort_custom(func(a,b): return h[a]>h[b])
	for prior in ordered:
		if not is_finite(cost[prior]): continue
		var row = prior/WIDTH
		var column = prior%WIDTH
		var before: Vector2 = face.to_world(position_at(column,row))
		for offset in [Vector2i(-1,0),Vector2i(1,0),Vector2i(-2,-1),Vector2i(0,-1),Vector2i(2,-1),Vector2i(-2,1),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)]:
			var next_column = column+offset.x
			var next_row = row+offset.y
			if next_column<0 or next_column>=WIDTH or next_row<0 or next_row>=ROWS: continue
			var id = next_row*WIDTH+next_column
			if not valid[id]: continue
			var drop = h[prior]-h[id]
			if drop<.2: continue
			var p: Vector2 = face.to_world(position_at(next_column,next_row))
			var distance_m = before.distance_to(p)
			if drop>distance_m*1.5: continue
			var exposed_distance = edge_rock_distance(field,before,p)
			if exposed_distance<0: continue
			var run_length = hard_run[prior]+exposed_distance if exposed_distance>0 else 0.0
			if run_length>30: continue
			predecessors[id] += 1
			var candidate = cost[prior]+distance_m/STEP+pow(drop/distance_m-.58,2)*.4+exposed_distance*.12
			if candidate<cost[id]:
				cost[id] = candidate
				parent[id] = prior
				hard_run[id] = run_length if rock_values[id]>.42 else 0.0
	var row_widths: Array = []
	var splits = 0
	for row in range(1,ROWS):
		var width = 0
		for column in WIDTH:
			var id = row*WIDTH+column
			if is_finite(cost[id]): width += 1
			if predecessors[id]>1: splits += 1
		row_widths.append(width)
	var paths: Array = []
	for side in [-1,1]:
		var best = -1
		var best_cost = INF
		for column in WIDTH:
			var id = (ROWS-1)*WIDTH+column
			var target_cost = cost[id]+absf(position_at(column,ROWS-1).x-side*1200)*2.0
			if target_cost<best_cost:
				best = id; best_cost = target_cost
		var path: Array[Vector2] = []
		while best>=0:
			path.append(position_at(best%WIDTH,best/WIDTH))
			reachable[best] = 1
			best = parent[best]
		path.reverse()
		paths.append(path)
	return {"face":face_index,"safe_samples":safe_count,"reachable_columns":row_widths,"merge_nodes":splits,"paths":paths}

static func clear_at(field,p: Vector2,radius: float) -> bool:
	if not field.geology_clear(Vector3(p.x,0,p.y),radius): return false
	var search_radius = radius+2.0
	for z in range(floori((p.y-search_radius)/field.SPATIAL_CELL),floori((p.y+search_radius)/field.SPATIAL_CELL)+1):
		for x in range(floori((p.x-search_radius)/field.SPATIAL_CELL),floori((p.x+search_radius)/field.SPATIAL_CELL)+1):
			for id in field.obstacle_grid.get(Vector2i(x,z),[]):
				var ob = field.obstacles[id]
				if p.distance_squared_to(Vector2(ob.position.x,ob.position.z))<pow(radius+ob.radius,2): return false
	return true

static func edge_rock_distance(field,a: Vector2,b: Vector2) -> float:
	var exposed = 0.0
	for i in range(1,6):
		var p = a.lerp(b,float(i)/6)
		if not clear_at(field,p,2.5): return -1.0
		if field.rock_fraction_at(p.x,p.y)>.5: exposed += .2
	return exposed*a.distance_to(b)
