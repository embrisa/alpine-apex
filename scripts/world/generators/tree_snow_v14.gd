extends RefCounted
## Permanent trunk-anchored wind deposits in the shared 4 m heightfield.
## All weights sample the unchanged input. Overlap takes the highest deposit,
## so dense woodland cannot sum hundreds of piles into an artificial plateau.
const MAX_RISE_M = 1.0

static func sample_delta(field, data: PackedFloat32Array, x: float, z: float) -> float:
	if data.is_empty(): return 0.0
	var p = ((Vector2(x,z)-Vector2(field.X_MIN,field.Z_MIN))/4.0).clamp(Vector2.ZERO,Vector2(field.NX-1.001,field.NZ-1.001))
	var ix = int(p.x); var iz = int(p.y); var u = p.x-ix; var v = p.y-iz
	var at = iz*field.NX+ix
	return data[at]*(1-u-v)+data[at+1]*u+data[at+field.NX]*v if u+v<=1 else data[at+field.NX+1]*(u+v-1)+data[at+1]*(1-v)+data[at+field.NX]*(1-u)

static func input_weight(field, ix: int, iz: int) -> float:
	var p = Vector2(field.X_MIN+ix*4.0,field.Z_MIN+iz*4.0)
	var normal: Vector3 = field.render_normal(p.x,p.y)
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
	var begin = Time.get_ticks_usec()
	field.build_material_map()
	var delta = PackedFloat32Array(); delta.resize(field.heights.size()); delta.fill(0.0)
	var masks = PackedFloat32Array(); masks.resize(delta.size()); masks.fill(-1.0)
	var rng = RandomNumberGenerator.new(); rng.seed = field.seed_value ^ 0x7AEE514
	var attempted = 0
	for ob in field.obstacles:
		if not ob.tree: continue
		attempted += 1
		var anchor = Vector2(ob.position.x,ob.position.z)
		var depth: float = field.snow_depth_at(anchor.x,anchor.y)
		var angle = .65+.35*sin(anchor.x*.002+anchor.y*.003)+rng.randf_range(-.30,.30)
		var across = Vector2(cos(angle),sin(angle)); var along = Vector2(-across.y,across.x)
		var radius = Vector2(rng.randf_range(4.5,6.0),rng.randf_range(5.5,8.0))
		var center = anchor+along*rng.randf_range(.20,.65)
		# Mostly small rounded shoulders, with a minority of larger wind piles.
		# Grid peaks are not the visible prominence above neighbouring snow.
		var height_m = minf(MAX_RISE_M,.58+depth*.25+.32*pow(rng.randf(),2))
		var extent = maxf(radius.x,radius.y)
		for iz in range(maxi(1,floori((center.y-extent-field.Z_MIN)/4)),mini(field.NZ-1,ceili((center.y+extent-field.Z_MIN)/4)+1)):
			for ix in range(maxi(1,floori((center.x-extent-field.X_MIN)/4)),mini(field.NX-1,ceili((center.x+extent-field.X_MIN)/4)+1)):
				var metres = Vector2(field.X_MIN+ix*4.0,field.Z_MIN+iz*4.0)-center
				var q = Vector2(metres.dot(across)/radius.x,metres.dot(along)/radius.y)
				var r2 = q.length_squared()
				if r2>=1: continue
				var index = iz*field.NX+ix
				if masks[index]<0: masks[index] = input_weight(field,ix,iz)
				var rise = height_m*pow(1-r2,3)*(1+.12*q.y)*masks[index]
				delta[index] = maxf(delta[index],minf(rise,MAX_RISE_M))
	# Commit only after every anchor and shaping weight has read the old grid.
	var shaped: PackedFloat32Array = field.heights.duplicate()
	var changed = 0; var maximum = 0.0
	for index in delta.size():
		shaped[index] += delta[index]
		if delta[index]>.001: changed += 1
		maximum = maxf(maximum,delta[index])
	field.heights = shaped
	field.tree_snow_height = delta
	var rises: Array[float] = []; var covered = 0; var small_covered = 0
	var prominences: Array[float] = []; var prominent = 0
	var per_face: Array = []
	for i in 6: per_face.append({"trees":0,"raised":0,"raised_5cm":0})
	for ob in field.obstacles:
		if not ob.tree: continue
		var p: Vector3 = ob.position
		var rise = sample_delta(field,delta,p.x,p.z)
		rises.append(rise)
		var surrounding = 0.0
		for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			surrounding += sample_delta(field,delta,p.x+direction.x*6.0,p.z+direction.y*6.0)*.25
		var prominence = rise-surrounding
		prominences.append(prominence)
		if prominence>=.25: prominent += 1
		var face_id = posmod(roundi(wrapf(atan2(p.x,p.z)-field.face_phase,0,TAU)/(TAU/6)),6)
		per_face[face_id].trees += 1
		if rise>=.15: covered += 1; per_face[face_id].raised += 1
		if rise>=.05: small_covered += 1; per_face[face_id].raised_5cm += 1
		p.y = field.sample(p.x,p.z).height
		ob.position = p
	# Raise mineral foundations by the least added snow under their footprint.
	# This cannot expose a previously buried corner. Rebuild the same convex
	# collision and reservation data from the final poses, without respawning.
	var placements: Array = []
	for original in field.geology.placements:
		var placed: Dictionary = original.duplicate(true)
		var lift = INF
		for local in field.geology.catalog.records[placed.asset].seating:
			var p: Vector3 = placed.pose*local
			lift = minf(lift,sample_delta(field,delta,p.x,p.z))
		if is_finite(lift): placed.pose.origin.y += lift
		placements.append(placed)
	field.geology.restore(placements,field.geology.statistics.duplicate(true))
	rises.sort()
	prominences.sort()
	field.tree_snow_statistics = {"trees":attempted,"raised_at_least_15cm":covered,"coverage":float(covered)/maxi(1,attempted),"median_center_rise_m":rises[rises.size()/2] if not rises.is_empty() else 0.0,"max_grid_rise_m":maximum,"changed_vertices":changed,"per_face":per_face,"bake_ms":(Time.get_ticks_usec()-begin)/1000.0}
	field.tree_snow_statistics.median_prominence_6m = prominences[prominences.size()/2] if not prominences.is_empty() else 0.0
	field.tree_snow_statistics.coverage_5cm = float(small_covered)/maxi(1,attempted)
	field.tree_snow_statistics.prominent_bases = prominent
	field.tree_snow_statistics.prominence_percentiles_m = [prominences[prominences.size()*3/10],prominences[prominences.size()/2],prominences[prominences.size()*9/10]]
	_finish_exposure(field,field.material_image)
	field.material_image = null

static func _finish_exposure(field, original_material: Image) -> void:
	field.exposure_image = Image.create_from_data(field.NX,field.NZ,false,Image.FORMAT_RGBA8,field._parallel_rows(field._exposure_rows,true))
	field.geology.paint_exposure(field)
	# Adding snow cannot uncover bedrock. Preserve the original material where
	# a deposit changes the normal stencil, and cover it where snow is deposited.
	# This final mask is shared by physics and rendering and stored in the bake.
	var delta: PackedFloat32Array = field.tree_snow_height
	for iz in field.NZ:
		for ix in field.NX:
			var at = iz*field.NX+ix
			var influence = maxf(delta[at],maxf(delta[iz*field.NX+maxi(0,ix-1)],delta[iz*field.NX+mini(field.NX-1,ix+1)]))
			influence = maxf(influence,maxf(delta[maxi(0,iz-1)*field.NX+ix],delta[mini(field.NZ-1,iz+1)*field.NX+ix]))
			if influence<=.001: continue
			var color: Color = field.exposure_image.get_pixel(ix,iz)
			var covered = minf(color.r,original_material.get_pixel(ix,iz).r)*(1-smoothstep(.02,.15,delta[at]))
			color.r = lerpf(color.r,covered,smoothstep(.001,.02,influence))
			color.a = 1.0
			field.exposure_image.set_pixel(ix,iz,color)
