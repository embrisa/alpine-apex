extends SceneTree
const Maps = preload("res://scripts/diagnostics/test_map.gd")
const Probe = preload("res://tests/small_landing_probe.gd")
const Evidence = preload("res://scripts/diagnostics/scenario_evidence.gd")
var checks = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)

func run() -> void:
	for id in Maps.catalog(false):
		var a=Maps.create(id); var b=Maps.create(id)
		check(a.heights==b.heights and a.obstacles==b.obstacles and a.fixture_identity==b.fixture_identity,id+": deterministic data and identity")
		check(a.CELL==4 and a.heights.size()==a.NX*a.NZ and a.heights.size()<=8385,id+": bounded authoritative 4 m grid")
		check(a.obstacles.size()==(18 if id=="obstacle-patch" else 0),id+": exact explicit object population")
		var exact=true
		for z in range(0,a.NZ-1,7):
			for x in range(0,a.NX-1,7):
				var p: Vector3 = a.vertex(x,z)*.2+a.vertex(x+1,z)*.3+a.vertex(x,z+1)*.5
				exact=exact and absf(p.y-a.sample(p.x,p.z).height)<.0001
		check(exact,id+": rendered triangle and support heights match")
		check(a.ski_bounds().has_point(Vector2(0,a.finish_z)),id+": finish lies within usable terrain")
	var obstacles=Maps.create("obstacle-patch")
	for index in [0,11]:
		var ob=obstacles.obstacles[index]
		var start: Vector3=ob.position+Vector3(-8,.5,0)
		var end: Vector3=ob.position+Vector3(8,.5,0)
		check(not obstacles.sweep_obstacle(start,end).is_empty(),"Explicit obstacle catches a continuous sweep: %d"%index)
		check(obstacles.sweep_obstacle(start+Vector3.UP*30,end+Vector3.UP*30).is_empty(),"Clear flight passes above obstacle: %d"%index)
	check(Maps.create("terrain-transitions",{"transition":"crest"}).heights!=Maps.create("terrain-transitions",{"transition":"compression"}).heights,"Transition variants have distinct physical geometry")
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/diagnostics/scenarios.json"))
	for id in ["small-hop","rough-snow","steady-carve"]:
		var spec=catalog.scenarios[id]
		var old_field=Probe.surface(spec.fixture); var compact=Maps.create(spec.map,spec.fixture)
		var old_sim=Probe.rider(old_field,spec.fixture); var sim=Probe.rider(compact,spec.fixture)
		var matched=true
		for tick in roundi(spec.seconds*120):
			old_sim.step(Probe.DT,Probe.input(tick,spec.fixture),old_field)
			sim.step(Probe.DT,Probe.input(tick,spec.fixture),compact)
			matched=matched and Evidence.Recorder.state(old_sim)==Evidence.Recorder.state(sim)
		check(matched,id+": compact map preserves every original scenario tick")
	var course=Maps.create("short-course")
	var race_type=preload("res://scripts/racing/race_definition.gd")
	var race=race_type.new()
	race.title="Compact course"; race.mountain=Maps.to_reference(course,course.seed_value)
	race.start=Vector3(0,course.sample(0,0).height,0)
	race.finish=Vector3(0,course.sample(0,200).height,200)
	var decoded=race_type.decode(race.share_text())
	check(decoded.has("race") and decoded.race.validate_surface(course).is_empty(),"Compact race codec retains explicit fixture identity and valid gates")
	var restored=race_type.reconstruct_surface(race.mountain)
	check(restored.has("field") and restored.field.heights==course.heights,"Compact race reconstructs only its declared fixture")
	var bad_reference=race.mountain.duplicate(true); bad_reference.options={"gradient":"bad"}
	check(not Maps.valid_reference(bad_reference),"Malformed fixture options are rejected before reconstruction")
	var rider=Probe.rider(course,{"kmh":60.0})
	var session=preload("res://scripts/core/run_session.gd").new()
	session.course_id=course.fixture_identity; session.finish_z=course.finish_z; session.eligible=false
	for tick in 3600:
		var before: Vector3=rider.position
		rider.step(Probe.DT,Probe.input(tick,{"hop":false}),course)
		if session.step(Probe.DT,before,rider.position,rider) or rider.crashed: break
	check(session.finished and not rider.crashed and session.elapsed<30,"Short course finishes under ordinary solver input within 30 seconds")
	check(not session.eligible and not session.new_best and session.recording==null,"Short course never records personal bests")
	if DisplayServer.get_name()!="headless": await capture_scene()
	print("TARGETED_MAP_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func capture_scene() -> void:
	root.size=Vector2i(1280,720)
	set_meta("test_map_fixture","smooth-slope")
	var game=load("res://main.tscn").instantiate()
	game.automated=true; root.add_child(game); current_scene=game
	while not game.initialized: await process_frame
	game.benchmark_no_captures=true
	game.effects.haptic_hardware_enabled=false
	game.set_audio_muted(true)
	game.automated=false; game.start_speed_lab(60)
	game.set_physics_process(false)
	for tick in 120:
		game._physics_process(1.0/120.0)
		if tick%4==0: await process_frame
	check(game.world.backdrop==null and game.world.wilderness==null and game.world.scenery.scrub_candidates.is_empty(),"Compact production scene constructs no distant scenery or scrub")
	check(game.world.scenery.powder_caps==null and game.world.scenery.contact_snow==null and game.world.scenery.tree_motion.definitions.is_empty(),"Empty fixtures skip unrelated scenery asset preparation")
	check(not game.session.eligible and game.session.benchmark_path.contains("targeted_tests"),"Rendered fixture isolates records and remains unranked")
	game._process(.016)
	await process_frame; await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/targeted_maps/rendered")
	check(root.get_texture().get_image().save_png("res://artifacts/targeted_maps/rendered/production-scene.png")==OK,"Production fixture screenshot saved")
	game.active=false; game.effects.stop_audio(); game.queue_free(); await process_frame
