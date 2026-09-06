extends "res://scripts/world/heightfield_surface.gd"
## Landform construction, not an erosion simulation. The complete physical
## surface and obstacle layout are baked once; no route enters the ski solver.
const GENERATOR_ID = "alpine-drainage"
const GENERATOR_VERSION = 2
var parameters: Dictionary
var features: Array[Dictionary] = []
var generation_ms: float
var height_checksum: String
var obstacle_checksum: String

func _init(mountain_seed: int = 849205174) -> void:
	var begin = Time.get_ticks_usec()
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
	heights.resize(NX*NZ)
	for z in range(NZ):
		for x in range(NX):
			heights[z*NX+x] = _landform(X_MIN+x*CELL,Z_MIN+z*CELL)
	_scatter(rng)
	features = [
		{"name":"Quick-entry shoulder", "position":Vector2(0,25)},
		{"name":"Split ridge", "position":Vector2(divide_at(450),450)},
		{"name":"West bowl", "position":Vector2(divide_at(parameters.bowl_z)-125,parameters.bowl_z)},
		{"name":"East bowl", "position":Vector2(divide_at(parameters.bowl_z+130)+135,parameters.bowl_z+130)},
		{"name":"Rock band / optional drop", "position":Vector2(parameters.cliff_x,parameters.cliff_z)},
		{"name":"Snow lip / open bypass", "position":Vector2(divide_at(parameters.roller_z)+125,parameters.roller_z)},
		{"name":"Forest & snowfields", "position":Vector2(-150,1400)},
		{"name":"Runout basin", "position":Vector2(0,1700)}]
	height_checksum = _digest(heights.to_byte_array())
	# Explicit binary SI-unit fields avoid JSON precision changing the fingerprint.
	var obstacle_bytes = PackedByteArray()
	for ob in obstacles:
		var values = PackedFloat64Array([ob.position.x,ob.position.y,ob.position.z,ob.radius,ob.height,ob.scale,ob.yaw,1.0 if ob.tree else 0.0])
		obstacle_bytes.append_array(values.to_byte_array())
	obstacle_checksum = _digest(obstacle_bytes)
	generation_ms = (Time.get_ticks_usec()-begin)/1000.0

func divide_at(z: float) -> float:
	return parameters.divide+sin(z*.003+parameters.phase)*parameters.bend

func _landform(x: float, z: float) -> float:
	# Integrated pitch transitions make a gentle summit shoulder, a sustained
	# face and a lower runout, instead of independently randomized grid cells.
	var base = 2680.0-z*.30-(parameters.pitch-.30)*_ramp(z,45,150)
	base += (parameters.pitch-.18)*_ramp(z,1510,210)
	# Broad convex entries into steep faces, then compressions to recover grip.
	# These changes in pitch run across the basin, beneath the branching forms.
	base -= .12*(_ramp(z,380,110)-_ramp(z,570,160))
	base -= .10*(_ramp(z,930,110)-_ramp(z,1110,170))
	var divide = divide_at(z)
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
	var drop = -13.0*_gauss(x-parameters.cliff_x,43)*(1+tanh((z-parameters.cliff_z)/12.0))*_gauss(z-parameters.cliff_z-90,270)
	# Optional convex snow lip with a long falling landing slope. Its opposite
	# bowl stays open so a skier can choose grip and speed instead of airtime.
	var rollers = 6.0*_gauss(z-parameters.roller_z,32)*_gauss(cross-125,100)
	# Detail is subordinate to the macroforms and slow along the descent.
	var detail = noise.get_noise_2d(x,z*.55)*1.0+sin(x*.05+z*.009)*.25
	var apron = smoothstep(60,200,z)
	return base+shoulders+headwall+ridge+(branch+west+east+gully+drop+rollers+detail)*apron

func spawn_point() -> Vector3:
	var x = divide_at(25)
	return Vector3(x,sample(x,25).height,25)

func snow_depth_at(x: float, z: float) -> float:
	var sheltered = 1.0-_gauss(x-divide_at(z),60)
	return .035+sheltered*.07+clampf(.5+noise.get_noise_2d(x+917,z-531),0,1)*.055

func _scatter(rng: RandomNumberGenerator) -> void:
	for i in range(1850):
		var x = rng.randf_range(-342,342)
		var z = rng.randf_range(200,1750)
		var normal = contact_normal(x,z)
		if normal.y<.62: continue
		# Forest follows lower, sheltered slopes; irregular glades are broad
		# environmental patches, not a cleared racing line.
		var forest = smoothstep(parameters.treeline_z,parameters.treeline_z+330,z)
		var patch = smoothstep(-.28,.32,noise.get_noise_2d(x*.65+325,z*.8-827))
		var cross = x-divide_at(z)
		var shoulder = smoothstep(160,255,absf(cross))
		var tree = rng.randf()<forest*patch*.90*shoulder and normal.y>.76
		# Exposed shoulder talus and the rock band supply readable hazard groups.
		# Snow-filled bowl interiors are broad speed choices, not obstacle soup.
		var band = _gauss(x-parameters.cliff_x,45)*_gauss(z-parameters.cliff_z,110)
		var rock_patch = smoothstep(-.05,.4,noise.get_noise_2d(x+450,z-190))
		var rock_density = maxf(shoulder*.48*rock_patch,band*.6)
		if not tree and rng.randf()>rock_density: continue
		# Keep the optional snow lip and its landing free of buried obstacles.
		if absf(cross-125)<80 and absf(z-parameters.roller_z)<125: continue
		if z>1630 and absf(x)<90: continue
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
