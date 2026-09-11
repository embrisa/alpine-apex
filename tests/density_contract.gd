extends RefCounted
## Actual occupied 48 m cells, physical size classes and altitude bands.
static func population(field) -> Dictionary:
	var faces: Array=[]
	for i in 6: faces.append({"trees":0,"scattered_trees":0,"woodland_trees":0,"rocks":0,"tree_cells":{},"rock_cells":{},"categories":{},"elevation":{}})
	for ob in field.obstacles:
		var p: Vector3=ob.position
		var face=dominant_face(field,Vector2(p.x,p.z))
		var bucket: Dictionary=faces[face.index]
		bucket.trees+=1
		bucket["scattered_trees" if ob.get("ecology","")=="scattered" else "woodland_trees"]+=1
		var cell=Vector2i(floori(p.x/48),floori(p.z/48))
		bucket.tree_cells[cell]=int(bucket.tree_cells.get(cell,0))+1
		var band=str(floori(p.y/500)*500)
		if not bucket.elevation.has(band): bucket.elevation[band]={"trees":0,"rocks":0}
		bucket.elevation[band].trees+=1
	for placed in field.geology.placements:
		var p: Vector3=placed.pose.origin
		var face=dominant_face(field,Vector2(p.x,p.z))
		var bucket: Dictionary=faces[face.index]
		bucket.rocks+=1
		var category: String=field.geology.catalog.records[placed.asset].category
		bucket.categories[category]=int(bucket.categories.get(category,0))+1
		bucket.rock_cells[Vector2i(floori(p.x/48),floori(p.z/48))]=true
		var band=str(floori(p.y/500)*500)
		if not bucket.elevation.has(band): bucket.elevation[band]={"trees":0,"rocks":0}
		bucket.elevation[band].rocks+=1
	for bucket in faces:
		bucket.tree_cell_density={"isolated_1_to_5":0,"loose_6_to_20":0,"wooded_21_to_50":0,"dense_over_50":0}
		for count in bucket.tree_cells.values():
			var label="isolated_1_to_5" if count<=5 else ("loose_6_to_20" if count<=20 else ("wooded_21_to_50" if count<=50 else "dense_over_50"))
			bucket.tree_cell_density[label]+=1
		bucket.tree_cells=bucket.tree_cells.size()
		bucket.rock_cells=bucket.rock_cells.size()
		bucket.tree_occupied_m2=bucket.tree_cells*48*48
		bucket.rock_occupied_m2=bucket.rock_cells*48*48
	return {"faces":faces,"trees":field.obstacles.size(),"rocks":field.geology.placements.size(),"categories":field.geology.statistics.categories.duplicate()}

static func dominant_face(field,p: Vector2):
	var nearby=field.adjacent_faces(p)
	var q0: Vector2=nearby[0].to_local(p)
	var q1: Vector2=nearby[1].to_local(p)
	return nearby[0] if nearby[0].sector_weight(q0.x,q0.y)>=nearby[1].sector_weight(q1.x,q1.y) else nearby[1]

static func spacing(field) -> bool:
	var grid: Dictionary={}
	for ob in field.obstacles:
		var p=Vector2(ob.position.x,ob.position.z)
		var key=Vector2i(floori(p.x/4.2),floori(p.y/4.2))
		for z in range(-1,2):
			for x in range(-1,2):
				for q in grid.get(key+Vector2i(x,z),[]):
					if p.distance_squared_to(q)<4.199*4.199: return false
		if not grid.has(key): grid[key]=[]
		grid[key].append(p)
	return true

static func swept_routes_clear(field,face,paths: Array) -> bool:
	# Verify the actual continuous trunk/mineral contracts, in addition to the
	# route graph's conservative sampled clearance. This is not a ski-feel test.
	for path in paths:
		for i in range(1,path.size()):
			var a: Vector2=face.to_world(path[i-1])
			var b: Vector2=face.to_world(path[i])
			var steps=maxi(1,ceili(a.distance_to(b)/4.0))
			var previous=Vector3(a.x,field.sample(a.x,a.y).height,a.y)
			for j in range(1,steps+1):
				var p=a.lerp(b,float(j)/steps)
				var next=Vector3(p.x,field.sample(p.x,p.y).height,p.y)
				if not field.sweep_obstacle_contact(previous,next).is_empty(): return false
				previous=next
	return true

static func drops(field) -> bool:
	for ob in field.obstacles:
		var p=Vector2(ob.position.x,ob.position.z)
		for face in field.adjacent_faces(p):
			if face.drop_protected(face.to_local(p),ob.radius+2): return false
	var base: int=field.geology.statistics.baseline_placements
	for placed in field.geology.placements.slice(base):
		var p: Vector3=placed.pose.origin
		var face=field.faces[placed.face]
		var size: Vector3=field.geology.catalog.records[placed.asset].size_m
		if face.drop_protected(face.to_local(Vector2(p.x,p.z)),Vector2(size.x,size.z).length()*.6+5): return false
	return true
