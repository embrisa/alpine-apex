extends RefCounted
## Continuous SAT for an upright moving box against frozen convex pieces.
## Includes face and edge axes: no oversized cylinder/box around a hollow cliff.
const CELL_M = 64.0
var entries: Array = []
var grid: Dictionary = {}

func add(placement: Dictionary, record: Dictionary) -> void:
	if not placement.get("solid",true): return
	var pose: Transform3D = placement.pose
	var entry = {"id":placement.id,"pose":pose,"aabb":pose*record.aabb,"hulls":[],"vertices":[],"source":record,"hull_bounds":[],"hull_bvh":[],"record":record.id}
	for i in record.hull_points.size():
		var vertices = PackedVector3Array()
		for p in record.hull_points[i]: vertices.append(pose.basis*p)
		var piece_box=AABB(vertices[0],Vector3.ZERO)
		for p in vertices: piece_box=piece_box.expand(p)
		entry.hull_bounds.append(piece_box)
		entry.vertices.append(vertices)
		entry.hulls.append(PackedFloat32Array())
	_build_hull_bvh(entry.hull_bounds,range(entry.hulls.size()),entry.hull_bvh)
	var proxy_box: AABB=entry.hull_bvh[0].box
	entry.aabb=entry.aabb.merge(AABB(proxy_box.position+pose.origin,proxy_box.size))
	var index = entries.size()
	entries.append(entry)
	var box: AABB = entry.aabb.grow(.5)
	for z in range(floori(box.position.z/CELL_M),floori(box.end.z/CELL_M)+1):
		for x in range(floori(box.position.x/CELL_M),floori(box.end.x/CELL_M)+1):
			var key = Vector2i(x,z)
			if not grid.has(key): grid[key] = []
			grid[key].append(index)

func _spans(entry: Dictionary, piece: int) -> PackedFloat32Array:
	if not entry.hulls[piece].is_empty(): return entry.hulls[piece]
	var vertices: PackedVector3Array=entry.vertices[piece]
	var axes: Array[Vector3] = [Vector3.RIGHT,Vector3.UP,Vector3.BACK]
	for v in entry.source.hull_axes[piece].normals:
		axes.append((entry.pose.basis*Vector3(v[0],v[1],v[2])).normalized())
	for v in entry.source.hull_axes[piece].edges:
		var edge = entry.pose.basis*Vector3(v[0],v[1],v[2])
		for direction in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
			var axis = edge.cross(direction)
			if axis.length_squared()>.000001: axes.append(axis.normalized())
	var unique: Dictionary = {}
	var spans = PackedFloat32Array()
	for axis in axes:
		if axis.x<-.00001 or (absf(axis.x)<.00001 and (axis.y<-.00001 or (absf(axis.y)<.00001 and axis.z<0))): axis = -axis
		var key = Vector3i((axis*10000).round())
		if unique.has(key): continue
		unique[key] = true
		var low = INF; var high = -INF
		for p in vertices:
			var d = axis.dot(p); low=minf(low,d); high=maxf(high,d)
		spans.append_array(PackedFloat32Array([axis.x,axis.y,axis.z,low,high]))
	entry.hulls[piece]=spans
	return spans

func candidates(from: Vector3, to: Vector3, padding: float = .4) -> Dictionary:
	var result: Dictionary = {}
	for z in range(floori((minf(from.z,to.z)-padding)/CELL_M),floori((maxf(from.z,to.z)+padding)/CELL_M)+1):
		for x in range(floori((minf(from.x,to.x)-padding)/CELL_M),floori((maxf(from.x,to.x)+padding)/CELL_M)+1):
			for index in grid.get(Vector2i(x,z),[]): result[index] = true
	return result

func sweep(from: Vector3, to: Vector3, half: Vector3 = Vector3(.35,.8,.35), offset: Vector3 = Vector3(0,.8,0)) -> Dictionary:
	var closest: Dictionary = {}
	var earliest = INF
	for index in candidates(from,to,maxf(half.x,half.z)):
		var entry = entries[index]
		var a: Vector3 = from+offset-entry.pose.origin
		var b: Vector3 = to+offset-entry.pose.origin
		var broad: AABB = entry.aabb.grow(maxf(half.x,maxf(half.y,half.z)))
		if not broad.has_point(from+offset) and broad.intersects_segment(from+offset,to+offset)==null: continue
		for piece in _hull_candidates(entry,a,b,half):
			var spans: PackedFloat32Array=_spans(entry,piece)
			var hit = sweep_hull(a,b,half,spans)
			if not hit.is_empty() and hit.fraction<earliest:
				earliest = hit.fraction
				closest = {"fraction":earliest,"position":from.lerp(to,earliest),"normal":hit.normal,
					"reason":"ROCK IMPACT","boundary":false,"id":entry.id}
	return closest

static func _build_hull_bvh(bounds: Array, indices: Array, nodes: Array) -> int:
	var box: AABB=bounds[indices[0]]
	for i in indices: box=box.merge(bounds[i])
	var index=nodes.size()
	var node={"box":box,"pieces":[],"left":-1,"right":-1}
	nodes.append(node)
	if indices.size()<=4:
		node.pieces=indices
	else:
		var axis=box.get_longest_axis_index()
		indices.sort_custom(func(a,b): return bounds[a].get_center()[axis]<bounds[b].get_center()[axis])
		var middle=indices.size()/2
		node.left=_build_hull_bvh(bounds,indices.slice(0,middle),nodes)
		node.right=_build_hull_bvh(bounds,indices.slice(middle),nodes)
	return index

static func _hull_candidates(entry: Dictionary, a: Vector3, b: Vector3, half: Vector3) -> Array:
	# Refined cliff shapes can contain hundreds of small pieces. A hierarchy
	# prunes buried and distant pieces before the continuous separating-axis test.
	var result: Array=[]
	var pending: Array=[0]
	while not pending.is_empty():
		var node: Dictionary=entry.hull_bvh[pending.pop_back()]
		var source: AABB=node.box
		var box=AABB(source.position-half,source.size+half*2.0)
		if not box.has_point(a) and box.intersects_segment(a,b)==null: continue
		if node.left<0:
			for piece in node.pieces:
				var piece_box: AABB=entry.hull_bounds[piece]
				piece_box=AABB(piece_box.position-half,piece_box.size+half*2.0)
				if piece_box.has_point(a) or piece_box.intersects_segment(a,b)!=null: result.append(piece)
		else: pending.append(node.left); pending.append(node.right)
	return result

static func sweep_hull(a: Vector3, b: Vector3, half: Vector3, spans: PackedFloat32Array) -> Dictionary:
	var delta = b-a
	var enter = 0.0; var leave = 1.0
	var normal = Vector3.ZERO
	var inside = true; var shallow = INF; var inside_normal = Vector3.UP
	for i in range(0,spans.size(),5):
		var axis = Vector3(spans[i],spans[i+1],spans[i+2])
		var padding = axis.abs().dot(half)
		var low = spans[i+3]-padding; var high = spans[i+4]+padding
		var start = axis.dot(a); var speed = axis.dot(delta)
		if start<low or start>high: inside = false
		var depth = minf(start-low,high-start)
		if depth<shallow:
			shallow=depth; inside_normal=-axis if start-low<high-start else axis
		if absf(speed)<.0000001:
			if start<low or start>high: return {}
			continue
		var first = (low-start)/speed; var second = (high-start)/speed
		var near = minf(first,second)
		if near>enter:
			enter=near; normal=-axis if speed>0 else axis
		leave=minf(leave,maxf(first,second))
		if enter>leave: return {}
	if leave<0 or enter>1: return {}
	if inside:
		normal=inside_normal
		if delta.dot(normal)>0: return {}
	if normal.is_zero_approx(): return {}
	return {"fraction":enter,"normal":normal}

func footprint_clear(point: Vector3, radius: float) -> bool:
	for index in candidates(point,point,radius):
		var box: AABB = entries[index].aabb
		var p = Vector2(point.x,point.z)
		var rect = Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(radius)
		if rect.has_point(p): return false
	return true
