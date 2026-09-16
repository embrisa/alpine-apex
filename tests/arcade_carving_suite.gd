extends SceneTree
## Paired path geometry on a fixed plane; input never writes velocity after setup.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const DT = 1.0/120.0
const OUTPUT = "res://artifacts/arcade_carving_v20"
const REFERENCE = "res://tests/fixtures/arcade_v19_carving.json"

class CarvePlane extends RefCounted:
	var gradient = .46
	func sample(_x: float, z: float) -> Dictionary:
		return {"height":-z*gradient,"normal":Vector3(0,1,gradient).normalized()}
	func sweep_obstacle(_a: Vector3, _b: Vector3) -> String: return ""

static func measure(model, kmh: float, steer: float, tuck: float = 0.0, switch_entry: bool = false, mode: String = "held", overrides: Dictionary = {}, trace: bool = false) -> Dictionary:
	var sim = model.new()
	for key in overrides: sim.tuning.set(key,overrides[key])
	var plane = CarvePlane.new()
	var forward = Vector3(0,-plane.gradient,1).normalized()
	sim.reset(Vector3.ZERO,PI if switch_entry else 0.0)
	sim.prime_contacts(plane)
	sim.velocity = forward*kmh/3.6
	sim.effective_tuck = tuck
	var intent = RiderInput.new()
	intent.tuck = tuck
	var row = {"kmh":kmh,"steer":steer,"tuck":tuck,"switch":switch_entry,"mode":mode,
		"radius_45_m":-1.0,"time_45_s":-1.0,"speed_45_kmh":-1.0,"initiation_s":-1.0,"reversal_s":-1.0,"grip_reversal_s":-1.0,"return_speed_kmh":-1.0,
		"turn_2s_deg":0.0,"turn_4s_deg":0.0,"speed_2s_kmh":0.0,"peak_slip_deg":0.0,
		"peak_roll_deg":0.0,"recovery_ticks":0,"trace":[]}
	var angle = 0.0
	var last_heading = 0.0
	var distance = 0.0
	var direction = -signf(steer)
	var reverse_start = 240 if mode=="reversal" else -1
	var tick_count = 1440 if mode in ["held","matched_reversal"] else 720
	for tick in tick_count:
		intent.steer = steer
		if mode=="matched_reversal" and reverse_start<0 and angle>=PI*.25: reverse_start = tick
		if reverse_start>=0 and tick>=reverse_start: intent.steer = -steer
		if mode=="release" and tick>=240: intent.steer = 0.0
		if mode=="rapid": intent.steer = steer*(1.0 if tick%60<30 else -1.0)
		var previous: Vector3 = sim.position
		var old_speed: float = sim.speed_kmh()
		var old_angle = angle
		sim.step(DT,intent,plane)
		var heading = atan2(sim.velocity.x,sim.velocity.dot(forward))
		var delta = angle_difference(last_heading,heading)*direction
		angle += delta
		last_heading = heading
		var segment: float = previous.distance_to(sim.position)
		if row.time_45_s<0.0 and angle>=PI*.25:
			var fraction = clampf((PI*.25-old_angle)/maxf(delta,.0000001),0.0,1.0)
			row.time_45_s = (tick+fraction)*DT
			row.radius_45_m = (distance+segment*fraction)/(PI*.25)
			row.speed_45_kmh = lerpf(old_speed,sim.speed_kmh(),fraction)
		distance += segment
		if row.initiation_s<0 and angle>deg_to_rad(1.0): row.initiation_s = (tick+1)*DT
		if reverse_start>=0 and tick>=reverse_start and row.reversal_s<0 and delta/DT<-.03: row.reversal_s = (tick-reverse_start+1)*DT
		if reverse_start>=0 and tick>=reverse_start and row.grip_reversal_s<0 and sim.lateral_acceleration*signf(steer)>1.0: row.grip_reversal_s = (tick-reverse_start+1)*DT
		if mode=="matched_reversal" and reverse_start>=0 and old_angle>0 and angle<=0 and row.return_speed_kmh<0:
			row.return_speed_kmh = lerpf(old_speed,sim.speed_kmh(),old_angle/(old_angle-angle))
		if tick==239: row.turn_2s_deg = rad_to_deg(angle); row.speed_2s_kmh = sim.speed_kmh()
		if tick==479: row.turn_4s_deg = rad_to_deg(angle)
		row.peak_slip_deg = maxf(row.peak_slip_deg,absf(rad_to_deg(sim.slip_angle)))
		row.peak_roll_deg = maxf(row.peak_roll_deg,absf(rad_to_deg(sim.body.roll)))
		row.recovery_ticks += int(sim.body.recovering_pose)
		if trace and tick%12==0:
			row.trace.append({"s":(tick+1)*DT,"turn_deg":rad_to_deg(angle),"speed":sim.speed_kmh(),
				"roll":rad_to_deg(sim.body.roll),"slip":rad_to_deg(sim.slip_angle),"lateral":sim.lateral_acceleration,
				"requested":sim.requested_lateral_acceleration,"com":[sim.body.com.x,sim.body.com.y],
				"reserve":sim.body.pressure_reserve,"load":sim.normal_load,"support_margin":sim.body.support_margin})
		if sim.crashed: break
		if mode=="matched_reversal" and row.return_speed_kmh>0: break
		# Fixed two/four-second readings remain available; long held runs stop
		# once the fixed-angle metric is complete rather than circling uphill.
		if mode=="held" and tick>=479 and row.time_45_s>0: break
	row.crash = sim.crash_reason
	row.airtime_s = sim.total_airtime
	return row

func _initialize() -> void: call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var args = OS.get_cmdline_user_args()
	if "--contracts" in args:
		var checks = contracts()
		preload("res://tests/test_report.gd").write(OUTPUT+"/contracts.json",JSON.stringify(checks,"\t"))
		print("ARCADE_CONTRACTS ",JSON.stringify(checks))
		quit(0 if checks.failures.is_empty() else 1); return
	var baseline = "--baseline" in args
	if baseline and FileAccess.file_exists(REFERENCE): printerr("Baseline fixture already exists; refusing overwrite"); quit(2); return
	var sweep = "--sweep" in args
	var full_sweep = "--racing" in args
	var model = load(OUTPUT+"/reference/ski_simulation.gd") if baseline else Sim
	var rows: Array = []
	var failures: Array = []
	var variants: Array = [{}]
	if sweep: variants = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"/variants.json"))
	for variant in variants:
		for kmh in ([60.0,90.0,120.0,160.0] if sweep else [15.0,30.0,45.0,60.0,90.0,120.0,160.0,200.0]):
			for steer in ([-1.0,1.0] if full_sweep else ([1.0] if sweep else [-1.0,-.5,-.2,.2,.5,1.0])):
				for tuck in ([0.0] if sweep and not full_sweep else [0.0,1.0]):
					for switch_entry in ([false] if sweep and not full_sweep else [false,true]):
						for mode in (["held","reversal"] if sweep else ["held","reversal","release"]):
							var row = measure(model,kmh,steer,tuck,switch_entry,mode,variant,"--trace" in args)
							row.variant = variant
							rows.append(row)
							if not row.crash.is_empty() or row.airtime_s>0: failures.append("Support: "+str([kmh,steer,tuck,switch_entry,mode]))
		print("CARVING_VARIANT ",JSON.stringify(variant)," rows=",rows.size())
		if sweep: preload("res://tests/test_report.gd").write(OUTPUT+"/sweep.json",JSON.stringify({"model":model.MODEL_VERSION,"rows":rows,"failures":failures},"\t"))
	var result = {"model":model.MODEL_VERSION,"unranked":true,"rows":rows,"failures":failures}
	if not baseline and not sweep:
		result.acceptance = acceptance(rows)
		failures.append_array(result.acceptance.failures)
		result.contracts = contracts()
		failures.append_array(result.contracts.failures)
	if baseline:
		if FileAccess.file_exists(REFERENCE): printerr("Baseline fixture already exists; refusing overwrite"); quit(2); return
		preload("res://tests/test_report.gd").write(REFERENCE,JSON.stringify(result,"\t"))
	var name = "baseline" if baseline else ("sweep" if sweep else "after")
	preload("res://tests/test_report.gd").write(OUTPUT+"/"+name+".json",JSON.stringify(result,"\t"))
	print("ARCADE_CARVING ",rows.size()," cases, failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

static func acceptance(rows: Array) -> Dictionary:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REFERENCE))
	var failures: Array = []
	var ratios: Array = []
	var speed_ratios: Array = []
	if rows.size()!=reference.rows.size(): return {"failures":["Incomplete paired matrix"]}
	for i in rows.size():
		var row: Dictionary = rows[i]
		var old: Dictionary = reference.rows[i]
		var key = [row.kmh,row.steer,row.tuck,row.switch,row.mode]
		if key!=[old.kmh,old.steer,old.tuck,old.switch,old.mode]:
			failures.append("Mismatched case "+str(key)); continue
		if absf(row.steer)<=.2 or (row.kmh<=30.0 and maxf(row.speed_2s_kmh,old.speed_2s_kmh)<=30.0):
			if absf(row.turn_2s_deg-old.turn_2s_deg)>maxf(.01,absf(old.turn_2s_deg)*.05): failures.append("Small/slow correction changed "+str(key))
		if absf(row.steer)!=1.0 or row.kmh<60 or row.kmh>160: continue
		if row.initiation_s>old.initiation_s+DT+.00001: failures.append("Slower initiation "+str(key))
		if row.mode=="reversal" and old.reversal_s>0:
			if row.grip_reversal_s<0 or row.grip_reversal_s>.75: failures.append("Opposite edge failed to engage promptly "+str(key))
			if row.reversal_s<0 or row.reversal_s>old.reversal_s+DT+.00001: failures.append("Slower reversal "+str(key))
		if row.mode!="held": continue
		if row.radius_45_m<=0 or old.radius_45_m<=0: failures.append("Missing 45-degree arc "+str(key)); continue
		var ratio: float = row.radius_45_m/old.radius_45_m
		ratios.append(ratio)
		speed_ratios.append(row.speed_45_kmh/old.speed_45_kmh)
		# Roughly 25-30% overall, allowing modest variation with entry speed.
		if ratio<.65 or ratio>.80: failures.append("Arc outside 20-35% improvement band "+str(key)+": "+str(ratio))
		if row.speed_45_kmh<old.speed_45_kmh*.95: failures.append("Momentum loss "+str(key))
	var mean_ratio = 0.0
	for ratio in ratios: mean_ratio += ratio/maxi(1,ratios.size())
	if ratios.size()!=32 or mean_ratio<.70 or mean_ratio>.75: failures.append("Require 25-30% smaller mean radius across all 32 racing cases")
	return {"failures":failures,"mean_radius_ratio":mean_ratio,"radius_ratios":ratios,"speed_ratios":speed_ratios}

static func contracts() -> Dictionary:
	var failures: Array = []
	var checks = 0
	# v21 changes tuck and suspension independently of carving. The historical
	# upright curves still isolate the disabled carving calibration; the new
	# tuck contract is exercised separately by tuck_contact_suite.
	var captured: Array = JSON.parse_string(FileAccess.get_file_as_string(REFERENCE)).rows
	var max_fixture_relative_error = 0.0
	for speed in [30.0,60.0,120.0,160.0]:
		for direction in [-1.0,1.0]:
			for mode in ["held","reversal","release"]:
				var curve = measure(Sim,speed,direction,0.0,false,mode,{"arcade_carve_strength":0.0})
				var old: Dictionary = captured.filter(func(row): return row.kmh==speed and row.steer==direction and row.tuck==0.0 and not row.switch and row.mode==mode)[0]
				checks += 1
				var error = 0.0
				for key in ["radius_45_m","time_45_s","speed_45_kmh","initiation_s","reversal_s","turn_2s_deg","turn_4s_deg","speed_2s_kmh","peak_slip_deg","peak_roll_deg"]:
					error = maxf(error,absf(float(curve[key])-float(old[key]))/maxf(1.0,absf(float(old[key]))))
				max_fixture_relative_error = maxf(max_fixture_relative_error,error)
				if error>.001 or curve.crash!=old.crash or curve.airtime_s!=old.airtime_s: failures.append("Disabled carving changed the historical upright curve")
	# A horizontal plane isolates contact work from downhill gravitational work.
	var flat = CarvePlane.new(); flat.gradient = 0.0
	var max_energy_gain = 0.0
	for amount in [-1.0,-.5,.5,1.0]:
		var sim = Sim.new(); sim.tuning.aerodynamic_drag = 0.0
		sim.reset(Vector3.ZERO); sim.prime_contacts(flat); sim.velocity = Vector3.BACK*40.0
		var intent = RiderInput.new(); intent.steer = amount
		for tick in 720:
			var energy = sim.velocity.slide(Vector3.UP).length_squared()
			sim.step(DT,intent,flat)
			max_energy_gain = maxf(max_energy_gain,sim.velocity.slide(Vector3.UP).length_squared()-energy)
		checks += 1
		if sim.crashed or max_energy_gain>.0005: failures.append("Ground contact added tangential energy")
	# Calibration belongs to one simulation, never to a shared resource or air input.
	var shared = SkiTuning.new()
	var values: Dictionary = {}
	for property in shared.get_property_list():
		if property.usage&PROPERTY_USAGE_SCRIPT_VARIABLE: values[property.name] = shared.get(property.name)
	var a = Sim.new(shared); var b = Sim.new(shared)
	for sim in [a,b]:
		sim.reset(Vector3(0,1000,0)); sim.velocity = Vector3(0,0,40)
		sim._begin_flight(Basis.IDENTITY)
	var steer = RiderInput.new(); steer.steer = 1.0
	for tick in 240: a.step(DT,steer,flat); b.step(DT,RiderInput.new(),flat)
	checks += 1
	if a.position!=b.position or a.velocity!=b.velocity or a.carve_blend!=0.0: failures.append("Air steering changed translation")
	var grounded = Sim.new(shared); grounded.reset(Vector3.ZERO); grounded.prime_contacts(flat); grounded.velocity = Vector3.BACK*30
	for tick in 240: grounded.step(DT,steer,flat)
	checks += 1
	for key in values:
		if shared.get(key)!=values[key]: failures.append("Shared tuning mutated: "+key)
	for speed in [15.0,30.0,45.0,60.0,120.0,160.0,200.0]:
		var prior = -1.0
		for amount in [0.0,.2,.25,.3,.5,.75,1.0]:
			var blend = shared.carving_blend(amount,speed/3.6)
			checks += 1
			if blend<prior or blend<0.0 or blend>1.0: failures.append("Non-progressive blend")
			if (amount<=.25 or speed<=30.0) and blend!=0.0: failures.append("Correction/low-speed dead band changed")
			prior = blend
	for speed in [60.0,90.0,120.0,160.0]:
		for amount in [-1.0,1.0]:
			var rapid = measure(Sim,speed,amount,1.0,false,"rapid")
			checks += 1
			if not rapid.crash.is_empty() or rapid.airtime_s>0: failures.append("Rapid reversals lost support")
	var shipped = load("res://config/ski_default.tres")
	checks += 1
	for key in values:
		if str(key).begins_with("arcade_") and shipped.get(key)!=shared.get(key): failures.append("Shipping calibration differs: "+str(key))
	var progressive: Array = []
	for tuck in [0.0,1.0]:
		var previous_radius = INF
		for amount in [.35,.5,.75,1.0]:
			var curve = measure(Sim,120.0,amount,tuck)
			progressive.append({"tuck":tuck,"steer":amount,"radius_m":curve.radius_45_m})
			checks += 1
			if curve.radius_45_m<=0 or curve.radius_45_m>=previous_radius or not curve.crash.is_empty(): failures.append("Intermediate input does not progressively tighten the path")
			previous_radius = curve.radius_45_m
	return {"checks":checks,"failures":failures,"max_contact_speed_squared_gain":max_energy_gain,"progressive_curves":progressive,"max_upright_fixture_relative_error":max_fixture_relative_error}
