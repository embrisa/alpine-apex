extends SceneTree
## Model v18: real contact geometry and measured impulses determine forgiveness.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Recovery = preload("res://scripts/core/impact_recovery.gd")
const Tuning = preload("res://scripts/core/ski_tuning.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const Replay = preload("res://scripts/racing/run_replay.gd")
const DT = 1.0/120.0
var checks = 0
var failures: Array = []
var metrics: Dictionary = {}

func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func run():
	curves()
	geometry()
	contacts()
	episodes()
	check(Sim.MODEL_VERSION==28 and Replay.VERSION==5,"Grounded snow retains the current landing and replay identity")
	DirAccess.make_dir_recursive_absolute("res://artifacts/landing_v18")
	var result = {"model":Sim.MODEL_VERSION,"checks":checks,"failures":failures,"metrics":metrics}
	FileAccess.open("res://artifacts/landing_v18/physics.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("LANDING_ABSORPTION_RESULTS ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func damage(speed: float, fit: float, alignment: float = 0.0, reference: float = 10.5) -> float:
	var recovery = Recovery.new()
	recovery.landing_hit(speed,alignment,reference,fit,"HARD LANDING",Tuning.new())
	return 1.0-recovery.reserve

func curves():
	var rows: Array = []
	for pair in [[0.0,0.0],[3.2,0.0],[8.0,0.0],[10.5,0.0],[14.0,.0222222222],[20.0,.0603174603],[30.0,.1238095238],[200.0,.65]]:
		var spent = damage(pair[0],1.0)
		check(absf(spent-pair[1])<.000001,"Clean %.1f m/s landing spends %.3f%% reserve"%[pair[0],pair[1]*100])
		rows.append({"normal_speed_mps":pair[0],"damage":spent})
	metrics.clean_curve = rows
	for speed in [3.2,8.0,10.5,14.0,30.0]:
		var old = Recovery.new()
		old.hit(speed+2.0,10.5,"OLD ROUGH",Tuning.new())
		check(absf(damage(speed,0.0,2.0)-(1.0-old.reserve))<.000001,"Unfitted landing retains rough curve at %.1f m/s"%speed)
		check(absf(damage(speed,.5,2.0)-(damage(speed,0.0,2.0)+damage(speed,1.0,2.0))*.5)<.000001,"Intermediate fit blends damage at %.1f m/s"%speed)
	check(damage(14.0,1.0,0.0,13.125)<damage(14.0,1.0),"Settled tuck is an optional extra allowance")
	var recovery = Recovery.new()
	var tuning = Tuning.new()
	recovery.hit(10.5,10.5,"PRIOR HIT",tuning)
	for tick in 180: recovery.step(DT,true,tuning)
	var age = recovery.since_hit
	var reserve = recovery.reserve
	recovery.landing_hit(10.5,0,10.5,1.0,"CLEAN",tuning)
	check(recovery.since_hit==age and recovery.reserve==reserve,"Zero-damage touchdown does not delay recovery")
	recovery.step(DT,true,tuning)
	check(recovery.reserve>reserve,"Recovery continues after a clean landing")
	recovery.reset()
	recovery.landing_hit(20,5,10.5,.5,"HARD LANDING",tuning)
	check(recovery.last_speed==20,"Landing telemetry retains normal speed, without alignment or absorption scaling")
	var reverse = Recovery.new()
	reverse.landing_hit(30,0,10.5,1,"SKI B",tuning)
	reverse.landing_hit(14,0,10.5,1,"SKI A",tuning)
	recovery.reset()
	recovery.landing_hit(14,0,10.5,1,"SKI A",tuning)
	recovery.landing_hit(30,0,10.5,1,"SKI B",tuning)
	check(absf(recovery.reserve-reverse.reserve)<.000001 and absf(1.0-recovery.reserve-.1238095238)<.000001,"Paired skis charge the strongest clean impact once in either order")

func geometry():
	var sim = Sim.new()
	var travel = Vector3(0,-20,30)
	for tilt in [0.0,10.0,30.0,50.0,100.0,180.0]:
		var fit = sim._landing_fit(Basis(Vector3.RIGHT,deg_to_rad(tilt)),Vector3.UP,travel)
		var expected = 1.0 if tilt<=10 else (.5 if tilt==30 else 0.0)
		check(absf(fit-expected)<.000001,"Pitch fit at %.0f degrees follows configured bands"%tilt)
		var rolled = sim._landing_fit(Basis(Vector3.BACK,deg_to_rad(tilt)),Vector3.UP,travel)
		check(absf(rolled-expected)<.000001,"Roll fit at %.0f degrees follows configured bands"%tilt)
	for yaw in [0.0,15.0,37.5,60.0,90.0,180.0]:
		var fit = sim._landing_fit(Basis(Vector3.UP,deg_to_rad(yaw)),Vector3.UP,travel)
		var expected = 1.0 if yaw<=15 or yaw==180 else (.5 if yaw==37.5 else 0.0)
		check(absf(fit-expected)<.000001,"Travel fit at %.1f degrees accepts either ski tip"%yaw)
	var combined = Basis(Vector3.UP,deg_to_rad(37.5))*Basis(Vector3.RIGHT,deg_to_rad(30))
	check(absf(sim._landing_fit(combined,Vector3.UP,travel)-.25)<.000001,"Pitch and travel fit multiply")
	check(sim._landing_fit(Basis(Vector3.UP,PI*.5),Vector3.UP,Vector3(0,-20,.1))==1.0,"Near-vertical travel uses slope fit alone")
	check(sim._landing_fit(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),Vector3.UP,travel)==0.0,"Degenerate equipment cannot earn absorption")
	check(sim._landing_fit(Basis(Vector3.RIGHT,PI*.5),Vector3.UP,travel)==0.0,"Vertical equipment cannot earn absorption")
	check(sim._landing_fit(Basis.IDENTITY,Vector3.ZERO,travel)==0.0,"Degenerate surface normal cannot earn absorption")

func setup() -> SkiSimulation:
	var sim = Sim.new()
	# Exact contact tests isolate geometry from gravity and analytic drag.
	sim.tuning.gravity_multiplier = 0.0
	sim.tuning.aerodynamic_drag = 0.0
	sim.reset(Vector3.ZERO)
	return sim

func touch(sim, plane, speed: float, tangent: float = 25.0, tilt: float = 0.0, yaw: float = 0.0):
	var n: Vector3 = plane.sample(0,0).normal
	var f = Vector3.BACK.slide(n).normalized()
	var frame = Basis(n.cross(f),n,f)
	sim.position = Vector3(0,.01,0)
	sim.surface_normal = n
	sim._begin_flight(frame*Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,tilt))
	sim.velocity = f*tangent-n*speed
	sim.step(DT,RiderInput.new(),plane)

func contacts():
	var rows: Array = []
	for slope in [0.0,.46,1.428148]: # flat, ordinary downhill, 55-degree face
		for reverse in [false,true]:
			for speed in [8.0,10.5,14.0,20.0,30.0]:
				var sim = setup()
				touch(sim,TestPlane.new(slope),speed,55.0,0.0,PI if reverse else 0.0)
				check(sim.time_since_landing==0.0 and absf((1.0-sim.impacts.reserve)-damage(speed,1.0))<.00001,"Actual slope %.2f / switch %s / %.1f m/s contact matches clean curve"%[slope,reverse,speed])
				var n: Vector3 = TestPlane.new(slope).sample(0,0).normal
				check(absf(sim.velocity.dot(n))<.00001 and absf(sim.velocity.length()-55.0)<.00001,"Clean contact preserves tangential momentum and removes inward speed")
				check(absf(sim.landing_force-speed)<.00001,"Physical landing telemetry is unscaled")
				rows.append({"slope":slope,"switch":reverse,"normal_speed_mps":speed,"damage":1.0-sim.impacts.reserve})
	metrics.contacts = rows
	var plane = TestPlane.new(0.0)
	for tangent in [20.0,100.0]:
		var grazing = setup()
		touch(grazing,plane,.2,tangent,0.0,PI*.5)
		check(grazing.impacts.reserve==1.0,"Fast broadside grazing does not create impact damage")
	for tilt in [deg_to_rad(30),deg_to_rad(60),PI]:
		var sim = setup()
		touch(sim,plane,20,25,tilt)
		check(sim.impacts.reserve<1.0-damage(20,1.0),"Awkward physical touchdown loses the clean-fit bonus")
	var low = setup()
	low.impacts.reserve = .05
	touch(low,plane,20)
	check(low.crashed and low.impacts.reserve==0 and low.crash_reason=="IMPACT LIMIT / HARD LANDING","Even a clean large impact can exhaust low reserve")
	var rough = setup()
	for event in 2:
		if event>0: rough.impacts.step(.4,false,rough.tuning); rough.landing_episode_age += .4
		touch(rough,plane,20,25,deg_to_rad(60))
	check(rough.crashed and rough.impacts.reserve==0,"Separated awkward impacts still accumulate to a crash")
	var a = setup(); var b = setup()
	b.tuning.landing_clean_damage_scale = 1.0
	a.position = Vector3(0,100,0); b.position = a.position
	a._begin_flight(Basis.IDENTITY); b._begin_flight(Basis.IDENTITY)
	a.velocity = Vector3(0,-10,30); b.velocity = a.velocity
	for tick in 120:
		a.step(DT,RiderInput.new(),plane); b.step(DT,RiderInput.new(),plane)
	check(a.position==b.position and a.velocity==b.velocity,"Absorption tuning cannot change airborne trajectory")

func bottom_out(sim, speed: float):
	# Drive a real supported compression stop, retaining the landing episode.
	sim.tuning.support_stiffness = 0.0
	sim.tuning.support_damping = .01
	sim.grounded = true
	sim.position = Vector3(0,-.27,0)
	sim.velocity = Vector3(0,-speed,20)
	sim.step(DT,RiderInput.new(),TestPlane.new(0.0))

func episodes():
	var plane = TestPlane.new(0.0)
	var sim = setup()
	touch(sim,plane,8)
	check(sim.landing_episode_age==0 and sim.landing_episode_fit==1 and sim.impacts.since_hit>1.25,"A free landing starts absorption history without starting damage recovery")
	bottom_out(sim,8)
	check(absf(sim.position.y+.28)<.00001 and sim.velocity.y==0 and sim.impacts.reserve==1 and sim.landing_force>7.9,"Immediate real bottom-out retains a free landing's absorption")
	bottom_out(sim,20)
	var reserve = sim.impacts.reserve
	check(absf((1.0-reserve)-damage(sim.impacts.last_speed,1.0))<.00001,"Stronger bottom-out charges only its clean residual damage")
	bottom_out(sim,14)
	check(sim.impacts.reserve==reserve,"A weaker compression stop cannot charge the episode twice")
	var age = sim.landing_episode_age
	touch(sim,plane,14)
	check(absf(sim.landing_episode_age-age-DT)<.000001,"Touchdown recontact does not refresh the episode timer")
	touch(sim,plane,14,25,deg_to_rad(60))
	check(sim.landing_episode_fit==0 and sim.impacts.reserve<reserve,"Worse recontact can reduce fit and charge only the damage difference")
	reserve = sim.impacts.reserve
	touch(sim,plane,14)
	check(sim.landing_episode_fit==0 and sim.impacts.reserve==reserve,"A later aligned ski cannot improve the episode's weakest fit")
	sim.landing_episode_age = .295
	touch(sim,plane,8)
	check(sim.landing_episode_age==0 and sim.landing_episode_fit==1,"A touchdown after 0.30 seconds starts a fresh fit episode")
	sim = setup()
	touch(sim,plane,8)
	sim.landing_episode_age = .295
	bottom_out(sim,14)
	check(sim.impacts.reserve<.5,"An unrelated bottom-out after expiry retains the ordinary rough curve")
	sim.reset(Vector3.ZERO)
	check(sim.landing_episode_fit==0 and sim.landing_episode_age==60 and sim.impacts.reserve==1,"Restart clears absorption history and reserve")
