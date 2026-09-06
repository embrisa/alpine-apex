extends "res://scripts/world/heightfield_surface.gd"
## Fixed south-face experiment. All features are static physical terrain data;
## no route, renderer, camera or rider state participates in surface generation.
const BaseMountain = preload("res://scripts/world/generated_mountain.gd")
const GENERATOR_ID = "alpine-drainage"
const GENERATOR_VERSION = 5
const SHOWCASE_SEED = 849205174
const FOOT_RADIUS = 2850.0
const MASK_ORIGIN = Vector2(-1792,160)
const MASK_SIZE = Vector2i(897,669)
var base
var parameters: Dictionary
var features: Array[Dictionary] = []
var jumps: Array[Dictionary] = []
var legacy_jumps: Array[Dictionary] = []
var landforms: Array[Dictionary] = []
var stands: Array[Dictionary] = []
var crags: Array[Dictionary] = []
var exposure_image: Image
var generation_ms: float
var height_checksum: String
var obstacle_checksum: String

func _init(mountain_seed: int = SHOWCASE_SEED) -> void:
	assert(mountain_seed==SHOWCASE_SEED,"The technical showcase supports only its fixed example seed.")
	var begin = Time.get_ticks_usec()
	base = BaseMountain.new(mountain_seed)
	seed_value = mountain_seed
	X_MIN = base.X_MIN
	Z_MIN = base.Z_MIN
	NX = base.NX
	NZ = base.NZ
	finish_z = FOOT_RADIUS
	boundary_message = base.boundary_message
	parameters = base.parameters
	noise = base.noise
	heights = base.heights.duplicate()
	legacy_jumps = base.jumps.duplicate(true)
	jumps = legacy_jumps.filter(func(jump): return sector_weight(jump.position.x,jump.position.y)==0)
	base.jumps.clear() # Remove old jump relief only where the sector is blended in.
	landforms = [
		{"kind":"ridge","name":"Broken summit ridge","position":Vector2(0,590),"radius":Vector2(92,380),"height":72.0},
		{"kind":"bowl","name":"Twin chute bowl","position":Vector2(35,980),"radius":Vector2(345,330),"height":-48.0},
		{"kind":"band","name":"Rock band · snow ramps","position":Vector2(0,1370),"height":38.0},
		{"kind":"apron","name":"Rolls and boulder apron","position":Vector2(0,1790)},
		{"kind":"drop","name":"Optional shelf drop","position":Vector2(50,1545),"width":26.0,"height":6.0}]
	jumps.append({"kind":"drop","position":landforms[4].position,"direction":Vector2.DOWN,"width":landforms[4].width,"height":landforms[4].height})
	crags = [
		{"position":Vector2(-680,1260),"width":175.0,"height":58.0},
		{"position":Vector2(-425,1370),"width":145.0,"height":46.0},
		{"position":Vector2(20,1360),"width":170.0,"height":64.0},
		{"position":Vector2(495,1450),"width":150.0,"height":42.0},
		{"position":Vector2(790,1280),"width":205.0,"height":58.0}]
	stands = [
		{"position":Vector2(-420,2110),"radius":Vector2(320,230)},
		{"position":Vector2(330,2160),"radius":Vector2(340,275)},
		{"position":Vector2(-350,2420),"radius":Vector2(425,205)},
		{"position":Vector2(820,2310),"radius":Vector2(250,265)},
		{"position":Vector2(-940,2340),"radius":Vector2(220,245)}]
	for iz in range(int((160-Z_MIN)/CELL),int((2832-Z_MIN)/CELL)+1):
		var z = Z_MIN+iz*CELL
		for ix in range(int((-1792-X_MIN)/CELL),int((1792-X_MIN)/CELL)+1):
			var x = X_MIN+ix*CELL
			var weight = sector_weight(x,z)
			if weight>0:
				heights[iz*NX+ix] = lerpf(heights[iz*NX+ix],_shaped_height(x,z),weight)
	for ob in base.obstacles:
		if sector_weight(ob.position.x,ob.position.z)<=0: add_obstacle(ob.duplicate())
	_scatter()
	exposure_image = Image.create(MASK_SIZE.x,MASK_SIZE.y,false,Image.FORMAT_RGBA8)
	for iz in MASK_SIZE.y:
		for ix in MASK_SIZE.x:
			var p = MASK_ORIGIN+Vector2(ix,iz)*CELL
			exposure_image.set_pixel(ix,iz,exposure_at(p.x,p.y))
	features = [{"name":"Summit · south showcase ↓","position":Vector2.ZERO}]
	for form in landforms: features.append({"name":form.name,"position":form.position})
	features.append({"name":"Forest stands and glades","position":Vector2(-350,2260)})
	height_checksum = BaseMountain._digest(heights.to_byte_array())
	var bytes = PackedByteArray()
	for ob in obstacles:
		bytes.append_array(PackedFloat64Array([ob.position.x,ob.position.y,ob.position.z,ob.radius,ob.height,ob.scale,ob.yaw,1.0 if ob.tree else 0.0]).to_byte_array())
	obstacle_checksum = BaseMountain._digest(bytes)
	generation_ms = (Time.get_ticks_usec()-begin)/1000.0

func sector_weight(x: float,z: float) -> float:
	if z<=180: return 0.0
	var r = Vector2(x,z).length()
	return smoothstep(180,340,r)*(1-smoothstep(2630,2830,r))*(1-smoothstep(deg_to_rad(27),deg_to_rad(35),absf(atan2(x,z))))

func _shaped_height(x: float,z: float) -> float:
	var r = Vector2(x,z).length()
	var a = atan2(x,z)
	var h: float = base._landform(x,z)
	var envelope = smoothstep(80,850,r)*(1-smoothstep(2220,2850,r))
	# Reduce the old repetitive folds inside this face, retaining the radial fall.
	h -= parameters.relief*envelope*(base._drainage(a,r)+.20*sin(a*3+parameters.phase))*.85
	var ridge = landforms[0]
	var ridge_x = 45*sin((z-270)*.010)-25*sin(z*.019)
	var ridge_envelope = exp(-pow((z-ridge.position.y)/ridge.radius.y,4))
	h += ridge.height*ridge_envelope*exp(-pow((x-ridge_x)/ridge.radius.x,2))*(.8+.2*cos(z*.023))
	var bowl = landforms[1]
	h += bowl.height*exp(-((Vector2(x,z)-bowl.position)/bowl.radius).length_squared()*1.5)
	# Gullies share the interrupted escarpment's snow gaps and forest glades.
	var gully_envelope = smoothstep(860,1060,z)*(1-smoothstep(1560,1800,z))
	for side in [-1,1]:
		var distance_value = (x-gully_x(z,side))/62.0
		h -= 27*exp(-distance_value*distance_value)*gully_envelope
	var gap = snow_gap(x,z)
	for crag in crags:
		var cross_weight = crag_weight(crag,x)
		if cross_weight<=0: continue
		var along = z-crag_z(crag,x)
		var step = lerpf(smoothstep(-4,8,along),smoothstep(-125,125,along),gap)
		h -= crag.height*cross_weight*step*(1-smoothstep(120,400,along))
		# Broken shoulders rise behind each scarp, giving it thickness in plan
		# and silhouette instead of forming a continuous retaining wall.
		h += 24*cross_weight*exp(-pow((along+80)/95,2))*(1-gap)
	# A quieter shelf before the band allows braking and a view into its gaps.
	h += 22*exp(-pow((z-1190)/155,2))*exp(-pow(x/730,4))
	var apron = smoothstep(1620,1720,z)*(1-smoothstep(1890,2020,z))
	h += apron*(.65*sin(z*TAU/40+x*.021)+.40*sin(z*TAU/28-x*.032)+1.3*sin(x*.069+sin(z*.027)))
	var drop = landforms[4]
	var d = Vector2(x,z)-drop.position
	var drop_along = d.y-.07*d.x-3*sin(d.x*.12)
	var drop_width = pow(clampf(1-pow(d.x/(drop.width+20),2),0,1),2)
	h -= drop.height*drop_width*smoothstep(0,4,drop_along)*(1-smoothstep(90,180,drop_along))
	return h

func gully_x(z: float,side: int) -> float:
	return side*(210+48*sin((z-1000)/190.0))+32*sin((z-900)/330.0)

func glade_x(z: float,side: int) -> float:
	return gully_x(1850,side)+55*sin((z-1850)/155.0+side*.4)-55*sin(side*.4)

func crag_weight(crag: Dictionary,x: float) -> float:
	return 1-smoothstep(crag.width*.55,crag.width,absf(x-crag.position.x))

func crag_z(crag: Dictionary,x: float) -> float:
	return crag.position.y+.11*(x-crag.position.x)+10*sin(x*.048)+4*sin(x*.107)

func band_z(x: float) -> float:
	var nearest = crags[0]
	for crag in crags:
		if absf(x-crag.position.x)<absf(x-nearest.position.x): nearest = crag
	return crag_z(nearest,x)

func snow_gap(x: float,z: float) -> float:
	var distance_value = minf(absf(x-gully_x(z,-1)),absf(x-gully_x(z,1)))
	return 1-smoothstep(12,34,distance_value)

func exposure_at(x: float,z: float) -> Color:
	var weight = sector_weight(x,z)
	if weight<=0: return Color(0,0,0,0)
	var rock = 0.0
	for crag in crags:
		var along = z-crag_z(crag,x)
		var face = 1-smoothstep(12,34,absf(along))
		var shoulder = .75*exp(-pow((along+80)/90,2))
		rock = maxf(rock,maxf(face,shoulder)*crag_weight(crag,x)*(1-snow_gap(x,z)))
	var ridge = landforms[0]
	var ridge_distance = absf(x-(45*sin((z-270)*.010)-25*sin(z*.019)))
	rock = maxf(rock,smoothstep(34,62,ridge_distance)*(1-smoothstep(90,125,ridge_distance))*exp(-pow((z-ridge.position.y)/ridge.radius.y,4))*.85)
	var drop_delta = Vector2(x,z)-landforms[4].position
	var drop_along = drop_delta.y-.07*drop_delta.x-3*sin(drop_delta.x*.12)
	var drop_width = pow(clampf(1-pow(drop_delta.x/(landforms[4].width+20),2),0,1),2)
	rock = maxf(rock,drop_width*(1-smoothstep(5,12,absf(drop_along))))
	# The mask is authoritative only where a feature asks for stone or clean snow.
	var snow = snow_gap(x,z)*smoothstep(950,1120,z)*(1-smoothstep(1550,1750,z))
	snow = maxf(snow,smoothstep(1780,1910,z))
	return Color(rock,0,0,maxf(rock,snow)*weight)

func stand_density(x: float,z: float) -> float:
	var density = 0.0
	for stand in stands:
		var p = (Vector2(x,z)-stand.position)/stand.radius
		density = maxf(density,1-smoothstep(.65,1.0,p.length()+.08*sin(x*.037)*sin(z*.043)))
	return density

func _scatter() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value+50771
	# Deterministic dart throwing avoids visible orchard rows. Spatial rejection
	# supplies minimum separation while irregular footprints define clearings.
	for i in 42000:
		var p = Vector2(rng.randf_range(-1380,1380),rng.randf_range(1830,2640))
		var density = stand_density(p.x,p.y)*sector_weight(p.x,p.y)
		if rng.randf()>density*.75 or contact_normal(p.x,p.y).y<.70: continue
		var gap = minf(absf(p.x-glade_x(p.y,-1)),absf(p.x-glade_x(p.y,1)))
		if gap<10+3*sin(p.y*.018) or in_landing_fan(p.x,p.y): continue
		_put_obstacle(p,true,rng.randf_range(.7,1.5),rng)
	for i in 2900:
		var p = Vector2(rng.randf_range(-1180,1180),rng.randf_range(420,1990))
		if sector_weight(p.x,p.y)<.95 or in_landing_fan(p.x,p.y): continue
		var below = p.y-band_z(p.x)
		var talus = smoothstep(35,95,below)*(1-smoothstep(330,560,below))
		var ridge = landforms[0]
		var outcrop = exp(-pow((p.y-ridge.position.y)/ridge.radius.y,4))*smoothstep(100,155,absf(p.x))*(1-smoothstep(240,340,absf(p.x)))
		var cluster = clampf(.5+.5*sin(p.x*.043+sin(p.y*.027)),0,1)
		if rng.randf()>maxf(talus*.8,outcrop*.6)*cluster: continue
		# Keep the widening bowl approach below the ridge readable and clear.
		if p.y<1060 and absf(p.x)<130+150*smoothstep(500,940,p.y): continue
		if snow_gap(p.x,p.y)>.01 or contact_normal(p.x,p.y).y<.53: continue
		_put_obstacle(p,false,rng.randf_range(1.1,3.25),rng)

func _put_obstacle(p: Vector2,tree: bool,scale_value: float,rng: RandomNumberGenerator) -> void:
	var radius = (.46 if tree else 1.35)*scale_value
	# Existing obstacle envelopes are the single source for scenery and impacts.
	for gz in range(floori((p.y-12)/SPATIAL_CELL),floori((p.y+12)/SPATIAL_CELL)+1):
		for gx in range(floori((p.x-12)/SPATIAL_CELL),floori((p.x+12)/SPATIAL_CELL)+1):
			for idx in obstacle_grid.get(Vector2i(gx,gz),[]):
				var other = obstacles[idx]
				if p.distance_to(Vector2(other.position.x,other.position.z))<maxf(6.0,radius+other.radius+2): return
	add_obstacle({"position":Vector3(p.x,sample(p.x,p.y).height,p.y),"radius":radius,
		"height":(11.0 if tree else 2.0)*scale_value,"scale":scale_value,"yaw":rng.randf_range(-PI,PI),"tree":tree})

func in_landing_fan(x: float,z: float) -> bool:
	var d = Vector2(x,z)-landforms[4].position
	if d.y>-65 and d.y<175 and absf(d.x)<56: return true
	if sector_weight(x,z)>0: return false
	for jump in legacy_jumps:
		var delta = Vector2(x,z)-jump.position
		if delta.dot(jump.direction)>-100 and delta.dot(jump.direction)<280 and absf(delta.cross(jump.direction))<jump.width+24: return true
	return false

func continuation_height(x: float,z: float) -> float:
	# Inside the mountain, all clients see the baked contact triangles. The
	# changed face ends before the physical boundary; the collar remains v4.
	if bounds().has_point(Vector2(x,z)): return sample(x,z).height
	return base.continuation_height(x,z)

func render_normal(x: float,z: float) -> Vector3:
	var ix = roundi((x-X_MIN)/CELL)
	var iz = roundi((z-Z_MIN)/CELL)
	if ix>0 and ix<NX-1 and iz>0 and iz<NZ-1:
		return Vector3(heights[iz*NX+ix-1]-heights[iz*NX+ix+1],8,heights[(iz-1)*NX+ix]-heights[(iz+1)*NX+ix]).normalized()
	return contact_normal(x,z)

func is_summit_mountain() -> bool: return true
func spawn_point() -> Vector3: return base.spawn_point()
func spawn_heading() -> float: return 0.0
func launch_point(heading: float) -> Vector3: return base.launch_point(heading)
func reached_base(position: Vector3) -> bool: return base.reached_base(position)
func descent_progress(position: Vector3) -> float: return base.descent_progress(position)
func snow_depth_at(x: float,z: float) -> float: return base.snow_depth_at(x,z)
