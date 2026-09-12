extends SceneTree
const Stress = preload("res://tests/performance_stress.gd")
const Trace = preload("res://tests/performance_trace.gd")
var failures: Array[String] = []
var checks = 0
class StressPlane extends RefCounted:
	var wall = false
	var queries = 0
	func sample(_x: float,z: float) -> Dictionary:
		return {"height":-z*.25,"normal":Vector3(0,1,.25).normalized()}
	func sweep_obstacle(from: Vector3,to: Vector3) -> String:
		queries += 1
		return "TEST WALL" if wall and from.z<10 and to.z>=10 else ""
	func sweep_obstacle_contact(from: Vector3,to: Vector3) -> Dictionary:
		return {"position":from.lerp(to,(10-from.z)/(to.z-from.z)),"normal":Vector3.FORWARD}
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ",label)
func run() -> void:
	var tuning=preload("res://config/ski_default.tres")
	var plane=StressPlane.new(); plane.wall=true
	var command=RiderInput.new(); command.tuck=1.0
	var a=Stress.create(tuning.duplicate(true),170)
	var b=Stress.create(tuning.duplicate(true),170)
	for sim in [a,b]: sim.reset(Vector3.ZERO); sim.prime_contacts(plane)
	for tick in 1800:
		a.step(1.0/120.0,command,plane); b.step(1.0/120.0,command,plane)
	check(Trace.Inputs.matches_state(a,Trace.Inputs.state(b)),"Stress trajectories repeat exactly")
	check(not a.crashed and a.ticks==1800,"Immortal driver completes all 1800 ticks")
	check(a.min_speed_kmh>169.99 and a.max_speed_kmh<170.01,"Completed speed stays at 170 km/h")
	check(a.travelled_m>690 and a.travelled_m<725,"Fifteen seconds covers about 708 metres")
	check(a.nonblocking_contacts>0 and a.position.z>100,"Obstacle queries cannot pin the immortal skier")
	check(a.obstacle_queries==1800 and plane.queries>=3600,"Real obstacle query workload remains active")
	check(a.motion.velocity_world_mps==a.velocity and absf(a.motion.speed_mps*3.6-170)<.01,"Completed presentation velocity matches stress speed")
	a.crash("TEST HARD LANDING"); a.step(1.0/120.0,command,plane)
	check(not a.crashed and a.prevented_crashes.has("TEST HARD LANDING"),"Fatal events are recorded without stopping the run")
	a.reset_measurement()
	check(a.measured_ticks==0 and a.travelled_m==0 and a.prevented_crashes.is_empty(),"Warmup/pre-roll counters reset independently of the trajectory")
	var normal=Trace.Simulation.new(tuning.duplicate(true)); normal.reset(Vector3.ZERO)
	normal.crash("ORDINARY"); normal.step(1.0/120.0,command,plane)
	check(normal.crashed and normal.ticks==0,"Ordinary solver keeps real crash behavior")
	var meta=Stress.metadata(170,Vector3.ZERO)
	check(Stress.preflight_error(meta,170).is_empty(),"Matching current stress identity passes")
	check(not Stress.preflight_error(meta,0).is_empty(),"Stress trace cannot silently run as ordinary input")
	check(not Stress.preflight_error(null,170).is_empty(),"Ordinary trace cannot silently become stress input")
	check(not Stress.preflight_error(meta,120).is_empty(),"Speed mismatch is rejected")
	meta.source_sha256="stale"
	check(not Stress.preflight_error(meta,170).is_empty(),"Changed stress driver requires a new trace")
	print("STRESS_SUITE ",JSON.stringify({"checks":checks,"failures":failures,"sample":b.report()}))
	quit(0 if failures.is_empty() else 1)
