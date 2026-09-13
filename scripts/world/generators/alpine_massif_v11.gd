extends "res://scripts/world/heightfield_surface.gd"
## One immutable support grid, with six seeded geological faces. Generation has
## no Nodes, rider state, rendering quality, or preferred player racing line.
const Face = preload("res://scripts/world/generators/alpine_face_v10.gd")
const GENERATOR_ID = "alpine-drainage"
const GENERATOR_VERSION = 11
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
var drainage_profiles: Array = []
var cache_hit = false
var geology = preload("res://scripts/world/mountain_geology.gd").new()

func _init(mountain_seed: int = DEFAULT_SEED,bake_surface: bool = true) -> void:
	if bake_surface and not preload("res://scripts/diagnostics/test_world_policy.gd").require_full("Full mountain generator"): return
	var begin = Time.get_ticks_usec()
	seed_value = mountain_seed
	X_MIN = MASK_ORIGIN.x
	Z_MIN = MASK_ORIGIN.y
	NX = MASK_SIZE.x
	NZ = MASK_SIZE.y
	finish_z = FOOT_RADIUS
	boundary_message = "MOUNTAIN BOUNDARY"
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	parameters = {"pitch":rng.randf_range(.77,.85),"phase":rng.randf_range(-PI,PI),"spurs":rng.randi_range(6,8),"bend":rng.randf_range(.08,.17),"relief":rng.randf_range(80,115)}
	face_phase = rng.randf_range(-PI/6,PI/6)
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = .003
	noise.fractal_octaves = 2
	features.append({"name":"Summit · choose any direction","position":Vector2.ZERO})
	for i in FACE_COUNT:
		var face = Face.new(self,i,face_phase+TAU*i/FACE_COUNT)
		faces.append(face)
		for form in face.landforms:
			features.append({"name":"Face %d · %s" % [i+1,form.name],"position":face.to_world(form.position)})
		features.append({"name":"Face %d · forest glades" % (i+1),"position":face.to_world(Vector2(face.glade_x(2230,-1),2230))})
		features.append({"name":"Face %d · powder banks" % (i+1),"position":face.to_world(Vector2(face.gully_x(820,-1),820))})
		var drop = face.landforms[4]
		jumps.append({"kind":"drop","position":face.to_world(drop.position),"direction":face.to_world(Vector2.DOWN),"width":drop.width,"height":drop.height})
		for deposit in face.powder_deposits:
			powder_deposits.append({"position":face.to_world(deposit.position),"radius":deposit.radius,"height":deposit.height,"face":i,"local_position":deposit.position})
	if not bake_surface: return
	heights = _parallel_rows(_landform_rows)
	generation_stages.landforms_ms = (Time.get_ticks_usec()-begin)/1000.0
	_drain_channels()
	geology.prepare(self)
	_sculpt_snow()
	_accumulate_powder()
	generation_stages.surface_ms = (Time.get_ticks_usec()-begin)/1000.0
	geology.finish(self)
	_scatter()
	generation_stages.obstacles_ms = (Time.get_ticks_usec()-begin)/1000.0
	exposure_image = Image.create_from_data(NX,NZ,false,Image.FORMAT_RGBA8,_parallel_rows(_exposure_rows,true))
	geology.paint_exposure(self)
	height_checksum = _digest(heights.to_byte_array())
	var bytes = PackedByteArray()
	for ob in obstacles:
		bytes.append_array(PackedFloat64Array([ob.position.x,ob.position.y,ob.position.z,ob.radius,ob.height,ob.scale,ob.yaw,1.0 if ob.tree else 0.0]).to_byte_array())
	bytes.append_array(geology.fingerprint().to_utf8_buffer())
	obstacle_checksum = _digest(bytes)
	generation_ms = (Time.get_ticks_usec()-begin)/1000.0
	# Drain profiles are construction intermediates, never a runtime steering aid.
	drainage_profiles.clear()

func adjacent_faces(p: Vector2) -> Array:
	var sector = wrapf(atan2(p.x,p.y)-face_phase,0,TAU)/(TAU/FACE_COUNT)
	var left = floori(sector)
	return [faces[left],faces[(left+1)%FACE_COUNT]]

func _landform_rows(first_row: int,last_row: int) -> PackedFloat32Array:
	var values = PackedFloat32Array()
	values.resize((last_row-first_row)*NX)
	for iz in range(first_row,last_row):
		for ix in NX:
			var p = Vector2(X_MIN+ix*CELL,Z_MIN+iz*CELL)
			var h = foundation_height(p.x,p.y)
			var delta = 0.0
			if p.length_squared()>180*180 and p.length_squared()<2830*2830:
				for face in adjacent_faces(p):
					var q: Vector2 = face.to_local(p)
					var weight: float = face.sector_weight(q.x,q.y)
					if weight>0: delta += (face._shaped_height(q.x,q.y,h)-h)*weight
			values[(iz-first_row)*NX+ix] = h+delta
	return values

func foundation_height(x: float,z: float) -> float:
	var r = Vector2(x,z).length()
	var h = 4300.0-.24*(sqrt(r*r+16)-4)
	h -= (parameters.pitch-.24)*_ramp(r,24,160)
	h += (parameters.pitch-.12)*_ramp(r,2310,470)
	if r<.001: return h
	var angle = atan2(x,z)
	var envelope = smoothstep(80,850,r)*(1-smoothstep(2220,2850,r))
	h += parameters.relief*.15*envelope*(cos(parameters.spurs*(angle+parameters.bend*sin(r*.0012))+parameters.phase)+.20*sin(angle*3+parameters.phase))
	h -= .10*(_ramp(r,500,150)-_ramp(r,810,200))
	h -= .08*(_ramp(r,1350,160)-_ramp(r,1670,220))
	return h+noise.get_noise_2d(x,z)*2.0*smoothstep(100,400,r)

func _drain_channels() -> void:
	# Survey the whole unmodified grid first. Rotated faces then carve connected,
	# banked outlets using interpolation in metres, independent of iteration order.
	for face in faces:
		var pair: Array = []
		for side in [-1,1]:
			var profile = PackedFloat32Array()
			var previous = INF
			for z in range(260,2761,4):
				var x: float = face.gully_x(z,side) if z<1850 else face.glade_x(z,side)
				var p: Vector2 = face.to_world(Vector2(x,z))
				previous = minf(sample(p.x,p.y).height,previous-.22*CELL)
				profile.append(previous)
			pair.append(profile)
		drainage_profiles.append(pair)
	heights = _parallel_rows(_drain_rows)

func _drain_rows(first_row: int,last_row: int) -> PackedFloat32Array:
	var drained = heights.slice(first_row*NX,last_row*NX)
	for iz in range(first_row,last_row):
		for ix in NX:
			var p = Vector2(X_MIN+ix*CELL,Z_MIN+iz*CELL)
			if p.length_squared()<260*260 or p.length_squared()>2800*2800: continue
			var original = heights[iz*NX+ix]
			var delta = 0.0
			for face in adjacent_faces(p):
				var q: Vector2 = face.to_local(p)
				if q.y<260 or q.y>2760: continue
				for side_index in 2:
					var side = side_index*2-1
					var centre: float = face.gully_x(q.y,side) if q.y<1850 else face.glade_x(q.y,side)
					var distance_m = absf(q.x-centre)
					if distance_m>=34: continue
					var s = (q.y-260)/CELL
					var profile: PackedFloat32Array = drainage_profiles[face.index][side_index]
					var height_value = lerpf(profile[floori(s)],profile[mini(floori(s)+1,profile.size()-1)],s-floorf(s))
					var weight: float = (1-smoothstep(12,34,distance_m))*smoothstep(260,430,q.y)*(1-smoothstep(2490,2760,q.y))*face.sector_weight(q.x,q.y)
					delta += (height_value+.014*distance_m*distance_m-original)*weight
			drained[(iz-first_row)*NX+ix] += delta
	return drained

func _sculpt_snow() -> void:
	heights = _parallel_rows(_snow_rows)

func _snow_rows(first_row: int,last_row: int) -> PackedFloat32Array:
	var sculpted = heights.slice(first_row*NX,last_row*NX)
	for iz in range(first_row,last_row):
		for ix in NX:
			var p = Vector2(X_MIN+ix*CELL,Z_MIN+iz*CELL)
			if p.length_squared()<260*260 or p.length_squared()>2800*2800: continue
			for face in adjacent_faces(p):
				var q: Vector2 = face.to_local(p)
				var weight: float = face.sector_weight(q.x,q.y)
				if weight<=0: continue
				var relief_weight: float = face.snow_relief_weight(q.x,q.y)*weight
				if relief_weight>0: sculpted[(iz-first_row)*NX+ix] += face.snow_relief_at(q.x,q.y)*relief_weight
	return sculpted

func _accumulate_powder() -> void:
	var accumulated = heights.duplicate()
	for deposit in powder_deposits:
		var face = faces[deposit.face]
		var p: Vector2 = deposit.position
		var extent = maxf(deposit.radius.x,deposit.radius.y)*2
		for iz in range(maxi(0,floori((p.y-extent-Z_MIN)/CELL)),mini(NZ,ceili((p.y+extent-Z_MIN)/CELL)+1)):
			for ix in range(maxi(0,floori((p.x-extent-X_MIN)/CELL)),mini(NX,ceili((p.x+extent-X_MIN)/CELL)+1)):
				var world_p = Vector2(X_MIN+ix*CELL,Z_MIN+iz*CELL)
				var q: Vector2 = face.to_local(world_p)
				var local: Vector2 = (q-deposit.local_position)/deposit.radius
				if local.length_squared()>=4: continue
				var falloff = exp(-local.length_squared()*1.7)*(1-smoothstep(1.5,2,local.length()))
				var weight: float = face.powder_region(q.x,q.y)*face.sector_weight(q.x,q.y)*smoothstep(.58,.80,render_normal(world_p.x,world_p.y).y)*(1-face.landing_weight(q.x,q.y))
				accumulated[iz*NX+ix] += deposit.height*falloff*weight
	heights = accumulated

func _scatter() -> void:
	for face in faces:
		var rng = RandomNumberGenerator.new()
		rng.seed = face.seed_value+50771
		for i in 18000:
			# Equal candidate budgets across elevation bands keep upper and middle
			# woods visible; suitability, clearings and spacing determine placement.
			var band = i%3
			var z = rng.randf_range([600.0,1230.0,1930.0][band],[1230.0,1930.0,2650.0][band])
			var q = Vector2(rng.randf_range(-.54,.54)*z,z)
			var density: float = face.stand_density(q.x,q.y)*face.sector_weight(q.x,q.y)
			if rng.randf()>density*.75: continue
			var p: Vector2 = face.to_world(q)
			if contact_normal(p.x,p.y).y<.63 or in_landing_fan(p.x,p.y) or face.exposure_at(q.x,q.y).r>.38: continue
			var lane_a: float = face.gully_x(q.y,-1) if q.y<1850 else face.glade_x(q.y,-1)
			var lane_b: float = face.gully_x(q.y,1) if q.y<1850 else face.glade_x(q.y,1)
			if minf(absf(q.x-lane_a),absf(q.x-lane_b))<14: continue
			_put_obstacle(p,true,rng.randf_range(.7,1.5)*lerpf(.72,1.0,smoothstep(700,1600,z)),rng)
		for i in 4500:
			var q = Vector2(rng.randf_range(-1180,1180),rng.randf_range(380,2490))
			if face.sector_weight(q.x,q.y)<.6: continue
			var talus = 0.0
			for crag in face.crags:
				var below: float = q.y-face.crag_z(crag,q.x)
				talus = maxf(talus,smoothstep(35,95,below)*(1-smoothstep(200,430,below))*face.crag_weight(crag,q.x))
			var ridge = face.landforms[0]
			var outcrop = exp(-pow((q.y-ridge.position.y)/ridge.radius.y,4))*smoothstep(100,155,absf(q.x))*(1-smoothstep(240,340,absf(q.x)))
			if rng.randf()>maxf(talus*.8,outcrop*.6)*clampf(.5+.5*sin(q.x*.043+sin(q.y*.027)),0,1): continue
			var p: Vector2 = face.to_world(q)
			if in_landing_fan(p.x,p.y) or contact_normal(p.x,p.y).y<.53: continue
			var lane: float = face.gully_x(q.y,-1 if q.x<0 else 1) if q.y<1850 else face.glade_x(q.y,-1 if q.x<0 else 1)
			if absf(q.x-lane)<12 or face.snow_gap(q.x,q.y)>.01: continue
			_put_obstacle(p,false,rng.randf_range(1.1,3.25),rng)
		for deposit in face.powder_deposits:
			if rng.randf()>.55: continue
			var p: Vector2 = face.to_world(deposit.position)
			if contact_normal(p.x,p.y).y>.60 and not in_landing_fan(p.x,p.y): _put_obstacle(p,false,rng.randf_range(1.7,2.5),rng)

func _put_obstacle(p: Vector2,tree: bool,scale_value: float,rng: RandomNumberGenerator) -> void:
	if not tree: return # Mineral placements replace the legacy rock cylinders in v11.
	if not geology.clear(Vector3(p.x,0,p.y),.46*scale_value+2): return
	var radius = (.46 if tree else 1.35)*scale_value
	for gz in range(floori((p.y-12)/SPATIAL_CELL),floori((p.y+12)/SPATIAL_CELL)+1):
		for gx in range(floori((p.x-12)/SPATIAL_CELL),floori((p.x+12)/SPATIAL_CELL)+1):
			for idx in obstacle_grid.get(Vector2i(gx,gz),[]):
				var other = obstacles[idx]
				if p.distance_to(Vector2(other.position.x,other.position.z))<maxf(6,radius+other.radius+2): return
	add_obstacle({"position":Vector3(p.x,sample(p.x,p.y).height,p.y),"radius":radius,"height":(11.0 if tree else 2.0)*scale_value,"scale":scale_value,"yaw":rng.randf_range(-PI,PI),"tree":tree,"powder_cap":not tree and powder_region(p.x,p.y)>.35})

func environment_weight(x: float,z: float) -> float:
	var r = Vector2(x,z).length()
	return smoothstep(180,340,r)*(1-smoothstep(2630,2830,r))

func exposure_at(x: float,z: float) -> Color:
	if environment_weight(x,z)<=0: return Color(0,0,0,0)
	var result = Color(0,0,0,0)
	for face in adjacent_faces(Vector2(x,z)):
		var q: Vector2 = face.to_local(Vector2(x,z))
		var weight: float = face.sector_weight(q.x,q.y)
		if weight>0: result += face.exposure_at(q.x,q.y)*weight
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
		value += face.powder_region(q.x,q.y)*face.sector_weight(q.x,q.y)
	return clampf(value,0,1)

func snow_depth_at(x: float,z: float) -> float:
	var packed = .035+.065*clampf(.5+noise.get_noise_2d(x+917,z-531),0,1)
	return lerpf(packed,.24+.07*sin(x*.031+sin(z*.019)),powder_region(x,z))

func in_landing_fan(x: float,z: float) -> bool:
	for face in adjacent_faces(Vector2(x,z)):
		var q: Vector2 = face.to_local(Vector2(x,z))
		if face.landing_weight(q.x,q.y)>.01: return true
	return false

func render_normal(x: float,z: float) -> Vector3:
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
	var count = mini(6,maxi(1,OS.get_processor_count()-2))
	if "--massif-serial" in OS.get_cmdline_user_args(): count = 1
	var jobs: Array = []
	for i in count:
		var work = bake.bind(floori(float(NZ*i)/count),floori(float(NZ*(i+1))/count))
		var thread = Thread.new()
		if count==1 or thread.start(work)!=OK:
			jobs.append(work.call())
		else: jobs.append(thread)
	var joined = PackedByteArray() if bytes else PackedFloat32Array()
	for job in jobs:
		joined.append_array(job.wait_to_finish() if job is Thread else job)
	return joined

func _exposure_rows(first_row: int,last_row: int) -> PackedByteArray:
	var data = PackedByteArray()
	data.resize((last_row-first_row)*NX*4)
	for iz in range(first_row,last_row):
		for ix in NX:
			var color = exposure_at(X_MIN+ix*CELL,Z_MIN+iz*CELL)
			var offset = ((iz-first_row)*NX+ix)*4
			data[offset] = clampi(roundi(color.r*255),0,255)
			data[offset+3] = clampi(roundi(color.a*255),0,255)
	return data

func sweep_obstacle_contact(from: Vector3, to: Vector3) -> Dictionary:
	var original = super.sweep_obstacle_contact(from,to)
	if original.get("boundary",false): return original
	var mineral = geology.collision.sweep(from,to)
	return mineral if not mineral.is_empty() and mineral.fraction<float(original.get("fraction",INF)) else original

func geology_clear(point: Vector3, radius: float) -> bool:
	return geology.clear(point,radius)

func ray_geology(from: Vector3, to: Vector3, radius: float = 0.0) -> Dictionary:
	return geology.collision.sweep(from,to,Vector3.ONE*radius,Vector3.ZERO)
