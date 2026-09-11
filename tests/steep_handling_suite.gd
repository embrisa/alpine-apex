extends SceneTree
## Travel-heading evidence, not visual ski yaw. The v16 baseline is immutable.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const SlopePlane = preload("res://tests/physics_suite.gd").TestPlane
const DT = 1.0/120.0
const OUTPUT = "res://artifacts/steep_animation_physics_upgrade"

static func measure(model, speed: float, steer: float, tuck: float = 0.0, reverse: bool = false, switch_entry: bool = false, overrides: Dictionary = {}) -> Dictionary:
	var sim = model.new()
	for key in overrides: sim.tuning.set(key,overrides[key])
	var plane = SlopePlane.new(.46)
	sim.reset(Vector3.ZERO,PI if switch_entry else 0.0); sim.prime_contacts(plane)
	sim.velocity = Vector3(0,-.46,1).normalized()*speed/3.6
	sim.effective_tuck = tuck
	var intent = RiderInput.new(); intent.tuck = tuck
	var last_heading = 0.0
	var turn = 0.0
	var distance = 0.0
	var result = {"kmh":speed,"steer":steer,"tuck":tuck,"reversal":reverse,"switch":switch_entry,
		"initiation_s":-1.0,"reversal_s":-1.0,"turn_2s_deg":0.0,"speed_2s_kmh":0.0,"turn_4s_deg":0.0,"peak_slip_deg":0.0,
		"time_45_s":-1.0,"time_90_s":-1.0,"time_180_s":-1.0,"distance_45_m":-1.0,"distance_90_m":-1.0,"distance_180_m":-1.0,"trace":[]}
	var reversal_peak = 0.0
	for tick in 1440:
		intent.steer = -steer if reverse and tick>=240 else steer
		var previous: Vector3 = sim.position
		sim.step(DT,intent,plane)
		var heading = atan2(sim.velocity.x,sim.velocity.z)
		var delta = angle_difference(last_heading,heading)*-signf(steer)
		turn += delta; last_heading = heading; distance += previous.distance_to(sim.position)
		result.peak_slip_deg = maxf(result.peak_slip_deg,absf(rad_to_deg(sim.slip_angle)))
		if result.initiation_s<0 and turn>deg_to_rad(1): result.initiation_s = (tick+1)*DT
		if tick>=240 and reverse:
			reversal_peak = maxf(reversal_peak,rad_to_deg(turn)-result.turn_2s_deg)
			if result.reversal_s<0 and delta/DT<-.03: result.reversal_s = (tick-239)*DT
		if tick==239: result.turn_2s_deg = rad_to_deg(turn); result.speed_2s_kmh = sim.speed_kmh()
		if tick==479: result.turn_4s_deg = rad_to_deg(turn); result.radius_4s_m = distance/maxf(absf(turn),.0001)
		for degrees in [45,90,180]:
			if result["time_%d_s"%degrees]<0 and rad_to_deg(turn)>=degrees:
				result["time_%d_s"%degrees] = (tick+1)*DT; result["distance_%d_m"%degrees] = distance
		if tick%12==0:
			result.trace.append({"s":(tick+1)*DT,"input":intent.steer,"ski_yaw_deg":rad_to_deg(sim.heading),"travel_turn_deg":rad_to_deg(turn),
				"edge_deg":rad_to_deg(sim.edge_angle),"roll_deg":rad_to_deg(sim.body.roll),"slip_deg":rad_to_deg(sim.slip_angle),
				"load_n":[sim.skis[0].load_n,sim.skis[1].load_n],"kmh":sim.speed_kmh()})
		if sim.crashed: break
	result.crash = sim.crash_reason; result.airtime_s = sim.total_airtime; result.reversal_overshoot_deg = reversal_peak
	return result

func _initialize(): call_deferred("run")
func run():
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var args = OS.get_cmdline_user_args()
	if "--validate-existing" in args:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"/handling_after.json"))
		var validation = acceptance(data.turns)
		FileAccess.open(OUTPUT+"/handling_acceptance.json",FileAccess.WRITE).store_string(JSON.stringify(validation,"\t"))
		print("HANDLING_ACCEPTANCE ",JSON.stringify(validation))
		quit(0 if validation.failures.is_empty() else 1)
		return
	var baseline = "--baseline" in args
	var model = load(OUTPUT+"/reference/ski_simulation.gd") if baseline else Sim
	var results = []
	var failures = []
	var sweep = "--tuning-sweep" in args
	var variants = [{}] if not sweep else [
		{}, {"steering_sensitivity":2.1,"turn_anticipation":.7},
		{"steering_sensitivity":2.1,"turn_anticipation":.7,"bank_pressure_reserve":.10,"turn_transfer_bank":.55,"turn_transfer_yaw_fraction":.25},
		{"steering_sensitivity":2.1,"turn_anticipation":.7,"bank_pressure_reserve":.14,"balance_damping":380.0,"turn_transfer_bank":.55}]
	for variant in variants:
		for speed in ([30.0,60.0,90.0,120.0] if sweep else [15.0,30.0,60.0,90.0,120.0,160.0,200.0]):
			for steer in ([1.0] if sweep else [-1.0,-.5,-.2,.2,.5,1.0]):
				for reverse in [false,true]:
					for tucked in ([0.0] if sweep else [0.0,1.0]):
						for switch_entry in ([false] if sweep else [false,true]):
							var row = measure(model,speed,steer,tucked,reverse,switch_entry,variant)
							row.variant = variant
							if sweep: row.erase("trace")
							results.append(row)
							if not row.crash.is_empty() or row.airtime_s>0: failures.append("Unexpected loss of support: "+str([speed,steer,reverse,tucked,switch_entry]))
		var partial = {"model":model.MODEL_VERSION,"failures":failures,"turns":results}
		FileAccess.open(OUTPUT+("/tuning_sweep.json" if sweep else ("/handling_before.json" if baseline else "/handling_after.json")),FileAccess.WRITE).store_string(JSON.stringify(partial,"\t"))
	if not baseline and not sweep:
		var validation = acceptance(results)
		failures.append_array(validation.failures)
		FileAccess.open(OUTPUT+"/handling_acceptance.json",FileAccess.WRITE).store_string(JSON.stringify(validation,"\t"))
	print("STEEP_HANDLING ",results.size()," cases; failures: ",failures)
	quit(0 if failures.is_empty() else 1)


static func acceptance(rows: Array) -> Dictionary:
	var reference: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/steep_v16_handling.json")).turns
	var failure = []
	var reversal_ratio = 0.0; var turn_ratio = 0.0; var reversals = 0; var turns = 0; var full_turns = 0
	if rows.size()!=reference.size(): return {"failures":["Incomplete before/after matrix"]}
	for index in rows.size():
		var row: Dictionary = rows[index]; var old: Dictionary = reference[index]
		if [row.kmh,row.steer,row.tuck,row.reversal,row.switch]!=[old.kmh,old.steer,old.tuck,old.reversal,old.switch]:
			failure.append("Mismatched fixture order"); continue
		if absf(row.steer)!=1: continue
		if row.reversal and row.reversal_s>0 and old.reversal_s>0:
			reversal_ratio += row.reversal_s/old.reversal_s; reversals += 1
		elif not row.reversal and row.time_90_s>0 and old.time_90_s>0:
			turn_ratio += row.time_90_s/old.time_90_s; turns += 1
			if row.kmh>=120 and row.time_180_s>0: full_turns += 1
	reversal_ratio /= maxi(reversals,1); turn_ratio /= maxi(turns,1)
	# These bands were selected after the frozen baseline: meaningful travel
	# reversal and sustained-turn gains, not equality with historical ski yaw.
	if reversals!=56 or reversal_ratio>.85: failure.append("Require at least 15% faster mean full-input travel reversal across the full matrix")
	if turns!=56 or turn_ratio>.96: failure.append("Require at least 4% faster mean full-input 90-degree travel change")
	if full_turns<12: failure.append("Require controllable 180-degree changes where entry momentum supports them")
	return {"checks":3,"failures":failure,"mean_reversal_ratio":reversal_ratio,"mean_time_90_ratio":turn_ratio,"reversals":reversals,"turns":turns,"full_turn_cases":full_turns}
