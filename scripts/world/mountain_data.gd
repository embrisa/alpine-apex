extends RefCounted
## Presentation-only generated mountain data. Metres, float32 heights, no Nodes.
## The supplied physical heightfield remains the sole contact authority.
const GENERATOR_VERSION = 3
var ORIGIN = Vector2(-4096,-2048)
const EXTENT = 8192.0
const COARSE_SIZE = 257
const GRID_SIZE = 2048
const CELL = 4.0
var seed_value: int
var height_image: Image
var environment_image: Image
var height_checksum: String
var environment_checksum: String
var generation_ms: float
var physics_authority: String
var noise = FastNoiseLite.new()
var detail = FastNoiseLite.new()

func generate(field, mountain_seed: int, job = null) -> void:
	var begin = Time.get_ticks_usec()
	if field.is_summit_mountain(): ORIGIN = Vector2(-4096,-4096)
	seed_value = mountain_seed
	physics_authority = "%s-v%d" % [field.GENERATOR_ID,field.GENERATOR_VERSION]
	noise.seed = seed_value
	noise.frequency = .00065
	noise.fractal_octaves = 4
	detail.seed = seed_value+173
	detail.frequency = .0025
	detail.fractal_octaves = 3
	var heights = PackedFloat32Array()
	heights.resize(COARSE_SIZE*COARSE_SIZE)
	for z in range(COARSE_SIZE):
		if job and job.is_cancelled(): return
		for x in range(COARSE_SIZE):
			var p = ORIGIN+Vector2(x,z)*32.0
			heights[z*COARSE_SIZE+x] = _landform(p,field)
	height_image = Image.create_from_data(COARSE_SIZE,COARSE_SIZE,false,Image.FORMAT_RF,heights.to_byte_array())
	# Resampling is presentation data preparation, never a new ski contact surface.
	height_image.resize(GRID_SIZE,GRID_SIZE,Image.INTERPOLATE_BILINEAR)
	# The physical surface is copied exactly. Generated basin shoulders continue
	# analytically through a wider collar so the scenery cannot form a cut wall.
	var generated: bool = field.GENERATOR_ID=="alpine-drainage"
	var apron = 192 if generated else 64
	var bounds: Rect2 = field.bounds()
	for z in range(int(bounds.position.y)-apron,int(bounds.end.y)+1+apron,4):
		if job and job.is_cancelled(): return
		for x in range(int(bounds.position.x)-apron,int(bounds.end.x)+1+apron,4):
			var gx = int((x-ORIGIN.x)/CELL)
			var gz = int((z-ORIGIN.y)/CELL)
			var ex = clampi(x,int(bounds.position.x),int(bounds.end.x))
			var ez = clampi(z,int(bounds.position.y),int(bounds.end.y))
			var fx = int((ex-field.X_MIN)/field.CELL)
			var fz = int((ez-field.Z_MIN)/field.CELL)
			var exact: float = field.heights[fz*field.NX+fx]
			var distance_value = Vector2(x-ex,z-ez).length()
			if generated and distance_value>0: exact = field.continuation_height(x,z)
			var broad = height_image.get_pixel(gx,gz).r
			var weight = smoothstep(32,192,distance_value) if generated else smoothstep(0,64,distance_value)
			height_image.set_pixel(gx,gz,Color(lerpf(exact,broad,weight),0,0))
	# Channels are snow coverage, exposed rock, vegetation suitability, wind exposure.
	# They describe appearance only; they do not change friction or collidable obstacles.
	environment_image = Image.create(COARSE_SIZE,COARSE_SIZE,false,Image.FORMAT_RGBA8)
	for z in range(COARSE_SIZE):
		if job and job.is_cancelled(): return
		for x in range(COARSE_SIZE):
			var p = ORIGIN+Vector2(x,z)*32.0
			var h = sample_height(p)
			var west = sample_height(p-Vector2(32,0))
			var east = sample_height(p+Vector2(32,0))
			var north = sample_height(p-Vector2(0,32))
			var south = sample_height(p+Vector2(0,32))
			var normal = Vector3(west-east,64,north-south).normalized()
			var exposure = clampf(.5+normal.dot(Vector3(.7,0,-.7))*.5,0,1)
			var hollow = clampf(((west+east+north+south)*.25-h)/25.0,-1,1)
			var variation = detail.get_noise_2d(p.x,p.y)
			var snow = snow_coverage(normal,hollow,exposure,variation)
			var treeline = 2050.0+noise.get_noise_2d(p.x,p.y)*250.0
			var vegetation = (1-smoothstep(treeline-250,treeline+60,h))*smoothstep(.64,.88,normal.y)*clampf(.65+variation,0,1)
			environment_image.set_pixel(x,z,Color(snow,1-snow,vegetation,exposure))
	height_checksum = _sha256(height_image.get_data())
	environment_checksum = _sha256(environment_image.get_data())
	generation_ms = (Time.get_ticks_usec()-begin)/1000.0

static func snow_coverage(normal: Vector3, hollow: float, exposure: float, variation: float) -> float:
	# Shared appearance rule for the playable mountain and decorative ridges.
	# Keep this independent of Nodes, physical terrain and material friction.
	return clampf(smoothstep(.44,.88,normal.y)+hollow*.13-(exposure-.5)*.17+variation*.10,0,1)

func _landform(p: Vector2, field) -> float:
	if field.is_summit_mountain():
		return field.continuation_height(p.x,p.y)
	var bounds: Rect2 = field.bounds()
	var edge = p.clamp(bounds.position,bounds.end)
	var base: float = field.sample(edge.x,edge.y).height-(p.y-edge.y)*.24
	var distance_value = p.distance_to(edge)
	if distance_value<.01: return base
	var warp = noise.get_noise_2d(p.y,400)*240.0
	var rise = 0.0
	for side in [-1.0,1.0]:
		var crest_x = side*(1550.0+warp)
		var along = noise.get_noise_2d(p.y*1.6,side*800)
		var ridge = exp(-pow(absf(p.x-crest_x)/850.0,1.6))
		var shoulder = exp(-pow(absf(p.x-side*2900)/1100.0,2.0))*.48
		var relief = 950.0+along*650.0
		rise += (ridge+shoulder)*relief
	# Broken saddles, broad bowls and drainage-like gullies. This is a landform
	# construction model; it does not claim a hydraulic erosion simulation.
	var folds = 1.0-absf(noise.get_noise_2d(p.x*2.2,p.y*2.2))
	var gullies = pow(clampf(1.0-absf(detail.get_noise_2d(p.x*.7,p.y*1.4))*3.0,0,1),1.5)
	rise *= .70+folds*.30
	rise -= gullies*65.0*smoothstep(100,700,rise)
	rise += detail.get_noise_2d(p.x,p.y)*45.0
	var result = base+maxf(0,rise)*smoothstep(0,420,distance_value)
	if field.GENERATOR_ID=="alpine-drainage" and distance_value<384:
		result = lerpf(field.continuation_height(p.x,p.y),result,smoothstep(64,384,distance_value))
	return result

func sample_height(p: Vector2) -> float:
	var g = (p-ORIGIN)/CELL
	g = g.clamp(Vector2.ZERO,Vector2(GRID_SIZE-1.001,GRID_SIZE-1.001))
	var x = int(g.x)
	var z = int(g.y)
	return lerpf(lerpf(height_image.get_pixel(x,z).r,height_image.get_pixel(x+1,z).r,g.x-x),lerpf(height_image.get_pixel(x,z+1).r,height_image.get_pixel(x+1,z+1).r,g.x-x),g.y-z)

func descriptor() -> Dictionary:
	return {"generator":"alpine-scenery","version":GENERATOR_VERSION,"seed":seed_value,"extent_m":EXTENT,"cell_m":CELL,"origin_m":[ORIGIN.x,ORIGIN.y],"height_sha256":height_checksum,"environment_sha256":environment_checksum,"godot_version":Engine.get_version_info().string,"physics_authority":physics_authority}

func _sha256(bytes: PackedByteArray) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
