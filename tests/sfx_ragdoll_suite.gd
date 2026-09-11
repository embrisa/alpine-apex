extends SceneTree
const Contacts = preload("res://scripts/presentation/crash_audio_contacts.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
var failures: Array[String]=[]
var checks=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)
func run() -> void:
	var floor_body=StaticBody3D.new()
	floor_body.collision_layer=8;floor_body.collision_mask=16
	floor_body.set_meta("audio_material",0)
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(200,1,200);shape.shape=box
	floor_body.add_child(shape);root.add_child(floor_body);floor_body.position.y=-.5
	var skier=preload("res://scripts/presentation/skier_visual.gd").new()
	root.add_child(skier)
	await process_frame
	var sim=Simulation.new()
	var plane=preload("res://tests/physics_suite.gd").TestPlane.new(0)
	sim.reset(Vector3(0,3,0));sim.prime_contacts(plane);sim.grounded=false
	sim.velocity=Vector3(0,-4,12)
	sim.crash("AUDIO TEST")
	skier.ragdoll.start(sim)
	var sampler=Contacts.new()
	var total_events=0;var max_reports=0;var slide_seen=false;var contact_height_valid=false
	for i in 360:
		await physics_frame
		var found=sampler.sample(skier.ragdoll,plane,null,1.0/120)
		total_events+=found.size()
		max_reports=maxi(max_reports,sampler.reports_read)
		slide_seen=slide_seen or sampler.slide.intensity>0
		for bone in skier.ragdoll.bodies.values():
			for j in range(bone.contact_count):
				if absf(bone.positions[j].y)<.25: contact_height_valid=true
	check(total_events>0,"Actual Jolt ragdoll contacts generate impacts")
	check(slide_seen,"Actual tangential contact generates sliding telemetry")
	check(max_reports>0 and max_reports<=60,"Fifteen bones report at most sixty contacts")
	check(contact_height_valid,"Reported contact positions agree with world-space floor height")
	var stored_velocity=skier.ragdoll.bodies.Hips.linear_velocity
	sampler.sample(skier.ragdoll,plane,null,1.0/120)
	check(skier.ragdoll.bodies.Hips.linear_velocity==stored_velocity,"Contact observation does not modify body velocity")
	skier.ragdoll.set_frozen(true)
	sampler.reset()
	skier.ragdoll.stop()
	check(skier.ragdoll.bodies.Hips.contact_count==0,"Stopping ragdoll clears stale contacts")
	skier.queue_free();floor_body.queue_free()
	await process_frame
	var report={"checks":checks,"failures":failures,"events":total_events,"max_reports":max_reports,"contact_max_us":sampler.max_update_us,"capture_max_bone_us":sampler.capture_max_bone_us,"capture_sum_max_us":sampler.capture_sum_max_us}
	DirAccess.make_dir_recursive_absolute("res://artifacts/sfx")
	FileAccess.open("res://artifacts/sfx/ragdoll_suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SFX_RAGDOLL_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
