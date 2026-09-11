extends RefCounted
## A seeded face description. Coordinates here are face-local metres; only the
## owning massif bakes heights and obstacles. Weak ownership avoids reference cycles.
const CELL = 4.0
var owner_ref: WeakRef
var index: int
var heading: float
var seed_value: int
var landforms: Array[Dictionary] = []
var stands: Array[Dictionary] = []
var crags: Array[Dictionary] = []
var ribs: Array[Dictionary] = []
var rib_grid: Dictionary = {}
var powder_deposits: Array[Dictionary] = []
var snow_noise = FastNoiseLite.new()
var bend_phase: float
var bend_scale: float
var terrain_noise = FastNoiseLite.new()
var forest_noise = FastNoiseLite.new()
var geology_angle: float
var ruggedness: float
var forest_cover: float

func _init(massif, face_index: int, face_heading: float) -> void:
	owner_ref = weakref(massif)
	index = face_index
	heading = face_heading
	seed_value = massif.seed_value + 104729 * (index + 1)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	bend_phase = rng.randf_range(-PI,PI)
	bend_scale = rng.randf_range(.65,1.20)
	geology_angle = rng.randf_range(-.85,.85)
	ruggedness = rng.randf_range(.55,1.3)
	forest_cover = rng.randf_range(.65,1.0)
	terrain_noise.seed = seed_value+3191
	terrain_noise.frequency = .0038
	terrain_noise.fractal_octaves = 3
	forest_noise.seed = seed_value+7193
	forest_noise.frequency = .0045
	forest_noise.fractal_octaves = 3
	landforms = [
		{"kind":"ridge","name":"Broken ridge and rock spines","position":Vector2(0,590),"radius":Vector2(92,380),"height":72.0},
		{"kind":"bowl","name":"Interlocking gullies","position":Vector2(35,980),"radius":Vector2(345,330),"height":-48.0},
		{"kind":"band","name":"Rock band · snow ramps","position":Vector2(0,1370),"height":38.0},
		{"kind":"apron","name":"Rough folds and boulder fields","position":Vector2(0,1790)},
		{"kind":"drop","name":"Optional shelf drop","position":Vector2(0,1770),"width":26.0,"height":6.0,"approach_length":65.0,"landing_length":130.0}]
	for form in landforms:
		if form.kind in ["ridge","bowl"]:
			form.position += Vector2(rng.randf_range(-180,180),rng.randf_range(-120,200))
			form.radius *= Vector2(rng.randf_range(.8,1.8),rng.randf_range(.7,1.5))
			form.height *= rng.randf_range(.45,1.1)*ruggedness
	landforms[4].position = Vector2(rng.randf_range(-65,65),rng.randf_range(1560,1940))
	# Each face has its own outcropping strata, with no common cliff altitude.
	for i in rng.randi_range(3,7):
		var z = rng.randf_range(700,2160)
		crags.append({"position":Vector2(rng.randf_range(-.43,.43)*z,z),"width":rng.randf_range(90,280),"height":rng.randf_range(18,55)*ruggedness,"angle":geology_angle+rng.randf_range(-.3,.3),"phase":rng.randf_range(-PI,PI),"length":rng.randf_range(160,380)})
	landforms[2].position = crags[0].position
	# Overlapping, warped stands supplement a continuous woodland suitability
	# field. Upper pockets, mid-slope woods and foothill forests share one rule.
	for band in 3:
		for i in rng.randi_range(4,7):
			var z = rng.randf_range(690+band*570,1230+band*570)
			stands.append({"position":Vector2(rng.randf_range(-.42,.42)*z,z),"radius":Vector2(rng.randf_range(110,280),rng.randf_range(160,360)),"angle":rng.randf_range(-1.2,1.2),"density":rng.randf_range(.55,1.0)})
	_build_ribs(rng)
	snow_noise.seed = seed_value
	snow_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	snow_noise.frequency = .009
	snow_noise.fractal_octaves = 3
	for i in 32:
		var z = rng.randf_range(640,1190) if rng.randf()<.6 else rng.randf_range(2040,2340)
		var side = -1 if rng.randf()<.5 else 1
		var edge = -1 if rng.randf()<.5 else 1
		var centre = gully_x(z,side) if z<1850 else glade_x(z,side)
		powder_deposits.append({"position":Vector2(centre+edge*rng.randf_range(23,32),z),"radius":Vector2(rng.randf_range(14,23),rng.randf_range(32,72)),"height":rng.randf_range(1.8,3.5)})

func to_world(p: Vector2) -> Vector2: return p.rotated(-heading)
func to_local(p: Vector2) -> Vector2: return p.rotated(heading)

func sector_weight(x: float,z: float) -> float:
	var r = Vector2(x,z).length()
	return smoothstep(180,340,r)*(1-smoothstep(2630,2830,r))*(1-smoothstep(deg_to_rad(25),deg_to_rad(35),absf(atan2(x,z))))

func _base_height(x: float,z: float) -> float:
	var p = to_world(Vector2(x,z))
	return owner_ref.get_ref().foundation_height(p.x,p.y)

func render_normal(x: float,z: float) -> Vector3:
	var p = to_world(Vector2(x,z))
	var n: Vector3 = owner_ref.get_ref().render_normal(p.x,p.y)
	var horizontal = to_local(Vector2(n.x,n.z))
	return Vector3(horizontal.x,n.y,horizontal.y)

func landing_weight(x: float,z: float) -> float:
	var d = Vector2(x,z)-landforms[4].position
	return (1-smoothstep(80,112,absf(d.x)))*smoothstep(-185,-153,d.y)*(1-smoothstep(228,260,d.y))

func _shaped_height(x: float,z: float,foundation: float) -> float:
	var h = foundation
	var ridge = landforms[0]
	var ridge_x = ridge_center(z)
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
	var rock_relief = 0.0
	for index in rib_grid.get(Vector2i(floori(x/128),floori(z/128)),[]):
		var rib = ribs[index]
		rock_relief = maxf(rock_relief,rib.height*rib_weight(rib,x,z))
	h += rock_relief*(1-floor_weight)
	var gap = snow_gap(x,z)
	for crag in crags:
		var cross_weight = crag_weight(crag,x)
		if cross_weight<=0: continue
		var along = z-crag_z(crag,x)
		var step = lerpf(smoothstep(-4,8,along),smoothstep(-125,125,along),gap)
		h -= crag.height*cross_weight*step*(1-smoothstep(crag.length*.4,crag.length,along))
		# Broken shoulders rise behind each scarp, giving it thickness in plan
		# and silhouette instead of forming a continuous retaining wall.
		h += crag.height*.35*cross_weight*exp(-pow((along+80)/95,2))*(1-gap)
	var apron = smoothstep(1620,1720,z)*(1-smoothstep(1890,2020,z))
	h += apron*(.65*sin(z*TAU/40+x*.021)+.40*sin(z*TAU/28-x*.032)+1.3*sin(x*.069+sin(z*.027)))
	var drop = landforms[4]
	var d = Vector2(x,z)-drop.position
	# The optional lip has a readable approach and pitched landing. Preserve
	# roughness everywhere else; do not put a convex bump at touchdown.
	var landing_weight = (1-smoothstep(drop.width,drop.width+30,absf(d.x)))*smoothstep(-drop.approach_length-60,-drop.approach_length,d.y)*(1-smoothstep(drop.landing_length,drop.landing_length+70,d.y))
	if landing_weight>0:
		var landing_height = _base_height(drop.position.x,drop.position.y)-d.y*.72
		h = lerpf(h,landing_height,landing_weight)
	var drop_along = d.y-.07*d.x-3*sin(d.x*.12)
	var drop_width = pow(clampf(1-pow(d.x/(drop.width+20),2),0,1),2)
	h -= drop.height*drop_width*smoothstep(0,4,drop_along)*(1-smoothstep(90,180,drop_along))
	return h

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
	var weight = smoothstep(260,430,z)*(1-smoothstep(2490,2720,z))
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
	# Warped non-periodic snow rolls avoid corrugated rows on every face.
	return 9*terrain_noise.get_noise_2d(x*2.5,z*2.0)+2.5*terrain_noise.get_noise_2d(x*7.0+817,z*5.0-331)

func ridge_center(z: float) -> float:
	return landforms[0].position.x+terrain_noise.get_noise_2d(731,z*.8)*145

func gully_x(z: float,side: int) -> float:
	var spread = (130+.035*z)*smoothstep(180,620,z)
	return side*spread+smoothstep(220,450,z)*(42*bend_scale*sin((z-300)/108.0+side*.3+bend_phase)+12*sin(z/43.0+bend_phase))

func glade_x(z: float,side: int) -> float:
	return gully_x(1850,side)+30*bend_scale*(sin((z-1850)/66.0+side*.4+bend_phase)-sin(side*.4+bend_phase))+9*sin((z-1850)/27.0)

func _build_ribs(rng: RandomNumberGenerator) -> void:
	# Irregular outcropping ridge groups follow a local geological direction.
	# Overlapping shoulders form connected mass, without paired rows or spikes.
	for group in rng.randi_range(5,10):
		var z = rng.randf_range(460,2240)
		var origin = Vector2(rng.randf_range(-.44,.44)*z,z)
		var angle = geology_angle+rng.randf_range(-.65,.65)
		var direction = Vector2(sin(angle),cos(angle))
		var width = rng.randf_range(55,145)
		var length_m = rng.randf_range(100,260)
		var height_m = rng.randf_range(25,72)*ruggedness
		var count = rng.randi_range(2,4)
		for member in count:
			var position = origin+direction*(member-(count-1)*.5)*length_m*.65
			position += Vector2(rng.randf_range(-35,35),rng.randf_range(-28,28))
			_add_rib({"position":position,"radius":Vector2(width*rng.randf_range(.65,1.2),length_m*rng.randf_range(.7,1.2)),"height":height_m*rng.randf_range(.55,1.0),"angle":angle+rng.randf_range(-.3,.3),"crown":rng.randf_range(1.5,2.5),"skew":rng.randf_range(-.3,.3),"phase":rng.randf_range(-PI,PI)})

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
	local.x += rib.skew*local.y
	var radius = pow(pow(absf(local.x),3)+pow(absf(local.y),3),1.0/3.0)
	radius *= 1+.13*sin(local.y*5+rib.phase)+.07*sin(local.x*7-rib.phase)
	if radius>=1: return 0.0
	var face = smoothstep(0,1,clampf((1-radius)*rib.crown,0,1))
	var joint = local.x*.38+local.y*.16
	var terraces = .045*smoothstep(.23,.31,face)+.045*smoothstep(.58,.66,face)
	return clampf(face*.88+terraces-joint*face*.15,0,1.05)

func crag_weight(crag: Dictionary,x: float) -> float:
	return 1-smoothstep(crag.width*.55,crag.width,absf(x-crag.position.x))

func crag_z(crag: Dictionary,x: float) -> float:
	return crag.position.y+crag.angle*(x-crag.position.x)+18*sin(x*.018+crag.phase)+5*sin(x*.053-crag.phase)

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
	var gap = snow_gap(x,z)
	for index in rib_grid.get(Vector2i(floori(x/128),floori(z/128)),[]):
		var w = rib_weight(ribs[index],x,z)
		rock = maxf(rock,smoothstep(.04,.20,w)*.96*(1-gap))
	for crag in crags:
		var along = z-crag_z(crag,x)
		var face = 1-smoothstep(12,34,absf(along))
		var shoulder = .75*exp(-pow((along+80)/90,2))
		rock = maxf(rock,maxf(face,shoulder)*crag_weight(crag,x)*(1-gap))
	var ridge = landforms[0]
	var ridge_distance = absf(x-ridge_center(z))/ridge.radius.x
	rock = maxf(rock,smoothstep(.4,.7,ridge_distance)*(1-smoothstep(1,1.4,ridge_distance))*exp(-pow((z-ridge.position.y)/ridge.radius.y,4))*.85)
	var drop_delta = Vector2(x,z)-landforms[4].position
	var drop_along = drop_delta.y-.07*drop_delta.x-3*sin(drop_delta.x*.12)
	var drop_width = pow(clampf(1-pow(drop_delta.x/(landforms[4].width+20),2),0,1),2)
	rock = maxf(rock,drop_width*(1-smoothstep(5,12,absf(drop_along))))
	# The mask is authoritative only where a feature asks for stone or clean snow.
	var snow = gap*smoothstep(950,1120,z)*(1-smoothstep(1550,1750,z))
	snow = maxf(snow,smoothstep(1780,1910,z))
	# Snow settles on the crowns and small ledges; near-vertical faces stay rock.
	var shelter = smoothstep(.70,.93,render_normal(x,z).y)
	rock *= 1.0-shelter*.55
	var powder = powder_region(x,z)*smoothstep(.60,.82,render_normal(x,z).y)
	rock *= 1.0-powder
	snow = maxf(snow,powder)
	return Color(rock,0,0,maxf(rock,snow))

func stand_density(x: float,z: float) -> float:
	var patch = forest_noise.get_noise_2d(x,z)
	var clearing = forest_noise.get_noise_2d(x*3.4+971,z*3.4-537)
	var density = .30*smoothstep(-.30,.28,patch)
	for stand in stands:
		var p = (Vector2(x,z)-stand.position).rotated(stand.angle)/stand.radius
		density = maxf(density,stand.density*(1-smoothstep(.45,1.1,p.length()+patch*.65)))
	var treeline = 530+170*forest_noise.get_noise_2d(x*.5+317,z*.5)
	return density*forest_cover*smoothstep(treeline,treeline+300,z)*(1-smoothstep(2530,2730,z))*smoothstep(-.43,-.02,clearing)

func powder_region(x: float,z: float) -> float:
	var envelope = smoothstep(540,650,z)*(1-smoothstep(1160,1290,z))
	envelope = maxf(envelope,smoothstep(1970,2050,z)*(1-smoothstep(2330,2430,z)))
	if envelope<=0: return 0.0
	var a = gully_x(z,-1) if z<1850 else glade_x(z,-1)
	var b = gully_x(z,1) if z<1850 else glade_x(z,1)
	var distance_m = minf(absf(x-a),absf(x-b))
	return envelope*(1-smoothstep(32,68,distance_m))

