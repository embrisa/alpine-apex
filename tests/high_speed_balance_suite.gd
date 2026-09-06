extends SceneTree
## Gentle analogue corrections and short keyboard taps on actual mountain snow.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const CrossSlope = preload("res://tests/physics_suite.gd").CrossSlope
const DT = 1.0/120.0
class Mountain:
	extends "res://scripts/world/test_slope.gd"
	# Isolate contact/balance from legitimate tree and rock collisions.
	func sweep_obstacle(_a: Vector3,_b: Vector3) -> String: return ""
class UnequalNormals:
	extends TestPlane
	func contact_normal(x: float,_z: float) -> Vector3:
		return Vector3(x*.3,1,.46).normalized()
var checks = 0
var failures: Array[String] = []
var metrics: Array = []
func _initialize(): call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
func fixture(surface, speed: float, direction: float, amount: float, mode: String) -> void:
	var sim = Sim.new()
	var z = 500.0 if surface is Mountain else 0.0
	sim.reset(Vector3(0,surface.sample(0,z).height,z))
	sim.prime_contacts(surface)
	sim.velocity = Vector3.BACK.slide(sim.surface_normal).normalized()*speed/3.6
	var input = RiderInput.new()
	input.tuck = 1.0
	var minimum_balance = 1.0
	var maximum_roll = 0.0
	var velocity_error = 0.0
	for tick in range(1440):
		input.steer = direction*amount
		if mode=="wave": input.steer *= sin(tick*DT*1.6)
		if mode=="release" and tick>240: input.steer = 0.0
		if mode=="tap":
			input.steer = direction*(1.0 if tick%480<240 else -1.0) if tick%240<18 else 0.0
		sim.step(DT,input,surface)
		minimum_balance = minf(minimum_balance,sim.balance)
		maximum_roll = maxf(maximum_roll,absf(sim.body.roll))
		for ski in sim.skis:
			velocity_error = maxf(velocity_error,ski.velocity.distance_to((ski.position-ski.previous_position)/DT))
		if sim.crashed: break
	var terrain_name = "mountain" if surface is Mountain else ("cross-slope" if surface is CrossSlope else "plane")
	var label = "%s %s %.2f / direction %s at %s km/h"%[terrain_name,mode,amount,direction,speed]
	check(not sim.crashed and minimum_balance>.5,label+" remains recoverable for 12 seconds")
	check(velocity_error<.0001,label+" retains complete ski/boot tick velocity")
	metrics.append({"fixture":label,"crash":sim.crash_reason,"seconds":sim.ticks*DT,"minimum_balance":minimum_balance,"maximum_roll_rad":maximum_roll,"final_slip_deg":rad_to_deg(sim.slip_angle)})
func run() -> void:
	for surface in [TestPlane.new(.46),CrossSlope.new(),Mountain.new()]:
		for speed in [120,160,200]:
			for direction in [-1.0,1.0]:
				for scenario in [[.04,"hold"],[.04,"release"],[.12,"release"],[.12,"wave"],[.25,"wave"],[1.0,"tap"]]:
					fixture(surface,speed,direction,scenario[0],scenario[1])
	# Changing pressure alone must not move the terrain frame under the body.
	var surface = UnequalNormals.new()
	var sim = Sim.new()
	sim.reset(Vector3.ZERO)
	sim.prime_contacts(surface)
	sim.body.load_fractions = Vector2(.99,.01)
	sim._update_contacts(surface,DT,false)
	var reference = sim.support_basis()
	sim.body.load_fractions = Vector2(.01,.99)
	sim._update_contacts(surface,DT,false)
	check(reference.is_equal_approx(sim.support_basis()),"Boot pressure transfer cannot rotate the shared terrain frame")
	check(not sim.skis[0].normal.is_equal_approx(sim.skis[1].normal),"Separate skis retain their own terrain normals")
	# A grazing touch transmits a small impulse even with large tangential slip.
	var plane = TestPlane.new(0.0)
	sim = Sim.new()
	sim.reset(Vector3(0,.0001,0),.2)
	sim.prime_contacts(plane)
	sim.grounded = false
	sim.velocity = Vector3(0,-.1,200/3.6)
	sim.step(DT,RiderInput.new(),plane)
	print("GLANCING_CONTACT ",JSON.stringify({"balance":sim.balance,"pitch_rate":sim.body.pitch_velocity,"impact_ms":sim.landing_force,"crash":sim.crash_reason}))
	check(not sim.crashed and sim.balance>.97 and absf(sim.body.pitch_velocity)<.12,"Glancing high-speed snow contact cannot act like a hard edge-catch landing")
	var result = {"checks":checks,"failures":failures,"metrics":metrics}
	DirAccess.make_dir_recursive_absolute("res://artifacts/high_speed_balance")
	FileAccess.open("res://artifacts/high_speed_balance/results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("HIGH_SPEED_BALANCE_RESULTS ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
