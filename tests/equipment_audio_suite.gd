extends SceneTree
const Contacts = preload("res://scripts/presentation/equipment_audio_contacts.gd")
const Events = preload("res://scripts/presentation/riding_audio_events.gd")
class CountingContacts extends Contacts:
	var sweeps = 0
	func _sweep(old_a: Dictionary, a: Dictionary, old_b: Dictionary, b: Dictionary, dt: float) -> Dictionary:
		sweeps += 1
		return super._sweep(old_a,a,old_b,b,dt)
var checks = 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS " if value else "FAIL ",label)
func pieces(x: float, metal: bool = false, shift: Vector3 = Vector3.ZERO) -> Array[Dictionary]:
	var material = Contacts.Surface.METAL if metal else Contacts.Surface.CARBON
	return [Contacts.proxy(0,Vector3(x,-.5,0)+shift,Vector3(x,.5,0)+shift,.009,material),Contacts.proxy(1,Vector3(0,0,-.5)+shift,Vector3(0,0,.5)+shift,.009,material)]
func load_fixture() -> Dictionary:
	return {"position":Vector3.ZERO,"velocity":Vector3(0,0,20),"grounded":true,"crashed":false,
		"tuning":{"rider_mass":80.0},"landing_force":0.0,"obstacle_contact":{},
		"skis":[{"grounded":true,"load_n":400.0,"landing_speed":0.0,"material_kind":0},
			{"grounded":true,"load_n":400.0,"landing_speed":0.0,"material_kind":0}]}
func sample_load(observer, sim: Dictionary, ticks: int = 1) -> Array:
	var found: Array = []
	for tick in ticks:
		found.append_array(observer.sample(sim,1.0/120).filter(func(e): return e.kind==Events.Kind.EQUIPMENT))
	return found
func check_load_rattles() -> void:
	var observer = Events.new()
	var sim = load_fixture()
	check(sample_load(observer,sim,20).is_empty(),"Steady skiing primes the load observer quietly")
	sim.skis[0].load_n = 100.0
	check(sample_load(observer,sim).is_empty(),"Unloading a supported ski does not trigger a binding rattle")
	sample_load(observer,sim,60)
	sim.skis[0].load_n = 700.0
	var found = sample_load(observer,sim)
	check(found.size()==1 and found[0].get("profile",0)==Events.EquipmentProfile.BINDING_RATTLE,"A distinct supported loading jolt produces one binding rattle")
	for tick in 360:
		sim.skis[0].load_n = 400.0 if tick%2==0 else 700.0
		found.append_array(sample_load(observer,sim))
	check(found.size()==1,"Three seconds of alternating ski pressure cannot repeat the same rattle episode")
	check(sample_load(observer,sim,60).is_empty(),"Settling pressure does not play an expired rattle")
	sim.skis[0].load_n = 1000.0
	check(sample_load(observer,sim).size()==1,"Settled support rearms a later independent loading jolt")
	sample_load(observer,sim,32)
	sim.skis[0].load_n = 1300.0
	check(sample_load(observer,sim,70).is_empty(),"A jolt inside the rattle tail is consumed without overlap or delayed playback")
	sim.skis[0].load_n = 1600.0
	check(sample_load(observer,sim).size()==1,"A fresh jolt can sound after the previous rattle tail finishes")
	observer.reset(); sim = load_fixture(); sample_load(observer,sim,20)
	found = []
	for tick in 240:
		sim.skis[0].grounded = tick%2!=0
		sim.skis[0].load_n = 400.0 if sim.skis[0].grounded else 0.0
		found.append_array(sample_load(observer,sim))
	check(found.is_empty(),"Rapid loss and regain of ski contact cannot manufacture binding rattles")
	observer.reset(); sim = load_fixture(); sample_load(observer,sim,20)
	sim.skis[0].load_n = 700.0; sim.skis[0].landing_speed = 5.0
	found = sample_load(observer,sim)
	sim.skis[0].landing_speed = 0.0
	found.append_array(sample_load(observer,sim,60))
	check(found.is_empty(),"Pending paired landing audio suppresses the same loading jolt's rattle")
	observer.reset(); sim = load_fixture(); sample_load(observer,sim,20)
	sim.obstacle_contact = {"closing_speed_mps":5.0,"reason":"ROCK"}; sim.skis[0].load_n = 700.0
	check(sample_load(observer,sim).is_empty(),"An obstacle impact suppresses a same-tick load rattle")
	observer.reset(); sim = load_fixture(); sample_load(observer,sim,20)
	sim.skis[0].load_n = 700.0; sim.position.z = 1000.0
	check(sample_load(observer,sim,20).is_empty(),"Teleport discards the old load onset and primes quietly")
	observer.reset(); sim.skis[0].load_n = 1000.0
	check(sample_load(observer,sim,20).is_empty(),"Lifecycle reset cannot replay the previous load jolt")
func run() -> void:
	check_load_rattles()
	var separated = CountingContacts.new()
	var distant: Array[Dictionary] = [Contacts.proxy(0,Vector3.ZERO,Vector3.UP,.01,0),Contacts.proxy(1,Vector3(4,0,0),Vector3(4,1,0),.01,0)]
	separated.sample(distant,Vector3.ZERO,.016,"riding")
	distant[0].b += Vector3(.5,0,.5)
	check(separated.sample(distant,Vector3.ZERO,.016,"riding").is_empty() and separated.sweeps==0,"Separated swept bounds avoid narrow-phase work without a sound")
	var margin = Contacts.new()
	margin.sample(pieces(0),Vector3.ZERO,.016,"riding")
	for frame in 8: margin.sample(pieces(-.035),Vector3.ZERO,.016,"riding")
	check(margin.touching.size()==1,"Broad phase retains the full two-centimetre contact rearm margin")
	for frame in 8: margin.sample(pieces(-.05),Vector3.ZERO,.016,"riding")
	check(margin.touching.is_empty(),"Separated bounds still let the contact episode rearm")
	var observer = Contacts.new()
	var ownership = Contacts.new()
	ownership.sample(pieces(-.3),Vector3.ZERO,.016,"riding")
	var same_owner=pieces(.3); same_owner[1].owner=0
	check(ownership.sample(same_owner,Vector3.ZERO,.016,"riding").is_empty(),"Changed ownership re-primes and cannot collide within one equipment owner")
	same_owner=pieces(-.3); same_owner[1].owner=0
	check(ownership.sample(same_owner,Vector3.ZERO,.016,"riding").is_empty(),"Cached ownership keeps same-owner crossing quiet")
	ownership.sample(pieces(-.3),Vector3.ZERO,.016,"riding")
	check(ownership.sample(pieces(.3),Vector3.ZERO,.033,"riding").size()==1,"Restored ownership rebuilds contact candidates and detects the next crossing")
	var initial = pieces(-.3)
	var original = initial.duplicate(true)
	check(observer.sample(initial,Vector3.ZERO,1.0/60,"riding").is_empty(),"First frame primes quietly")
	check(initial==original,"Observer never mutates supplied pose proxies")
	var found = observer.sample(pieces(.3),Vector3.ZERO,1.0/30,"riding")
	check(found.size()==1 and found[0].profile==Events.EquipmentProfile.SHAFT_TICK and absf(found[0].speed-18)<.1,"Fast carbon shafts crossing between frames produce one speed-scaled tick")
	observer.reset()
	observer.sample(pieces(-.3,true),Vector3.ZERO,1.0/60,"riding")
	found = observer.sample(pieces(.3,true),Vector3.ZERO,1.0/30,"riding",Transform3D(Basis.IDENTITY,Vector3(-2,0,0)))
	check(found.size()==1 and found[0].profile==Events.EquipmentProfile.METAL_CLINK and found[0].pan>.9,"Metal-to-metal selects a clink at the contact's listener-relative side")
	observer.reset()
	for i in 120: found = observer.sample(pieces(0),Vector3.ZERO,1.0/120,"riding")
	check(found.is_empty() and observer.touching.size()==1,"Resting initial overlap never rattles")
	for fps in [30,60,120,240]:
		observer.reset()
		var collected: Array = []
		for i in fps+1:
			var t: float = float(i)/fps
			var x: float = -.3+2*t if t<.3 else .3 if t<.65 else .3-2*(t-.65)
			collected.append_array(observer.sample(pieces(x),Vector3.ZERO,1.0/fps,"riding"))
		check(collected.size()==2,"Separated forward/back crossings rearm once at %d FPS" % fps)
		check(collected.all(func(e): return absf(e.speed-2)<.02),"Closing-speed intensity agrees at %d FPS" % fps)
	observer.reset()
	for i in 30:
		var shift = Vector3(0,0,i*4)
		found = observer.sample(pieces(-.025,false,shift),shift,1.0/30,"riding")
	check(found.is_empty(),"120 m/s common downhill translation cannot create equipment contacts")
	observer.reset(); observer.sample(pieces(-.3),Vector3.ZERO,.016,"riding")
	check(observer.sample(pieces(.3,false,Vector3(0,0,100)),Vector3(0,0,100),.016,"riding").is_empty(),"Teleport primes without a swept strike")
	observer.reset(); observer.sample(pieces(-.3),Vector3.ZERO,.016,"riding")
	check(observer.sample(pieces(.3),Vector3.ZERO,.016,"crash").is_empty(),"Riding-to-crash transition clears pose history")
	observer.reset(); observer.sample(pieces(-.3),Vector3.ZERO,.016,"riding")
	check(observer.sample(pieces(.3),Vector3.ZERO,.5,"riding").is_empty(),"Long frame gaps re-prime without false hits")
	check(observer.sample(pieces(0),Vector3.ZERO,.016,"").is_empty() and observer.previous.is_empty(),"Inactive presentation clears contact state")
	var slow = Contacts.new(); slow.sample(pieces(-.019),Vector3.ZERO,.016,"riding")
	check(slow.sample(pieces(-.017),Vector3.ZERO,.033,"riding").is_empty(),"Sub-threshold contact movement remains quiet")
	observer.reset(); observer.sample(pieces(-.03),Vector3.ZERO,.016,"riding")
	found = observer.sample(pieces(-.015),Vector3.ZERO,.016,"riding")
	check(found.size()==1,"Separation margin does not prematurely latch an approaching contact")
	for i in 30: found = observer.sample(pieces(-.015),Vector3.ZERO,.016,"riding")
	check(found.is_empty(),"Sustained contact does not repeat")
	var duplicate = pieces(-.3); duplicate.append(duplicate[0].duplicate())
	observer.reset(); observer.sample(duplicate,Vector3.ZERO,.016,"riding")
	duplicate = pieces(.3); duplicate.append(duplicate[0].duplicate())
	check(observer.sample(duplicate,Vector3.ZERO,.033,"riding").size()==1,"Multiple surfaces on the same equipment pair coalesce")
	var invalid = pieces(0); invalid[0].a.x = NAN
	check(observer.sample(invalid,Vector3.ZERO,.016,"riding").is_empty() and observer.previous.is_empty(),"Invalid pose cannot poison observer history")
	var source = preload("res://scripts/presentation/procedural_sfx.gd").new()
	root.add_child(source)
	source.pending_equipment = Events._equipment(0,5,0,1)
	source.silence()
	check(source.pending_equipment.is_empty() and source.equipment_contacts.previous.is_empty(),"Mute/reset discards pending rattles and contacts")
	source._queue_equipment(Events._equipment(0,12,0,1))
	source._queue_equipment(Events._equipment(2,3,.5,.3))
	check(source.pending_equipment.profile==2,"Actual metal contact wins over same-jolt load rattling")
	source.stop_audio();source.queue_free()
	await process_frame
	var report = {"checks":checks,"failures":failures,"observer_max_us":observer.max_update_us,"sweep_exhausted":observer.sweep_exhausted}
	DirAccess.make_dir_recursive_absolute("res://artifacts/natural_audio")
	preload("res://tests/test_report.gd").write("res://artifacts/natural_audio/equipment_suite.json",JSON.stringify(report,"\t"))
	print("EQUIPMENT_AUDIO_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
