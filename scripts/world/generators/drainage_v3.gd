extends "res://scripts/world/heightfield_surface.gd"
## Landform construction, not an erosion simulation. The complete physical
## surface and obstacle layout are baked once; no route enters the ski solver.
const GENERATOR_ID = "alpine-drainage"
const GENERATOR_VERSION = 3
var parameters: Dictionary
var features: Array[Dictionary] = []
var jumps: Array[Dictionary] = []
var generation_ms: float
var height_checksum: String
var obstacle_checksum: String

func _init(mountain_seed: int = 849205174) -> void:
	var begin = Time.get_ticks_usec()
	X_MIN = -768.0
	Z_MIN = -384.0
	NX = 385
	NZ = 1025
	finish_z = 3480.0
	seed_value = mountain_seed
	boundary_message = "MOUNTAIN BOUNDARY — CHOOSE A LINE INSIDE THE BASIN"
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	parameters = {"pitch":rng.randf_range(.65,.75), "phase":rng.randf_range(-PI,PI),
		"bend":rng.randf_range(12,26), "divide":rng.randf_range(-45,45),
		"ridge_height":rng.randf_range(32,46), "ridge_width":rng.randf_range(64,84),
		"bowl_z":rng.randf_range(440,620), "bowl_depth":rng.randf_range(24,36),
		"cliff_x":rng.randf_range(155,215)*(1 if rng.randf()>.5 else -1),
		"cliff_z":rng.randf_range(850,1120), "roller_z":rng.randf_range(1150,1330),
		"treeline_z":rng.randf_range(900,1050), "peak_height":rng.randf_range(110,180)}
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = .006
	noise.fractal_octaves = 2
	_build_jumps(rng)
	heights.resize(NX*NZ)
	for z in range(NZ):
		for x in range(NX):
			heights[z*NX+x] = _landform(X_MIN+x*CELL,Z_MIN+z*CELL)
	_scatter(rng)
	features = [
		{"name":"Summit shoulder", "position":Vector2(divide_at(50),50)},
		{"name":"Ridge roller · 4 m", "position":jumps[0].position},
		{"name":"West cornice · 12 m", "position":jumps[1].position},
		{"name":"East snow takeoff · 6 m", "position":jumps[2].position},
		{"name":"Rock escarpment · 22 m", "position":jumps[3].position},
		{"name":"Lower roller · 5 m", "position":jumps[4].position},
		{"name":"Forest drop · 9 m", "position":jumps[5].position},
		{"name":"Runout basin", "position":Vector2(0,3400)}]
	height_checksum = _digest(heights.to_byte_array())
	# Explicit binary SI-unit fields avoid JSON precision changing the fingerprint.
	var obstacle_bytes = PackedByteArray()
	for ob in obstacles:
		var values = PackedFloat64Array([ob.position.x,ob.position.y,ob.position.z,ob.radius,ob.height,ob.scale,ob.yaw,1.0 if ob.tree else 0.0])
		obstacle_bytes.append_array(values.to_byte_array())
	obstacle_checksum = _digest(obstacle_bytes)
	generation_ms = (Time.get_ticks_usec()-begin)/1000.0

func _small_divide_at(z: float) -> float:
	return parameters.divide+sin(z*.003+parameters.phase)*parameters.bend

func divide_at(z: float) -> float:
	return 2.0*_small_divide_at(z*.5)

func _build_jumps(rng: RandomNumberGenerator) -> void:
	# Physical landforms, not triggers. Wide shoulders remain available around
	# every feature; takeoffs and falling landing fans stay clear of obstacles.
	var shift = rng.randf_range(-24,24)
	# Put the east takeoff in the bowl floor, where its landing does not also
	# demand a large cross-slope weight transfer during touchdown.
	var east_lip_x = _east_bowl_floor(1420.0)
	jumps = [
		{"kind":"lip","position":Vector2(divide_at(420),420),"width":90.0,"height":4.0,"approach":44.0,"face":16.0},
		{"kind":"drop","position":Vector2(-230+shift,920),"width":78.0,"height":12.0,"approach":0.0,"face":8.0},
		{"kind":"lip","position":Vector2(east_lip_x,1420),"width":95.0,"height":6.0,"approach":55.0,"face":16.0},
		{"kind":"drop","position":Vector2(_east_bowl_floor(2050.0),2050),"width":90.0,"height":22.0,"approach":0.0,"face":8.0},
		{"kind":"lip","position":Vector2(-120+shift,2580),"width":100.0,"height":5.0,"approach":50.0,"face":16.0},
		{"kind":"drop","position":Vector2(-330+shift,3020),"width":80.0,"height":9.0,"approach":0.0,"face":8.0}]

func _landform(x: float, z: float) -> float:
	# Double the horizontal AND vertical landform scale, retaining downhill
	# pitch, the 4 m contact grid and the old generators as immutable recipes.
	var height_value = 4200.0+2.0*(_basin_landform(x*.5,z*.5)-2680.0)
	for jump in jumps:
		var cross = 1.0-smoothstep(jump.width*.65,jump.width,absf(x-jump.position.x))
		if cross<=0.0: continue
		var along: float = z-jump.position.y
		if jump.kind=="drop":
			height_value -= jump.height*cross*smoothstep(0.0,jump.face,along)*(1.0-smoothstep(180.0,480.0,along))
			if jump.height>15.0:
				# A steep landing fan catches the large escarpment along the
				# flight direction before easing into a long compression.
				height_value -= cross*.40*(_ramp(along,8,24)-_ramp(along,140,120))*(1.0-smoothstep(300,600,along))
		else:
			height_value += jump.height*cross*smoothstep(-jump.approach,0.0,along)*(1.0-smoothstep(0.0,jump.face,along))
	return height_value

func _basin_landform(x: float, z: float) -> float:
	# Integrated pitch transitions make a gentle summit shoulder, a sustained
	# face and a lower runout, instead of independently randomized grid cells.
	var base = 2680.0-z*.30-(parameters.pitch-.30)*_ramp(z,45,150)
	base += (parameters.pitch-.18)*_ramp(z,1510,210)
	# Broad convex entries into steep faces, then compressions to recover grip.
	# These changes in pitch run across the basin, beneath the branching forms.
	base -= .12*(_ramp(z,380,110)-_ramp(z,570,160))
	base -= .10*(_ramp(z,930,110)-_ramp(z,1110,170))
	var divide = _small_divide_at(z)
	var cross = x-divide
	var shoulders = pow(absf(cross)/310.0,2.4)*82.0
	var headwall = parameters.peak_height*_gauss(z+65,210)*pow(absf(x)/330.0,1.8)
	# A spur attached to the headwall separates two broad drainage bowls, then
	# dissolves into an alluvial apron. Both sides remain independently skiable.
	var ridge = parameters.ridge_height*_gauss(cross,parameters.ridge_width+60*(1-smoothstep(100,420,z)))*(1-smoothstep(1030,1490,z))
	var branch_x = divide-145.0*smoothstep(350,1030,z)
	var branch = 18.0*_gauss(x-branch_x,64)*_gauss(z-1000,300)
	var west = -parameters.bowl_depth*_gauss(cross+130,112)*_gauss(z-parameters.bowl_z,235)
	var east = -(parameters.bowl_depth+6)*_gauss(cross-140,125)*_gauss(z-parameters.bowl_z-130,255)
	# Drainage narrows downslope; the adjacent shoulder is a longer bypass.
	var gully = -15.0*_gauss(cross+85+sin(z*.005)*22,lerpf(60,24,smoothstep(750,1280,z)))*_gauss(z-1150,270)
	# Optional convex snow lip with a long falling landing slope. Its opposite
	# bowl stays open so a skier can choose grip and speed instead of airtime.
	var rollers = 6.0*_gauss(z-parameters.roller_z,32)*_gauss(cross-125,100)
	# Detail is subordinate to the macroforms and slow along the descent.
	var detail = noise.get_noise_2d(x,z*.55)*1.0+sin(x*.05+z*.009)*.25
	var apron = smoothstep(60,200,z)
	return base+shoulders+headwall+ridge+(branch+west+east+gully+rollers+detail)*apron

func spawn_point() -> Vector3:
	var x = divide_at(50)
	return Vector3(x,sample(x,50).height,50)

func snow_depth_at(x: float, z: float) -> float:
	var sheltered = 1.0-_gauss(x-divide_at(z),60)
	return .035+sheltered*.07+clampf(.5+noise.get_noise_2d(x+917,z-531),0,1)*.055

func _scatter(rng: RandomNumberGenerator) -> void:
	for i in range(3600):
		var x = rng.randf_range(-700,700)
		var z = rng.randf_range(400,3510)
		var normal = contact_normal(x,z)
		if normal.y<.62: continue
		# Forest follows lower, sheltered slopes; irregular glades are broad
		# environmental patches, not a cleared racing line.
		var forest = smoothstep(parameters.treeline_z*2,parameters.treeline_z*2+660,z)
		var patch = smoothstep(-.28,.32,noise.get_noise_2d(x*.65+325,z*.8-827))
		var cross = x-divide_at(z)
		var shoulder = smoothstep(320,510,absf(cross))
		var tree = rng.randf()<forest*patch*.90*shoulder and normal.y>.76
		# Exposed shoulder talus and the rock band supply readable hazard groups.
		# Snow-filled bowl interiors are broad speed choices, not obstacle soup.
		var band = _gauss(x-parameters.cliff_x*2,90)*_gauss(z-parameters.cliff_z*2,220)
		var rock_patch = smoothstep(-.05,.4,noise.get_noise_2d(x+450,z-190))
		var rock_density = maxf(shoulder*.48*rock_patch,band*.6)
		if not tree and rng.randf()>rock_density: continue
		# Keep the optional snow lip and its landing free of buried obstacles.
		if absf(cross-250)<160 and absf(z-parameters.roller_z*2)<250: continue
		if in_landing_fan(x,z): continue
		if z>3260 and absf(x)<180: continue
		var scale_value = rng.randf_range(.65,1.5) if tree else rng.randf_range(.8,2.8)
		add_obstacle({"position":Vector3(x,sample(x,z).height,z),
			"radius":.46*scale_value if tree else 1.35*scale_value,
			"height":11.0*scale_value if tree else 2.0*scale_value,
			"scale":scale_value,"yaw":rng.randf_range(-PI,PI),"tree":tree})

static func _gauss(distance_value: float, width: float) -> float:
	return exp(-pow(distance_value/width,2))

static func _ramp(z: float, start: float, length_value: float) -> float:
	var u = clampf((z-start)/length_value,0,1)
	return length_value*(u*u*u-.5*u*u*u*u)+maxf(0,z-start-length_value)

static func _digest(bytes: PackedByteArray) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func continuation_height(x: float, z: float) -> float:
	return _landform(x,z)

func render_normal(x: float, z: float) -> Vector3:
	var west = sample(x-2,z).height if x-2>=X_MIN else continuation_height(x-2,z)
	var east = sample(x+2,z).height if x+2<=X_MIN+(NX-1)*CELL else continuation_height(x+2,z)
	var north = sample(x,z-2).height if z-2>=Z_MIN else continuation_height(x,z-2)
	var south = sample(x,z+2).height if z+2<=Z_MIN+(NZ-1)*CELL else continuation_height(x,z+2)
	return Vector3(west-east,4,north-south).normalized()

func spawn_heading() -> float:
	# Initial orientation only. A seeded cross-slope must not start the skis
	# sideways to gravity; subsequent steering is entirely the player's input.
	var p = spawn_point()
	var downhill = Vector3.DOWN.slide(contact_normal(p.x,p.z))
	return atan2(downhill.x,downhill.z)

func in_landing_fan(x: float, z: float) -> bool:
	for jump in jumps:
		if absf(x-jump.position.x)<jump.width+18 and z>jump.position.y-95 and z<jump.position.y+240:
			return true
	return false

func _east_bowl_floor(z: float) -> float:
	var result = divide_at(z)+280.0
	var best_cross = INF
	for i in 46:
		var candidate = divide_at(z)+180.0+i*4.0
		var cross_slope = 0.0
		for along in [z-85.0,z+80.0]:
			cross_slope += absf(_basin_landform((candidate-2)*.5,along*.5)-_basin_landform((candidate+2)*.5,along*.5))
		if cross_slope<best_cross:
			best_cross = cross_slope
			result = candidate
	return result
