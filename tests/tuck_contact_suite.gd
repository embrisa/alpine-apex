extends SceneTree
## Auto-tuck behavior and matched contact measurements on authoritative 4 m snow.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Contacts = preload("res://tests/downhill_contact_suite.gd")
const Carving = preload("res://tests/arcade_carving_suite.gd")
const Replay = preload("res://scripts/racing/run_replay.gd")
const DT = 1.0/120.0
const OUTPUT = "res://artifacts/tuck_contact_v21"
const REFERENCE = "res://tests/fixtures/tuck_contact_v20.json"
var failures: Array[String] = []
var checks = 0
var metrics: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)

func rider(surface, kmh: float = 120.0):
	var sim = Sim.new()
	sim.reset(Vector3(0,surface.sample(0,0).height,0)); sim.prime_contacts(surface)
	sim.velocity = sim.support_basis().z*kmh/3.6
	return sim

func advance(sim, surface, input, ticks: int) -> void:
	for tick in ticks: sim.step(DT,input,surface)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	_tuck()
	_contact()
	_flight_and_replay()
	FileAccess.open(OUTPUT+"/results.json",FileAccess.WRITE).store_string(JSON.stringify({"model":Sim.MODEL_VERSION,"checks":checks,"failures":failures,"metrics":metrics,"unranked":true},"\t"))
	print("TUCK_CONTACT_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"path":OUTPUT+"/results.json"}))
	quit(0 if failures.is_empty() else 1)

func _tuck() -> void:
	var plane = Carving.CarvePlane.new()
	var input = RiderInput.new(); input.tuck = 1.0
	var sim = rider(plane)
	input.steer = 1.0
	advance(sim,plane,input,18)
	check(sim.effective_tuck==0.0,"Pressing forward and steering together does not start a new tuck")
	sim = rider(plane); input.steer = 0.0
	advance(sim,plane,input,120)
	check(sim.effective_tuck>.95,"Holding forward on a straight enters tuck automatically")
	for correction in [-.20,.20]:
		input.steer = correction; advance(sim,plane,input,120)
		check(sim.effective_tuck>.99 and sim.total_airtime==0,"Small correction %.2f stays tucked and supported" % correction)
	input.steer = 1.0
	var start: float = sim.heading
	advance(sim,plane,input,18)
	check(sim.effective_tuck>.99 and absf(angle_difference(start,sim.heading))>.03,"A 150 ms steering tap turns the skis while retaining tuck")
	input.steer = -1.0
	advance(sim,plane,input,36)
	check(sim.effective_tuck<.04,"Sustained steering opens tuck by 450 ms, even when steering changes sign")
	input.steer = 0.0; advance(sim,plane,input,120)
	check(sim.effective_tuck>.95,"Centering steering while holding forward automatically tucks again")
	# W is an aerodynamic/posture request, never a default input or grip handicap.
	var peak_error = 0.0
	for speed in [60.0,90.0,120.0,160.0]:
		for steer in [-1.0,-.2,.2,1.0]:
			var a = rider(plane,speed); var b = rider(plane,speed)
			a.tuning.aerodynamic_drag = 0; b.tuning.aerodynamic_drag = 0
			b.effective_tuck = 1.0
			var upright = RiderInput.new(); upright.steer = steer
			var tucked = RiderInput.new(); tucked.steer = steer; tucked.tuck = 1.0
			a.step(DT,upright,plane); b.step(DT,tucked,plane)
			var error = maxf(absf(a.turn_demand-b.turn_demand),absf(a.edge_angle-b.edge_angle))
			for ski in 2: error = maxf(error,absf(a.skis[ski].grip_n-b.skis[ski].grip_n))
			peak_error = maxf(peak_error,error)
			check(error<.00001,"Identical initial contact has full yaw, edge response and grip with W: %.0f km/h, steer %.1f" % [speed,steer])
	metrics.tuck_initial_authority_error = peak_error
	for brake in [false,true]:
		sim = rider(plane); sim.effective_tuck = 1.0
		input = RiderInput.new(); input.steer = 1.0
		input.tuck = 1.0 if brake else 0.0; input.brake = 1.0 if brake else 0.0
		advance(sim,plane,input,12)
		check(sim.effective_tuck<.31,"Braking/releasing forward bypasses the steering grace window: "+str(brake))
	# Recordings depend on the same per-tick state after restart, not an old timer.
	sim.reset(Vector3.ZERO); sim.prime_contacts(plane)
	# Match the original high-speed tuck fixture; low-speed forward now requests poles.
	sim.velocity = sim.support_basis().z*120.0/3.6
	input = RiderInput.new(); input.tuck = 1.0
	advance(sim,plane,input,120)
	input.steer = 1.0; advance(sim,plane,input,18)
	check(sim.effective_tuck>.95,"Restart clears sustained-steering history")
	var shipped = load("res://config/ski_default.tres")
	for key in ["tuck_steering_window","tuck_correction_window","tuck_grip_ratio","tuck_edge_response_ratio","support_stiffness","support_damping","support_damping_limit","support_recatch_time","support_recatch_speed"]:
		check(shipped.get(key)==SkiTuning.new().get(key),"Shipping/default tuning agrees: "+key)

func _contact() -> void:
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REFERENCE))
	var rows: Array = []
	var old_small = 0.0; var new_small = 0.0
	for baseline in old.bumps:
		var row = Contacts.measure(Sim,Contacts.Ripple.new(baseline.amplitude,baseline.wavelength),baseline.speed,6.0,.15)
		row.erase("telemetry"); row.amplitude = baseline.amplitude; row.wavelength = baseline.wavelength
		rows.append(row)
		var label = "%.2f m / %.0f m ripple at %.0f km/h" % [row.amplitude,row.wavelength,row.speed]
		check(row.duration_s==6.0 and row.crash.is_empty(),label+": completes without crash")
		check(row.min_load_n>=0 and row.unloaded_grip_n==0,label+": positive support and zero unsupported grip")
		check(row.max_reach_m<=.281 and row.foot_error_m<.001,label+": actual 4 m contact within leg reach")
		if row.amplitude<=.15:
			old_small += baseline.airtime_s; new_small += row.airtime_s
			check(row.airtime_s<=maxf(.10,baseline.airtime_s*.25),label+": at least 75% less airtime or below 100 ms")
	check(new_small<old_small*.15,"Small-ripple matrix loses at least 85% less support time than frozen v20")
	metrics.bumps = rows
	metrics.small_bump_airtime = {"v20_s":old_small,"current_s":new_small,"reduction":1.0-new_small/old_small}
	for speed in [10.0,30.0,60.0]:
		var slow = Contacts.measure(Sim,Contacts.Ripple.new(.05,16),speed,6.0,.15)
		check(slow.airtime_s<=DT*2 and slow.crash.is_empty(),"Low-speed small-bump maneuvering retains support at %.0f km/h" % speed)
	var crest = Contacts.measure(Sim,Contacts.Crest.new(),150,1.5)
	check(crest.airtime_s>.05,"A real convex crest still releases naturally")
	var ledge = Contacts.measure(Sim,Contacts.Ledge.new(),72,.15)
	check(ledge.airtime_s>.04 and ledge.max_clearance_m>11.9,"A 12 m drop preserves momentum and real flight")
	var plane = Carving.CarvePlane.new(); plane.gradient = 0
	for reason in ["hop","reach","unloaded"]:
		var sim = rider(plane); sim.position.y = .15; sim.velocity.y = -.1
		sim._begin_flight(Basis.IDENTITY,reason)
		if reason=="unloaded": sim.airtime = .25
		sim.step(DT,RiderInput.new(),plane)
		check(not sim.grounded and sim.normal_load==0,"Soft recontact cannot catch a deliberate jump, drop, or established flight: "+reason)

func _flight_and_replay() -> void:
	var plane = Carving.CarvePlane.new(); plane.gradient = 0
	var a = rider(plane); var b = rider(plane)
	for sim in [a,b]:
		sim.position.y = 100.0; sim._begin_flight(Basis.IDENTITY,"hop")
		sim.tuning.aerodynamic_drag = 0
	b.tuning.support_stiffness = 60; b.tuning.support_damping = 12; b.tuning.support_recatch_time = 0
	var input = RiderInput.new(); input.steer = 1.0
	var initial_y: float = a.velocity.y
	for tick in 120: a.step(DT,input,plane); b.step(DT,input,plane)
	check(a.position==b.position and a.velocity==b.velocity and a.flight_frame==b.flight_frame,"Suspension tuning does not change airborne translation or rotation authority")
	check(absf(a.velocity.y-initial_y+9.81)<.001,"Established flight retains ordinary gravity")
	a = rider(plane); b = rider(plane)
	var recording = Replay.new(); var identity = Replay.key("auto-tuck-test")
	recording.begin(a,identity)
	var same = true
	for tick in 360:
		input = RiderInput.new(); input.tuck = 1.0
		input.steer = 0.0 if tick<120 or tick>300 else (1.0 if tick<210 else -1.0)
		a.step(DT,input,plane)
		recording.record(DT,(tick+1)*DT,a,input,1.0 if tick==359 else -1.0)
		b.step(DT,recording.input_at(tick),plane)
		same = same and a.position==b.position and a.velocity==b.velocity and a.effective_tuck==b.effective_tuck
	check(same,"Current replay input fields reproduce auto-tuck and steering at every tick")
	check(identity.physics==30 and Replay.VERSION==7 and Replay.INPUT_WIDTH==9,"Pole propulsion versions forward intent and retains the complete input layout")
	preload("res://tests/ghost_replay_fixture.gd").attach_sample_poses(recording)
	var data = recording.to_data()
	check(Replay.decode(data,identity,recording.duration)!=null,"Current auto-tuck recording round-trips")
	data.compatibility.physics = 20
	check(Replay.decode(data,identity,recording.duration)==null,"Previous v20 recording is incompatible with v21")
	# The 20% decimal boundary rounds upward in the float32 replay layout.
	a = rider(plane); b = rider(plane)
	a.effective_tuck = 1.0; b.effective_tuck = 1.0
	recording = Replay.new(); recording.begin(a,identity)
	input = RiderInput.new(); input.tuck = 1.0; input.steer = .20
	for tick in 120:
		a.step(DT,input,plane); recording.record(DT,(tick+1)*DT,a,input)
		b.step(DT,recording.input_at(tick),plane)
	check(a.effective_tuck>.99 and b.effective_tuck>.99 and a.position.distance_to(b.position)<.002,"Live and float32-replayed 20% corrections both retain tuck")
