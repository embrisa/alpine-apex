extends SceneTree
## Current-model regression measurements. No renderer or personal-best persistence.
const Carving = preload("res://tests/arcade_carving_suite.gd")
const Sim = preload("res://scripts/core/ski_simulation.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const Ledge = preload("res://tests/jump_suite.gd").Ledge
const DT = 1.0/120.0
var checks = 0
var failures: Array = []
var metrics: Array = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func run() -> void:
	_ledge_requests()
	_landing_buffer()
	_input_contract()
	_rapid_reversals()
	_recorded_requests()
	var reference: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/downhill_v14.json")).turns
	for kmh in [60.0,120.0,160.0,200.0]:
		for tuck in [0.0,1.0]:
			var old: Dictionary = reference.filter(func(row): return row.kmh==kmh and row.tuck==tuck and row.steer==1.0 and row.reverse)[0]
			var next = _reverse(kmh,tuck,1.0)
			var mirrored = _reverse(kmh,tuck,-1.0)
			metrics.append({"entry_kmh":kmh,"tuck":tuck,"v14_reference":old,"current":next,"mirror":mirrored})
			var label = "%.0f km/h, tuck %.0f" % [kmh,tuck]
			check(next.response>0 and next.response<=old.response_s-DT*2,"Earlier opposite grip than captured v14: "+label)
			check(not next.crashed and next.balance>.85 and next.slip<20.0,"Reversal retains balance and bounded slip: "+label)
			# Compare speed after the same 45-degree excursion and return to the
			# fall line. A fixed six seconds compares different uphill headings
			# after tighter carving, which confounds gravitational speed loss.
			var arc = Carving.measure(Sim,kmh,1.0,tuck,false,"matched_reversal")
			var arc_mirror = Carving.measure(Sim,kmh,-1.0,tuck,false,"matched_reversal")
			metrics[-1].matched_arc = arc
			metrics[-1].matched_mirror = arc_mirror
			check(roundi(absf(next.response-mirrored.response)/DT)<=2,"Mirrored reversal response within two ticks: "+label)
			check(arc.return_speed_kmh>0 and arc_mirror.return_speed_kmh>0 and absf(arc.return_speed_kmh-arc_mirror.return_speed_kmh)/arc.return_speed_kmh<.01,"Mirrored reversal speed within 1% at matching headings: "+label)
			check(next.speed_before_change<=kmh+.1 and next.exit_kmh<=old.exit_kmh+1.0,"Earlier turn does not provide a speed boost: "+label)
	DirAccess.make_dir_recursive_absolute("res://artifacts/handling_upgrade")
	var result = {"model":Sim.MODEL_VERSION,"checks":checks,"failures":failures,"reversals":metrics}
	FileAccess.open("res://artifacts/handling_upgrade/physics.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("HANDLING_UPGRADE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _ledge_rider(surface):
	var sim = Sim.new()
	sim.reset(Vector3.ZERO)
	sim.prime_contacts(surface)
	sim.velocity = Vector3(0,0,20)
	return sim

func _ledge_requests() -> void:
	var surface = Ledge.new()
	var baseline = _ledge_rider(surface)
	var empty = RiderInput.new()
	var release_tick = -1
	for tick in range(60):
		var supported: bool = baseline.grounded
		baseline.step(DT,empty,surface)
		if supported and not baseline.grounded and release_tick<0: release_tick = tick
	check(release_tick>0,"Fixture crosses its ledge at a supported simulation boundary")
	for offset in [-1,0,1,2]:
		var sim = _ledge_rider(surface)
		for tick in range(60):
			var intent = RiderInput.new()
			intent.jump = tick==release_tick+offset
			sim.step(DT,intent,surface)
		if offset<=0:
			check(sim.position.y>baseline.position.y+.9 and not sim.crashed,"Release at ledge tick %+d still hops" % offset)
		else:
			check(sim.position.distance_to(baseline.position)<.00001 and sim.velocity.distance_to(baseline.velocity)<.00001,"Release %+d ticks after support cannot boost flight" % offset)
		check(sim.normal_load==0.0 and sim.friction_force==0.0,"No snow forces after ledge release %+d" % offset)

func _falling_rider():
	var sim = Sim.new()
	sim.reset(Vector3(0,.8,0))
	sim.grounded = false
	sim.velocity = Vector3(0,-5,0)
	sim.tuning.aerodynamic_drag = 0.0
	return sim

func _landing_buffer() -> void:
	var plane = TestPlane.new(0.0)
	var baseline = _falling_rider()
	var landed_tick = -1
	for tick in range(60):
		baseline.step(DT,RiderInput.new(),plane)
		if baseline.grounded:
			landed_tick = tick
			break
	check(landed_tick>10 and not baseline.crashed,"Buffered landing fixture is survivable")
	for lead in [0,2,5,7,10]:
		var sim = _falling_rider()
		var takeoffs = 0
		var before_landing_identical = true
		var reference = _falling_rider()
		for tick in range(180):
			var intent = RiderInput.new()
			intent.jump = tick==landed_tick-lead
			var grounded_before: bool = sim.grounded
			sim.step(DT,intent,plane)
			reference.step(DT,RiderInput.new(),plane)
			if tick<=landed_tick:
				before_landing_identical = before_landing_identical and sim.position.distance_to(reference.position)<.00001
			if grounded_before and not sim.grounded: takeoffs += 1
		check(before_landing_identical,"Early release preserves incoming ballistic trajectory, lead %d" % lead)
		check(takeoffs==(1 if lead<9 else 0),"Landing request consumed once within its window or expires, lead %d" % lead)
		check(not sim.crashed and sim.grounded and is_zero_approx(sim.jump_buffer_remaining),"No automatic bounce on the next landing, lead %d" % lead)
	for action in ["clear","reset","crash"]:
		var sim = _falling_rider()
		var intent = RiderInput.new()
		intent.jump = true
		sim.step(DT,intent,plane)
		check(sim.jump_buffer_remaining>0.0,"Air release creates pending request before "+action)
		if action=="clear": sim.clear_input_buffer()
		elif action=="reset": sim.reset(Vector3.ZERO)
		else: sim.crash("TEST IMPACT")
		check(sim.jump_buffer_remaining==0.0,"Lifecycle cancels pending request: "+action)
	var immediate = Sim.new()
	immediate.tuning.jump_buffer_time = 0.0
	immediate.reset(Vector3.ZERO)
	immediate.prime_contacts(plane)
	var request = RiderInput.new()
	request.jump = true
	immediate.step(DT,request,plane)
	check(not immediate.grounded and immediate.velocity.y>3.0,"Zero buffer duration still allows an immediate supported release")

func _input_contract() -> void:
	var plane = TestPlane.new(0.0)
	var short_hold = Sim.new()
	var long_hold = Sim.new()
	for pair in [[short_hold,2],[long_hold,120]]:
		var sim = pair[0]
		sim.reset(Vector3.ZERO)
		sim.prime_contacts(plane)
		var intent = RiderInput.new()
		intent.jump_held = true
		for tick in range(pair[1]): sim.step(DT,intent,plane)
		check(sim.grounded and sim.total_airtime==0,"Holding jump prepares without taking off (%d ticks)" % pair[1])
		intent.jump_held = false
		intent.jump = true
		sim.step(DT,intent,plane)
	check(not short_hold.grounded and short_hold.velocity.is_equal_approx(long_hold.velocity),"Hold duration does not charge power; release applies the same hop")
	var original = RiderInput.new()
	original.jump_held = true
	check(original.copy().jump_held and not original.copy().jump,"Intent copy preserves readiness independently of the release event")

func _reverse(kmh: float, tuck: float, direction: float) -> Dictionary:
	var sim = Sim.new()
	var plane = TestPlane.new(.46)
	sim.reset(Vector3.ZERO)
	sim.prime_contacts(plane)
	sim.velocity = sim.support_basis().z*kmh/3.6
	sim.effective_tuck = tuck
	var intent = RiderInput.new()
	intent.tuck = tuck
	var response = -1.0
	var min_balance = 1.0
	var max_slip = 0.0
	var entry = kmh
	for tick in range(720):
		intent.steer = direction if tick<240 else -direction
		if tick==240: entry = sim.speed_kmh()
		sim.step(DT,intent,plane)
		if tick>=240 and response<0 and sim.lateral_acceleration*direction>1.0: response = (tick-239)*DT
		min_balance = minf(min_balance,sim.balance)
		max_slip = maxf(max_slip,absf(rad_to_deg(sim.slip_angle)))
		if sim.crashed: break
	return {"response":response,"balance":min_balance,"slip":max_slip,"exit_kmh":sim.speed_kmh(),"speed_before_change":entry,"crashed":sim.crashed}

func _rapid_reversals() -> void:
	for period in [60,120]:
		for direction in [-1.0,1.0]:
			var plane = TestPlane.new(.46)
			var sim = Sim.new()
			sim.reset(Vector3.ZERO)
			sim.prime_contacts(plane)
			sim.velocity = sim.support_basis().z*200.0/3.6
			var minimum = 1.0
			for tick in range(480):
				var intent = RiderInput.new()
				intent.steer = direction*(1.0 if tick%(period*2)<period else -1.0)
				sim.step(DT,intent,plane)
				minimum = minf(minimum,sim.balance)
				if sim.crashed: break
			check(not sim.crashed and minimum>.9,"Rapid %.1f-second reversals at 200 km/h remain controllable, side %.0f" % [period*DT,direction])

func _recorded_requests() -> void:
	const Replay = preload("res://scripts/racing/run_replay.gd")
	var plane = TestPlane.new(0.0)
	var sim = Sim.new()
	sim.reset(Vector3.ZERO)
	sim.prime_contacts(plane)
	var playback = Sim.new()
	playback.reset(Vector3.ZERO)
	playback.prime_contacts(plane)
	var recording = Replay.new()
	var identity = Replay.key("release-contract-test")
	recording.begin(sim,identity)
	var matches = true
	for tick in range(150):
		var intent = RiderInput.new()
		intent.jump_held = tick<20 or tick in range(100,110)
		intent.jump = tick in [20,60,110]
		sim.step(DT,intent,plane)
		recording.record(DT,(tick+1)*DT,sim,intent,1.0 if tick==149 else -1.0)
		var restored = RiderInput.new()
		restored = recording.input_at(tick)
		playback.step(DT,restored,plane)
		matches = matches and playback.position.is_equal_approx(sim.position) and playback.velocity.is_equal_approx(sim.velocity)
	check(matches,"Recorded held preparation and release commands reproduce every physics step")
	check(identity.physics==31 and Replay.VERSION==7 and Replay.INPUT_WIDTH==9 and recording.inputs.size()==150*Replay.INPUT_WIDTH,"Model 31/replay 7 retain all nine fields including held preparation")
	# Add only neutral presentation samples to the real recorded physics/inputs.
	preload("res://tests/ghost_replay_fixture.gd").attach_sample_poses(recording)
	var data = recording.to_data()
	var decoded = Replay.decode(data,identity,recording.duration)
	check(decoded!=null and decoded.samples==recording.samples and decoded.inputs==recording.inputs and decoded.sample_times==recording.sample_times,"Release recording round-trips exact physical/input frames with synthetic codec poses")
	if decoded==null: return
	var incompatible = data.duplicate(true)
	incompatible.compatibility.physics = 30
	check(Replay.decode(incompatible,identity,recording.duration)==null,"Previous physics model cannot load as a compatible model 31 ghost")
