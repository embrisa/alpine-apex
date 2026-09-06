extends SceneTree
const Race = preload("res://scripts/racing/race_definition.gd")
const Store = preload("res://scripts/racing/race_store.gd")
const Session = preload("res://scripts/core/run_session.gd")
var checks: int = 0
var failures: Array = []
var game
var test_dir: String
var captures: Array = []
var metrics: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ",label)
	else: print("PASS: ",label)

func point(field, x: float, z: float) -> Vector3:
	return Vector3(x,field.sample(x,z).height,z)

func fixture(field, seed_value: int):
	var race = Race.new()
	race.title = "Ravine Rush"
	race.mountain = Race.mountain_reference(field,seed_value)
	race.start = point(field,0,25)
	race.finish = point(field,0,240)
	return race

func run() -> void:
	test_dir = "user://race_test_%d" % OS.get_process_id()
	var benchmark_before = FileAccess.get_file_as_string("user://benchmark_v1.json") if FileAccess.file_exists("user://benchmark_v1.json") else ""
	var field = Race.Terrain.new()
	var race = fixture(field,849209361)
	_contract_checks(race,field)
	_timing_checks(race)
	root.size = Vector2i(1440,900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.effects.muted = true
	game.set_graphics_quality(0)
	await process_frame
	game.workshop.store.directory = test_dir.path_join("library")
	var workshop = game.workshop
	workshop.open_library()
	check(not game.active and workshop.panel.visible and workshop.survey.current,"Race library pauses skiing and enters the world survey")
	workshop.begin_creation()
	check(workshop.mode=="create" and workshop.save_button.disabled,"Create mode requires endpoints and a name")
	var original_position: Vector3 = game.sim.position
	var original_elapsed: float = game.session.elapsed
	workshop.focus_point = point(field,0,150)
	workshop.survey_height = 300
	workshop._update_survey()
	var start_screen: Vector2 = workshop.survey.unproject_position(race.start)
	var finish_screen: Vector2 = workshop.survey.unproject_position(race.finish)
	var pick_start = Time.get_ticks_usec()
	for i in range(100): workshop.pick_snow(start_screen)
	metrics.snow_pick_mean_us = float(Time.get_ticks_usec()-pick_start)/100.0
	var hit = workshop.pick_snow(start_screen)
	check(hit is Vector3 and hit.distance_to(race.start)<0.05,"Survey mouse ray picks the same triangulated snow used by physics")
	click(start_screen)
	click(finish_screen)
	workshop.name_input.text = "Ravine Rush"
	workshop._refresh_draft()
	check(workshop.has_start and workshop.has_finish and not workshop.save_button.disabled,"World clicks place start and finish without checkpoints")
	check(game.sim.position==original_position and game.session.elapsed==original_elapsed,"Surveying leaves rider state and the clock frozen")
	await capture("create")
	check(root.get_visible_rect().encloses(workshop.panel.get_global_rect()),"Creator panel fits inside the viewport")
	workshop.save_draft()
	check(workshop.mode=="library" and workshop.races.size()==1,"Save returns a persistent, immediately raceable entry")
	var saved = workshop.selected
	var fresh_store = Store.new()
	fresh_store.directory = workshop.store.directory
	check(fresh_store.load_all().size()==1 and fresh_store.load_all()[0].identity()==saved.identity(),"A fresh library instance loads the exact saved race")
	await capture("saved")
	check(root.get_visible_rect().encloses(workshop.panel.get_global_rect()),"Saved/shared race controls fit inside the viewport")
	var code: String = saved.share_text()
	if DisplayServer.get_name()!="headless":
		var previous_clipboard = DisplayServer.clipboard_get()
		workshop.copy_selected()
		check(DisplayServer.clipboard_get()==code,"Copy to share places the complete mountain and race on the clipboard")
		DisplayServer.clipboard_set(previous_clipboard)
	workshop.store.directory = test_dir.path_join("recipient")
	check(workshop.import_text(code) and workshop.races.size()==1,"A recipient can paste, validate and save a shared race")
	check(workshop.import_text(code) and workshop.races.size()==1,"Importing the same race twice does not duplicate it")
	check(not workshop.import_text('{"race":false}') and workshop.races.size()==1,"Invalid imports leave the saved library intact")
	workshop.play_selected()
	game.session.eligible = false
	check(game.active and game.timed and game.session.race!=null and game.sim.position.distance_to(saved.start)<0.01,"Race it spawns at the authored start with a reset clock")
	check(not workshop.panel.visible and game.camera.current and game.world.benchmark_markers.all(func(m): return not m.visible),"Custom race restores chase view and hides benchmark corridor markers")
	game.sim.velocity = Vector3.BACK*15
	game.sim.position = point(game.field,0,140)
	game.previous_position = game.sim.position
	for i in range(10): game._process(1.0/60.0)
	await capture("racing")
	game.restart()
	game.session.eligible = false
	check(game.sim.position.distance_to(saved.start)<0.01 and game.sim.velocity.is_zero_approx() and game.session.elapsed==0,"Instant retry returns to this race's own start")
	game.start_speed_lab(120)
	check(not game.session.eligible,"Custom race speed-lab attempts cannot write personal bests")
	game.restart()
	game.session.eligible = false
	for i in range(6000):
		game.intent = RiderInput.new()
		game.intent.tuck = 1.0
		var before: Vector3 = game.sim.position
		game.sim.step(1.0/120.0,game.intent,game.field)
		if game.sim.crashed: break
		if game.session.step(1.0/120.0,before,game.sim.position): break
	check(game.session.finished and not game.sim.crashed,"An authored open-route race can be completed with the real ski solver")
	game.active = false
	game.hud.toast_time = 0.0
	game.hud.show_menu("finished",Session.format_time(game.session.elapsed))
	await capture("finished")
	workshop.open_library()
	workshop.begin_creation()
	workshop.place_point(race.start)
	workshop.back_pressed()
	check(workshop.races.size()==1,"Canceling a partial draft does not save it")
	workshop.back_pressed()
	check(not game.active and game.hud.menu_mode=="finished","Closing the workshop returns to the finished run without resuming it")
	# Rebuild both seeds through the same scene transition used by real imports.
	var other_field = Race.Terrain.new(12981)
	var other = fixture(other_field,78342)
	workshop.open_library()
	check(workshop.import_text(other.share_text()),"Import validates coordinates against the referenced terrain seed")
	var old = game
	workshop.play_selected()
	await scene_changed
	game = current_scene
	game.set_physics_process(false)
	game.session.eligible = false
	game.effects.muted = true
	check(game!=old and game.field.seed_value==12981 and game.world.mountain.seed_value==78342,"Racing an imported mountain reconstructs both terrain and scenery seeds")
	check(game.session.race.identity()==other.identity() and game.sim.position==other.start,"Mountain reload preserves the selected race and spawn")
	game.workshop.open_library()
	game.workshop.benchmark_button.pressed.emit()
	await scene_changed
	game = current_scene
	game.set_physics_process(false)
	game.session.eligible = false
	check(game.field.seed_value==849205174 and game.session.race==null and game.session.course_id=="laboratory-v3-physics-v10-default","Returning to the benchmark restores its original terrain and identity")
	var benchmark_after = FileAccess.get_file_as_string("user://benchmark_v1.json") if FileAccess.file_exists("user://benchmark_v1.json") else ""
	check(benchmark_before==benchmark_after,"Race tests do not change the user's benchmark record")
	game.active = false
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	_cleanup(test_dir)
	var output = {"checks":checks,"failures":failures,"captures":captures,"metrics":metrics}
	FileAccess.open("res://artifacts/race_results%s.json" % ("_rendered" if DisplayServer.get_name()!="headless" else ""),FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("RACE_RESULTS ",JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)

func click(screen: Vector2) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = screen
	game._unhandled_input(event)

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/race_%s.png" % label)
	captures.append(label)

func _contract_checks(race, field) -> void:
	var parsed = Race.decode(race.share_text())
	check(parsed.has("race") and parsed.race.identity()==race.identity(),"Share code round trip preserves the race identity and both seed references")
	check(parsed.race.validate_surface(field).is_empty(),"Endpoint-only race validates without a checkpoints field")
	var changed = Race.decode(race.share_text()).race
	changed.finish = point(field,10,250)
	check(changed.record_identity()!=race.record_identity(),"Changing endpoints creates a different personal-best identity")
	for variant in ["schema","seed","version","engine","nan","bounds","height","near","rules","name","heading"]:
		var data: Dictionary = race.to_data()
		match variant:
			"schema": data.schema = 999
			"seed": data.mountain.seed = 1.5
			"version": data.mountain.version = 99
			"engine": data.mountain.engine = "different-engine"
			"nan": data.race.start[0] = "NaN"
			"bounds": data.race.start[0] = 500.0
			"height": data.race.start[1] += 50.0
			"near": data.race.finish = data.race.start.duplicate()
			"rules": data.race.checkpoints = [[0,0,10]]
			"name": data.race.name = "\nBad name"
			"heading": data.race.heading_rad = true
		var result = Race.decode(JSON.stringify(data,"",true,true))
		check(not result.has("race") or not result.race.validate_surface(field).is_empty(),"Reject invalid/unsupported race: "+variant)
	check(not Race.decode("x".repeat(Race.MAX_BYTES+1)).has("race"),"Import size limit rejects oversized payloads")
	var obstacle: Vector3 = field.obstacles[0].position
	check(not Race.point_error(obstacle,field).is_empty(),"Endpoint validation rejects occupied spawn/finish patches")

func _timing_checks(race) -> void:
	var session = Session.new()
	session.record_directory = test_dir.path_join("records")
	session.configure(race)
	session.eligible = false
	var finish: Vector3 = race.finish
	var timing_start = Time.get_ticks_usec()
	for i in range(10000): session.finish_fraction(finish+Vector3.LEFT*20,finish+Vector3.RIGHT*20)
	metrics.finish_query_mean_us = float(Time.get_ticks_usec()-timing_start)/10000.0
	for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK,Vector3(1,0,1).normalized()]:
		session.reset()
		session.eligible = false
		check(session.step(1.0,finish-direction*20,finish+direction*20) and absf(session.elapsed-0.2)<0.00001,"Swept finish accepts arrival from "+str(direction))
	session.reset()
	session.eligible = false
	check(not session.step(1.0,finish+Vector3(-30,0,13),finish+Vector3(30,0,13)),"Passing outside the finish radius does not complete the race")
	check(not session.step(1.0,finish+Vector3(-30,17,0),finish+Vector3(30,17,0)),"Flying above the finite finish volume does not complete the race")
	session.reset()
	session.eligible = false
	check(session.step(1.0,finish+Vector3.UP*20,finish+Vector3.DOWN*20) and absf(session.elapsed-0.1)<0.00001,"Vertical entry respects the finish height and sub-tick timing")
	check(not session.step(1.0,finish,finish) and absf(session.elapsed-0.1)<0.00001,"Finished race cannot record or advance twice")
	session.reset()
	session.step(1.0,finish+Vector3.LEFT*20,finish+Vector3.RIGHT*20)
	var fresh = Session.new()
	fresh.record_directory = session.record_directory
	fresh.configure(race)
	check(absf(fresh.personal_best-0.2)<0.00001 and fresh.history.size()==1,"Custom race records persist in their isolated course file")
	fresh.reset()
	fresh.eligible = false
	fresh.step(0.1,finish+Vector3.LEFT*20,finish+Vector3.RIGHT*20)
	check(absf(fresh.personal_best-0.2)<0.00001 and fresh.history.size()==1,"Unranked faster runs leave the saved custom best unchanged")

func _cleanup(path: String) -> void:
	for child in DirAccess.get_directories_at(path): _cleanup(path.path_join(child))
	for file in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
