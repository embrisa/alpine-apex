extends RefCounted
const Store = preload("res://scripts/diagnostics/case_store.gd")
const Inputs = preload("res://scripts/diagnostics/case_inputs.gd")
const Pose = preload("res://scripts/diagnostics/case_pose.gd")
const Policy = preload("res://scripts/diagnostics/case_policy.gd")
var data = Store.new()
var running = false
var tick = 0
var input_ticks = 0
var initial_settings: Dictionary
var last_frame_time = 0.0
var events: Array = []

static func sources() -> Dictionary:
	var result = {}
	_collect_sources("res://scripts",result)
	return result

static func _collect_sources(folder: String, result: Dictionary) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"): result[folder+"/"+file] = FileAccess.get_sha256(folder+"/"+file)
	for child in DirAccess.get_directories_at(folder): _collect_sources(folder+"/"+child,result)

static func tuning_data(tuning) -> Dictionary:
	var result: Dictionary = {}
	for property in tuning.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_STORAGE and property.name not in ["script","resource_local_to_scene","resource_name"]:
			var value = tuning.get(property.name)
			if not value is Object: result[property.name] = value
	return result

static func state(sim) -> Dictionary:
	return {"sim_tick":sim.ticks,"position":sim.position,"velocity":sim.velocity,"heading":sim.heading,
		"grounded":sim.grounded,"crashed":sim.crashed,"crash_reason":sim.crash_reason,"reserve":sim.impacts.reserve,
		"normal":sim.surface_normal,"load":sim.normal_load,"edge":sim.edge_angle,"slip":sim.slip_angle,
		"ski_loads":PackedFloat64Array([sim.skis[0].load_n,sim.skis[1].load_n]),
		"ski_grounded":[sim.skis[0].grounded,sim.skis[1].grounded],"rock_contact":sim.rock_contact,
		"impact_speed":sim.impacts.last_speed,"impact_reason":sim.impacts.last_reason,"obstacle":sim.obstacle_contact,
		"prevented_damage":sim.impacts.get("prevented_damage") if "prevented_damage" in sim.impacts else 0.0,
		"speed_delta":sim.policy.speed_delta if "policy" in sim else Vector3.ZERO}

func begin(game) -> void:
	data = Store.new(); tick = 0; input_ticks = 0; last_frame_time = 0
	initial_settings = game.sim.policy.values.duplicate()
	data.metadata = {"title":"Recording "+Time.get_datetime_string_from_system(),"what":"","expected":"",
		"recorded_utc":Time.get_datetime_string_from_system(true)+"Z","start_tick":0,"end_tick":0,"duration_ticks":0,"input_ticks":0,
		"initial_settings":initial_settings,"policy_version":Policy.VERSION,"input_version":Store.INPUT_VERSION,"rig":Pose.rig(game.skier),
		"identity":{"sources":game.diagnostic_source_identity.duplicate(),"model":game.sim.MODEL_VERSION,"engine":Engine.get_version_info().string,
			"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"mountain":game.current_mountain.to_reference()},
		"termination":"","capture":"observed","origin":"automated" if game.automated else "player","personal_records":false}
	var initial = {"t":0.0,"tick":0,"input":PackedFloat64Array(),"events":[],"state":state(game.sim),"tuning":tuning_data(game.sim.tuning),
		"presentation":{"camera":game.camera_settings.snapshot(),"graphics":game.display_settings.snapshot(),"weather":game.weather.snapshot(),"appearance":game.skier.appearance.values.duplicate(true)}}
	data.append("ticks",initial); running = true

func observe_tick(sim, intent, skiing: bool, changes: Array) -> void:
	if not running: return
	var controls = PackedFloat64Array()
	if skiing:
		for value in Inputs.encode(intent): controls.append(float(value))
	var next = tick+1
	if data.append("ticks",{"t":next/120.0,"tick":next,"input":controls,"events":changes.duplicate(true),"state":state(sim)}):
		tick = next
		if skiing: input_ticks += 1
	else: running = false
	if tick>=Store.MAX_TICKS: running = false

func observe_frame(game, dt: float, fraction: float) -> void:
	if not running: return
	var time = maxf(last_frame_time,(tick-1+fraction)/120.0 if not game.sim.crashed else tick/120.0)
	var contacts = PackedFloat32Array()
	if not game.sim.crashed:
		contacts = Pose.GhostPose.capture(game.skier,game.sim,game.field).slice(Pose.GhostPose.CONTACT_START)
	var row = {"t":time,"tick":tick,"alpha":fraction,"frame_dt":dt,"pose":Pose.capture(game.skier),
		"camera":Pose.camera_capture(game.presentation_camera),"weather":game.weather.snapshot(),"contacts":contacts,"crashed":game.sim.crashed}
	if not data.append("frames",row): running = false
	last_frame_time = time

func finish(reason: String) -> void:
	running = false
	data.metadata.merge({"termination":reason,"duration_ticks":tick,"end_tick":tick,"input_ticks":input_ticks,"stable_sources":data.metadata.identity.sources==sources()},true)
	for kind in data.buffers: data._flush(kind)

static func input_from(values: PackedFloat64Array) -> RiderInput:
	var command: Array = []
	for i in values.size(): command.append(values[i]!=0.0 if i in [3,4,7] else values[i])
	return Inputs.decode(command)
