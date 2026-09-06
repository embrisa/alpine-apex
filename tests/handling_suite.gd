extends SceneTree
## Player handling regressions: actual travel, recovery and sustained turns.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const CrossSlope = preload("res://tests/physics_suite.gd").CrossSlope
const Terrain = preload("res://scripts/world/test_slope.gd")
const DT = 1.0/120.0
var checks = 0
var failures: Array[String] = []
var metrics: Array = []

func _initialize(): call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func fixture(surface, speed: float, direction: float, mode: String, z: float = 0.0):
	var sim = Sim.new(load("res://config/ski_default.tres").duplicate())
	sim.reset(Vector3(0,surface.sample(0,z).height,z))
	sim.prime_contacts(surface)
	sim.velocity = Vector3.BACK.slide(sim.surface_normal).normalized()*speed/3.6
	var intent = RiderInput.new()
	var minimum_balance = 1.0
	var maximum_slip = 0.0
	var signed_lateral = 0.0
	var duration = 4.0 if mode!="mountain" else 2.0
	for tick in range(roundi(duration/DT)):
		intent.steer = direction
		if mode=="reverse": intent.steer *= 1.0 if tick%240<120 else -1.0
		if mode=="release" and tick>=120: intent.steer = 0.0
		if mode=="mountain": intent.steer *= .7
		sim.step(DT,intent,surface)
		minimum_balance = minf(minimum_balance,sim.balance)
		maximum_slip = maxf(maximum_slip,absf(sim.slip_angle))
		if tick>=360: signed_lateral += sim.lateral_acceleration*DT
		if sim.crashed: break
	metrics.append({"speed_kmh":speed,"direction":direction,"mode":mode,"z":z,
		"minimum_balance":minimum_balance,"max_slip_deg":rad_to_deg(maximum_slip),
		"travel_turn_deg":-direction*rad_to_deg(atan2(sim.velocity.x,sim.velocity.z)),
		"last_second_lateral_impulse_ms":signed_lateral,"crash":sim.crash_reason})
	check(not sim.crashed and minimum_balance>.5,"%s at %s km/h, direction %s, z=%s stays recoverable" % [mode,speed,direction,z])
	if mode=="hold":
		check(-direction*sim.velocity.x>1.0,"Held turn changes the actual travel direction")
		if speed>=60:
			check(maximum_slip<deg_to_rad(23),"Fast held turns avoid broadside skids")
	if mode=="release":
		check(absf(sim.slip_angle)<deg_to_rad(3),"Releasing steering recovers ski alignment")
	return sim

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/handling")
	for speed in [30,60,90,120,150,200]:
		for direction in [-1.0,1.0]:
			for mode in ["hold","reverse","release"]:
				fixture(TestPlane.new(.46),speed,direction,mode)
	for direction in [-1.0,1.0]:
		fixture(CrossSlope.new(),120,direction,"hold")
		# A single reversal must actually turn the trajectory the other way.
		var surface = TestPlane.new(.46)
		var sim = Sim.new()
		sim.reset(Vector3.ZERO)
		sim.prime_contacts(surface)
		sim.velocity = Vector3.BACK.slide(sim.surface_normal).normalized()*120/3.6
		var input = RiderInput.new()
		for tick in range(720):
			input.steer = direction if tick<120 else -direction
			sim.step(DT,input,surface)
		check(not sim.crashed and sim.velocity.x*direction>1.0,"A sustained reversal changes actual travel to the opposite direction")
	var mountain = Terrain.new()
	for z in [250,500,900]:
		for direction in [-1.0,1.0]:
			fixture(mountain,120,direction,"mountain",z)
	print("HANDLING_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	FileAccess.open("res://artifacts/handling/results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	quit(0 if failures.is_empty() else 1)
