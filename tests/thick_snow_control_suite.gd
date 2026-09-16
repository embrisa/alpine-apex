extends SceneTree
## Travel response on identical slopes, including grip settings and reversals.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const SnowPlane = preload("res://tests/physics_suite.gd").SnowPlane
const Response = preload("res://scripts/presentation/snow_response.gd")
const DT = 1.0/120.0
var rows: Array = []
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func measure(depth: float, kmh: float, steer: float, maximum: bool = false) -> Dictionary:
	var field = SnowPlane.new(.46); field.depth = depth
	var sim = Sim.new(); sim.reset(Vector3.ZERO); sim.prime_contacts(field)
	if maximum: sim.tuning.edge_grip = 3.0; sim.tuning.carving_strength = 18.0
	sim.velocity = sim.support_basis().z*kmh/3.6
	var input = RiderInput.new(); input.steer = steer
	var slip_sum = 0.0; var peak_slip = 0.0; var turn = 0.0
	var previous = atan2(sim.velocity.x,sim.velocity.z)
	var unsupported_grip = 0.0; var reversal = -1.0; var powder = 0.0
	for tick in 480:
		if tick==240: input.steer = -steer
		sim.step(DT,input,field)
		var travel = atan2(sim.velocity.x,sim.velocity.z)
		if tick<240:
			turn -= signf(steer)*angle_difference(previous,travel)
			slip_sum += absf(sim.slip_angle)
			peak_slip = maxf(peak_slip,absf(sim.slip_angle))
		elif reversal<0 and angle_difference(previous,travel)*signf(steer)>DT*.03:
			reversal = (tick-239)*DT
		previous = travel
		for ski in sim.skis:
			if not ski.grounded: unsupported_grip = maxf(unsupported_grip,ski.grip_n)
			var response = Response.new(); response.sample(sim,ski,field)
			powder = maxf(powder,response.powder)
	return {"depth":depth,"kmh":kmh,"steer":steer,"maximum":maximum,"turn_deg":rad_to_deg(turn),"mean_slip_deg":rad_to_deg(slip_sum/240),"peak_slip_deg":rad_to_deg(peak_slip),"reversal_s":reversal,"airtime_s":sim.total_airtime,"exit_kmh":sim.speed_kmh(),"unsupported_grip_n":unsupported_grip,"crash":sim.crash_reason,"powder_peak":powder}
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: ",message)
func run() -> void:
	for kmh in [60.0,120.0,200.0]:
		for steer in [.5,1.0]:
			for depth in [.02,.20]:
				for maximum in [false,true]:
					rows.append(measure(depth,kmh,steer,maximum))
	var baseline = "--baseline" in OS.get_cmdline_user_args()
	if not baseline:
		for row in rows:
			check(row.crash.is_empty() and row.airtime_s==0 and row.unsupported_grip_n==0,"Supported snow turn: "+str(row))
			if row.depth==.20 and not row.maximum:
				var shallow = rows.filter(func(v): return v.depth==.02 and v.kmh==row.kmh and v.steer==row.steer and not v.maximum)[0]
				check(row.mean_slip_deg<shallow.mean_slip_deg*.70,"Thick snow reduces sustained sideways slip by at least 30%: "+str(row.kmh)+"/"+str(row.steer))
				check(row.mean_slip_deg<6.0 and row.peak_slip_deg<12.0,"Thick snow holds a controllable line: "+str(row.kmh)+"/"+str(row.steer))
				check(row.reversal_s>0 and row.reversal_s<=.65,"Thick snow responds to reversed steering")
				var stronger = rows.filter(func(v): return v.depth==.20 and v.kmh==row.kmh and v.steer==row.steer and v.maximum)[0]
				check(stronger.mean_slip_deg<row.mean_slip_deg*.80,"Workbench grip/response has a measurable effect in thick snow")
	DirAccess.make_dir_recursive_absolute("res://artifacts/snow_control_fix")
	preload("res://tests/test_report.gd").write("res://artifacts/snow_control_fix/"+("baseline" if baseline else "control")+".json",JSON.stringify({"model":Sim.MODEL_VERSION,"rows":rows,"failures":failures},"\t"))
	print("THICK_SNOW_CONTROL model=",Sim.MODEL_VERSION," rows=",rows.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
