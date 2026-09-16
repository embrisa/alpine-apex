extends SceneTree
## Model v12: forgiveness comes from distinct impacts, never balance depletion.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Recovery = preload("res://scripts/core/impact_recovery.gd")
const Tuning = preload("res://scripts/core/ski_tuning.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const Surface = preload("res://scripts/world/heightfield_surface.gd")
const DT = 1.0/120.0
var checks = 0
var failures: Array = []
var metrics: Dictionary = {}

class ObstaclePlane extends Surface:
	func sample(_x: float,_z: float) -> Dictionary: return {"height":0.0,"normal":Vector3.UP}
	func contact_normal(_x: float,_z: float) -> Vector3: return Vector3.UP
	func ski_bounds() -> Rect2: return Rect2(-100,-100,200,200)

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)
func run() -> void:
	_warning_loop()
	_landings()
	_turns()
	_obstacles()
	DirAccess.make_dir_recursive_absolute("res://artifacts/impact_recovery")
	var result = {"model":Sim.MODEL_VERSION,"checks":checks,"failures":failures,"metrics":metrics}
	preload("res://tests/test_report.gd").write("res://artifacts/impact_recovery/physics.json",JSON.stringify(result,"\t"))
	print("IMPACT_RECOVERY_RESULTS ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func _warning_loop() -> void:
	var tuning = Tuning.new()
	var recovery = Recovery.new()
	check(not recovery.hit(5.0,10.5,"LANDING",tuning) and recovery.reserve==1.0,"Soft landing has no impact cost")
	check(not recovery.hit(10.5,10.5,"LANDING",tuning) and absf(recovery.reserve-.70)<.00001,"Reference rough landing spends 30 percent of the bar")
	check(not recovery.hit(10.5,10.5,"SECOND SKI",tuning) and absf(recovery.reserve-.70)<.00001,"Two ski contacts do not charge twice for one landing")
	for i in range(24): recovery.step(DT,true,tuning)
	check(not recovery.hit(10.5,10.5,"RECONTACT",tuning) and absf(recovery.reserve-.70)<.00001,"Immediate recontact remains part of the same impact")
	for i in range(24): recovery.step(DT,true,tuning)
	check(not recovery.hit(3.2,10.5,"SMALL HOP",tuning) and absf(recovery.reserve-.70)<.00001,"Small hops do not spend reserve or restart the delay")
	check(not recovery.hit(10.5,10.5,"SECOND LANDING",tuning) and absf(recovery.reserve-.40)<.00001,"Second ordinary rough landing leaves reserve instead of enforcing a two-hit rule")
	for i in range(48): recovery.step(DT,true,tuning)
	check(not recovery.hit(10.5,10.5,"THIRD LANDING",tuning) and absf(recovery.reserve-.10)<.00001,"Third reference landing survives with ten percent reserve")
	for i in range(48): recovery.step(DT,true,tuning)
	check(recovery.hit(10.5,10.5,"FOURTH LANDING",tuning) and recovery.reserve==0.0,"Fourth separated reference impact empties the bar and causes a fall")
	recovery.reset()
	recovery.hit(10.5,10.5,"LANDING",tuning)
	for i in range(120): recovery.step(DT,true,tuning)
	check(absf(recovery.reserve-.70)<.00001,"Recovery waits for smooth riding instead of immediately refunding the impact")
	for i in range(150): recovery.step(DT,true,tuning)
	check(recovery.reserve>.85 and recovery.reserve<.89,"The bar refills gradually after the delay")
	for i in range(720): recovery.step(DT,true,tuning)
	check(recovery.reserve==1.0,"Prolonged smooth contact restores the full bar without overfilling")
	recovery.hit(10.5,10.5,"LANDING",tuning)
	for i in range(720): recovery.step(DT,false,tuning)
	check(absf(recovery.reserve-.70)<.00001,"Free flight cannot refill the impact bar")
	recovery.reset()
	check(not recovery.hit(50.0,10.5,"VERY HARD LANDING",tuning) and absf(recovery.reserve-.35)<.00001,"Single-impact damage is capped at 65 percent for forgiveness")
	check(not recovery.hit(100.0,10.5,"SAME CONTACT CLUSTER",tuning) and absf(recovery.reserve-.35)<.00001,"A stronger probe in the same event cannot stack beyond the event cap")
	var reserves: Array = []
	for speed in [3.2,8.0,10.5,14.0,30.0]:
		recovery.reset()
		recovery.hit(speed,10.5,"SEVERITY",tuning)
		reserves.append(recovery.reserve)
	metrics.reserve_after_normal_impact_3_2_8_10_5_14_30_ms = reserves
	check(reserves[0]==1.0 and reserves[1]>reserves[2] and reserves[2]>reserves[3] and reserves[3]>reserves[4],"Increasing normal impact speed spends progressively more reserve")
	var first = Recovery.new()
	var second = Recovery.new()
	first.hit(8.0,10.5,"SKI A",tuning)
	first.hit(12.0,10.5,"SKI B",tuning)
	second.hit(12.0,10.5,"SKI B",tuning)
	second.hit(8.0,10.5,"SKI A",tuning)
	check(absf(first.reserve-second.reserve)<.00001,"Event grouping charges the maximum impact regardless of probe order")
	recovery.reset()
	check(recovery.reserve==1.0 and recovery.last_reason.is_empty(),"Reset restores reserve and clears the last impact reason")

func _drop(sim, speed: float, plane) -> void:
	sim.position = Vector3(0,.01,0)
	sim.velocity = Vector3(0,-speed,8.0)
	sim.grounded = false
	sim.flight_initialized = false
	sim.step(DT,RiderInput.new(),plane)

func _landings() -> void:
	var plane = TestPlane.new(0.0)
	var sim = Sim.new()
	sim.reset(Vector3.ZERO)
	_drop(sim,12.0,plane)
	check(sim.grounded and not sim.crashed and sim.impacts.dizziness>0.0,"Actual hard landing survives with an impact warning")
	check(sim.velocity.y==0.0 and sim.velocity.z>7.0,"Survived landing removes inward momentum and preserves tangential motion")
	for i in range(48): sim.step(DT,RiderInput.new(),plane)
	_drop(sim,3.2,plane)
	check(not sim.crashed and sim.impacts.dizziness>0.0,"Actual small landing during recovery remains survivable")
	var before_small = sim.impacts.reserve
	_drop(sim,8.0,plane)
	check(not sim.crashed and sim.impacts.reserve==before_small,"A clean small landing during recovery absorbs its entire impact")
	for i in range(48): sim.step(DT,RiderInput.new(),plane)
	sim.impacts.reserve = .05
	_drop(sim,20.0,plane)
	check(sim.crashed and sim.impacts.reserve==0.0 and sim.crash_reason=="IMPACT LIMIT / HARD LANDING","A large clean landing still falls when its residual cost exhausts low reserve")
	sim.reset(Vector3.ZERO)
	_drop(sim,35.0,plane)
	check(not sim.crashed and sim.impacts.dizziness>0 and absf(sim.body.pitch)<=.70001,"Very hard first landing cannot secretly fall through body balance")
	sim.reset(Vector3.ZERO)
	check(sim.impacts.dizziness==0.0 and not sim.crashed,"Simulation restart restores the impact allowance")
	for heading in [0.0,PI]:
		sim.reset(Vector3.ZERO,heading)
		_drop(sim,5.0,plane)
		check(not sim.crashed and sim.impacts.dizziness==0.0,"Aligned forward/switch landing is accepted, heading %.0f" % rad_to_deg(heading))

func _turns() -> void:
	var plane = TestPlane.new(0.0)
	for kmh in [90.0,200.0]:
		var sim = Sim.new()
		sim.reset(Vector3.ZERO)
		sim.prime_contacts(plane)
		sim.velocity = Vector3.BACK*kmh/3.6
		sim.heading = PI*.5
		sim.balance = 0.0 # Historical diagnostic must have no gameplay authority.
		for i in range(360): sim.step(DT,RiderInput.new(),plane)
		check(not sim.crashed and sim.impacts.dizziness==0.0,"Broadside skidding costs speed without balance death at %.0f km/h" % kmh)
		check(sim.speed_kmh()<kmh,"Forgiving skid still dissipates momentum at %.0f km/h" % kmh)
	var sim = Sim.new()
	sim.reset(Vector3.ZERO)
	sim.prime_contacts(plane)
	sim.body.roll = 1.45
	sim.body.pitch = .95
	sim.body.roll_velocity = 2.0
	sim.body.pitch_velocity = 2.0
	for i in range(480): sim.step(DT,RiderInput.new(),plane)
	check(not sim.crashed and sim.impacts.dizziness==0.0,"Body tipping alone cannot cause a fall or impact warning")
	check(absf(sim.body.roll)<.15 and absf(sim.body.pitch)<.15,"Supported pose assist returns a tipped rider upright")
	for period in [30,60,120]:
		sim.reset(Vector3.ZERO)
		sim.prime_contacts(plane)
		sim.velocity = Vector3.BACK*200.0/3.6
		for tick in range(720):
			var intent = RiderInput.new()
			intent.steer = 1.0 if tick%(period*2)<period else -1.0
			sim.step(DT,intent,plane)
		check(not sim.crashed and sim.impacts.dizziness==0.0,"Repeated turns every %.2f s cannot drain hidden balance" % (period*DT))

func _obstacle_plane():
	var plane = ObstaclePlane.new()
	plane.add_obstacle({"position":Vector3(0,0,5),"radius":1.0,"height":2.0,"tree":false})
	return plane

func _obstacles() -> void:
	var plane = _obstacle_plane()
	var hit = plane.sweep_obstacle_contact(Vector3.ZERO,Vector3(0,0,20))
	check(not hit.is_empty() and absf(hit.position.z-3.65)<.001 and hit.normal.dot(Vector3.FORWARD)>.999,"Sweep returns the entry point and outward normal of a thin obstacle")
	check(plane.sweep_obstacle(Vector3(0,50,0),Vector3(0,50,20)).is_empty(),"Flight well above an obstacle remains clear")
	var roof = plane.sweep_obstacle_contact(Vector3(0,5,5),Vector3(0,0,5))
	check(roof.normal==Vector3.UP and absf(roof.position.y-2.0)<.001,"Vertical collision measures the struck top surface")
	plane.add_obstacle({"position":Vector3(0,0,2),"radius":.3,"height":2.0,"tree":true})
	hit = plane.sweep_obstacle_contact(Vector3.ZERO,Vector3(0,0,20))
	check(hit.id==1 and hit.reason=="TREE IMPACT","Earliest collision wins independently of obstacle insertion order")
	check(plane.sweep_obstacle(Vector3.ZERO,Vector3(200,0,0))==plane.boundary_message,"World boundary rule remains explicit")
	plane = _obstacle_plane()
	var sim = Sim.new()
	sim.reset(Vector3.ZERO)
	sim.prime_contacts(plane)
	sim.velocity = Vector3.BACK*20.0
	for i in range(90): sim.step(DT,RiderInput.new(),plane)
	check(not sim.crashed and sim.impacts.dizziness>0.0,"First direct rock impact gives a warning and survives repeated contact")
	check(sim.position.z<3.66 and sim.velocity.length()<.1,"Surviving a direct hit stops at the obstacle instead of passing through")
	sim.position = Vector3.ZERO
	sim.velocity = Vector3.BACK*20.0
	for i in range(40):
		sim.step(DT,RiderInput.new(),plane)
		if sim.crashed: break
	check(sim.crashed and sim.impacts.reserve==0.0 and sim.crash_reason=="IMPACT LIMIT / ROCK IMPACT","A second heavy rock impact exhausts the remaining reserve")
	sim.reset(Vector3(1.34,0,0))
	sim.prime_contacts(plane)
	sim.velocity = Vector3.BACK*20.0
	for i in range(80): sim.step(DT,RiderInput.new(),plane)
	check(not sim.crashed and sim.impacts.dizziness==0.0,"Fast grazing contact is judged by normal closing speed, not total speed")
	check(sim.position.z>8 and sim.speed_kmh()>40,"A glancing contact deflects and continues along the obstacle")
