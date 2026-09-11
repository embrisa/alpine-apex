extends RefCounted
## Tiles own disjoint output vertices; every contribution reads the same input.
const Settings = preload("res://scripts/world/generation_settings.gd")
const MAX_RISE_M = 1.0
const TILE = 64

static func sample_delta(field, data: PackedFloat32Array, x: float, z: float) -> float:
	if data.is_empty(): return 0.0
	var p = ((Vector2(x,z)-Vector2(field.X_MIN,field.Z_MIN))/4.0).clamp(Vector2.ZERO,Vector2(field.NX-1.001,field.NZ-1.001))
	var ix = int(p.x); var iz = int(p.y); var u = p.x-ix; var v = p.y-iz; var at = iz*field.NX+ix
	return data[at]*(1-u-v)+data[at+1]*u+data[at+field.NX]*v if u+v<=1 else data[at+field.NX+1]*(u+v-1)+data[at+1]*(1-v)+data[at+field.NX]*(1-u)

static func input_weight(field, ix: int, iz: int) -> float:
	var p = Vector2(field.X_MIN+ix*4.0,field.Z_MIN+iz*4.0)
	var normal: Vector3 = field.final_normals[iz*field.NX+ix]
	var rock = field.material_image.get_pixel(ix,iz).r
	var weight = (1-smoothstep(.12,.40,rock))*smoothstep(.60,.74,normal.y)
	weight *= smoothstep(.025,.11,Vector2(normal.x,normal.z).length())
	weight *= smoothstep(400,650,p.length())*(1-smoothstep(2630,2780,p.length()))
	if weight<=0: return 0.0
	for face in field.adjacent_faces(p):
		var q: Vector2 = face.to_local(p)
		if face.sector_weight(q.x,q.y)>.01: weight *= 1-face.protected_drop_weight(q.x,q.y)
	return weight

static func apply(field) -> void:
	var width = ceili(float(field.NX)/TILE); var height = ceili(float(field.NZ)/TILE)
	field.job.set_total(width*height)
	var outputs: Array = field.job.map_tiles(width*height,func(i): return _tile(field,i%width,i/width))
	if field.job.is_cancelled(): return
	var delta = PackedFloat32Array(); delta.resize(field.NX*field.NZ)
	var changed = 0; var maximum = 0.0
	for id in outputs.size():
		var tile: PackedFloat32Array = outputs[id]
		var x0 = (id%width)*TILE; var z0 = (id/width)*TILE
		var nx = mini(TILE,field.NX-x0); var nz = mini(TILE,field.NZ-z0)
		for z in nz:
			for x in nx:
				var value = tile[z*nx+x]; delta[(z0+z)*field.NX+x0+x] = value
				if value>.001: changed += 1
				maximum = maxf(maximum,value)
		if field.job.is_cancelled(): return
	outputs.clear()
	# Commit after all reads and worker joins, preserving maximum overlap.
	var heights: PackedFloat32Array = field.heights.duplicate()
	var rgba: PackedByteArray = field.exposure_image.get_data()
	var material = PackedByteArray(); material.resize(delta.size())
	for z in field.NZ:
		if field.job.is_cancelled(): return
		for x in field.NX:
			var i = z*field.NX+x
			heights[i] += delta[i]
			# Added snow cannot expose rock. Input material is already final for
			# all unchanged vertices; no second analytic whole-mountain exposure pass.
			var influence = maxf(delta[i],maxf(delta[z*field.NX+maxi(0,x-1)],delta[z*field.NX+mini(field.NX-1,x+1)]))
			influence = maxf(influence,maxf(delta[maxi(0,z-1)*field.NX+x],delta[mini(field.NZ-1,z+1)*field.NX+x]))
			var rock = float(rgba[i*4])/255.0
			rock *= 1-smoothstep(.02,.15,delta[i])*smoothstep(.001,.02,influence)
			rgba[i*4] = roundi(rock*255); material[i] = rgba[i*4]
	field.heights = heights; field.tree_snow_height = delta
	field.exposure_image = Image.create_from_data(field.NX,field.NZ,false,Image.FORMAT_RGBA8,rgba)
	field.material_image = Image.create_from_data(field.NX,field.NZ,false,Image.FORMAT_R8,material)
	field.tree_snow_statistics = {"trees":field.tree_data.size(),"max_grid_rise_m":maximum,"changed_vertices":changed}

static func _tile(field, tx: int, tz: int) -> PackedFloat32Array:
	var x0 = tx*TILE; var z0 = tz*TILE
	var nx = mini(TILE,field.NX-x0); var nz = mini(TILE,field.NZ-z0)
	var delta = PackedFloat32Array(); delta.resize(nx*nz)
	var weights = PackedFloat32Array(); weights.resize(nx*nz); weights.fill(-1)
	var center = Vector3(field.X_MIN+(x0+nx*.5)*4,0,field.Z_MIN+(z0+nz*.5)*4)
	var candidates = field.tree_data.nearby(center,Vector2(nx,nz).length()*2+10)
	var rng = RandomNumberGenerator.new()
	for id in candidates:
		if field.job.is_cancelled(): return delta
		rng.seed = Settings.stream(field.seed_value,81,field.tree_data.candidate_ids[id])
		var p: Vector3 = field.tree_data.positions[id]; var anchor = Vector2(p.x,p.z)
		var depth: float = field.snow_depth_at(p.x,p.z)
		var angle = .65+.35*sin(p.x*.002+p.z*.003)+rng.randf_range(-.30,.30)
		var across = Vector2(cos(angle),sin(angle)); var along = Vector2(-across.y,across.x)
		var radius = Vector2(rng.randf_range(4.5,6),rng.randf_range(5.5,8))
		var deposit = anchor+along*rng.randf_range(.20,.65)
		var height_m = minf(MAX_RISE_M,.58+depth*.25+.32*pow(rng.randf(),2))
		var extent = maxf(radius.x,radius.y)
		for z in range(maxi(z0,maxi(1,floori((deposit.y-extent-field.Z_MIN)/4))),mini(z0+nz,mini(field.NZ-1,ceili((deposit.y+extent-field.Z_MIN)/4)+1))):
			for x in range(maxi(x0,maxi(1,floori((deposit.x-extent-field.X_MIN)/4))),mini(x0+nx,mini(field.NX-1,ceili((deposit.x+extent-field.X_MIN)/4)+1))):
				var metres = Vector2(field.X_MIN+x*4,field.Z_MIN+z*4)-deposit
				var q = Vector2(metres.dot(across)/radius.x,metres.dot(along)/radius.y); var r2 = q.length_squared()
				if r2>=1: continue
				var i = (z-z0)*nx+x-x0
				if weights[i]<0: weights[i] = input_weight(field,x,z)
				delta[i] = maxf(delta[i],minf(MAX_RISE_M,height_m*pow(1-r2,3)*(1+.12*q.y)*weights[i]))
	field.job.count_work("tree_snow_candidates",candidates.size())
	field.job.advance()
	return delta

static func seat(field) -> void:
	var count: int = field.tree_data.size()
	var tiles: Array = field.job.map_tiles(ceili(float(count)/2048),func(i): return _seat_tree_tile(field,i*2048,mini(count,(i+1)*2048)))
	if field.job.is_cancelled(): return
	var positions = PackedVector3Array(); var rises = PackedFloat32Array(); var prominences = PackedFloat32Array()
	var per_face: Array = []
	for face in 6: per_face.append({"trees":0,"raised":0,"raised_5cm":0})
	var raised = 0; var small = 0; var prominent = 0
	for tile in tiles:
		positions.append_array(tile.positions); rises.append_array(tile.rises); prominences.append_array(tile.prominences)
		raised += tile.raised; small += tile.small; prominent += tile.prominent
		for face in 6:
			for key in per_face[face]: per_face[face][key] += tile.faces[face][key]
	field.tree_data.positions = positions
	tiles.clear()
	var minerals: int = field.geology.placements.size()
	var lifts = field.job.map_tiles(ceili(float(minerals)/256),func(i): return _seat_mineral_tile(field,i*256,mini(minerals,(i+1)*256)))
	if field.job.is_cancelled(): return
	# Commit in stable placement order after every worker has finished reading.
	var placed_id = 0
	for tile in lifts:
		for lift in tile:
			if is_finite(lift): field.geology.placements[placed_id].pose.origin.y += lift
			placed_id += 1

	rises.sort(); prominences.sort()
	field.tree_snow_statistics.merge({"coverage":float(raised)/maxi(1,rises.size()),"coverage_5cm":float(small)/maxi(1,rises.size()),"raised_at_least_15cm":raised,"prominent_bases":prominent,"per_face":per_face,
		"median_center_rise_m":rises[rises.size()/2] if not rises.is_empty() else 0.0,"median_prominence_6m":prominences[prominences.size()/2] if not prominences.is_empty() else 0.0,
		"prominence_percentiles_m":[prominences[prominences.size()*3/10],prominences[prominences.size()/2],prominences[prominences.size()*9/10]] if not prominences.is_empty() else [0,0,0]})

static func _seat_tree_tile(field, first: int, last: int) -> Dictionary:
	var positions = PackedVector3Array(); positions.resize(last-first)
	var rises = PackedFloat32Array(); rises.resize(last-first)
	var prominences = PackedFloat32Array(); prominences.resize(last-first)
	var per_face: Array = []
	for face in 6: per_face.append({"trees":0,"raised":0,"raised_5cm":0})
	var raised = 0; var small = 0; var prominent = 0
	var delta: PackedFloat32Array = field.tree_snow_height
	for id in range(first,last):
		if id%128==0 and field.job.is_cancelled(): break
		var i = id-first; var p: Vector3 = field.tree_data.positions[id]
		var rise = sample_delta(field,delta,p.x,p.z); rises[i] = rise
		var surrounding = 0.0
		for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]: surrounding += sample_delta(field,delta,p.x+direction.x*6,p.z+direction.y*6)*.25
		prominences[i] = rise-surrounding
		if prominences[i]>=.25: prominent += 1
		var face = posmod(roundi(wrapf(atan2(p.x,p.z)-field.face_phase,0,TAU)/(TAU/6)),6)
		per_face[face].trees += 1
		if rise>=.15: raised += 1; per_face[face].raised += 1
		if rise>=.05: small += 1; per_face[face].raised_5cm += 1
		p.y = field.height_at(p.x,p.z); positions[i] = p
	field.job.advance(last-first)
	return {"positions":positions,"rises":rises,"prominences":prominences,"faces":per_face,"raised":raised,"small":small,"prominent":prominent}

static func _seat_mineral_tile(field, first: int, last: int) -> PackedFloat32Array:
	var lifts = PackedFloat32Array(); lifts.resize(last-first)
	var delta: PackedFloat32Array = field.tree_snow_height
	for id in range(first,last):
		if field.job.is_cancelled(): return lifts
		var placed: Dictionary = field.geology.placements[id]
		var lift = INF
		for local in field.geology.catalog.records[placed.asset].seating:
			var p: Vector3 = placed.pose*local
			lift = minf(lift,sample_delta(field,delta,p.x,p.z))
		lifts[id-first] = lift
	field.job.advance(last-first)
	return lifts
