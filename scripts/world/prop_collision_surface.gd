extends RefCounted
## Opt-in collision adapter. The existing surface remains terrain authority.
## Frozen oriented boxes are shared with FlavorProp's StaticBody3D shapes.
## No Nodes, render-frame queries, or changes to terrain/replay identity here.
var terrain
var groups: Dictionary = {}
var grid: Dictionary = {}
var indexed: Array = []

func _init(source = null) -> void:
	terrain = source

func sample(x: float, z: float) -> Dictionary:
	return terrain.sample(x,z)

func contact_normal(x: float, z: float) -> Vector3:
	return terrain.contact_normal(x,z) if terrain.has_method("contact_normal") else terrain.sample(x,z).normal

func snow_depth_at(x: float, z: float) -> float:
	return terrain.snow_depth_at(x,z) if terrain.has_method("snow_depth_at") else 0.0

func rock_fraction_at(x: float, z: float) -> float:
	return terrain.rock_fraction_at(x,z) if terrain.has_method("rock_fraction_at") else 0.0

func register_props(key: int, boxes: Array) -> void:
	groups[key] = boxes.duplicate(true)
	_reindex()

func unregister_props(key: int) -> void:
	groups.erase(key)
	_reindex()

func _reindex() -> void:
	grid.clear(); indexed.clear()
	for key in groups:
		for box in groups[key]:
			var index=indexed.size(); indexed.append([key,box])
			var pose: Transform3D=box.transform
			var half: Vector3=box.size*.5
			var extent=pose.basis.x.abs()*half.x+pose.basis.y.abs()*half.y+pose.basis.z.abs()*half.z+Vector3.ONE*.4
			for z in range(floori((pose.origin.z-extent.z)/48),floori((pose.origin.z+extent.z)/48)+1):
				for x in range(floori((pose.origin.x-extent.x)/48),floori((pose.origin.x+extent.x)/48)+1):
					var cell=Vector2i(x,z)
					if not grid.has(cell): grid[cell]=[]
					grid[cell].append(index)

func sweep_obstacle(from: Vector3, to: Vector3) -> String:
	return sweep_obstacle_contact(from,to).get("reason","")

func sweep_obstacle_contact(from: Vector3, to: Vector3, terrain_hit: Variant = null) -> Dictionary:
	var closest: Dictionary = {}
	if terrain_hit is Dictionary:
		closest = terrain_hit
	elif terrain.has_method("sweep_obstacle_contact"):
		closest = terrain.sweep_obstacle_contact(from,to)
	elif terrain.has_method("sweep_obstacle"):
		var reason: String = terrain.sweep_obstacle(from,to)
		if not reason.is_empty(): return {"reason":reason,"boundary":true}
	if closest.get("boundary",false): return closest
	var earliest: float = closest.get("fraction",INF)
	var candidates: Dictionary={}
	for z in range(floori(minf(from.z,to.z)/48),floori(maxf(from.z,to.z)/48)+1):
		for x in range(floori(minf(from.x,to.x)/48),floori(maxf(from.x,to.x)/48)+1):
			for index in grid.get(Vector2i(x,z),[]): candidates[index]=true
	for index in candidates:
		var key=indexed[index][0]; var box=indexed[index][1]
		var hit = sweep_box(from,to,box.transform,box.size)
		if not hit.is_empty() and hit.fraction<earliest:
			earliest = hit.fraction
			hit.reason = box.get("reason","PROP IMPACT")
			hit.id = key
			hit.boundary = false
			closest = hit
	return closest

static func sweep_box(from: Vector3, to: Vector3, pose: Transform3D, size: Vector3) -> Dictionary:
	# Slab sweep of the rider's upright 0.7 x 1.6 x 0.7 m envelope.
	# Expanding in local box axes is conservative under rotated/tilted props.
	if absf(pose.basis.determinant())<.000001 or size.x<=0 or size.y<=0 or size.z<=0: return {}
	var inverse = pose.affine_inverse()
	var a = inverse * (from+Vector3.UP*.8)
	var b = inverse * (to+Vector3.UP*.8)
	var delta = b-a
	var extents = size*.5
	for axis in 3:
		extents[axis] += absf(inverse.basis.x[axis])*.35+absf(inverse.basis.y[axis])*.8+absf(inverse.basis.z[axis])*.35
	var enter = 0.0
	var leave = 1.0
	var normal = Vector3.ZERO
	var inside = true
	var shallow = INF
	var inside_normal = Vector3.ZERO
	for axis in 3:
		if absf(a[axis])>extents[axis]: inside=false
		var depth: float = extents[axis]-absf(a[axis])
		if depth<shallow:
			shallow=depth
			inside_normal=Vector3.ZERO
			inside_normal[axis]=1.0 if a[axis]>=0 else -1.0
		if absf(delta[axis])<.0000001:
			if absf(a[axis])>=extents[axis]: return {}
			continue
		var first: float = (-extents[axis]-a[axis])/delta[axis]
		var second: float = (extents[axis]-a[axis])/delta[axis]
		var near: float = minf(first,second)
		if near>enter:
			enter=near
			normal=Vector3.ZERO
			normal[axis]=-1.0 if delta[axis]>0 else 1.0
		leave=minf(leave,maxf(first,second))
		if enter>leave: return {}
	if leave<0 or enter>1: return {}
	if inside:
		normal=inside_normal
		if delta.dot(normal)>0: return {} # Allow escape from a bad placement/spawn.
	if normal.is_zero_approx(): return {}
	return {"fraction":enter,"position":from.lerp(to,enter),
		"normal":(inverse.basis.transposed()*normal).normalized()}
