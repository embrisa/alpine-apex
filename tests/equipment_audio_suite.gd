extends SceneTree
const Contacts = preload("res://scripts/presentation/equipment_audio_contacts.gd")
const Events = preload("res://scripts/presentation/riding_audio_events.gd")
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
func run() -> void:
	var observer = Contacts.new()
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
	FileAccess.open("res://artifacts/natural_audio/equipment_suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("EQUIPMENT_AUDIO_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
