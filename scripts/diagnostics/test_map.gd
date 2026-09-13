extends "res://scripts/world/heightfield_surface.gd"
## Explicit automated-test terrain. Production contact and triangulation; no bake/cache.
const GENERATOR_ID = "targeted-test"
const GENERATOR_VERSION = 1
const CATALOG = "res://tests/fixtures/test_maps.json"
var fixture_id: String
var fixture_spec: Dictionary
var fixture_options: Dictionary
var fixture_identity: String

static func catalog(include_performance: bool = true) -> Dictionary:
	var data=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not data is Dictionary or not data.get("maps") is Dictionary:
		push_error("Missing or invalid targeted test map catalog: "+CATALOG); return {}
	if include_performance:
		var performance=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/performance_maps.json"))
		if not performance is Dictionary or not performance.get("maps") is Dictionary:
			push_error("Missing or invalid performance test map catalog"); return {}
		data.maps.merge(performance.maps)
	return data.maps

static func to_reference(field,scenery_seed: int) -> Dictionary:
	return {"generator":GENERATOR_ID,"version":GENERATOR_VERSION,"seed":field.seed_value,
		"scenery_seed":scenery_seed,"scenery_version":GENERATOR_VERSION,"engine":Engine.get_version_info().string,
		"fixture":field.fixture_id,"options":field.fixture_options,"identity":field.fixture_identity}

static func valid_reference(value: Dictionary) -> bool:
	if not preload("res://scripts/diagnostics/test_world_policy.gd").automated(): return false
	if value.size()!=9 or value.get("generator")!=GENERATOR_ID or value.get("version")!=GENERATOR_VERSION or value.get("scenery_version")!=GENERATOR_VERSION: return false
	if value.get("engine")!=Engine.get_version_info().string or value.get("seed")!=849205174: return false
	if not value.get("fixture") is String or not catalog().has(value.fixture) or not value.get("options") is Dictionary or not value.get("identity") is String: return false
	if not valid_options(value.options): return false
	if catalog()[value.fixture].get("kind","")=="performance" and not value.options.is_empty(): return false
	var scenery=value.get("scenery_seed")
	if not (scenery is int or scenery is float) or not is_finite(scenery) or scenery<0 or scenery>2147483647 or scenery!=floor(scenery): return false
	return value.identity=="targeted-v%d-%s-%s" % [GENERATOR_VERSION,value.fixture,JSON.stringify([catalog()[value.fixture],value.options],"",true).sha256_text().left(16)]

static func create(id: String, options: Dictionary = {}):
	if not catalog().has(id) or not valid_options(options):
		push_error("Unknown targeted test map or invalid options: "+id)
		return null
	if catalog()[id].get("kind","")=="performance":
		if not options.is_empty():
			push_error("Performance maps use their exact authored recipe"); return null
		return load("res://scripts/diagnostics/performance_map.gd").new(id,options)
	return load("res://scripts/diagnostics/test_map.gd").new(id,options)

static func valid_options(options: Dictionary) -> bool:
	for key in options:
		if key in ["hop","flat"]:
			if not options[key] is bool: return false
		elif key=="transition":
			if options[key] not in ["crest","compression","small-drop"]: return false
		elif key in ["gradient","amplitude","wavelength","depth","angle","rock","kmh","tuck","steer"]:
			if not (options[key] is int or options[key] is float) or not is_finite(options[key]): return false
			if key=="wavelength" and options[key]<=0: return false
		else: return false
	return true

func _init(id: String = "smooth-slope", options: Dictionary = {}) -> void:
	fixture_id = id
	fixture_spec = catalog()[id].duplicate(true)
	fixture_options = JSON.parse_string(JSON.stringify(options))
	seed_value = 849205174
	X_MIN = -fixture_spec.width_m/2.0
	Z_MIN = -32.0 if fixture_spec.length_m<=256 else -64.0
	NX = int(fixture_spec.width_m/CELL)+1
	NZ = int(fixture_spec.length_m/CELL)+1
	finish_z = Z_MIN+fixture_spec.length_m-48.0
	boundary_message = "TARGETED FIXTURE BOUNDARY"
	heights.resize(NX*NZ)
	for z in NZ:
		for x in NX:
			var p = Vector2(X_MIN+x*CELL,Z_MIN+z*CELL)
			heights[z*NX+x] = _height(p)
	for placement in fixture_spec.get("objects",[]):
		if placement.get("kind","")=="mineral": continue
		var p = Vector3(placement.x,0,placement.z)
		p.y = sample(p.x,p.z).height
		add_obstacle({"position":p,"radius":.6 if placement.tree else 1.35,
			"height":11.0*placement.get("scale",1.0) if placement.tree else 2.0,"scale":placement.get("scale",1.0),"yaw":deg_to_rad(placement.get("yaw",0.0)),
			"tree":placement.tree,"fixture_family":placement.family})
	assert(fixture_spec.get("objects",[]).size()<=(448 if fixture_spec.get("kind","")=="performance" else 64))
	fixture_identity = "targeted-v%d-%s-%s" % [GENERATOR_VERSION,id,JSON.stringify([fixture_spec,fixture_options],"",true).sha256_text().left(16)]

func _height(p: Vector2) -> float:
	if fixture_options.get("flat",false): return 0.0
	var gradient: float = fixture_options.get("gradient",fixture_spec.get("gradient",.46))
	var height_value: float = -p.y*gradient
	if fixture_id=="rough-snow" or fixture_options.has("amplitude"):
		var rotated = p.rotated(fixture_options.get("angle",0.0))
		height_value += fixture_options.get("amplitude",.6)*cos(rotated.y*TAU/fixture_options.get("wavelength",16.0))
	if fixture_id=="terrain-transitions":
		match fixture_options.get("transition","crest"):
			"crest": height_value += 3.0*exp(-pow((p.y-70.0)/16.0,2))
			"compression": height_value -= 3.0*exp(-pow((p.y-70.0)/16.0,2))
			"small-drop": height_value -= .6*(1.0+tanh((p.y-70.0)/4.0))
	return height_value

func snow_depth_at(_x: float,_z: float) -> float:
	return fixture_options.get("depth",fixture_spec.get("depth",.06))

func rock_fraction_at(_x: float,_z: float) -> float:
	return fixture_options.get("rock",0.0)

func spawn_point() -> Vector3:
	return Vector3(0,sample(0,0).height,0)

func fixture_descriptor() -> Dictionary:
	return {"id":fixture_id,"identity":fixture_identity,"width_m":fixture_spec.width_m,
		"length_m":fixture_spec.length_m,"cell_m":CELL,"height_samples":heights.size(),
		"objects":obstacles.size(),"full_mountain":false,"options":fixture_options}
