extends SceneTree
## Ballistic/contact regressions, plus physical takeoffs on the shipped terrain.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Terrain = preload("res://scripts/world/generators/drainage_v3.gd")
const DT = 1.0/120.0
var failures: Array = []
var metrics: Array = []
var checks = 0
class Ledge extends RefCounted:
	func sample(_x: float,z: float) -> Dictionary:
		return {"height":0.0 if z<2.0 else -12.0,"normal":Vector3.UP}
	func sweep_obstacle(_a: Vector3,_b: Vector3) -> String: return ""
class RemoteTerrain extends RefCounted:
	var tilted = false
	func sample(_x: float,_z: float) -> Dictionary:
		return {"height":-1000.0,"normal":Vector3(.4,1,1.2).normalized() if tilted else Vector3.UP}
	func sweep_obstacle(_a: Vector3,_b: Vector3) -> String: return ""
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ",label)
	if not value: failures.append(label)
func run() -> void:
	var ledge = Ledge.new()
	var sim = Sim.new()
	sim.reset(Vector3.ZERO)
	sim.prime_contacts(ledge)
	sim.velocity = Vector3(0,0,20)
	var input = RiderInput.new()
	for i in 18: sim.step(DT,input,ledge)
	check(not sim.grounded and sim.position.y>-.08 and sim.total_airtime>.04,"An abrupt 12 m ledge releases contact without snapping down or pressing jump")
	check(sim.normal_load==0 and sim.friction_force==0 and sim.skis[0].load_n==0 and sim.skis[1].load_n==0,"Released skis exert no snow force")
	var remote = RemoteTerrain.new()
	var a = Sim.new()
	var b = Sim.new()
	for rider in [a,b]:
		rider.reset(Vector3.ZERO)
		rider.grounded = false
		rider.velocity = Vector3(0,0,25)
		rider.step(DT,input,remote)
	var start = a.position
	var initial_velocity = a.velocity
	a.tuning.aerodynamic_drag = 0
	b.tuning.aerodynamic_drag = 0
	for i in 120:
		remote.tilted = false
		a.step(DT,input,remote)
		remote.tilted = true
		b.step(DT,input,remote)
	check(a.position.distance_to(b.position)<.0001 and a.support_basis().is_equal_approx(b.support_basis()),"Distant terrain cannot rotate airborne skis or change their trajectory")
	check(a.body.joints==b.body.joints and not b.crashed,"Flight articulation is independent of the changing slope below")
	check(absf(a.velocity.y-initial_velocity.y+9.81)<.001 and absf(a.position.z-start.z-25.0)<.1,"Airtime follows gravity and incoming horizontal momentum")
	check(a.body.pelvis_height<.87,"Airborne stance draws knees up instead of rigidly extending into empty space")
	_feature_tests(Terrain.new(),[90.0,130.0])
	for seed_value in [0,1,42,12981,2147483647]:
		_feature_tests(Terrain.new(seed_value),[110.0])
	DirAccess.make_dir_recursive_absolute("res://artifacts/jump_upgrade")
	FileAccess.open("res://artifacts/jump_upgrade/physics.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"features":metrics},"\t"))
	print("JUMP_RESULTS ",JSON.stringify(metrics))
	quit(0 if failures.is_empty() else 1)

func _feature_tests(field, speeds: Array) -> void:
	for feature in field.jumps:
		for kmh in speeds:
			var sim = Sim.new()
			var x: float = feature.position.x
			var z: float = feature.position.y-85
			sim.reset(Vector3(x,field.sample(x,z).height,z))
			sim.prime_contacts(field)
			sim.velocity = sim.support_basis().z*kmh/3.6
			var input = RiderInput.new()
			input.tuck = .6
			var clearance = 0.0
			var landed = false
			var impact = 0.0
			var longest_flight = 0.0
			for i in 1600:
				var in_air = not sim.grounded
				sim.step(DT,input,field)
				clearance = maxf(clearance,sim.position.y-field.sample(sim.position.x,sim.position.z).height)
				longest_flight = maxf(longest_flight,sim.airtime)
				if in_air and sim.grounded:
					landed = true
					impact = maxf(impact,sim.landing_force)
				if sim.crashed or (landed and sim.position.z>feature.position.y+160): break
			metrics.append({"seed":field.seed_value,"kind":feature.kind,"z":feature.position.y,"entry_kmh":kmh,"clearance_m":clearance,"airtime_s":sim.total_airtime,"longest_flight_s":longest_flight,"landed":landed,"impact_m_s":impact,"crashed":sim.crashed,"reason":sim.crash_reason,"end":str(sim.position),"roll":sim.body.roll,"pitch":sim.body.pitch,"pitch_rate":sim.body.pitch_velocity,"roll_rate":sim.body.roll_velocity})
			check(longest_flight>.15 and clearance>.25,"%s at %.0f m gives natural airtime at %.0f km/h" % [feature.kind,feature.position.y,kmh])
			check(landed and not sim.crashed,"%s at %.0f m has a reachable landing at %.0f km/h" % [feature.kind,feature.position.y,kmh])
