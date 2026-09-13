extends RefCounted
## Common diagnostic envelope. Measurements are observations, never auto-grades.
const FORMAT = "alpine-scenario-evidence"
const VERSION = 1
const Recorder = preload("res://scripts/diagnostics/case_recorder.gd")

static func identity(extra: Array = []) -> Dictionary:
	var hashes = Recorder.sources()
	for path in extra + ["res://config/ski_default.tres", "res://scripts/diagnostics/scenarios.json", "res://tests/fixtures/test_maps.json", "res://scripts/diagnostics/test_map.gd", "res://scripts/diagnostics/scenario_runner.gd", "res://tests/small_landing_probe.gd", "res://tests/planted_snow_probe.gd", "res://assets/graphics/models/skier_v7.glb"]:
		hashes[path] = FileAccess.get_sha256(path)
	return {"sources":hashes,"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"build":preload("res://scripts/diagnostics/build_identity.gd").current()}

static func envelope(id: String, stimulus: Dictionary, source: Dictionary) -> Dictionary:
	return {"format":FORMAT,"version":VERSION,"scenario":id,"stimulus":stimulus,"identity":source,
		"created_utc":Time.get_datetime_string_from_system(true)+"Z","simulation_hz":120,"scope":"diagnostic_fixture",
		"personal_records":false,"performance_evidence":false,"human_acceptance":false,"status":"running",
		"telemetry":"telemetry.json","captures":[],"events":[],"failures":[]}

static func sample(sim, tick: int, intent, surface = null) -> Dictionary:
	var state = Recorder.state(sim)
	state.body_roll = sim.body.roll
	var clearance = null
	var normal_speed = null
	if surface != null:
		var terrain: Dictionary = surface.sample(sim.position.x,sim.position.z)
		clearance = sim.position.y-terrain.height
		normal_speed = sim.velocity.dot(terrain.normal)
	return {"tick":tick,"time":tick/120.0,"input":Recorder.Inputs.encode(intent) if intent != null else [],"state":state,
		"metrics":{"speed_mps":sim.velocity.length(),"normal_speed_mps":normal_speed,"clearance_m":clearance,
			"load_n":sim.skis[0].load_n+sim.skis[1].load_n,"slip_rad":sim.slip_angle,"edge_rad":sim.edge_angle,"body_roll_rad":sim.body.roll,
			"impact_speed_mps":sim.impacts.last_speed,"grounded":1 if sim.grounded else 0},"events":[]}

static func events(previous: Dictionary, current: Dictionary) -> Array:
	var result: Array = []
	if previous.is_empty(): return result
	for key in ["grounded","crashed"]:
		if previous[key] != current[key]:
			result.append("landing" if key=="grounded" and current[key] else "takeoff" if key=="grounded" else "crash" if current[key] else "recovered")
	return result

static func write(path: String, value: Variant) -> Error:
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(json_value(value),"\t",true,true)); file.flush()
	return file.get_error()

static func json_value(value: Variant) -> Variant:
	if value is Vector2: return [value.x,value.y]
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Dictionary:
		var result = {}
		for key in value: result[str(key)] = json_value(value[key])
		return result
	if value is Array or value is PackedFloat64Array or value is PackedFloat32Array or value is PackedInt32Array:
		var result: Array = []
		for item in value: result.append(json_value(item))
		return result
	return value
