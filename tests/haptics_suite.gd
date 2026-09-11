extends SceneTree
const Haptics = preload("res://scripts/presentation/rider_haptics.gd")
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Carving = preload("res://tests/arcade_carving_suite.gd")
const DT = 1.0/120.0
var checks = 0
var failures: Array = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)

func observe(h, sim) -> void:
	sim.ticks += 1
	h.observe_tick(sim,DT)

func landing(h, sim, speed: float) -> Vector3:
	sim.skis[0].landing_speed = speed
	observe(h,sim)
	sim.skis[0].landing_speed = 0.0
	for tick in 9: observe(h,sim)
	return h.advance(0.0,true,false,1.0)

func run() -> void:
	var h = Haptics.new()
	var sim = Sim.new()
	var field = Carving.CarvePlane.new()
	sim.reset(Vector3.ZERO); sim.prime_contacts(field)
	sim.velocity = sim.support_basis().z*160.0/3.6
	var intent = RiderInput.new(); intent.tuck = 1.0
	var silent = true
	for tick in 480:
		intent.steer = .7 if tick>240 else 0.0
		sim.step(DT,intent,field)
		h.observe_tick(sim,DT)
		silent = silent and h.advance(DT,true,false,1.0)==Vector3.ZERO
	check(silent,"Smooth snow and fast sustained turns produce no background rumble")
	h.reset(); sim.reset(Vector3.ZERO)
	sim.grounded = false; sim.velocity = Vector3(10,-5,40); sim.slip_angle = 1.0; sim.edge_load = 1.0; sim.impacts.reserve = .1
	observe(h,sim)
	check(h.advance(DT,true,false,1.0)==Vector3.ZERO,"Flight, slip, edge load and low impact reserve are silent")
	for speed in [.9,1.0,2.0,3.2,3.49]:
		check(landing(h,sim,speed)==Vector3.ZERO,"Small %.2f m/s landings are silent"%speed)
	var small = landing(h,sim,3.5)
	check(small.is_equal_approx(Vector3(.08,.02,.045)),"A threshold landing creates only a faint 45 ms pulse")
	h.advance(.02,true,false,1.0)
	var large = landing(h,sim,14.0)
	check(large.is_equal_approx(Vector3(.55,1.0,.16)),"An overlapping large impact takes maximum strength without resetting cluster age")
	var ignored = landing(h,sim,2.0)
	check(ignored==large,"A tiny recontact cannot change or extend an active impact")
	check(h.advance(.17,true,false,1.0)==Vector3.ZERO,"The entire overlapping impact cluster ends within 180 ms")
	var capped = landing(h,sim,60.0)
	check(capped.is_equal_approx(Vector3(.55,1.0,.18)),"Extreme contacts saturate amplitude and duration")
	check(h.advance(0.0,false,true,.5).is_equal_approx(Vector3(.275,.5,.18)),"The existing intensity scales both motors and a crash pulse may finish")
	check(h.advance(.2,false,true,1.0)==Vector3.ZERO,"Persistent crash state does not repeat an impact")
	var previous = Vector3.ZERO
	for speed in [3.5,4.0,6.0,8.0,10.0,12.0,14.0]:
		h.reset(); sim.reset(Vector3.ZERO)
		var output = landing(h,sim,speed)
		check(output.x>previous.x and output.y>previous.y and output.z>previous.z,"Stronger %.1f m/s physical contact increases both motors and duration"%speed)
		previous = output
	h.reset(); sim.reset(Vector3.ZERO)
	sim._obstacle_contact = {"reason":"TREE","closing_speed_mps":3.49}
	observe(h,sim)
	check(h.advance(0.0,true,false,1.0)==Vector3.ZERO,"A glancing obstacle brush below the threshold is silent")
	h.reset(); sim.reset(Vector3.ZERO)
	sim._obstacle_contact = {"reason":"TREE","closing_speed_mps":7.0}
	observe(h,sim)
	var obstacle = h.advance(0.0,true,false,1.0)
	check(obstacle.y>.2,"Obstacle closing speed triggers impact feedback independently of reserve damage")
	sim._obstacle_contact.clear()
	h.advance(.3,true,false,1.0)
	h.observe_tick(sim,DT)
	check(h.advance(0.0,true,false,1.0)==Vector3.ZERO,"Reobserving a completed tick cannot replay its event")
	h.reset(); sim.reset(Vector3.ZERO)
	check(landing(h,sim,7.0).is_equal_approx(obstacle),"Landing and obstacle feedback use the same physical severity scale")
	h.reset(); sim.reset(Vector3.ZERO); observe(h,sim)
	sim.landing_force = 3.2
	for tick in 10: observe(h,sim)
	check(h.advance(0.0,true,false,1.0)==Vector3.ZERO,"Small supported bottom-outs stay silent")
	sim.landing_force = 7.0
	for tick in 10: observe(h,sim)
	check(h.advance(0.0,true,false,1.0).is_equal_approx(obstacle),"Hard supported bottom-outs use physical closing-speed telemetry")
	h.reset(); sim.reset(Vector3.ZERO)
	sim.velocity = Vector3(0,0,10); sim.rock_contact = .5; sim.normal_load = 9.81
	observe(h,sim)
	var rock = h.advance(.1,true,false,1.0)
	check(rock.is_equal_approx(Vector3(.06,0,.03)),"Mixed rock contact produces a faint 30 ms pulse even at a slow render frame")
	check(h.advance(.031,true,false,1.0)==Vector3.ZERO,"Rock taps have a quiet gap")
	check(h.advance(.418,true,false,1.0)==Vector3.ZERO,"Rock cannot retrigger inside 450 ms")
	check(h.advance(.002,true,false,1.0).x>0.0,"Sustained rock can pulse after the 450 ms interval")
	sim.rock_contact = 0.0; observe(h,sim)
	check(h.advance(0.0,true,false,1.0)==Vector3.ZERO,"Leaving rock immediately cancels its pulse")
	sim.rock_contact = 1.0; sim.grounded = false; observe(h,sim)
	check(h.advance(1.0,true,false,1.0)==Vector3.ZERO,"Airborne rock proximity never rumbles")
	sim.grounded = true; sim.velocity = Vector3(0,0,2); observe(h,sim)
	check(h.advance(1.0,true,false,1.0)==Vector3.ZERO,"Stationary or slow rock contact is silent")
	sim.velocity.z = 10.0; sim.normal_load = 0.0; observe(h,sim)
	check(h.advance(1.0,true,false,1.0)==Vector3.ZERO,"Unsupported rock contact is silent")
	sim.normal_load = 9.81; observe(h,sim)
	h.advance(0.0,true,false,1.0)
	var priority = landing(h,sim,14.0)
	check(Vector2(priority.x,priority.y).is_equal_approx(Vector2(.55,1.0)) and h.rock_remaining==0.0,"Impact feedback takes priority over rock taps")
	check(h.advance(0.0,true,false,0.0)==Vector3.ZERO,"Zero intensity immediately clears feedback")
	check(h.advance(0.0,true,false,1.0)==Vector3.ZERO,"Re-enabling vibration does not replay cleared events")
	landing(h,sim,5.0)
	check(h.advance(0.0,false,false,1.0)==Vector3.ZERO,"Inactive non-crash views cancel all pulses")
	check(h.advance(0.0,true,false,1.0)==Vector3.ZERO,"Resume starts with no queued impact or rock pulse")
	# Haptics only observes: compare the complete numerical output of paired runs.
	var a = Sim.new(); var b = Sim.new(); h.reset()
	for model in [a,b]:
		model.reset(Vector3.ZERO); model.prime_contacts(field); model.velocity = model.support_basis().z*90.0/3.6
	var equal = true
	for tick in 240:
		a.step(DT,intent,field); b.step(DT,intent,field)
		h.observe_tick(a,DT); h.advance(DT,true,false,1.0)
		equal = equal and a.position==b.position and a.velocity==b.velocity and a.effective_tuck==b.effective_tuck and a.impacts.reserve==b.impacts.reserve
	check(equal,"Haptic observation cannot alter skiing or impact reserve")
	DirAccess.make_dir_recursive_absolute("res://artifacts/controller_input_v1")
	var result = {"checks":checks,"failures":failures}
	FileAccess.open("res://artifacts/controller_input_v1/haptics.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("HAPTICS_RESULTS ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
