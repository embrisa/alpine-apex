extends RefCounted
const Obstacles = preload("res://scripts/world/obstacle_access.gd")
## Versioned, deterministic prop placement. No Nodes or terrain mutations.
const VERSION = 1
const MAX_SITES = 16
const MANIFEST = "res://assets/graphics/flavor_v1/manifest.json"
static var records: Dictionary = {}
static var cached_layouts: Dictionary = {}
var placements: Array[Dictionary] = []
var sites: Array[Vector2] = []
var fingerprint: String = ""

static func for_field(field):
	var key="%d:%s:%d:%d" % [VERSION,field.GENERATOR_ID,field.GENERATOR_VERSION,field.seed_value]
	if "obstacle_checksum" in field: key += ":"+field.obstacle_checksum
	if not cached_layouts.has(key):
		var result=load("res://scripts/world/flavor_layout.gd").new(); result.generate(field)
		if cached_layouts.size()>=2: cached_layouts.erase(cached_layouts.keys()[0])
		cached_layouts[key]=result
	return cached_layouts[key]

static func catalog() -> Dictionary:
	if records.is_empty():
		for record in JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)).assets:
			records[record.id]=record
	return records

static func downhill_heading(field, point: Vector3, fallback: float=0) -> float:
	var n: Vector3=field.contact_normal(point.x,point.z)
	return atan2(n.x,n.z) if Vector2(n.x,n.z).length()>.035 else fallback

static func obstacle_clear(field, point: Vector3, radius: float) -> bool:
	if field.has_method("geology_clear") and not field.geology_clear(point,radius+2): return false
	var p=Vector2(point.x,point.z)
	var padding: float = field.tree_data.max_radius if "tree_data" in field else 8.0
	for index in field.nearby_obstacle_indices(point,radius+padding+1):
		var ob = Obstacles.record(field,index)
		if p.distance_to(Vector2(ob.position.x,ob.position.z))<radius+ob.radius+1: return false
	return true

static func seat(field, id: String, position: Vector3, yaw: float) -> Dictionary:
	var record=catalog()[id]
	var size: Array=record.dimensions_m
	var basis=Basis(Vector3.UP,yaw)
	var low=INF; var high=-INF
	for x in [-.45,0.,.45]:
		for z in [-.45,0.,.45]:
			var p=position+basis*Vector3(x*size[0],0,z*size[2])
			var h: float=field.sample(p.x,p.z).height
			low=minf(low,h); high=maxf(high,h)
	var tolerance=1.8 if id=="alpine_refuge" else (.85 if id=="picnic_table" else .40)
	if high-low>tolerance: return {}
	var foundations: Array=[]
	if id=="alpine_refuge":
		position.y=high-.06
		var depth=high-low+.12
		foundations.append({"center":[0,-depth*.5,0],"size":[size[0]*.90,depth,size[2]*.90]})
	else: position.y=low-.04
	return {"asset_id":id,"position":position,"yaw":yaw,"site":-1,"foundations":foundations}

static func gate_seat(field, point: Vector3, yaw: float) -> Dictionary:
	var basis=Basis(Vector3.UP,yaw)
	var low=INF; var high=-INF; var foot_lows: Array=[]
	for side in [-5.6,5.6]:
		var foot_low=INF
		for x in [-.6,.6]:
			for z in [-.9,.9]:
				var p=point+basis*Vector3(side+x,0,z)
				if not field.ski_bounds().grow(-2).has_point(Vector2(p.x,p.z)): return {}
				var h: float=field.sample(p.x,p.z).height
				low=minf(low,h); high=maxf(high,h); foot_low=minf(foot_low,h)
		foot_lows.append(foot_low)
	if high-low>2.2 or high-point.y>1.4: return {}
	# Upright timber, with short stone foundations reaching the sampled ground.
	var origin=Vector3(point.x,high-.10,point.z)
	var foundations: Array=[]
	for i in 2:
		var depth: float=origin.y-foot_lows[i]+.12
		if depth>.05: foundations.append({"center":[[-5.6,5.6][i],-depth*.5,0],"size":[1.2,depth,1.8]})
	return {"pose":Transform3D(basis,origin),"foundations":foundations}

func generate(field) -> void:
	placements.clear(); sites.clear()
	# Archived terrain and the laboratory retain their original obstacle layout.
	if not field.is_summit_mountain() or field.GENERATOR_VERSION<10: return
	catalog()
	var rng=RandomNumberGenerator.new(); rng.seed=field.seed_value ^ 0x4F1A902
	# Four plausible camps, then single discoveries. Strange objects are sparse
	# across the entire 25 km² skiable disk, never repeated along a racing line.
	var choices=["alpine_refuge","picnic_table","alpine_refuge","stone_fire_pit","marmot_monument","garden_gnome","summit_armchair","wet_floor_sign","supply_crate","giant_rubber_duck","garden_gnome","marmot_monument"]
	for id in choices:
		if id=="giant_rubber_duck" and field.seed_value%3==0: continue
		for attempt in (2000 if id in ["alpine_refuge","picnic_table"] else 500):
			var radius=rng.randf_range(350,2580)
			var p=Vector2.from_angle(rng.randf_range(-PI,PI))*radius
			if sites.any(func(other): return other.distance_to(p)<240): continue
			var point=Vector3(p.x,field.sample(p.x,p.y).height,p.y)
			var slope: Vector3=field.contact_normal(p.x,p.y)
			if slope.y<cos(deg_to_rad(28 if id=="alpine_refuge" else 34)): continue
			if field.has_method("exposure_at") and field.exposure_at(p.x,p.y).r>.40: continue
			if not obstacle_clear(field,point,9.0 if id in ["alpine_refuge","picnic_table","stone_fire_pit"] else 3.0): continue
			var yaw=downhill_heading(field,point,rng.randf_range(-PI,PI))
			var placed=seat(field,id,point,yaw)
			if placed.is_empty(): continue
			placed.site=sites.size(); placements.append(placed); sites.append(p)
			if id=="alpine_refuge":
				_accessory(field,placed,"picnic_table",Vector3(5,0,1))
				_accessory(field,placed,"supply_crate",Vector3(-3.7,0,0))
			elif id=="picnic_table": _accessory(field,placed,"stone_fire_pit",Vector3(4,0,0))
			elif id=="stone_fire_pit":
				_accessory(field,placed,"supply_crate",Vector3(3,0,0))
				_accessory(field,placed,"expedition_radio",Vector3(-2,0,0))
			break
	var canonical: Array=[]
	for p in placements: canonical.append([p.asset_id,p.position.x,p.position.y,p.position.z,p.yaw])
	fingerprint=JSON.stringify([VERSION,field.seed_value,canonical],"",true,true).sha256_text()

func _accessory(field, anchor: Dictionary, id: String, offset: Vector3) -> void:
	var point: Vector3=anchor.position+Basis(Vector3.UP,anchor.yaw)*offset
	if not obstacle_clear(field,point,2): return
	var placed=seat(field,id,point,anchor.yaw)
	if not placed.is_empty(): placed.site=anchor.site; placements.append(placed)

func point_clear(point: Vector3, radius: float) -> bool:
	for placed in placements:
		var size: Array=catalog()[placed.asset_id].dimensions_m
		if Vector2(point.x,point.z).distance_to(Vector2(placed.position.x,placed.position.z))<radius+maxf(size[0],size[2])*.5: return false
	return true
