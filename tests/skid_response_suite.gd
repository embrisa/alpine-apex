extends SceneTree
## Diagnose sustained equipment-yaw loss separately from trajectory response.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const DT = 1.0/120.0
const OUT = "res://artifacts/steering_response_v22/"
class PlaneSurface extends RefCounted:
	var gradient = .46
	func sample(_x: float, z: float) -> Dictionary:
		return {"height":-z*gradient,"normal":Vector3(0,1,gradient).normalized()}
	func sweep_obstacle(_a: Vector3, _b: Vector3) -> String: return ""

func _initialize() -> void: call_deferred("run")

static func measure(kmh: float, slip: float, steer: float, mode: String, slope: float = .46, trace: bool = false) -> Dictionary:
	var sim = Sim.new(); var surface = PlaneSurface.new(); surface.gradient = slope
	sim.reset(Vector3.ZERO,deg_to_rad(-slip)); sim.prime_contacts(surface)
	sim.velocity = Vector3(0,-slope,1).normalized()*kmh/3.6
	var input = RiderInput.new()
	var row = {"kmh":kmh,"slip":slip,"steer":steer,"mode":mode,"slope":slope,"zero_yaw_s":0.0,"weak_yaw_s":0.0,"max_zero_s":0.0,"max_weak_s":0.0,"yaw_deg":0.0,"trace":[],"airtime_s":0.0,"crash":""}
	var zero_run = 0.0; var weak_run = 0.0; var motor_run = 0.0
	row.max_motor_stall_s = 0.0
	row.max_skid_weak_s = 0.0
	var skid_weak_run = 0.0
	for tick in 960:
		input.steer = steer
		input.tuck = 1.0 if mode=="tuck" else 0.0
		input.brake = 1.0 if mode=="brake_release" and tick<120 else 0.0
		if mode=="reverse" and tick>=240: input.steer = -steer
		if mode=="alternate": input.steer = steer*(1.0 if tick%120<60 else -1.0)
		var old_ski: float = sim.skis[0].heading
		sim.step(DT,input,surface)
		var ratio = absf(sim.steering_applied_yaw)/maxf(.000001,absf(sim.steering_requested_yaw))
		var supported = sim.grounded and sim.speed_kmh()>30
		motor_run = motor_run+DT if supported and absf(angle_difference(old_ski,sim.skis[0].heading))/DT<.001 else 0.0
		row.max_motor_stall_s = maxf(row.max_motor_stall_s,motor_run)
		zero_run = zero_run+DT if supported and ratio<.001 else 0.0
		weak_run = weak_run+DT if supported and ratio<.1 else 0.0
		# Separately gate the reported skid lock. Low-authority edge transfers
		# inside the healthy carving envelope are recorded, not confused with it.
		skid_weak_run = skid_weak_run+DT if supported and ratio<.1 and absf(sim.slip_angle)>=deg_to_rad(18.0) else 0.0
		row.max_skid_weak_s = maxf(row.max_skid_weak_s,skid_weak_run)
		row.max_zero_s = maxf(row.max_zero_s,zero_run); row.max_weak_s = maxf(row.max_weak_s,weak_run)
		row.zero_yaw_s += DT if zero_run>0 else 0.0; row.weak_yaw_s += DT if weak_run>0 else 0.0
		row.yaw_deg += absf(rad_to_deg(sim.steering_applied_yaw))*DT
		if trace and tick%6==0:
			row.trace.append({"s":(tick+1)*DT,"input":input.steer,"speed":sim.speed_kmh(),"heading":sim.heading,"ski_heading":sim.skis[0].heading,"slip_deg":rad_to_deg(sim.slip_angle),"request":sim.steering_requested_yaw,"applied":sim.steering_applied_yaw,"transfer":sim.steering_transfer_factor,"skid":sim.steering_slip_factor,"roll":sim.body.roll,"roll_velocity":sim.body.roll_velocity,"com":[sim.body.com.x,sim.body.com.y,sim.body.com.z],"load":sim.normal_load,"lateral":sim.lateral_acceleration})
		if sim.crashed: break
	row.airtime_s = sim.total_airtime; row.crash = sim.crash_reason
	return row

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var baseline = "--baseline" in args
	var quick = "--quick" in args
	var rows: Array = []; var failures: Array = []
	for speed in ([120.0,200.0] if quick else [60.0,90.0,120.0,160.0,200.0]):
		for slip in ([30.0,60.0] if quick else [-90.1,-60.0,-30.0,-18.0,0.0,17.9,18.1,30.0,60.0,89.9,90.1]):
			for steer in [-1.0,1.0]:
				for mode in (["hold","reverse"] if quick else ["hold","reverse","alternate","tuck","brake_release"]):
					var row = measure(speed,slip,steer,mode,.46,true)
					rows.append(row)
					if not baseline and maxf(row.max_zero_s,row.max_motor_stall_s)>.15: failures.append("Steering lock "+str([speed,slip,steer,mode])+": "+str(row.max_zero_s))
					if not baseline and row.max_skid_weak_s>.35: failures.append("Sustained weak skid steering "+str([speed,slip,steer,mode])+": "+str(row.max_skid_weak_s))
		print("SKID_CASES ",rows.size())
	DirAccess.make_dir_recursive_absolute(OUT)
	var result = {"model":Sim.MODEL_VERSION,"baseline":baseline,"cases":rows.size(),"failures":failures,"rows":rows}
	preload("res://tests/test_report.gd").write(OUT+("baseline" if baseline else "after")+("_quick" if quick else "")+".json",JSON.stringify(result))
	print("SKID_RESPONSE ",rows.size()," cases, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
