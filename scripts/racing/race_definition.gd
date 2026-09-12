extends RefCounted
## Portable, checkpoint-free race contract. Positions use world metres; yaw uses radians.
const Terrain = preload("res://scripts/world/test_slope.gd")
const Mountain = preload("res://scripts/world/mountain_data.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const MountainDefinition = preload("res://scripts/world/mountain_definition.gd")
const SCHEMA = 5
const WeatherRules = preload("res://scripts/presentation/weather_rules.gd")
const Flavor = preload("res://scripts/world/flavor_layout.gd")
const Zone = preload("res://scripts/world/mountain_zone.gd")
const FINISH_WIDTH = 10.0
const FINISH_HEIGHT = 4.5
const MAX_BYTES = 16384
var weather_preset = "clear"
var time_band = "day"
var weather_rules = WeatherRules.VERSION
var title: String = ""
var mountain: Dictionary = {}
var start = Vector3.ZERO
var finish = Vector3.ZERO
var heading: float = 0.0
var finish_heading: float = 0.0
var finish_base_y: float = NAN # Derived from the pinned support surface, never saved.

static func mountain_reference(field, scenery_seed: int) -> Dictionary:
	if field.GENERATOR_ID == "alpine-drainage":
		return MountainDefinition.from_field(field).to_reference()
	return {"generator":"laboratory", "version":Terrain.GENERATOR_VERSION,
		"seed":field.seed_value, "scenery_seed":scenery_seed, "scenery_version":Mountain.GENERATOR_VERSION,
		"engine":Engine.get_version_info().string}

func to_data() -> Dictionary:
	return {"schema":SCHEMA, "conditions":{"weather":weather_preset,"time":time_band,"rules":weather_rules}, "mountain":mountain.duplicate(true), "race":{
		"name":title, "type":"open_route", "start":[start.x,start.y,start.z],
		"heading_rad":heading, "finish":[finish.x,finish.y,finish.z],
		"finish_heading_rad":finish_heading,"finish_width_m":FINISH_WIDTH,
		"finish_height_m":FINISH_HEIGHT,"props_version":Flavor.VERSION}}

func share_text() -> String:
	return JSON.stringify(to_data(), "", true, true)

func identity() -> String:
	return share_text().sha256_text()

func record_identity() -> String:
	return "race-v5-props%d-zone%d-%s-physics-v%d-%s" % [Flavor.VERSION,Zone.RULES_VERSION,identity(),Simulation.MODEL_VERSION,
		FileAccess.get_sha256("res://config/ski_default.tres")]

static func decode(text_value: String) -> Dictionary:
	if text_value.to_utf8_buffer().size() > MAX_BYTES:
		return {"error":"Race code is too large (maximum 16 KB)."}
	var parser = JSON.new()
	if parser.parse(text_value)!=OK: return {"error":"Unsupported race format. Paste a complete Alpine Apex race code."}
	var data = parser.data
	if data is Dictionary and data.get("schema")==2:
		return {"error":"This race uses the old finish area. Recreate it with the new gates; earlier times stay separate."}
	if not data is Dictionary or not _keys(data,["schema","conditions","mountain","race"]) or data.get("schema") != SCHEMA:
		return {"error":"Unsupported race format. Paste a complete Alpine Apex race code."}
	var conditions = data.conditions
	if not conditions is Dictionary or not _keys(conditions,["weather","time","rules"]):
		return {"error":"Race conditions are missing or unsupported."}
	if not conditions.weather is String or not conditions.weather in WeatherRules.PRESETS or not conditions.time is String or not conditions.time in WeatherRules.TIMES or not _number(conditions.rules) or conditions.rules!=WeatherRules.VERSION:
		return {"error":"Unsupported weather, time band or weather rules."}
	var m = data.mountain
	if m is Dictionary and m.get("generator")=="alpine-drainage":
		var error = MountainDefinition.reference_error(m)
		if not error.is_empty(): return {"error":error}
	else:
		if not m is Dictionary or not _keys(m,["generator","version","seed","scenery_seed","scenery_version","engine"]):
			return {"error":"The mountain reference is incomplete or unsupported."}
		if m.generator != "laboratory" or m.version != Terrain.GENERATOR_VERSION or m.scenery_version != Mountain.GENERATOR_VERSION or m.engine != Engine.get_version_info().string:
			return {"error":"This race needs a different mountain generator or Godot version."}
		for key in ["seed","scenery_seed"]:
			if not _number(m[key]) or float(m[key]) != floor(float(m[key])) or float(m[key]) < 0 or float(m[key]) > 2147483647:
				return {"error":"Mountain seeds must be whole numbers from 0 to 2147483647."}
	var r = data.race
	if not r is Dictionary or not _keys(r,["name","type","start","heading_rad","finish","finish_heading_rad","finish_width_m","finish_height_m","props_version"]):
		return {"error":"This race has missing or unsupported rules. Only open-route races are supported."}
	if not r.name is String or r.name.strip_edges().is_empty() or r.name.length() > 60:
		return {"error":"Give the race a name between 1 and 60 characters."}
	for i in r.name.length():
		if r.name.unicode_at(i) < 32 or r.name.unicode_at(i) == 127:
			return {"error":"Race names cannot contain control characters."}
	if r.type != "open_route" or r.finish_width_m != FINISH_WIDTH or r.finish_height_m != FINISH_HEIGHT or r.props_version!=Flavor.VERSION:
		return {"error":"Unsupported finish area or race type."}
	if not _vector(r.start) or not _vector(r.finish) or not _number(r.heading_rad) or absf(float(r.heading_rad)) > PI or not _number(r.finish_heading_rad) or absf(float(r.finish_heading_rad))>PI:
		return {"error":"Start, finish and heading must be finite world coordinates and radians."}
	var result = load("res://scripts/racing/race_definition.gd").new()
	result.weather_preset = conditions.weather; result.time_band = conditions.time; result.weather_rules = int(conditions.rules)
	result.title = r.name.strip_edges()
	result.mountain = m.duplicate(true)
	for key in ["seed","scenery_seed","version","scenery_version"]:
		result.mountain[key] = int(result.mountain[key])
	result.start = Vector3(r.start[0],r.start[1],r.start[2])
	result.finish = Vector3(r.finish[0],r.finish[1],r.finish[2])
	result.heading = float(r.heading_rad)
	result.finish_heading = float(r.finish_heading_rad)
	if Vector2(result.start.x,result.start.z).distance_to(Vector2(result.finish.x,result.finish.z)) < 40.0:
		return {"error":"Place the finish at least 40 metres from the start."}
	return {"race":result, "error":""}

func validate_surface(field) -> String:
	if mountain_reference(field,int(mountain.scenery_seed)) != mountain:
		return "The loaded mountain does not match this race."
	if field.is_summit_mountain() and Vector2(start.x,start.z).length()<12:
		return "Place the race start on a summit rim or farther downhill."
	for endpoint in [start,finish]:
		var error = point_error(endpoint,field)
		if not error.is_empty(): return error
	for pair in [[start,heading],[finish,finish_heading]]:
		var error=gate_error(pair[0],pair[1],field)
		if not error.is_empty(): return error
	finish_base_y=Flavor.gate_seat(field,finish,finish_heading).pose.origin.y
	return ""

static func gate_error(point: Vector3, yaw: float, field) -> String:
	if not Flavor.for_field(field).point_clear(point,10.0): return "Move the gate away from the mountain's huts or discoveries."
	if not Flavor.obstacle_clear(field,point,8.0): return "Choose a wider clearing for the gate and its supports."
	if Flavor.gate_seat(field,point,yaw).is_empty(): return "The ground is too uneven across this gate. Choose a smoother clearing."
	return ""

func finish_fraction(before: Vector3, after: Vector3) -> float:
	var inverse=Basis(Vector3.UP,finish_heading).transposed()
	var a=inverse*(before-finish); var b=inverse*(after-finish)
	# Either direction is valid, but standing on / moving along the plane is not.
	if absf(b.z-a.z)<.000001 or (a.z>0 and b.z>0) or (a.z<0 and b.z<0) or absf(a.z)<.000001: return -1.0
	var t=-a.z/(b.z-a.z); var crossing=before.lerp(after,t)
	var local=a.lerp(b,t)
	var base=finish_base_y if is_finite(finish_base_y) else finish.y
	return t if absf(local.x)<=FINISH_WIDTH*.5-.35 and crossing.y>=finish.y-2.0 and crossing.y+1.6<=base+FINISH_HEIGHT else -1.0

static func suggested(field, scenery_seed: int):
	if not field.is_summit_mountain() or field.GENERATOR_VERSION<10: return null
	for angle_step in 12:
		var angle=TAU*angle_step/12.
		var axis=Vector3(sin(angle),0,cos(angle))
		for radius in [90.,140.,220.]:
			var result=load("res://scripts/racing/race_definition.gd").new()
			result.title="Mountain Sprint"; result.mountain=mountain_reference(field,scenery_seed)
			result.start=axis*radius; result.start.y=field.sample(result.start.x,result.start.z).height
			result.heading=Flavor.downhill_heading(field,result.start,angle)
			for distance in [380.,520.,700.]:
				result.finish=axis*distance; result.finish.y=field.sample(result.finish.x,result.finish.z).height
				result.finish_heading=Flavor.downhill_heading(field,result.finish,angle)
				if result.validate_surface(field).is_empty(): return result
	return null

static func point_error(point: Vector3, field) -> String:
	var zone_error = Zone.new(field).endpoint_error(point)
	if not zone_error.is_empty(): return zone_error
	if not point.is_finite() or not field.ski_bounds().grow(-25.0).has_point(Vector2(point.x,point.z)):
		return "Choose a point inside the skiable mountain, away from its boundary."
	if absf(point.y-float(field.sample(point.x,point.z).height))>0.1:
		return "Place endpoints on the snow surface."
	if field.contact_normal(point.x,point.z).y < cos(deg_to_rad(40.0)):
		return "Choose a gentler spot for the start or finish (under 40 degrees)."
	# Reserve a small clear patch around the skier/target, not a racing corridor.
	for offset in [Vector3.ZERO,Vector3.LEFT*2,Vector3.RIGHT*2,Vector3.FORWARD*2,Vector3.BACK*2]:
		if not field.sweep_obstacle(point+offset,point+offset).is_empty():
			return "Move the endpoint away from trees or rocks."
	return ""

static func _keys(data: Dictionary, required: Array) -> bool:
	return data.size()==required.size() and required.all(func(key): return data.has(key))

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _vector(value: Variant) -> bool:
	return value is Array and value.size()==3 and value.all(func(v): return _number(v) and absf(float(v)) < 10000.0)

static func reconstruct_surface(reference: Dictionary, job = null) -> Dictionary:
	if reference.generator == "alpine-drainage":
		var error = MountainDefinition.reference_error(reference)
		if not error.is_empty(): return {"error":error}
		var field = MountainDefinition.generate(int(reference.seed),int(reference.version),reference.settings,job)
		if field==null: return {"error":"Mountain loading cancelled or failed."}
		if mountain_reference(field,int(reference.scenery_seed))!=reference:
			return {"error":"The reconstructed race mountain does not match its saved checksums."}
		return {"field":field,"error":""}
	return {"field":Terrain.new(int(reference.seed)),"error":""}
