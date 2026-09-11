extends RefCounted
## Finite alpine landforms, tributaries and ecological regions, in face-local metres.
## These describe terrain, never a route to follow or a force on the rider.
const CELL = 4.0
const REGION_CELL = 192.0
var owner_ref: WeakRef
var index: int
var heading: float
var seed_value: int
var landforms: Array[Dictionary] = []
var bowls: Array[Dictionary] = []
var shelves: Array[Dictionary] = []
var channels: Array[Dictionary] = []
var channel_grid: Dictionary = {}
var stands: Array[Dictionary] = []
var clearings: Array[Dictionary] = []
var forest_passages: Array[Dictionary] = []
var debris_pockets: Array[Dictionary] = []
var crags: Array[Dictionary] = []
var ribs: Array[Dictionary] = []
var rib_grid: Dictionary = {}
var powder_deposits: Array[Dictionary] = []
var snow_noise = FastNoiseLite.new()
var terrain_noise = FastNoiseLite.new()
var forest_noise = FastNoiseLite.new()
var geology_angle: float
var ruggedness: float
var forest_cover: float
var wind_angle: float
var treeline_height: float

func _init(massif, face_index: int, face_heading: float) -> void:
	owner_ref = weakref(massif)
	index = face_index
	heading = face_heading
	seed_value = massif.seed_value+104729*(index+1)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	geology_angle = rng.randf_range(-.65,.65)
	ruggedness = rng.randf_range(.75,1.15)
	forest_cover = rng.randf_range(.72,1.0)
	wind_angle = rng.randf_range(-.6,.6)
	treeline_height = rng.randf_range(3270,3450)
	for pair in [[terrain_noise,3191,.0038],[forest_noise,7193,.0045],[snow_noise,9319,.009]]:
		pair[0].seed = seed_value+pair[1]
		pair[0].frequency = pair[2]
		pair[0].noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		pair[0].fractal_octaves = 3
	# Offset cirques widen downhill and overlap across ribs. Bowl depth is small
	# relative to the background drop, retaining pitched floors and open outlets.
	for tier in 3:
		var z = 730+tier*610+rng.randf_range(-100,100)
		var bowl = {"position":Vector2(rng.randf_range(-.22,.22)*z,z),"radius":Vector2(rng.randf_range(240,370)+tier*70,rng.randf_range(280,420)),"height":rng.randf_range(36,68),"angle":rng.randf_range(-.35,.35)}
		bowls.append(bowl)
	for i in 9:
		var z = rng.randf_range(600,2390)
		shelves.append({"position":Vector2(rng.randf_range(-.44,.44)*z,z),"radius":Vector2(rng.randf_range(85,205),rng.randf_range(100,210)),"height":rng.randf_range(12,27),"angle":rng.randf_range(-.55,.55)})
	landforms = [
		{"kind":"ridge","name":"Snow ridges and broken rock shoulders","position":Vector2(rng.randf_range(-110,110),720),"radius":Vector2(180,450),"height":32.0},
		{"kind":"bowl","name":"Open cirques and branching tributaries","position":bowls[0].position,"radius":bowls[0].radius,"height":-bowls[0].height},
		{"kind":"band","name":"Interrupted scarps and snow traverses","position":Vector2(0,1350),"height":28.0},
		{"kind":"apron","name":"Snow shelves and sheltered pockets","position":bowls[2].position},
		{"kind":"drop","name":"Small natural shelf lip","position":shelves[3].position,"width":20.0,"height":3.0,"approach_length":45.0,"landing_length":90.0}]
	_build_channels(rng)
	for i in rng.randi_range(3,5):
		var z = rng.randf_range(700,2160)
		var crag = {"position":Vector2(rng.randf_range(-.40,.40)*z,z),"width":rng.randf_range(140,290),"height":rng.randf_range(19,39)*ruggedness,"angle":geology_angle+rng.randf_range(-.22,.22),"phase":rng.randf_range(-PI,PI),"length":rng.randf_range(230,400),"gaps":[]}
		# Each band breaks at its own positions. Openings have finite length and
		# do not line up into cleared top-to-bottom stripes.
		for gap in [-1,1]:
			crag.gaps.append({"x":crag.position.x+crag.width*gap*rng.randf_range(.20,.55),"width":rng.randf_range(22,42)})
		crags.append(crag)
		debris_pockets.append({"position":crag.position+Vector2(rng.randf_range(-50,50),rng.randf_range(65,160)),"radius":Vector2(rng.randf_range(55,110),rng.randf_range(65,135))})
	landforms[2].position = crags[0].position
	_build_ribs(rng)
	for band in 3:
		for i in 6:
			var z = rng.randf_range(1120+band*390,1590+band*390)
			stands.append({"position":Vector2(rng.randf_range(-.46,.46)*z,z),"radius":Vector2(rng.randf_range(100,260),rng.randf_range(170,360)),"angle":rng.randf_range(-.9,.9),"density":rng.randf_range(.58,1.0)})
	for i in 12:
		var z = rng.randf_range(1200,2570)
		clearings.append({"position":Vector2(rng.randf_range(-.44,.44)*z,z),"radius":Vector2(rng.randf_range(30,85),rng.randf_range(65,160)),"angle":rng.randf_range(-.85,.85)})
	for i in 32:
		var bowl = bowls[i%bowls.size()]
		var position: Vector2 = bowl.position+Vector2(rng.randf_range(-.8,.8)*bowl.radius.x,rng.randf_range(-.7,.9)*bowl.radius.y)
		powder_deposits.append({"position":position,"radius":Vector2(rng.randf_range(18,34),rng.randf_range(42,90)),"height":rng.randf_range(1.0,2.6)})
	_build_forests()

func _build_forests() -> void:
	# Separate ecology stream: tree revisions do not move snow or geology.
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value+0xF012E57
	stands.clear()
	clearings.clear()
	for region in 4:
		var centre = Vector2.ZERO
		var best = -INF
		for attempt in 24:
			var z = rng.randf_range(1590+region*220,1770+region*220)
			var candidate = Vector2(rng.randf_range(-.39,.39)*z,z)
			var support = 0.0
			for offset in [Vector2.ZERO,Vector2(-65,0),Vector2(65,0),Vector2(0,-85),Vector2(0,85)]:
				var q: Vector2 = candidate+offset
				var n = Vector3(_forest_height(q-Vector2(12,0))-_forest_height(q+Vector2(12,0)),24,_forest_height(q-Vector2(0,12))-_forest_height(q+Vector2(0,12))).normalized()
				support += n.y/5.0
			var score = support-.002*maxf(0,_forest_height(candidate)-(treeline_height-220))+rng.randf_range(0,.035)
			for stand in stands:
				score -= .05*(1-smoothstep(120,270,candidate.distance_to(stand.position)))
			if score>best: best = score; centre = candidate
		var angle = rng.randf_range(-.8,.8)
		# Overlapping lobes form a woodland body, with a scalloped boundary.
		for lobe in 3:
			var offset = Vector2(rng.randf_range(-90,90),rng.randf_range(-110,110)).rotated(angle)
			stands.append({"position":centre+offset,"radius":Vector2(rng.randf_range(95,155),rng.randf_range(130,210)),"angle":angle+rng.randf_range(-.3,.3),"density":rng.randf_range(.86,1.0)})
		clearings.append({"position":centre+Vector2(rng.randf_range(-55,55),rng.randf_range(-80,80)),"radius":Vector2(rng.randf_range(18,35),rng.randf_range(38,75)),"angle":rng.randf_range(-.9,.9)})
		# A local opening enters and leaves this stand. Other woods and terrain
		# determine the next choice; this is never a mountain-length cleared lane.
		var direction = Vector2(sin(angle),cos(angle))
		forest_passages.append({"start":centre-direction*200+Vector2(rng.randf_range(-65,65),0),"finish":centre+direction*200+Vector2(rng.randf_range(-65,65),0),"width":rng.randf_range(9,17),"bend":rng.randf_range(-35,35)})

func _forest_height(q: Vector2) -> float:
	var foundation = _base_height(q.x,q.y)
	return foundation+(_shaped_height(q.x,q.y,foundation)-foundation)*sector_weight(q.x,q.y)*smoothstep(220,640,q.y)

func _build_channels(rng: RandomNumberGenerator) -> void:
	# Tributaries join neighbouring basins, sometimes splitting around a shoulder.
	# No segment lasts longer than one elevation tier; widths and junctions vary.
	var tiers: Array = []
	for tier in 5:
		var z = 400+tier*520
		var nodes: Array[Vector2] = []
		var count = 3 if tier%2==0 else 4
		for i in count:
			var fraction = lerpf(-.40,.40,float(i)/(count-1))+rng.randf_range(-.055,.055)
			nodes.append(Vector2(fraction*z,z+rng.randf_range(-55,55)))
		tiers.append(nodes)
	for tier in 4:
		for i in tiers[tier].size():
			var start: Vector2 = tiers[tier][i]
			var target = clampi(roundi(float(i)*(tiers[tier+1].size()-1)/(tiers[tier].size()-1)),0,tiers[tier+1].size()-1)
			_add_channel(start,tiers[tier+1][target],rng)
			if tier in [1,2] and i<tiers[tier].size()-1:
				_add_channel(start,tiers[tier+1][mini(target+1,tiers[tier+1].size()-1)],rng)

func _add_channel(start: Vector2, finish: Vector2, rng: RandomNumberGenerator) -> void:
	var channel = {"start":start,"finish":finish,"width":rng.randf_range(32,76),"depth":rng.randf_range(6,17),"bend":rng.randf_range(-32,32),"phase":rng.randf_range(-PI,PI)}
	var id = channels.size()
	channels.append(channel)
	var extent: float = channel.width+absf(channel.bend)+16
	_index_region(channel_grid,id,Rect2(start.min(finish)-Vector2.ONE*extent,(finish-start).abs()+Vector2.ONE*extent*2))

func _index_region(grid: Dictionary, id: int, rect: Rect2) -> void:
	for z in range(floori(rect.position.y/REGION_CELL),floori(rect.end.y/REGION_CELL)+1):
		for x in range(floori(rect.position.x/REGION_CELL),floori(rect.end.x/REGION_CELL)+1):
			var key = Vector2i(x,z)
			if not grid.has(key): grid[key] = []
			grid[key].append(id)

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
	var across = to_local(Vector2(n.x,n.z))
	return Vector3(across.x,n.y,across.y)

func channel_values(x: float,z: float) -> Vector2:
	var cut = 0.0
	var floor_weight = 0.0
	for id in channel_grid.get(Vector2i(floori(x/REGION_CELL),floori(z/REGION_CELL)),[]):
		var channel = channels[id]
		var t = (z-channel.start.y)/(channel.finish.y-channel.start.y)
		if t<0 or t>1: continue
		var centre = lerpf(channel.start.x,channel.finish.x,t)+channel.bend*sin(t*PI)*sin(t*PI+channel.phase)
		var width: float = channel.width*lerpf(.75,1.15,t)
		var across = absf(x-centre)/width
		var envelope = smoothstep(0,.13,t)*(1-smoothstep(.84,1,t))
		cut = maxf(cut,channel.depth*(1-smoothstep(.10,1,across))*envelope)
		floor_weight = maxf(floor_weight,(1-smoothstep(.16,.48,across))*envelope)
	return Vector2(cut,floor_weight)

func _shaped_height(x: float,z: float,foundation: float) -> float:
	var p = Vector2(x,z)
	var h = foundation
	var ridge = landforms[0]
	var crest = exp(-pow((z-ridge.position.y)/ridge.radius.y,4))
	h += ridge.height*crest*exp(-pow((x-ridge_center(z))/ridge.radius.x,2))
	for bowl in bowls:
		var q: Vector2 = (p-bowl.position).rotated(bowl.angle)/bowl.radius
		h -= bowl.height*exp(-q.length_squared()*1.45)
	for shelf in shelves:
		var q: Vector2 = (p-shelf.position).rotated(shelf.angle)/shelf.radius
		# Rounded glacial benches flatten briefly then roll into the next face.
		h += shelf.height*q.y*exp(-q.length_squared()*1.6)*2.0
	var channels_here = channel_values(x,z)
	h -= channels_here.x
	var rock_relief = 0.0
	for id in rib_grid.get(Vector2i(floori(x/REGION_CELL),floori(z/REGION_CELL)),[]):
		rock_relief = maxf(rock_relief,ribs[id].height*rib_weight(ribs[id],x,z))
	h += rock_relief*(1-channels_here.y*.5)*smoothstep(450,900,z)
	for crag in crags:
		var cross_weight = crag_weight(crag,x)
		if cross_weight<=0: continue
		var along = z-crag_z(crag,x)
		var gap = crag_gap(crag,x)
		var step = lerpf(smoothstep(-10,12,along),smoothstep(-115,115,along),gap)
		h -= crag.height*cross_weight*step*(1-smoothstep(crag.length*.35,crag.length,along))
		h += crag.height*.27*cross_weight*exp(-pow((along+90)/110,2))*(1-gap)
	var rough = smoothstep(300,550,z)*(1-smoothstep(2470,2730,z))
	h += rough*(6.5*terrain_noise.get_noise_2d(x*2.0,z*1.3)+1.8*terrain_noise.get_noise_2d(x*5.4+817,z*3.2-331))
	return h

func _build_ribs(rng: RandomNumberGenerator) -> void:
	for group in rng.randi_range(5,8):
		var z = rng.randf_range(490,2240)
		var origin = Vector2(rng.randf_range(-.44,.44)*z,z)
		var angle = geology_angle+rng.randf_range(-.5,.5)
		var direction = Vector2(sin(angle),cos(angle))
		var width = rng.randf_range(75,145)
		var length_m = rng.randf_range(110,245)
		for member in rng.randi_range(2,3):
			var rib = {"position":origin+direction*member*length_m*.58,"radius":Vector2(width*rng.randf_range(.8,1.2),length_m),"height":rng.randf_range(25,58)*ruggedness,"angle":angle,"crown":rng.randf_range(1.6,2.1),"skew":rng.randf_range(-.2,.2),"phase":rng.randf_range(-PI,PI)}
			var id = ribs.size()
			ribs.append(rib)
			var extent: float = maxf(rib.radius.x,rib.radius.y)*1.6
			_index_region(rib_grid,id,Rect2(rib.position-Vector2.ONE*extent,Vector2.ONE*extent*2))

func rib_weight(rib: Dictionary,x: float,z: float) -> float:
	var q: Vector2 = (Vector2(x,z)-rib.position).rotated(rib.angle)/rib.radius
	q.x += rib.skew*q.y
	var radius = pow(pow(absf(q.x),3)+pow(absf(q.y),3),1.0/3.0)
	radius *= 1+.10*sin(q.y*5+rib.phase)+.06*sin(q.x*7-rib.phase)
	return smoothstep(0,1,clampf((1-radius)*rib.crown,0,1))
func ridge_center(z: float) -> float:
	return landforms[0].position.x+terrain_noise.get_noise_2d(731,z*.8)*125
func crag_weight(crag: Dictionary,x: float) -> float:
	return 1-smoothstep(crag.width*.55,crag.width,absf(x-crag.position.x))
func crag_z(crag: Dictionary,x: float) -> float:
	return crag.position.y+crag.angle*(x-crag.position.x)+14*sin(x*.018+crag.phase)+4*sin(x*.053-crag.phase)
func crag_gap(crag: Dictionary,x: float) -> float:
	var gap = 0.0
	for opening in crag.gaps: gap = maxf(gap,1-smoothstep(opening.width*.55,opening.width*1.6,absf(x-opening.x)))
	return gap
func snow_gap(x: float,z: float) -> float:
	var gap = 0.0
	for crag in crags:
		gap = maxf(gap,crag_gap(crag,x)*(1-smoothstep(115,175,absf(z-crag_z(crag,x))))*crag_weight(crag,x))
	return gap
func band_z(x: float) -> float:
	var nearest = crags[0]
	for crag in crags:
		if absf(x-crag.position.x)<absf(x-nearest.position.x): nearest = crag
	return crag_z(nearest,x)

func exposure_at(x: float,z: float) -> Color:
	var normal_value = render_normal(x,z)
	var n = normal_value.y
	var stone = 0.0
	for id in rib_grid.get(Vector2i(floori(x/REGION_CELL),floori(z/REGION_CELL)),[]):
		stone = maxf(stone,smoothstep(.08,.27,rib_weight(ribs[id],x,z)))
	for crag in crags:
		var along = z-crag_z(crag,x)
		var face = 1-smoothstep(13,42,absf(along))
		var shoulder = .62*exp(-pow((along+70)/85,2))
		stone = maxf(stone,maxf(face,shoulder)*crag_weight(crag,x)*(1-crag_gap(crag,x)))
	var ridge = landforms[0]
	var cross_value = absf(x-ridge_center(z))/ridge.radius.x
	stone = maxf(stone,.7*smoothstep(.4,.8,cross_value)*(1-smoothstep(.95,1.6,cross_value))*exp(-pow((z-ridge.position.y)/ridge.radius.y,4)))
	# Snow covers ordinary 25-40 degree faces and rock crowns. Steep source
	# shoulders expose coherent bedrock; unsupported cliff faces stay hard.
	var bare = 1-smoothstep(.625,.815,n)
	var source = stone*(1-smoothstep(.66,.85,n))
	var rock = maxf(bare,source)
	rock *= 1-.65*snow_gap(x,z)*smoothstep(.65,.83,n)
	rock *= 1-.75*channel_values(x,z).y*smoothstep(.66,.84,n)
	rock *= smoothstep(360,740,Vector2(x,z).length())
	return Color(clampf(rock,0,1),0,0,1)

func stand_density(x: float,z: float) -> float:
	if z<800 or z>2790: return 0
	var patch = forest_noise.get_noise_2d(x,z)
	var texture = forest_noise.get_noise_2d(x*3.1+971,z*3.1-537)
	var density = 0.0
	for stand in stands:
		var q: Vector2 = (Vector2(x,z)-stand.position).rotated(stand.angle)/stand.radius
		density = maxf(density,stand.density*(1-smoothstep(.65,1.10,q.length()+patch*.28)))
	if density<=.001: return 0
	var clearing_weight = 0.0
	for clearing in clearings:
		var q: Vector2 = (Vector2(x,z)-clearing.position).rotated(clearing.angle)/clearing.radius
		clearing_weight = maxf(clearing_weight,1-smoothstep(.50,1.05,q.length()+patch*.3))
	for passage in forest_passages:
		var delta: Vector2 = passage.finish-passage.start
		var t = clampf((Vector2(x,z)-passage.start).dot(delta)/delta.length_squared(),0,1)
		var centre: Vector2 = passage.start.lerp(passage.finish,t)+delta.orthogonal().normalized()*sin(t*PI)*passage.bend
		var distance_m = Vector2(x,z).distance_to(centre)
		clearing_weight = maxf(clearing_weight,1-smoothstep(passage.width,passage.width+7,distance_m))
	var altitude = _base_height(x,z)
	var treeline = treeline_height+forest_noise.get_noise_2d(x*.6+317,z*.6)*210
	var edge = 1-smoothstep(treeline-180,treeline+90,altitude)
	# Avalanche hollows thin woods locally; their ends open into other terrain.
	var hollow = channel_values(x,z).y
	return density*edge*(1-smoothstep(2620,2800,z))*lerpf(.85,1.0,smoothstep(-.4,.35,texture))*(1-clearing_weight)*(1-hollow*.9)*(1-snow_gap(x,z))

func powder_region(x: float,z: float) -> float:
	var weight = 0.0
	for bowl in bowls:
		var q: Vector2 = (Vector2(x,z)-bowl.position)/bowl.radius
		weight = maxf(weight,(1-smoothstep(.35,1.1,q.length()))*.80)
	return maxf(weight,channel_values(x,z).y*.65)*smoothstep(350,600,z)*(1-smoothstep(2500,2740,z))
func snow_relief_at(x: float,z: float) -> float:
	var q = Vector2(x,z).rotated(wind_angle)
	var warp = snow_noise.get_noise_2d(x*1.7+513,z*.65-927)
	return .85*sin(q.x*.21+q.y*.025+warp*2)+.14*sin(q.x*.39-q.y*.041+warp*3.4)+.65*snow_noise.get_noise_2d(x*3.0-319,z*.5+811)
func snow_relief_weight(x: float,z: float) -> float:
	var n = render_normal(x,z)
	return smoothstep(300,520,z)*(1-smoothstep(2500,2760,z))*smoothstep(.20,.47,n.z/maxf(n.y,.001))*smoothstep(.64,.84,n.y)*(1-smoothstep(.15,.5,exposure_at(x,z).r))
func landing_weight(_x: float,_z: float) -> float: return 0.0

# A point inside the nearest local hollow for scenery/ice orientation and old
# survey cameras. It neither carves terrain nor reserves obstacle-free lanes.
func gully_x(z: float,side: int) -> float:
	var chosen = side*.20*z
	var nearest = INF
	for channel in channels:
		var t = clampf((z-channel.start.y)/(channel.finish.y-channel.start.y),0,1)
		var p: Vector2 = channel.start.lerp(channel.finish,t)
		var cost = absf(p.y-z)+absf(p.x-side*.20*z)*.3
		if cost<nearest:
			nearest = cost
			chosen = p.x+channel.bend*sin(t*PI)*sin(t*PI+channel.phase)
	return chosen
func glade_x(z: float,side: int) -> float: return gully_x(z,side)
