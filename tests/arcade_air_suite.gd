extends SceneTree
const Sim = preload("res://scripts/core/ski_simulation.gd")
const DT = 1.0/120.0
var failures: Array = []
var checks = 0
var metrics = {}

class AirPlane extends RefCounted:
	func sample(_x,_z): return {"height":0.0,"normal":Vector3.UP}
	func sweep_obstacle(_a,_b): return ""
	func is_finished(_p): return false

func _initialize(): call_deferred("run")
func check(ok, message):
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ",message)

func flight(backward = false):
	var sim = Sim.new(); sim.reset(Vector3(0,500,0)); sim.prime_contacts(AirPlane.new())
	sim.velocity = Vector3(0,3,25); sim._begin_flight(Basis.IDENTITY)
	sim.facing_backward = backward; sim.facing_pose.capture(sim,true)
	return sim

func advance(sim,intent,ticks):
	for i in ticks: sim.step(DT,intent,AirPlane.new())

func delta(a: Basis,b: Basis):
	return a.get_rotation_quaternion().angle_to(b.get_rotation_quaternion())

func run():
	for backward in [false,true]:
		for sign_value in [-1.0,1.0]: rotations(backward,sign_value)
	pitch_limits(); handoffs(); combinations(); drag_equality(); assistance(); replay()
	var output = "res://artifacts/arcade_air_v27/focused.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var report = {"checks":checks,"failures":failures,"metrics":metrics}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ARCADE_AIR_RESULTS ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)

func rotations(backward,sign_value):
	var sim = flight(backward); var intent = RiderInput.new(); intent.air_pitch = sign_value
	var elapsed = 0.0
	while absf(sim.air_control.integrated_pitch)<TAU and elapsed<3.0:
		advance(sim,intent,1); elapsed += DT
	check(elapsed>=1.65 and elapsed<=1.75,"Full flip takes about 1.7 seconds in either direction/facing")
	check(signf(sim.air_control.integrated_pitch)==sign_value*(-1.0 if backward else 1.0),"Pitch sign follows rider facing")
	advance(sim,intent,120)
	check(absf(sim.air_control.integrated_pitch)<2.0*TAU,"Another second of held input cannot squeeze in a second full flip")
	advance(sim,intent,240)
	check(absf(sim.air_control.integrated_pitch)>2.0*TAU,"Holding input continues into multiple flips")
	var angle = sim.air_control.integrated_pitch
	intent.air_pitch = 0.0; var stop_ticks = 0
	while sim.air_control.angular_velocity.length()>.00001 and stop_ticks<60:
		advance(sim,intent,1); stop_ticks += 1
	check(stop_ticks*DT<=.15,"Release brakes maximum flip speed within 150 ms")
	check(absf(sim.air_control.integrated_pitch-angle)<deg_to_rad(8.0),"Flips stop with less than 8 degrees of release drift")
	var release_radians: float = absf(sim.air_control.integrated_pitch-angle)
	var held: Basis = sim.support_basis(); advance(sim,intent,30)
	check(delta(held,sim.support_basis())<.00001,"Release holds current angle without automatic completion")
	intent.air_pitch = sign_value; advance(sim,intent,30); intent.air_pitch = -sign_value
	advance(sim,intent,20)
	var rate: float = sim.air_control.angular_velocity.dot(sim.support_basis().x)*(-1.0 if backward else 1.0)
	check(rate*sign_value < -3.79,"Full reversal reaches opposite speed within 167 ms")
	metrics["flip_%s_%s"%[backward,sign_value]] = {"full_turn_s":elapsed,"stop_s":stop_ticks*DT,"release_radians":release_radians}

func pitch_limits():
	for backward in [false,true]:
		var sim = flight(backward); var intent = RiderInput.new(); intent.air_tilt = 1.0; intent.tuck = 1.0
		advance(sim,intent,60)
		check(sim.support_basis().is_equal_approx(Basis.IDENTITY) and not sim.air_control.tilt_armed,"Held takeoff tuck cannot pitch before centering")
		intent.air_tilt = 0.0; advance(sim,intent,1)
		check(sim.air_control.tilt_armed,"Neutral forward/back input arms limited pitch")
		intent.air_tilt = 1.0; advance(sim,intent,180)
		check(absf(sim.air_control.tilt_angle-deg_to_rad(50.0))<.005,"Normal pitch reaches the 50 degree limit")
		check(sim.air_control.orientation_flight and sim.air_control.tilt_flight and not sim.air_control.trick_flight,"Limited pitch rotates whole skier without becoming a trick")
		for i in 5:
			intent.air_tilt = 0.0; advance(sim,intent,8); intent.air_tilt = 1.0; advance(sim,intent,20)
		check(sim.air_control.tilt_angle<=deg_to_rad(50.0)+.00001,"Repeated release/reapply cannot bypass the pitch limit")
		intent.air_tilt = -1.0; advance(sim,intent,300)
		check(absf(sim.air_control.tilt_angle+deg_to_rad(50.0))<.005,"Reverse input reaches the negative pitch limit")
		sim.reset(Vector3.ZERO); sim.prime_contacts(AirPlane.new())
		advance(sim,intent,1)
		check(not sim.air_control.tilt_armed and sim.air_control.tilt_angle==0.0,"Reset and supported skiing clear airborne pitch state")

func handoffs():
	var sim = flight(); var intent = RiderInput.new(); intent.air_pitch = 1.0
	advance(sim,intent,36); intent.air_pitch = 0.0; intent.air_tilt = 1.0
	advance(sim,intent,30)
	check(not sim.air_control.tilt_armed and sim.air_control.angular_velocity.length()<.00001,"Releasing explicit flip while keyboard pitch is held stops without triggering tilt")
	var reference: Basis = sim.support_basis()
	intent.air_tilt = 0.0; advance(sim,intent,1); intent.air_tilt = .5; advance(sim,intent,30)
	check(sim.air_control.tilt_armed and sim.air_control.tilt_angle>.12 and delta(reference,sim.support_basis())<.15,"Normal pitch resumes from stopped flip attitude at analog strength")
	var old_rate: float = sim.air_control.pitch_velocity
	intent.air_pitch = -1.0; advance(sim,intent,1)
	check(sim.air_control.pitch_velocity<old_rate and not sim.air_control.tilt_armed,"Explicit flip takes priority over ordinary pitch with continuous braking")

func combinations():
	for kind in ["tilt_yaw","banked_tilt","trick","steer","spin","partial","vertical"]:
		var sim = flight(); var neutral = flight(); var intent = RiderInput.new()
		if kind=="vertical": sim._begin_flight(Basis(Vector3.RIGHT,PI*.5))
		if kind=="banked_tilt": sim._begin_flight(Basis(Vector3.BACK,.55)*Basis(Vector3.RIGHT,.35))
		advance(sim,intent,1); advance(neutral,intent,1)
		var peak_speed = 0.0; var peak_accel = 0.0; var max_position_error = 0.0
		for tick in 360:
			intent.air_tilt = (1.0 if tick<180 else -1.0) if kind in ["tilt_yaw","banked_tilt"] else 0.0
			intent.steer = (1.0 if tick<180 else -1.0) if kind in ["steer","tilt_yaw","banked_tilt"] else 0.0
			intent.air_pitch = (1.0 if tick<180 else -.6) if kind in ["trick","vertical"] else (.25 if kind=="partial" else 0.0)
			intent.air_yaw = .8 if kind=="trick" else (1.0 if kind=="spin" else 0.0)
			var old: Basis = sim.support_basis(); var omega: Vector3 = sim.air_control.angular_velocity
			advance(sim,intent,1); advance(neutral,RiderInput.new(),1)
			peak_speed = maxf(peak_speed,sim.air_control.angular_velocity.length())
			peak_accel = maxf(peak_accel,(sim.air_control.angular_velocity-omega).length()/DT)
			max_position_error = maxf(max_position_error,sim.position.distance_to(neutral.position)+sim.velocity.distance_to(neutral.velocity))
			check(sim.support_basis().is_finite() and absf(sim.support_basis().determinant()-1.0)<.00001,"Quaternion stays normalized: "+kind)
			check(delta(old,sim.support_basis())<=sim.tuning.air_rotation_rate_limit*DT+.0001,"Per-tick orientation remains rate bounded: "+kind)
			if kind in ["tilt_yaw","banked_tilt"]: check(absf(sim.air_control.tilt_angle)<=sim.tuning.air_tilt_limit+.00001,"Combined yaw cannot exceed normal pitch limit")
		check(max_position_error<.000001,"Air rotation adds no lift, propulsion or lateral force: "+kind)
		check(peak_speed<=7.2001 and peak_accel<=48.02,"Combined world angular speed/acceleration stay bounded: "+kind)
		if kind=="steer":
			check(absf(absf(sim.air_control.angular_velocity.y)-1.56)<.00001,"Normal turning reaches about 89 degrees per second")
			check(sim.air_control.orientation_flight and not sim.air_control.tilt_flight and not sim.air_control.trick_flight,"Ordinary air turning carries the whole rider without selecting trick history or blocking brief support recovery")
		if kind=="partial": check(absf(sim.air_control.angular_velocity.x-.95)<.00001,"Quarter input retains proportional flip speed")
		if kind=="spin": check(absf(sim.air_control.angular_velocity.y+5.4)<.00001,"Full spin input reaches 5.4 radians per second")
		metrics[kind] = {"peak_rad_s":peak_speed,"peak_rad_s2":peak_accel,"trajectory_error":max_position_error}
		advance(sim,RiderInput.new(),18)
		check(sim.air_control.angular_velocity.length()<.00001,"Release stops combined rotation within 150 ms: "+kind)

func drag_equality():
	for tuck in [0.0,.4,1.0]:
		var sim = flight(); var neutral = flight()
		var intent = RiderInput.new(); var reference = RiderInput.new()
		intent.tuck = tuck; reference.tuck = tuck
		advance(sim,intent,1); advance(neutral,reference,1)
		var error = 0.0
		for tick in 240:
			intent.air_pitch = 1.0 if tick<94 else 0.0
			intent.air_yaw = -.7 if tick<160 else 0.0
			intent.air_tilt = -.5 if tick>180 else 0.0
			advance(sim,intent,1); advance(neutral,reference,1)
			error = maxf(error,sim.position.distance_to(neutral.position)+sim.velocity.distance_to(neutral.velocity))
		check(error==0.0,"Rotating and neutral riders have identical trajectories with tuck %s"%tuck)
		metrics["drag_tuck_%s"%tuck] = {"trajectory_error":error}

func assistance():
	var sim = flight(); sim.tuning.landing_assist_enabled = true; var intent = RiderInput.new()
	advance(sim,intent,1); intent.air_tilt = .5; advance(sim,intent,10)
	check(sim.landing_assist.strength==0 and sim.air_control.assist_acceleration==Vector3.ZERO,"Normal pitch immediately overrides assistance")
	intent.air_tilt = 0.0; advance(sim,intent,120)
	check(sim.air_control.angular_velocity.length()<.00001,"Manual pitch remains held after release even with optional assistance")

func replay():
	var Replay = preload("res://scripts/racing/run_replay.gd")
	var sim = flight(); var intent = RiderInput.new(); intent.air_tilt = -.7
	check(intent.copy().air_tilt==intent.air_tilt,"Copy retains signed normal pitch")
	var recording = Replay.new(); var identity = Replay.key("air27-fixture"); recording.begin(sim,identity)
	for tick in 12:
		advance(sim,intent,1); recording.record(DT,(tick+1)*DT,sim,intent,1.0 if tick==11 else -1.0)
	preload("res://tests/ghost_replay_fixture.gd").attach_sample_poses(recording)
	var data = recording.to_data(); var restored = Replay.decode(data,identity,.1)
	check(Replay.VERSION==7 and Replay.INPUT_WIDTH==9 and restored!=null,"Replay v7 accepts nine-field tick records with held preparation")
	if restored==null: return
	check(absf(restored.input_at(4).air_tilt+.7)<.000001,"Replay round trip retains negative normal pitch")
	var invalid = data.duplicate(true)
	var bad_payload: PackedByteArray = Marshalls.base64_to_raw(data.payload)
	var input_offset: int = bad_payload.size()-recording.inputs.size()*4-recording.tick_kinds.size()
	bad_payload.encode_float(input_offset+7*4,1.1)
	invalid.payload = Marshalls.raw_to_base64(bad_payload)
	check(Replay.decode(invalid,identity,.1)==null,"Replay rejects out-of-range normal pitch")
	bad_payload.encode_float(input_offset+7*4,NAN)
	invalid.payload = Marshalls.raw_to_base64(bad_payload)
	check(Replay.decode(invalid,identity,.1)==null,"Replay rejects non-finite normal pitch")
	data.version = 4; check(Replay.decode(data,identity,.1)==null,"Old recording layouts are rejected")
