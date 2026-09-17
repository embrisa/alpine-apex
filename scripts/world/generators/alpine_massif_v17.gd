extends "res://scripts/world/heightfield_surface.gd"
## V18: rounded terrain joins and visible sheltered snow banks.
## One immutable support grid. Generation has
## no Nodes, rider state, rendering quality, or preferred player racing line.
const Face = preload("res://scripts/world/generators/alpine_face_v17.gd")
const TreeSnow = preload("res://scripts/world/generators/tree_snow_v15.gd")
const GENERATOR_ID = "alpine-drainage"
const GENERATOR_VERSION = 18
const SNOW_REVISION = 3 # rounded joins, sheltered banks and preserved snow coverage
const DEFAULT_SEED = 849205174
const FACE_COUNT = 6
const FOOT_RADIUS = 2850.0
const MASK_ORIGIN = Vector2(-3072,-3072)
const MASK_SIZE = Vector2i(1537,1537)
var faces: Array = []
var parameters: Dictionary
var features: Array[Dictionary] = []
var jumps: Array[Dictionary] = []
var powder_deposits: Array[Dictionary] = []
var exposure_image: Image
var generation_ms: float
var generation_stages: Dictionary = {}
var height_checksum: String
var obstacle_checksum: String
var face_phase: float
var cache_hit = false
const Settings = preload("res://scripts/world/generation_settings.gd")
const Job = preload("res://scripts/world/generation_job.gd")
const Trees = preload("res://scripts/world/packed_trees.gd")
var generation_settings: Dictionary = Settings.preset()
var job
var tree_data = Trees.new()
var final_normals = PackedVector3Array()
var population: Dictionary = {}
var valid: bool = false
var _ecology_values = PackedVector2Array()
const ECOLOGY_SIDE = 769
const ECOLOGY_CELL = 8.0
var _candidate_spacing: float = 4.5
var _candidate_side: int = 0
var tree_snow_height = PackedFloat32Array()
var tree_snow_statistics: Dictionary = {}
var _snow_added = PackedFloat32Array()
var _snow_input_material = PackedByteArray()
var geology = preload("res://scripts/world/mountain_geology_v15.gd").new()

func _init(mountain_seed: int = DEFAULT_SEED,bake_surface: bool = true,settings: Dictionary = {},context = null,restore_only: bool = false) -> void:
	if bake_surface and not preload("res://scripts/diagnostics/test_world_policy.gd").require_full("Full mountain generator"): return
	_height_query_script = load("res://scripts/world/generators/alpine_massif_v17.gd")
	var begin = Time.get_ticks_usec()
	generation_settings = Settings.canonical(settings)
	job = context if context else Job.new()
	if generation_settings.is_empty(): job.complete("Invalid generation settings."); return
	generation_settings.make_read_only()
	if not restore_only: job.begin_stage("recipe",6)
	seed_value = mountain_seed
	X_MIN = MASK_ORIGIN.x
	Z_MIN = MASK_ORIGIN.y
	NX = MASK_SIZE.x
	NZ = MASK_SIZE.y
	finish_z = FOOT_RADIUS
	boundary_message = "MOUNTAIN BOUNDARY"
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	parameters = {"pitch":rng.randf_range(.69,.77),"phase":rng.randf_range(-PI,PI),"spurs":rng.randi_range(3,4),"bend":rng.randf_range(.08,.17),"relief":rng.randf_range(100,145)}
	face_phase = rng.randf_range(-PI/6,PI/6)
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = .003
	noise.fractal_octaves = 2
	if restore_only: return
	features.append({"name":"Summit · choose any direction","position":Vector2.ZERO})
	for i in FACE_COUNT:
		if job.is_cancelled(): return
		var face = Face.new(self,i,face_phase+TAU*i/FACE_COUNT)
		if job.is_cancelled(): return
		faces.append(face)
		for form in face.landforms:
			features.append({"name":"Face %d · %s" % [i+1,form.name],"position":face.to_world(form.position)})
		features.append({"name":"Face %d · forest glades" % (i+1),"position":face.to_world(face.clearings[0].position)})
		features.append({"name":"Face %d · powder basin" % (i+1),"position":face.to_world(face.bowls[0].position)})

		for deposit in face.powder_deposits:
			powder_deposits.append({"position":face.to_world(deposit.position),"radius":deposit.radius,"height":deposit.height,"face":i,"local_position":deposit.position})
	job.end_stage("recipe",6)
	if not bake_surface: return
	_stage("terrain_shaping",NX*NZ,func(): heights = _parallel_rows(_landform_rows))
	if job.is_cancelled(): return
	_stage("geology_foundations",faces.size(),func(): geology.prepare(self))
	if job.is_cancelled(): return
	_rebuild_surface("before_snow")
	_stage("snow_shaping",NX*NZ,_sculpt_snow)
	if job.is_cancelled(): return
	_stage("normals_before_trees",NX*NZ,_build_normals)
	_stage("geology_placement",roundi(108000*generation_settings.mineral_density),func(): geology.finish(self))
	if job.is_cancelled(): return
	_rebuild_surface("before_trees",false)
	_stage("ecology_filters",ECOLOGY_SIDE*ECOLOGY_SIDE,_build_ecology)
	if job.is_cancelled(): return
	job.begin_stage("tree_candidates",candidate_count())
	_scatter_packed()
	_ecology_values.clear()
	if job.is_cancelled(): return
	_stage("tree_snow",tree_data.size(),func(): TreeSnow.apply(self))
	if job.is_cancelled(): return
	_stage("final_seating",tree_data.size()+geology.placements.size(),func(): TreeSnow.seat(self))
	if job.is_cancelled(): return
	_stage("collision_preparation",tree_data.size()+geology.placements.size(),func():
		tree_data.build_index(48.0,job)
		if not job.is_cancelled(): geology._reindex(); geology._freeze())
	if job.is_cancelled(): return
	_stage("final_normals",NX*NZ,_build_normals)
	_stage("hashing",heights.size()+tree_data.size(),_refresh_identity)
	population = Settings.targets(generation_settings)
	population.requested_trees = population.trees; population.requested_minerals = population.minerals
	population.trees = tree_data.size(); population.minerals = geology.placements.size()
	population.tree_saturated = population.trees<population.requested_trees
	population.mineral_saturated = population.minerals<population.requested_minerals
	generation_ms = (Time.get_ticks_usec()-begin)/1000.0
	generation_stages = job.snapshot().timings_ms
	valid = not job.is_cancelled()

func _stage(name: String, count: int, work: Callable) -> void:
	if job.is_cancelled(): return
	job.begin_stage(name,count); work.call(); job.end_stage(name)

func _rebuild_surface(suffix: String, normals: bool = true) -> void:
	if normals: _stage("normals_"+suffix,NX*NZ,_build_normals)
	_stage("exposure_"+suffix,NX*NZ,func():
		var bytes: PackedByteArray = _parallel_rows(_exposure_rows,true)
		if job.is_cancelled(): return
		exposure_image = Image.create_from_data(NX,NZ,false,Image.FORMAT_RGBA8,bytes)
		geology.paint_exposure(self)
		if suffix=="before_trees": _finish_snow_cover()
		_material_from_exposure())

func _material_from_exposure() -> void:
	var rgba = exposure_image.get_data()
	var bytes = PackedByteArray(); bytes.resize(NX*NZ)
	for i in bytes.size(): bytes[i] = rgba[i*4]
	material_image = Image.create_from_data(NX,NZ,false,Image.FORMAT_R8,bytes)

func _build_normals() -> void:
	var values = PackedVector3Array()
	for rows in job.map_tiles(ceili(float(NZ)/32),func(i): return _normal_rows(i*32,mini(NZ,(i+1)*32))): values.append_array(rows)
	if not job.is_cancelled(): final_normals = values

func _normal_rows(first: int, last: int) -> PackedVector3Array:
	var values = PackedVector3Array(); values.resize((last-first)*NX)
	for z in range(first,last):
		if job.is_cancelled(): return values
		for x in NX:
			var dx = heights[z*NX+maxi(0,x-1)]-heights[z*NX+mini(NX-1,x+1)]
			var dz = heights[maxi(0,z-1)*NX+x]-heights[mini(NZ-1,z+1)*NX+x]
			values[(z-first)*NX+x] = Vector3(dx,8,dz).normalized()
		job.advance(NX)
	return values

func _refresh_identity() -> void:
	height_checksum = _digest(heights.to_byte_array())
	var context = HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	context.update(Settings.identity(generation_settings).to_utf8_buffer())
	tree_data.fingerprint(context,job)
	context.update(geology.fingerprint().to_utf8_buffer())
	context.update(material_image.get_data())
	obstacle_checksum = context.finish().hex_encode()

func adjacent_faces(p: Vector2) -> Array:
	var sector = wrapf(atan2(p.x,p.y)-face_phase,0,TAU)/(TAU/FACE_COUNT)
	var left = floori(sector)
	return [faces[left],faces[(left+1)%FACE_COUNT]]

func _landform_rows(first_row: int,last_row: int) -> PackedFloat32Array:
	var values = PackedFloat32Array()
	values.resize((last_row-first_row)*NX)
	for iz in range(first_row,last_row):
		if job.is_cancelled(): break
		job.advance(NX)
		for ix in NX:
			var p = Vector2(X_MIN+ix*CELL,Z_MIN+iz*CELL)
			var h = foundation_height(p.x,p.y)
			var delta = 0.0
			if p.length_squared()>180*180 and p.length_squared()<2830*2830:
				for face in adjacent_faces(p):
					var q: Vector2 = face.to_local(p)
					var weight: float = face.sector_weight(q.x,q.y)
					if weight>0: delta += (face._shaped_height(q.x,q.y,h)-h)*weight*smoothstep(220,640,q.y)
			values[(iz-first_row)*NX+ix] = h+delta
	return values

func foundation_height(x: float,z: float) -> float:
	var r = Vector2(x,z).length()
	var h = 4300.0-.24*(sqrt(r*r+16)-4)
	h -= (parameters.pitch-.24)*_ramp(r,24,160)
	h += (parameters.pitch-.12)*_ramp(r,2310,470)
	if r<.001: return h
	var angle = atan2(x,z)
	# Settle the large massif relief before the shallow runout begins. Fading
	# deep valleys into an already flat apron would create uphill basin closures.
	var envelope = smoothstep(80,850,r)*(1-smoothstep(1700,2350,r))
	# Broad asymmetric spurs and an elongated shoulder break the circular cone.
	# Low angular frequency gives each spur room for a snow face and a traverse.
	var backbone = .13*parameters.pitch*r*cos(2*(angle-parameters.phase))
	h += envelope*(backbone+parameters.relief*.85*(cos(parameters.spurs*(angle+parameters.bend*sin(r*.0012))+parameters.phase)+.24*sin(angle*3+parameters.phase)))
	h -= .10*(_ramp(r,500,150)-_ramp(r,810,200))
	h -= .08*(_ramp(r,1350,160)-_ramp(r,1670,220))
	return h+noise.get_noise_2d(x,z)*2.0*smoothstep(100,400,r)

func _sculpt_snow() -> void:
	var sculpted = _parallel_rows(_snow_rows)
	if job.is_cancelled(): return
	_snow_added.resize(heights.size())
	for i in heights.size(): _snow_added[i] = maxf(0,sculpted[i]-heights[i])
	_snow_input_material = material_image.get_data()
	heights = sculpted

func _finish_snow_cover() -> void:
	if _snow_added.is_empty(): return
	var rgba = exposure_image.get_data()
	for z in NZ:
		for x in NX:
			var i = z*NX+x
			var influence = maxf(_snow_added[i],maxf(_snow_added[z*NX+maxi(0,x-1)],_snow_added[z*NX+mini(NX-1,x+1)]))
			influence = maxf(influence,maxf(_snow_added[maxi(0,z-1)*NX+x],_snow_added[mini(NZ-1,z+1)*NX+x]))
			if influence<=.001: continue
			# The steeper side of an added snowbank is still snow. Preserve the
			# input rock mask around its normal stencil, then cover deposited cells.
			var rock = minf(float(rgba[i*4]),float(_snow_input_material[i]))/255.0
			rgba[i*4] = roundi(255*rock*(1-smoothstep(.08,.35,_snow_added[i])))
	exposure_image = Image.create_from_data(NX,NZ,false,Image.FORMAT_RGBA8,rgba)
	_snow_added.clear()
	_snow_input_material.clear()

func _snow_rows(first_row: int,last_row: int) -> PackedFloat32Array:
	var sculpted = heights.slice(first_row*NX,last_row*NX)
	for iz in range(first_row,last_row):
		if job.is_cancelled(): break
		job.advance(NX)
		for ix in NX:
			var p = Vector2(X_MIN+ix*CELL,Z_MIN+iz*CELL)
			if p.length_squared()<260*260 or p.length_squared()>2800*2800: continue
			for face in adjacent_faces(p):
				var q: Vector2 = face.to_local(p)
				var weight: float = face.sector_weight(q.x,q.y)
				if weight<=0: continue
				var n = render_normal(p.x,p.y)
				var rock = material_image.get_pixel(ix,iz).r
				var relief_weight: float = weight*smoothstep(220,380,q.y)*(1-smoothstep(2530,2780,q.y))*smoothstep(.025,.12,Vector2(n.x,n.z).length())*smoothstep(.52,.73,n.y)*(1-smoothstep(.25,.50,rock))*(1-face.protected_drop_weight(q.x,q.y))
				if relief_weight>0: sculpted[(iz-first_row)*NX+ix] += face.snow_relief_at(q.x,q.y)*relief_weight
	return sculpted

func environment_weight(x: float,z: float) -> float:
	var r = Vector2(x,z).length()
	return smoothstep(180,340,r)*(1-smoothstep(2630,2830,r))

func exposure_at(x: float,z: float) -> Color:
	var result = Color(0,0,0,1)
	for face in adjacent_faces(Vector2(x,z)):
		var q: Vector2 = face.to_local(Vector2(x,z))
		var weight: float = face.sector_weight(q.x,q.y)
		if weight>0: result.r += face.exposure_at(q.x,q.y).r*weight
	return result

func stand_density(x: float,z: float) -> float:
	var value = 0.0
	for face in adjacent_faces(Vector2(x,z)):
		var q: Vector2 = face.to_local(Vector2(x,z))
		value += face.stand_density(q.x,q.y)*face.sector_weight(q.x,q.y)
	return value

func powder_region(x: float,z: float) -> float:
	var value = 0.0
	if environment_weight(x,z)<=0: return value
	for face in adjacent_faces(Vector2(x,z)):
		var q: Vector2 = face.to_local(Vector2(x,z))
		var weight: float = face.sector_weight(q.x,q.y)
		if weight > 0.0: value += face.powder_region(q.x,q.y)*weight
	return clampf(value,0,1)

func snow_depth_at(x: float,z: float) -> float:
	# A continuous thick mantle covers snowy terrain, including open faces.
	# Wind varies its depth without turning ordinary snow into a slippery thin
	# layer. Exposed rock retains its separate authoritative material response.
	var cover = clampf(.5+noise.get_noise_2d(x+917,z-531),0,1)
	var thick = .19+.08*cover
	return minf(.35,lerpf(thick,.28+.04*sin(x*.031+sin(z*.019)),powder_region(x,z))+minf(.06,TreeSnow.sample_delta(self,tree_snow_height,x,z)*.12))

func in_landing_fan(x: float,z: float) -> bool:
	for face in adjacent_faces(Vector2(x,z)):
		var q: Vector2 = face.to_local(Vector2(x,z))
		if face.landing_weight(q.x,q.y)>.01: return true
	return false

func render_normal(x: float,z: float) -> Vector3:
	if final_normals.size()==NX*NZ:
		return final_normals[clampi(roundi((z-Z_MIN)/CELL),0,NZ-1)*NX+clampi(roundi((x-X_MIN)/CELL),0,NX-1)]
	var ix = roundi((x-X_MIN)/CELL)
	var iz = roundi((z-Z_MIN)/CELL)
	if ix>0 and ix<NX-1 and iz>0 and iz<NZ-1:
		return Vector3(heights[iz*NX+ix-1]-heights[iz*NX+ix+1],8,heights[(iz-1)*NX+ix]-heights[(iz+1)*NX+ix]).normalized()
	return contact_normal(x,z)

func continuation_height(x: float,z: float) -> float:
	return sample(x,z).height if bounds().has_point(Vector2(x,z)) else foundation_height(x,z)

func is_summit_mountain() -> bool: return true
func spawn_point() -> Vector3: return Vector3(0,sample(0,0).height,0)
func spawn_heading() -> float: return face_phase
func launch_point(heading: float) -> Vector3:
	var p = Vector2(sin(heading),cos(heading))*16
	return Vector3(p.x,sample(p.x,p.y).height,p.y)
func reached_base(position: Vector3) -> bool: return Vector2(position.x,position.z).length()>=FOOT_RADIUS
func descent_progress(position: Vector3) -> float: return clampf(Vector2(position.x,position.z).length()/FOOT_RADIUS*100,0,100)

static func _ramp(distance_value: float,start: float,length_value: float) -> float:
	var u = clampf((distance_value-start)/length_value,0,1)
	return length_value*(u*u*u-.5*u*u*u*u)+maxf(0,distance_value-start-length_value)

static func _digest(bytes: PackedByteArray) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _parallel_rows(bake: Callable, bytes: bool = false):
	var rows = job.map_tiles(ceili(float(NZ)/32),func(i): return bake.call(i*32,mini(NZ,(i+1)*32)))
	var joined = PackedByteArray() if bytes else PackedFloat32Array()
	for row in rows: joined.append_array(row)
	return joined

func _exposure_rows(first_row: int,last_row: int) -> PackedByteArray:
	var data = PackedByteArray()
	data.resize((last_row-first_row)*NX*4)
	for iz in range(first_row,last_row):
		if job.is_cancelled(): break
		job.advance(NX)
		for ix in NX:
			var color = exposure_at(X_MIN+ix*CELL,Z_MIN+iz*CELL)
			var offset = ((iz-first_row)*NX+ix)*4
			data[offset] = clampi(roundi(color.r*255),0,255)
			data[offset+3] = clampi(roundi(color.a*255),0,255)
	return data

func sweep_obstacle_contact(from: Vector3, to: Vector3) -> Dictionary:
	var original = _sweep_trees(from,to)
	if original.get("boundary",false): return original
	var mineral = geology.collision.sweep(from,to)
	return mineral if not mineral.is_empty() and mineral.fraction<float(original.get("fraction",INF)) else original

func geology_clear(point: Vector3, radius: float) -> bool:
	return geology.clear(point,radius)

func ray_geology(from: Vector3, to: Vector3, radius: float = 0.0) -> Dictionary:
	return geology.collision.sweep(from,to,Vector3.ONE*radius,Vector3.ZERO)

func obstacle_count() -> int: return tree_data.size()
func obstacle_at(id: int) -> Dictionary: return tree_data.record(id)
func obstacle_position(id: int) -> Vector3: return tree_data.positions[id]

func nearby_obstacle_indices(center: Vector3, radius: float) -> Array:
	return Array(tree_data.nearby(center,radius))

func _build_ecology() -> void:
	var tiles = job.map_tiles(ceili(float(ECOLOGY_SIDE)/16),func(i): return _ecology_rows(i*16,mini(ECOLOGY_SIDE,(i+1)*16)))
	for tile in tiles: _ecology_values.append_array(tile)

func _ecology_rows(first: int, last: int) -> PackedVector2Array:
	var values = PackedVector2Array(); values.resize((last-first)*ECOLOGY_SIDE)
	for z in range(first,last):
		if job.is_cancelled(): return values
		for x in ECOLOGY_SIDE:
			var p = Vector2(X_MIN+x*ECOLOGY_CELL,Z_MIN+z*ECOLOGY_CELL)
			if p.length_squared()<120*120 or p.length_squared()>2800*2800: continue
			if render_normal(p.x,p.y).y<.64 or rock_fraction_at(p.x,p.y)>.45: continue
			var pair = adjacent_faces(p)
			var face = pair[0]; var q: Vector2 = face.to_local(p)
			var other: Vector2 = pair[1].to_local(p)
			if pair[1].sector_weight(other.x,other.y)>face.sector_weight(q.x,q.y): face = pair[1]; q = other
			var woodland: float = face.stand_density(q.x,q.y)*face.sector_weight(q.x,q.y) if p.length_squared()>=950*950 else 0.0
			var scattered: float = face.scattered_density(q.x,q.y) if woodland<.25 and p.length_squared()>=950*950 else 0.0
			var altitude=height_at(p.x,p.y)
			var grove: float=face.upper_woodland_density(q.x,q.y,altitude)
			grove *= smoothstep(.70,.86,render_normal(p.x,p.y).y)*(1-smoothstep(.10,.35,rock_fraction_at(p.x,p.y)))
			woodland=maxf(woodland,grove)
			# Small sheltered groves give way to sparse trees toward the summit.
			if woodland<.25:
				var upper: float = face.sparse_upper_density(q.x,q.y,altitude)
				upper *= smoothstep(120,280,p.length())*smoothstep(.78,.91,render_normal(p.x,p.y).y)
				upper *= 1-smoothstep(.10,.28,rock_fraction_at(p.x,p.y))
				scattered = maxf(scattered,upper)
			values[(z-first)*ECOLOGY_SIDE+x] = Vector2(woodland,scattered)
		job.advance(ECOLOGY_SIDE)
	return values

func _ecology_at(p: Vector2) -> Vector2:
	var q = ((p-Vector2(X_MIN,Z_MIN))/ECOLOGY_CELL).clamp(Vector2.ZERO,Vector2.ONE*(ECOLOGY_SIDE-1.001))
	var x = int(q.x); var z = int(q.y); var u = q.x-x; var v = q.y-z; var at = z*ECOLOGY_SIDE+x
	return _ecology_values[at].lerp(_ecology_values[at+1],u).lerp(_ecology_values[at+ECOLOGY_SIDE].lerp(_ecology_values[at+ECOLOGY_SIDE+1],u),v)

func candidate_count() -> int:
	_candidate_spacing = 4.5*minf(generation_settings.tree_spacing,1.0/sqrt(generation_settings.tree_population))
	_candidate_side = ceili(5560.0/_candidate_spacing)
	return _candidate_side*_candidate_side

func _candidate_rows(first: int, last: int) -> Dictionary:
	var poses = PackedVector3Array(); var scales = PackedFloat32Array(); var yaws = PackedFloat32Array(); var ids = PackedInt64Array(); var ecology = PackedByteArray()
	var rng = RandomNumberGenerator.new()
	for z in range(first,last):
		if job.is_cancelled(): break
		for x in _candidate_side:
			var id = z*_candidate_side+x
			rng.seed = Settings.stream(seed_value,37,id)
			var p = Vector2(-2780+x*_candidate_spacing,-2780+z*_candidate_spacing)+Vector2(rng.randf_range(-.24,.24),rng.randf_range(-.24,.24))*_candidate_spacing
			if p.length_squared()<120*120 or p.length_squared()>2780*2780: continue
			var density = _ecology_at(p)
			var woodland = density.x>=density.y
			if rng.randf()>maxf(density.x,density.y): continue
			if contact_normal(p.x,p.y).y<.68 or rock_fraction_at(p.x,p.y)>.38: continue
			var pair = adjacent_faces(p)
			var opening = false
			for face in pair:
				if face.natural_opening(face.to_local(p)): opening = true; break
			if opening: continue
			for angle in 8:
				var at = p+Vector2.from_angle(angle*TAU/8)*12.0
				if contact_normal(at.x,at.y).y<.64 or rock_fraction_at(at.x,at.y)>.45: opening = true; break
			if opening: continue
			var altitude = height_at(p.x,p.y)
			var stature = lerpf(.65,1.08,1-smoothstep(pair[0].treeline_height-320,pair[0].treeline_height+60,altitude))
			var maturity = lerpf(.8,1.35,smoothstep(.1,.7,density.x)) if woodland else 1.0
			var scale_value = rng.randf_range(.9,1.65)*stature*maturity
			var clearance = .46*scale_value+2*generation_settings.tree_spacing
			if not geology.clear(Vector3(p.x,0,p.y),clearance): continue
			for face in pair:
				if face.drop_protected(face.to_local(p),clearance) or face.natural_opening(face.to_local(p),clearance): opening = true; break
			if opening: continue
			poses.append(Vector3(p.x,altitude,p.y)); scales.append(scale_value); yaws.append(rng.randf_range(-PI,PI)); ids.append(id); ecology.append(0 if woodland else 1)
		job.advance(_candidate_side)
	return {"positions":poses,"scales":scales,"yaws":yaws,"ids":ids,"ecology":ecology}

func _scatter_packed() -> void:
	var tiles = job.map_tiles(ceili(float(_candidate_side)/16),func(i): return _candidate_rows(i*16,mini(_candidate_side,(i+1)*16)))
	if job.is_cancelled(): return
	job.end_stage("tree_candidates")
	job.begin_stage("tree_filtering",_candidate_side*_candidate_side)
	tree_data.build_index(6*generation_settings.tree_spacing)
	# A fixed candidate order resolves conflicts, independent of worker completion.
	var filtered = 0
	for tile in tiles:
		for i in tile.positions.size():
			if i%512==0 and job.is_cancelled(): return
			var p: Vector3 = tile.positions[i]; var scale_value: float = tile.scales[i]
			filtered += 1
			if not tree_data.clear_at(Vector2(p.x,p.z),.46*scale_value,generation_settings.tree_spacing): continue
			if tree_data.size()>=Trees.LIMIT: break
			tree_data.append(p,.46*scale_value,11*scale_value,scale_value,tile.yaws[i],tile.ids[i],tile.ecology[i]==1)
			tree_data.links.append(-1); tree_data.insert_index(tree_data.size()-1)
		job.advance(tile.positions.size())
	job.count_work("tree_filter_candidates",filtered)
	job.count_work("tree_spacing_accepted",tree_data.size())
	tree_data.thin(roundi(Settings.TREE_BASELINE*generation_settings.tree_population),Settings.stream(seed_value,38,0))
	tree_data.build_index(48.0,job)
	job.end_stage("tree_filtering",filtered)


func height_at(x: float, z: float) -> float:
	var gx = clampf((x-X_MIN)/CELL,0,NX-1.001); var gz = clampf((z-Z_MIN)/CELL,0,NZ-1.001)
	var ix = int(gx); var iz = int(gz); var u = gx-ix; var v = gz-iz; var i = iz*NX+ix
	return heights[i]*(1-u-v)+heights[i+1]*u+heights[i+NX]*v if u+v<=1 else heights[i+NX+1]*(u+v-1)+heights[i+1]*(1-v)+heights[i+NX]*(1-u)

func _sweep_trees(from: Vector3, to: Vector3) -> Dictionary:
	if not ski_bounds().has_point(Vector2(to.x,to.z)): return {"reason":boundary_message,"boundary":true}
	var a = Vector2(from.x,from.z); var b = Vector2(to.x,to.z); var delta = b-a
	var length_squared = delta.length_squared(); var dy = to.y-from.y
	var closest: Dictionary = {}; var earliest = INF
	for id in tree_data.nearby((from+to)*.5,sqrt(length_squared)*.5+tree_data.max_radius+.4):
		var center = tree_data.positions[id]; var dimensions = tree_data.dimensions[id]
		var offset = a-Vector2(center.x,center.z); var radius = dimensions.x+.35
		var c = offset.length_squared()-radius*radius; var enter = 0.0; var leave = 1.0
		if length_squared<.000001:
			if c>=0: continue
		else:
			var along = offset.dot(delta); var discriminant = along*along-length_squared*c
			if discriminant<=0: continue
			enter = maxf(0,(-along-sqrt(discriminant))/length_squared); leave = minf(1,(-along+sqrt(discriminant))/length_squared)
		var vertical_enter = 0.0; var vertical_leave = 1.0
		if absf(dy)<.000001:
			if from.y>=center.y+dimensions.y or from.y+1.6<=center.y: continue
		else:
			var first = (center.y-1.6-from.y)/dy; var second = (center.y+dimensions.y-from.y)/dy
			vertical_enter = maxf(0,minf(first,second)); vertical_leave = minf(1,maxf(first,second))
		var fraction = maxf(enter,vertical_enter)
		if fraction>minf(leave,vertical_leave) or fraction>=earliest: continue
		var point = from.lerp(to,fraction); var normal = Vector3(point.x-center.x,0,point.z-center.z).normalized()
		if vertical_enter>enter: normal = Vector3.DOWN if dy>0 else Vector3.UP
		if normal.length_squared()<.5: normal = -(to-from).normalized() if from!=to else Vector3.RIGHT
		earliest = fraction
		closest = {"reason":"TREE IMPACT","id":id,"fraction":fraction,"position":point,"normal":normal,"boundary":false}
	return closest
