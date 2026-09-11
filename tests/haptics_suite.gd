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
	check(landing(h,sim,.9)==Vector3.ZERO,"Sub-1 m/s contacts are silent")
	var small = landing(h,sim,1.0)
	check(small.is_equal_approx(Vector3(.16,.05,.06)),"A small landing creates one 60 ms pulse")
	h.advance(.02,true,false,1.0)
	var large = landing(h,sim,10.0)
	check(large.is_equal_approx(Vector3(.45,.80,.16)),"An overlapping large impact takes maximum strength without resetting cluster age")
	check(h.advance(.17,true,false,1.0)==Vector3.ZERO,"The entire overlapping impact cluster ends within 180 ms")
	var capped = landing(h,sim,60.0)
	check(capped.is_equal_approx(Vector3(.45,.80,.18)),"Extreme contacts saturate amplitude and duration")
	check(h.advance(0.0,false,true,.5).is_equal_approx(Vector3(.225,.4,.18)),"The existing intensity scales both motors and a crash pulse may finish")
	check(h.advance(.2,false,true,1.0)==Vector3.ZERO,"Persistent crash state does not repeat an impact")
	h.reset(); sim.reset(Vector3.ZERO)
	sim._obstacle_contact = {"reason":"TREE","closing_speed_mps":7.0}
	observe(h,sim)
	check(h.advance(0.0,true,false,1.0).y>.5,"Obstacle closing speed triggers impact feedback independently of reserve damage")
	sim._obstacle_contact.clear()
	h.advance(.3,true,false,1.0)
	h.observe_tick(sim,DT)
	check(h.advance(0.0,true,false,1.0)==Vector3.ZERO,"Reobserving a completed tick cannot replay its event")
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
	var priority = landing(h,sim,10.0)
	check(Vector2(priority.x,priority.y).is_equal_approx(Vector2(.45,.80)) and h.rock_remaining==0.0,"Impact feedback takes priority over rock taps")
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
