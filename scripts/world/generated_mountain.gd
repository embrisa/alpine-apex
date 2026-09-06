extends "res://scripts/world/heightfield_surface.gd"
## A complete summit massif. Radial drainage structures define the mountain;
## neither the renderer nor a racing line participates in terrain generation.
const GENERATOR_ID = "alpine-drainage"
const GENERATOR_VERSION = 4
const SUMMIT_HEIGHT = 4300.0
const FOOT_RADIUS = 2850.0
var parameters: Dictionary
var features: Array[Dictionary] = []
var jumps: Array[Dictionary] = []
var generation_ms: float
var height_checksum: String
var obstacle_checksum: String

func _init(mountain_seed: int = 849205174) -> void:
	var begin = Time.get_ticks_usec()
	X_MIN = -3072.0
	Z_MIN = -3072.0
	NX = 1537
	NZ = 1537
	finish_z = FOOT_RADIUS # Legacy descriptor; completion itself is radial.
	seed_value = mountain_seed
	boundary_message = "MOUNTAIN BOUNDARY"
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	parameters = {"pitch":rng.randf_range(.77,.85),"phase":rng.randf_range(-PI,PI),
		"spurs":rng.randi_range(6,8),"bend":rng.randf_range(.08,.17),
		"relief":rng.randf_range(80,115),"treeline":rng.randf_range(1750,1950)}
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = .003
	noise.fractal_octaves = 2
	for i in 6:
		var angle = parameters.phase+TAU*i/6.0+.20
		var direction = Vector2(sin(angle),cos(angle))
		var radius = 780.0+(i%3)*520.0+rng.randf_range(-90,90)
		jumps.append({"kind":"lip" if i%2==0 else "drop","position":direction*radius,
			"direction":direction,"width":rng.randf_range(90,125),"height":rng.randf_range(5,7) if i%2==0 else rng.randf_range(12,20)})
	heights.resize(NX*NZ)
	for iz in NZ:
		for ix in NX:
			heights[iz*NX+ix] = _landform(X_MIN+ix*CELL,Z_MIN+iz*CELL)
	_scatter(rng)
	features = [{"name":"Summit · choose any direction","position":Vector2.ZERO},
		{"name":"North face","position":Vector2(0,-1500)},
		{"name":"East bowls","position":Vector2(1500,0)},
		{"name":"South face","position":Vector2(0,1500)},
		{"name":"West ridges","position":Vector2(-1500,0)},
		{"name":"Lower forests","position":Vector2(-1900,1200)}]
	height_checksum = _digest(heights.to_byte_array())
	var obstacle_bytes = PackedByteArray()
	for ob in obstacles:
		obstacle_bytes.append_array(PackedFloat64Array([ob.position.x,ob.position.y,ob.position.z,ob.radius,ob.height,ob.scale,ob.yaw,1.0 if ob.tree else 0.0]).to_byte_array())
	obstacle_checksum = _digest(obstacle_bytes)
	generation_ms = (Time.get_ticks_usec()-begin)/1000.0

func _landform(x: float, z: float) -> float:
	var p = Vector2(x,z)
	var r = p.length()
	# A small rounded summit feeds steep faces on every azimuth. Integrated
	# pitch transitions make the base a long compression, not a retaining wall.
	var h = SUMMIT_HEIGHT-.24*(sqrt(r*r+16.0)-4.0)
	h -= (parameters.pitch-.24)*_ramp(r,24,160)
	h += (parameters.pitch-.12)*_ramp(r,2310,470)
	if r<.001: return h
	var angle = atan2(x,z)
	var drainage = _drainage(angle,r)
	var envelope = smoothstep(80,850,r)*(1-smoothstep(2220,2850,r))
	# Spurs diverge from the summit; widening hollows between them become bowls.
	# Secondary folds break rotational repetition without turning into cell noise.
	h += parameters.relief*envelope*(drainage+.20*sin(angle*3.0+parameters.phase))
	h -= .10*(_ramp(r,500,150)-_ramp(r,810,200))
	h -= .08*(_ramp(r,1350,160)-_ramp(r,1670,220))
	h += noise.get_noise_2d(x,z)*2.0*smoothstep(100,400,r)
	for jump in jumps:
		var delta = p-jump.position
		var along: float = delta.dot(jump.direction)
		if along < -100 or along>480: continue
		var cross: float = absf(delta.cross(jump.direction))
		if cross>=jump.width: continue
		var weight = 1-smoothstep(jump.width*.65,jump.width,cross)
		if jump.kind=="drop":
			h -= jump.height*weight*smoothstep(0,16,along)*(1-smoothstep(180,480,along))
		else:
			h += jump.height*weight*smoothstep(-70,0,along)*(1-smoothstep(0,36,along))
	return h

func _drainage(angle: float, radius: float) -> float:
	return cos(parameters.spurs*(angle+parameters.bend*sin(radius*.0012))+parameters.phase)

func _scatter(rng: RandomNumberGenerator) -> void:
	for i in 11000:
		var angle = rng.randf_range(-PI,PI)
		var r = sqrt(rng.randf())*2800.0
		if r<300: continue
		var p = Vector2(sin(angle),cos(angle))*r
		var normal = contact_normal(p.x,p.y)
		if normal.y<.63 or in_landing_fan(p.x,p.y): continue
		var patch = smoothstep(-.12,.40,noise.get_noise_2d(p.x+415,p.y-750))
		var forest = smoothstep(parameters.treeline,parameters.treeline+500,r)
		var tree = rng.randf()<forest*patch*.85 and normal.y>.77
		var talus = smoothstep(.25,.9,_drainage(angle,r))*(1-smoothstep(2200,2750,r))
		if not tree and rng.randf()>talus*patch*.40: continue
		var scale_value = rng.randf_range(.7,1.55) if tree else rng.randf_range(.9,2.9)
		add_obstacle({"position":Vector3(p.x,sample(p.x,p.y).height,p.y),
			"radius":.46*scale_value if tree else 1.35*scale_value,
			"height":11.0*scale_value if tree else 2.0*scale_value,
			"scale":scale_value,"yaw":rng.randf_range(-PI,PI),"tree":tree})

func is_summit_mountain() -> bool: return true
func spawn_point() -> Vector3: return Vector3(0,sample(0,0).height,0)
func spawn_heading() -> float: return 0.0

func launch_point(heading: float) -> Vector3:
	# Selecting a summit entry is a session setup action, not a movement force.
	# The rim is only 16 m from the high point and less than 4 m below it.
	var p = Vector2(sin(heading),cos(heading))*16.0
	return Vector3(p.x,sample(p.x,p.y).height,p.y)

func reached_base(position: Vector3) -> bool:
	return Vector2(position.x,position.z).length()>=FOOT_RADIUS

func descent_progress(position: Vector3) -> float:
	return clampf(Vector2(position.x,position.z).length()/FOOT_RADIUS*100,0,100)

func snow_depth_at(x: float, z: float) -> float:
	return .035+.065*clampf(.5+noise.get_noise_2d(x+917,z-531),0,1)

func in_landing_fan(x: float, z: float) -> bool:
	var p = Vector2(x,z)
	for jump in jumps:
		var delta = p-jump.position
		var along: float = delta.dot(jump.direction)
		if along>-100 and along<280 and absf(delta.cross(jump.direction))<jump.width+24: return true
	return false

func continuation_height(x: float, z: float) -> float: return _landform(x,z)

func render_normal(x: float, z: float) -> Vector3:
	# At grid vertices this is the same four-metre support stencil as sampling,
	# without constructing four Dictionary results for every rendered vertex.
	var ix = roundi((x-X_MIN)/CELL)
	var iz = roundi((z-Z_MIN)/CELL)
	if ix>0 and ix<NX-1 and iz>0 and iz<NZ-1:
		return Vector3(heights[iz*NX+ix-1]-heights[iz*NX+ix+1],8,heights[(iz-1)*NX+ix]-heights[(iz+1)*NX+ix]).normalized()
	return Vector3(_landform(x-2,z)-_landform(x+2,z),4,_landform(x,z-2)-_landform(x,z+2)).normalized()

static func _ramp(distance_value: float, start: float, length_value: float) -> float:
	var u = clampf((distance_value-start)/length_value,0,1)
	return length_value*(u*u*u-.5*u*u*u*u)+maxf(0,distance_value-start-length_value)

static func _digest(bytes: PackedByteArray) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
