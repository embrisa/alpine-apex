extends SceneTree
## Deterministic travel measurements. --baseline captures the pre-v15 checkout.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Carving = preload("res://tests/arcade_carving_suite.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const DT = 1.0/120.0
const OUTPUT = "res://artifacts/handling_v15"
const REFERENCE = "res://tests/fixtures/downhill_v14.json"
var failures: Array[String] = []
var checks = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)

static func turn_fixture(model, kmh: float, tuck: float, steer: float, reverse: bool = false, overrides: Dictionary = {}) -> Dictionary:
	var sim = model.new()
	for key in overrides: sim.tuning.set(key,overrides[key])
	var plane = TestPlane.new(.46)
	sim.reset(Vector3.ZERO)
	sim.prime_contacts(plane)
	sim.velocity = sim.support_basis().z*kmh/3.6
	sim.effective_tuck = tuck
	var input = RiderInput.new()
	input.tuck = tuck
	var response = -1.0
	var travel_response = -1.0
	var previous_travel = 0.0
	var peak_slip = 0.0
	var min_load = INF
	var max_load = 0.0
	var result = {}
	var tick_times: Array[float] = []
	for tick in range(720 if reverse else 240):
		input.steer = -steer if reverse and tick>=240 else steer
		var started = Time.get_ticks_usec()
		sim.step(DT,input,plane)
		tick_times.append(Time.get_ticks_usec()-started)
		peak_slip = maxf(peak_slip,absf(rad_to_deg(sim.slip_angle)))
		for ski in sim.skis:
			min_load = minf(min_load,ski.load_n)
			max_load = maxf(max_load,ski.load_n)
		if tick==29: result.tuck_250ms = sim.effective_tuck
		if tick==53: result.tuck_450ms = sim.effective_tuck
		if tick==239:
			result.turn_deg = -signf(steer)*rad_to_deg(atan2(sim.velocity.x,sim.velocity.z))
			result.speed_2s_kmh = sim.speed_kmh()
		if reverse and tick>=240 and response<0 and sim.lateral_acceleration*signf(steer)>1.0:
			response = (tick-239)*DT
		var travel = atan2(sim.velocity.x,sim.velocity.z)
		if reverse and tick>=240 and travel_response<0 and angle_difference(previous_travel,travel)*signf(steer)>DT*.03:
			travel_response = (tick-239)*DT
		previous_travel = travel
		if sim.crashed: break
	tick_times.sort()
	result.merge({"kmh":kmh,"tuck":tuck,"steer":steer,"reverse":reverse,"response_s":response,
		"travel_response_s":travel_response,"exit_kmh":sim.speed_kmh(),"max_slip_deg":peak_slip,"airtime_s":sim.total_airtime,
		"min_ski_load_n":min_load,"max_ski_load_n":max_load,"crash":sim.crash_reason,
		"tick_p95_us":tick_times[floori((tick_times.size()-1)*.95)],
		"tick_p99_us":tick_times[floori((tick_times.size()-1)*.99)]})
	return result

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var baseline = "--baseline" in OS.get_cmdline_user_args()
	var model = load("res://artifacts/handling_v15/reference/ski_simulation.gd") if baseline else Sim
	var results: Array = []
	var reference: Array = [] if baseline else JSON.parse_string(FileAccess.get_file_as_string(REFERENCE)).turns
	var carve_reference: Array = [] if baseline else JSON.parse_string(FileAccess.get_file_as_string(Carving.REFERENCE)).rows
	for kmh in [60.0,90.0,120.0,160.0,200.0]:
		for tuck in [0.0,1.0]:
			for steer in [-1.0,-.5,.5,1.0]:
				for reverse in [false,true]:
					var row = turn_fixture(model,kmh,tuck,steer,reverse)
					var index = results.size()
					results.append(row)
					if baseline: continue
					var label = "%.0f km/h tuck %.0f steer %.1f reverse %s" % [kmh,tuck,steer,reverse]
					check(row.crash.is_empty() and row.airtime_s==0.0,label+": supported and recoverable")
					check(row.min_ski_load_n>=0 and row.max_slip_deg<20.0,label+": positive support and bounded slip")
					if absf(steer)==1.0 and kmh<=160:
						check(row.turn_deg>=reference[index].turn_deg*1.20,label+": at least 20% greater travel turn")
						if reverse: check(row.travel_response_s>0 and row.travel_response_s<=.60,label+": actual travel begins reversing within 0.60 seconds")
					if not reverse:
						# Compare speed at equal travel angle; v20 reaches farther across the slope in 2 s.
						var curve = Carving.measure(model,kmh,steer,tuck)
						# Sustained half-input steering now fully opens tuck. Compare
						# that case with the same upright aerodynamic state; the old
						# half-tucked v19 run intentionally had less drag.
						var reference_tuck = 0.0 if absf(steer)==.5 else tuck
						var old_curve: Dictionary = carve_reference.filter(func(value): return value.kmh==kmh and value.steer==steer and value.tuck==reference_tuck and not value.switch and value.mode=="held")[0]
						check(curve.speed_45_kmh>=old_curve.speed_45_kmh*.95,label+": retains at least 95% of v19 speed at equal travel angle and sustained tuck state")
						if tuck==1.0 and absf(steer)==1.0: check(row.tuck_450ms<.04,label+": full turn opens tuck after the short steering grace window")
	var result = {"model":model.MODEL_VERSION,"checks":checks,"failures":failures,"turns":results,"unranked":true}
	var path = OUTPUT+("/baseline_turns.json" if baseline else "/turns.json")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("DOWNHILL_CONTROL_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"path":path}))
	quit(0 if failures.is_empty() else 1)
