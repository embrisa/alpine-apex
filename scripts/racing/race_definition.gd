extends RefCounted
## Portable, checkpoint-free race contract. Positions use world metres; yaw uses radians.
const Terrain = preload("res://scripts/world/test_slope.gd")
const Mountain = preload("res://scripts/world/mountain_data.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const MountainDefinition = preload("res://scripts/world/mountain_definition.gd")
const SCHEMA = 1
const FINISH_RADIUS = 12.0
const FINISH_HALF_HEIGHT = 16.0
const MAX_BYTES = 16384
var title: String = ""
var mountain: Dictionary = {}
var start = Vector3.ZERO
var finish = Vector3.ZERO
var heading: float = 0.0

static func mountain_reference(field, scenery_seed: int) -> Dictionary:
	if field.GENERATOR_ID == "alpine-drainage":
		return MountainDefinition.from_field(field).to_reference()
	return {"generator":"laboratory", "version":Terrain.GENERATOR_VERSION,
		"seed":field.seed_value, "scenery_seed":scenery_seed, "scenery_version":Mountain.GENERATOR_VERSION,
		"engine":Engine.get_version_info().string}

func to_data() -> Dictionary:
	return {"schema":SCHEMA, "mountain":mountain.duplicate(true), "race":{
		"name":title, "type":"open_route", "start":[start.x,start.y,start.z],
		"heading_rad":heading, "finish":[finish.x,finish.y,finish.z],
		"finish_radius_m":FINISH_RADIUS, "finish_half_height_m":FINISH_HALF_HEIGHT}}

func share_text() -> String:
	return JSON.stringify(to_data(), "", true, true)

func identity() -> String:
	return share_text().sha256_text()

func record_identity() -> String:
	return "race-v1-%s-physics-v%d-%s" % [identity(),Simulation.MODEL_VERSION,
		FileAccess.get_sha256("res://config/ski_default.tres")]

static func decode(text_value: String) -> Dictionary:
	if text_value.to_utf8_buffer().size() > MAX_BYTES:
		return {"error":"Race code is too large (maximum 16 KB)."}
	var data = JSON.parse_string(text_value)
	if not data is Dictionary or not _keys(data,["schema","mountain","race"]) or data.get("schema") != SCHEMA:
		return {"error":"Unsupported race format. Paste a complete Alpine Apex race code."}
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
	if not r is Dictionary or not _keys(r,["name","type","start","heading_rad","finish","finish_radius_m","finish_half_height_m"]):
		return {"error":"This race has missing or unsupported rules. Only open-route races are supported."}
	if not r.name is String or r.name.strip_edges().is_empty() or r.name.length() > 60:
		return {"error":"Give the race a name between 1 and 60 characters."}
	for i in r.name.length():
		if r.name.unicode_at(i) < 32 or r.name.unicode_at(i) == 127:
			return {"error":"Race names cannot contain control characters."}
	if r.type != "open_route" or r.finish_radius_m != FINISH_RADIUS or r.finish_half_height_m != FINISH_HALF_HEIGHT:
		return {"error":"Unsupported finish area or race type."}
	if not _vector(r.start) or not _vector(r.finish) or not _number(r.heading_rad) or absf(float(r.heading_rad)) > PI:
		return {"error":"Start, finish and heading must be finite world coordinates and radians."}
	var result = load("res://scripts/racing/race_definition.gd").new()
	result.title = r.name.strip_edges()
	result.mountain = m.duplicate(true)
	for key in ["seed","scenery_seed","version","scenery_version"]:
		result.mountain[key] = int(result.mountain[key])
	result.start = Vector3(r.start[0],r.start[1],r.start[2])
	result.finish = Vector3(r.finish[0],r.finish[1],r.finish[2])
	result.heading = float(r.heading_rad)
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
	return ""

static func point_error(point: Vector3, field) -> String:
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

static func reconstruct_surface(reference: Dictionary) -> Dictionary:
	if reference.generator == "alpine-drainage":
		var error = MountainDefinition.reference_error(reference)
		if not error.is_empty(): return {"error":error}
		var field = MountainDefinition.generate(int(reference.seed),int(reference.version))
		if mountain_reference(field,int(reference.scenery_seed))!=reference:
			return {"error":"The reconstructed race mountain does not match its saved checksums."}
		return {"field":field,"error":""}
	return {"field":Terrain.new(int(reference.seed)),"error":""}
