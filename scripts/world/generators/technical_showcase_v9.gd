extends "res://scripts/world/heightfield_surface.gd"
## Powder banks and buried outcrops over the archived v8 showcase.
## V1-v8 remain archived unchanged. All features are static physical terrain data;
## no route, renderer, camera or rider state participates in surface generation.
const BaseMountain = preload("res://scripts/world/generated_mountain.gd")
const GENERATOR_ID = "alpine-drainage"
const GENERATOR_VERSION = 9
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
var ribs: Array[Dictionary] = []
var rib_grid: Dictionary = {}
var exposure_image: Image
var generation_ms: float
var height_checksum: String
var obstacle_checksum: String
var snow_noise = FastNoiseLite.new()
var powder_deposits: Array[Dictionary] = []

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
		{"kind":"ridge","name":"Broken ridge and rock spines","position":Vector2(0,590),"radius":Vector2(92,380),"height":72.0},
		{"kind":"bowl","name":"Interlocking gullies","position":Vector2(35,980),"radius":Vector2(345,330),"height":-48.0},
		{"kind":"band","name":"Rock band · snow ramps","position":Vector2(0,1370),"height":38.0},
		{"kind":"apron","name":"Rough folds and boulder fields","position":Vector2(0,1790)},
		{"kind":"drop","name":"Optional shelf drop","position":Vector2(0,1770),"width":26.0,"height":6.0,"approach_length":65.0,"landing_length":130.0}]
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
	_build_ribs()
	for iz in range(int((160-Z_MIN)/CELL),int((2832-Z_MIN)/CELL)+1):
		var z = Z_MIN+iz*CELL
		for ix in range(int((-1792-X_MIN)/CELL),int((1792-X_MIN)/CELL)+1):
			var x = X_MIN+ix*CELL
			var weight = sector_weight(x,z)
			if weight>0:
				heights[iz*NX+ix] = lerpf(heights[iz*NX+ix],_shaped_height(x,z),weight)
	_drain_channels()
	_sculpt_snow()
	_accumulate_powder()
	for ob in base.obstacles:
		if sector_weight(ob.position.x,ob.position.z)<=0: add_obstacle(ob.duplicate())
	_scatter()
	_powder_outcrops()
	exposure_image = Image.create(MASK_SIZE.x,MASK_SIZE.y,false,Image.FORMAT_RGBA8)
	for iz in MASK_SIZE.y:
		for ix in MASK_SIZE.x:
			var p = MASK_ORIGIN+Vector2(ix,iz)*CELL
			exposure_image.set_pixel(ix,iz,exposure_at(p.x,p.y))
	features = [{"name":"Summit · south showcase ↓","position":Vector2.ZERO}]
	for form in landforms: features.append({"name":form.name,"position":form.position})
	features.append({"name":"Forest stands and glades","position":Vector2(-350,2260)})
	features.append({"name":"Powder garden · banks and buried stone","position":Vector2(gully_x(820,-1),820)})
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
	var ridge_face = clampf((1.0-absf(x-ridge_x)/(ridge.radius.x*1.6))*1.45,0,1)
	h += ridge.height*ridge_envelope*ridge_face*(.88+.12*cos(z*.011))
	var bowl = landforms[1]
	h += bowl.height*exp(-((Vector2(x,z)-bowl.position)/bowl.radius).length_squared()*1.5)
	# Deep, narrow-floor gullies keep their rock shoulders beside the rider.
	# The old broad Gaussian hollows looked almost planar from skiing height.
	var gully_envelope = smoothstep(260,480,z)*(1-smoothstep(1810,1980,z))
	for side in [-1,1]:
		var distance_value = absf(x-gully_x(z,side))
		h -= 38*(1-smoothstep(3,60,distance_value))*gully_envelope
	# Physical folds run through the snow passages as well as their shoulders.
	var rough = smoothstep(260,430,z)*(1-smoothstep(2490,2720,z))
	var centre = gully_x(z,-1) if x<0 else gully_x(z,1)
	if z>1850: centre = glade_x(z,-1) if x<0 else glade_x(z,1)
	var floor_weight = 1-smoothstep(10,28,absf(x-centre))
	# Deposits retain their longitudinal rolls inside the drainage floor;
	# the shoulders carry the stronger transverse folds.
	h += rough*lerpf(_snow_folds(x,z),_snow_folds(centre,z),floor_weight*.85)
	for index in rib_grid.get(Vector2i(floori(x/128),floori(z/128)),[]):
		var rib = ribs[index]
		h += rib.height*rib_weight(rib,x,z)*(1-floor_weight)
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
	# The optional lip has a readable approach and pitched landing. Preserve
	# roughness everywhere else; do not put a convex bump at touchdown.
	var landing_weight = (1-smoothstep(drop.width,drop.width+30,absf(d.x)))*smoothstep(-drop.approach_length-60,-drop.approach_length,d.y)*(1-smoothstep(drop.landing_length,drop.landing_length+70,d.y))
	var landing_height = base._landform(drop.position.x,drop.position.y)-d.y*.72
	h = lerpf(h,landing_height,landing_weight)
	var drop_along = d.y-.07*d.x-3*sin(d.x*.12)
	var drop_width = pow(clampf(1-pow(d.x/(drop.width+20),2),0,1),2)
	h -= drop.height*drop_width*smoothstep(0,4,drop_along)*(1-smoothstep(90,180,drop_along))
	return h

func _drain_channels() -> void:
	# Cut an outlet from closed depressions in each snow drainage. The profile
	# retains rolls and changing pitch, while a banked cross-section gives the
	# narrow snow bed a physical shape instead of a flat strip through cliffs.
	for side in [-1,1]:
		var profile: Array[float] = []
		var previous = 0.0
		for z in range(260,2761,4):
			var centre = gully_x(z,side) if z<1850 else glade_x(z,side)
			var raw = sample(centre,z).height
			var height_value = raw if z==260 else minf(raw,previous-.22*CELL)
			profile.append(height_value)
			previous = height_value
		for z in range(260,2761,4):
			var centre = gully_x(z,side) if z<1850 else glade_x(z,side)
			var iz = roundi((z-Z_MIN)/CELL)
			var envelope = smoothstep(260,430,z)*(1-smoothstep(2490,2760,z))
			for ix in range(floori((centre-34-X_MIN)/CELL),ceili((centre+34-X_MIN)/CELL)+1):
				var x = X_MIN+ix*CELL
				var distance_value = absf(x-centre)
				var weight = (1-smoothstep(12,34,distance_value))*envelope*sector_weight(x,z)
				var banked = profile[(z-260)/4]+.014*distance_value*distance_value
				heights[iz*NX+ix] = lerpf(heights[iz*NX+ix],banked,weight)

func _sculpt_snow() -> void:
	# Keep the laboratory's small snow noise independent of the v4 landform noise.
	snow_noise.seed = seed_value
	snow_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	snow_noise.frequency = .009
	snow_noise.fractal_octaves = 3
	# Every weight reads the same pre-relief surface. Commit only after the entire
	# pass, so slope/exposure at neighbouring vertices cannot depend on loop order.
	var sculpted = heights.duplicate()
	for iz in range(int((160-Z_MIN)/CELL),int((2832-Z_MIN)/CELL)+1):
		var z = Z_MIN+iz*CELL
		for ix in range(int((-1792-X_MIN)/CELL),int((1792-X_MIN)/CELL)+1):
			var x = X_MIN+ix*CELL
			var weight = snow_relief_weight(x,z)
			if weight>0:
				sculpted[iz*NX+ix] += snow_relief_at(x,z)*weight
	heights = sculpted

func snow_relief_at(x: float,z: float) -> float:
	# Same metre-scale ridges, scallops and mounds as laboratory v3. The south
	# face's fade is separate; neither heading nor a preferred route sets phase.
	var warp = snow_noise.get_noise_2d(x*1.7+513.0,z*.65-927.0)
	var phase = x*.29+z*.035+sin(z*.014)*.65+warp*2.0
	var drift = sin(phase)*1.15
	var scallop = sin(x*.47-z*.058+warp*3.4)*.18
	var mounds = snow_noise.get_noise_2d(x*4.0-319.0,z*.5+811.0)*.70
	return drift+scallop+mounds

func snow_relief_weight(x: float,z: float) -> float:
	# Generation-only geometric masks, evaluated before sculpting; no material,
	# weather, camera, track or rider state participates in physical snow coverage.
	var weight = sector_weight(x,z)*smoothstep(260,430,z)*(1-smoothstep(2490,2720,z))
	if weight<=0: return 0.0
	var d = Vector2(x,z)-landforms[4].position
	# Protect the entire authored approach/landing blend plus a support stencil.
	var protected = (1-smoothstep(80,112,absf(d.x)))*smoothstep(-185,-153,d.y)*(1-smoothstep(228,260,d.y))
	weight *= 1-protected
	if weight<=0: return 0.0
	var normal_value = render_normal(x,z)
	# Shallow south-facing exits cannot reliably carry a full transverse mound:
	# preserve their drainage instead of creating a pocket at low riding speed.
	var grade = normal_value.z/maxf(normal_value.y,.001)
	var exposed = exposure_at(x,z).r
	return weight*smoothstep(.18,.50,grade)*smoothstep(.60,.82,normal_value.y)*(1-smoothstep(.10,.48,exposed))

func _snow_folds(x: float,z: float) -> float:
	return 3.2*sin(z*TAU/64+x*.025)+1.5*sin(z*TAU/52-x*.035)+.8*sin(z*TAU/40+x*.041)+7.0*sin(z*.020+x*.018)*sin(x*.025-z*.009)

func gully_x(z: float,side: int) -> float:
	var spread = (130+.035*z)*smoothstep(180,620,z)
	return side*spread+smoothstep(220,450,z)*(42*sin((z-300)/108.0+side*.3)+12*sin(z/43.0))

func glade_x(z: float,side: int) -> float:
	return gully_x(1850,side)+30*sin((z-1850)/66.0+side*.4)-30*sin(side*.4)+9*sin((z-1850)/27.0)

func _build_ribs() -> void:
	# Staggered rock spines project above and across the fall line. They remain
	# substantial terrain from the downhill camera, not distant scenery cuts.
	for row in range(15):
		var z = 420.0+row*120
		for side in [-1,1]:
			var centre = gully_x(z,side) if z<1830 else glade_x(z,side)
			var direction = -1.0 if (row+int(side))%2==0 else 1.0
			var rib = {"position":Vector2(centre+direction*59,z),"radius":Vector2(38+(row%3)*7,45+(row%2)*14),"height":38+(row%4)*12,"angle":direction*.45}
			_add_rib(rib)
		# Larger buttresses divide the face into several visible rock ranges.
		if row%3==0:
			_add_rib({"position":Vector2(20*sin(row),z+50),"radius":Vector2(65,85),"height":105.0,"angle":.35})
	for row in range(6):
		for side in [-1,1]:
			_add_rib({"position":Vector2(side*(360+row*85),650+row*245),"radius":Vector2(75,105),"height":95.0+row*9,"angle":side*.65})

func _add_rib(rib: Dictionary) -> void:
	var drop = landforms[4].position
	if absf(rib.position.x-drop.x)<rib.radius.x+56 and absf(rib.position.y-(drop.y+55))<rib.radius.y+120: return
	var index = ribs.size()
	ribs.append(rib)
	var extent = maxf(rib.radius.x,rib.radius.y)*1.5
	for gz in range(floori((rib.position.y-extent)/128),floori((rib.position.y+extent)/128)+1):
		for gx in range(floori((rib.position.x-extent)/128),floori((rib.position.x+extent)/128)+1):
			var cell = Vector2i(gx,gz)
			if not rib_grid.has(cell): rib_grid[cell] = []
			rib_grid[cell].append(index)

func rib_weight(rib: Dictionary,x: float,z: float) -> float:
	var local = (Vector2(x,z)-rib.position).rotated(rib.angle)/rib.radius
	# Intersected planar faces retain a broad crown and coherent joint direction.
	# Each terrace spans several contact cells; no shader displacement or hidden
	# collision shell is placed over the skiable surface.
	var radius = maxf(maxf(absf(local.x),absf(local.y)),(absf(local.x)+absf(local.y))*.72)
	if radius>=1: return 0.0
	var face = clampf((1-radius)*1.75,0,1)
	var joint = local.x*.38+local.y*.16
	var terraces = .045*smoothstep(.23,.31,face)+.045*smoothstep(.58,.66,face)
	return clampf(face*.88+terraces-joint*face*.15,0,1.05)

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
	return 1-smoothstep(8,16,distance_value)

func exposure_at(x: float,z: float) -> Color:
	var weight = sector_weight(x,z)
	if weight<=0: return Color(0,0,0,0)
	var rock = 0.0
	for index in rib_grid.get(Vector2i(floori(x/128),floori(z/128)),[]):
		var w = rib_weight(ribs[index],x,z)
		rock = maxf(rock,smoothstep(.04,.20,w)*.96*(1-snow_gap(x,z)))
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
	# Snow settles on the crowns and small ledges; near-vertical faces stay rock.
	var shelter = smoothstep(.70,.93,render_normal(x,z).y)
	rock *= 1.0-shelter*.55
	var powder = powder_region(x,z)*smoothstep(.60,.82,render_normal(x,z).y)
	rock *= 1.0-powder
	snow = maxf(snow,powder)
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
		if rng.randf()>density*.75 or contact_normal(p.x,p.y).y<.55: continue
		var gap = minf(absf(p.x-glade_x(p.y,-1)),absf(p.x-glade_x(p.y,1)))
		if gap<9+2*sin(p.y*.018) or in_landing_fan(p.x,p.y): continue
		_put_obstacle(p,true,rng.randf_range(.7,1.5),rng)
	for i in 12000:
		var p = Vector2(rng.randf_range(-1180,1180),rng.randf_range(380,2490))
		if sector_weight(p.x,p.y)<.95 or in_landing_fan(p.x,p.y): continue
		var below = p.y-band_z(p.x)
		var talus = smoothstep(35,95,below)*(1-smoothstep(330,560,below))
		var ridge = landforms[0]
		var outcrop = exp(-pow((p.y-ridge.position.y)/ridge.radius.y,4))*smoothstep(100,155,absf(p.x))*(1-smoothstep(240,340,absf(p.x)))
		var cluster = clampf(.5+.5*sin(p.x*.043+sin(p.y*.027)),0,1)
		if rng.randf()>maxf(talus*.8,outcrop*.6)*cluster: continue
		# Keep the widening bowl approach below the ridge readable and clear.
		if p.y<500 and absf(p.x)<75: continue
		var lane = gully_x(p.y,-1) if p.x<0 else gully_x(p.y,1)
		if p.y>1850: lane = glade_x(p.y,-1) if p.x<0 else glade_x(p.y,1)
		if absf(p.x-lane)<8: continue
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
func powder_region(x: float,z: float) -> float:
	var envelope = smoothstep(540,650,z)*(1-smoothstep(1160,1290,z))
	envelope = maxf(envelope,smoothstep(1970,2050,z)*(1-smoothstep(2330,2430,z)))
	if envelope<=0: return 0.0
	var a = gully_x(z,-1) if z<1850 else glade_x(z,-1)
	var b = gully_x(z,1) if z<1850 else glade_x(z,1)
	var distance_m = minf(absf(x-a),absf(x-b))
	return envelope*(1-smoothstep(32,68,distance_m))*sector_weight(x,z)

func snow_depth_at(x: float,z: float) -> float:
	var region = powder_region(x,z)
	if region<=0: return base.snow_depth_at(x,z)
	var deposit = .24+.07*sin(x*.031+sin(z*.019))
	return lerpf(base.snow_depth_at(x,z),deposit,region)

func _accumulate_powder() -> void:
	# Leeward banks accumulate beside the existing drainages. Wide longitudinal
	# envelopes keep the rolls skiable; the exact baked 4 m surface owns them.
	for row in 8:
		var z = [660.0,790.0,920.0,1050.0,1180.0,2080.0,2190.0,2310.0][row]
		for side in [-1,1]:
			var centre = gully_x(z,side) if z<1850 else glade_x(z,side)
			for edge in [-1,1]:
				var deposit = {"position":Vector2(centre+edge*(23.0+3.0*sin(row*2.1+side)),z+edge*15.0),"radius":Vector2(16.0+row%3*2.0,40.0+row%2*12.0),"height":2.6+(row%3)*.65}
				powder_deposits.append(deposit)
	var accumulated = heights.duplicate()
	for deposit in powder_deposits:
		var p: Vector2 = deposit.position
		var radius: Vector2 = deposit.radius
		for iz in range(floori((p.y-radius.y*2-Z_MIN)/CELL),ceili((p.y+radius.y*2-Z_MIN)/CELL)+1):
			for ix in range(floori((p.x-radius.x*2-X_MIN)/CELL),ceili((p.x+radius.x*2-X_MIN)/CELL)+1):
				var x = X_MIN+ix*CELL
				var z = Z_MIN+iz*CELL
				var local = (Vector2(x,z)-p)/radius
				var falloff = exp(-local.length_squared()*1.7)*(1-smoothstep(1.5,2.0,local.length()))
				# Snow rests on shoulders, never across the authored cliff drop.
				var weight = powder_region(x,z)*smoothstep(.58,.80,render_normal(x,z).y)
				accumulated[iz*NX+ix] += deposit.height*falloff*weight
	heights = accumulated

func _powder_outcrops() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value+90617
	for z in [736.0,824.0,912.0,1016.0,2136.0,2272.0]:
		for side in [-1,1]:
			var centre = gully_x(z,side) if z<1850 else glade_x(z,side)
			for edge in [-1,1]:
				var p = Vector2(centre+edge*(18.0+rng.randf_range(0,4)),z+edge*9.0)
				if contact_normal(p.x,p.y).y>.60: _put_obstacle(p,false,rng.randf_range(1.7,2.5),rng)
	for ob in obstacles:
		if not ob.tree and powder_region(ob.position.x,ob.position.z)>.35:
			ob["powder_cap"] = true
