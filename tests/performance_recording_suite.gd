extends SceneTree
const Recorder = preload("res://tests/performance_recorder.gd")
const Inputs = preload("res://tests/performance_input.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures.append(message)
func run() -> void:
	var intent = RiderInput.new()
	intent.steer = -.317; intent.tuck = .73; intent.brake = .12; intent.jump = true; intent.jump_held = true
	intent.air_pitch = -.56; intent.air_yaw = .38; intent.grab = true; intent.air_tilt = -.91
	var command = Inputs.encode(intent)
	check(Inputs.valid(command) and Inputs.encode(Inputs.decode(command))==command,"All nine resolved input fields survive encoding, including jump hold and air tilt")
	var field = preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: check(false,"Current warm fixture is available"); quit(1); return
	field.build_material_map()
	var sim = Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
	var heading = field.faces[3].heading
	sim.reset(field.launch_point(heading),heading); sim.prime_contacts(field)
	var recorder = Recorder.new(); recorder.begin(field,sim,{})
	check(recorder.recording,"Fresh production summit launch starts a recording")
	for tick in 240:
		intent = RiderInput.new(); intent.tuck = .71; intent.steer = sin(tick*.07)*.21
		intent.jump_held = tick>=40 and tick<60; intent.jump = tick==60
		sim.step(1.0/120,intent,field); recorder.observe(sim,intent)
	check(recorder.finish(sim,false,"manual"),"Early manual stop produces a valid scenario recording")
	check(recorder.data.commands.size()==240 and recorder.data.checkpoints.size()==2,"Every physics input and one-second checkpoints are retained")
	check(not Recorder.Trace.preflight_error(recorder.data,15).is_empty(),"Partial clips cannot masquerade as full-descent benchmarks")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Inputs.storage(recorder.data),"",true,true))
	check(Recorder.Trace.preflight_error(saved,15,false).is_empty(),"Saved JSON is accepted for explicit scenario playback")
	check(saved.commands==recorder.data.commands and saved.heading==recorder.data.heading,"Packed input and heading bits survive storage without decimal rounding")
	var replay = Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
	replay.reset(field.launch_point(saved.heading),saved.heading); replay.prime_contacts(field)
	check(Inputs.matches_state(replay,saved.initial_state),"Saved initial state reconstructs exactly")
	var checkpoints_exact = true
	for tick in saved.commands.size():
		replay.step(1.0/120,Inputs.decode(saved.commands[tick]),field)
		if replay.ticks%120==0:
			var expected: Array = saved.checkpoints[replay.ticks/120-1]
			checkpoints_exact = checkpoints_exact and Inputs.matches_state(replay,expected)
	check(checkpoints_exact and Inputs.matches_state(replay,saved.final_state),"Serialized player inputs reproduce checkpoint positions/velocities exactly and heading within 1e-12 radians")
	recorder.begin(field,replay,{})
	check(not recorder.recording,"Mid-run state cannot be mislabeled as a fresh launch")
	replay.reset(field.launch_point(heading),heading); replay.prime_contacts(field)
	recorder.begin(field,replay,{})
	check(recorder.recording and recorder.data.commands.is_empty(),"Restart starts a fresh input stream")
	replay.step(1.0/120,RiderInput.new(),field); recorder.observe(replay,RiderInput.new())
	replay.crashed = true; replay.crash_reason = "fixture crash outcome"
	check(recorder.finish(replay,false,"crash") and recorder.data.termination=="crash","Diagnostic recordings preserve a crash outcome without promoting it to a baseline")
	quit(0 if failures.is_empty() else 1)
