extends SceneTree
## Compare force-driven hard turns against the model-v8 bank limit.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const DT = 1.0/120.0
var checks = 0
var failures: Array[String] = []
var metrics: Array = []

func _initialize(): call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func fixture(speed: float, direction: float, tuck: float, mode: String, legacy: bool = false) -> Dictionary:
	var tuning = load("res://config/ski_default.tres").duplicate()
	if legacy:
		tuning.high_speed_body_lean = .85
		tuning.arcade_carve_strength = 0.0 # The v8 comparison must not inherit v20 carving.
	var sim = Sim.new(tuning)
	var surface = TestPlane.new(.46)
	sim.reset(Vector3.ZERO)
	sim.prime_contacts(surface)
	sim.velocity = Vector3.BACK.slide(sim.surface_normal).normalized()*speed/3.6
	sim.effective_tuck = tuck
	var input = RiderInput.new()
	input.tuck = tuck
	var minimum_balance = 1.0
	var maximum_slip = 0.0
	var result = {}
	var duration = 4.0 if mode=="hold" else 6.0
	for tick in range(roundi(duration/DT)):
		input.steer = direction
		if tick>=240 and mode=="reverse": input.steer = -direction
		if tick>=240 and mode=="release": input.steer = 0.0
		var previous_travel = sim.velocity.normalized()
		sim.step(DT,input,surface)
		minimum_balance = minf(minimum_balance,sim.balance)
		maximum_slip = maxf(maximum_slip,absf(rad_to_deg(sim.slip_angle)))
		if tick in [239,479]:
			# Three-dimensional trajectory curvature on the inclined plane.
			var angular_rate = previous_travel.angle_to(sim.velocity.normalized())/DT
			result[str((tick+1)/120)] = {
				"travel_turn_deg":-direction*rad_to_deg(atan2(sim.velocity.x,sim.velocity.z)),
				"radius_m":sim.velocity.length()/maxf(angular_rate,.0001),
				"speed_kmh":sim.speed_kmh(),"lateral_ms2":absf(sim.lateral_acceleration)}
		if sim.crashed: break
	result.merge({"start_kmh":speed,"direction":direction,"tuck":tuck,"mode":mode,
		"legacy":legacy,"crash":sim.crash_reason,"minimum_balance":minimum_balance,
		"maximum_slip_deg":maximum_slip,"final_vx_ms":sim.velocity.x,
		"final_slip_deg":rad_to_deg(sim.slip_angle)})
	return result

func run() -> void:
	for speed in [120.0,160.0,200.0]:
		for direction in [-1.0,1.0]:
			for tuck in [0.0,1.0]:
				var label = "%s km/h, direction %s, tuck %s"%[speed,direction,tuck]
				var before = fixture(speed,direction,tuck,"hold",true)
				var after = fixture(speed,direction,tuck,"hold")
				metrics.append(before)
				metrics.append(after)
				check(before.crash.is_empty() and after.crash.is_empty() and after.minimum_balance>.5,label+": held hard turn stays balanced")
				if before.has("4") and after.has("4"):
					check(after["4"].travel_turn_deg>before["4"].travel_turn_deg*1.18,label+": four-second hard turn redirects travel at least 18% farther")
					check(after["2"].radius_m<before["2"].radius_m*.85,label+": established turn radius is at least 15% tighter")
					# Compare initiation before the stronger held turn points uphill.
					check(after["2"].speed_kmh>before["2"].speed_kmh*.88,label+": tighter initiation retains most of the previous exit speed")
				check(after.maximum_slip_deg<18.0,label+": harder turn avoids a broadside skid")
				for mode in ["release","reverse"]:
					var recovery = fixture(speed,direction,tuck,mode)
					metrics.append(recovery)
					check(recovery.crash.is_empty() and recovery.minimum_balance>.5,label+": "+mode+" after a committed two-second turn stays recoverable")
					if mode=="release": check(absf(recovery.final_slip_deg)<3.0,label+": released skis recover alignment")
					if mode=="reverse": check(recovery.final_vx_ms*direction>1.0,label+": reversal turns actual travel the other way")
	var result = {"checks":checks,"failures":failures,"metrics":metrics}
	DirAccess.make_dir_recursive_absolute("res://artifacts/high_speed_turns")
	preload("res://tests/test_report.gd").write("res://artifacts/high_speed_turns/results.json",JSON.stringify(result,"\t"))
	print("HIGH_SPEED_TURNS_RESULTS ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
