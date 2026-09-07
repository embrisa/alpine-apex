extends SceneTree
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Race = preload("res://scripts/racing/race_definition.gd")
var game
var failures: Array = []
var checks: int = 0
var captures: Array = []
var test_dir: String
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ",label)
	if not value: failures.append(label)
func run() -> void:
	test_dir = "user://mountain_ui_test_%d" % Time.get_ticks_usec()
	var record_path = "user://benchmark_v1_competition_v2.apexrun"
	var record_before = FileAccess.get_sha256(record_path) if FileAccess.file_exists(record_path) else ""
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.set_graphics_quality(0)
	game.effects.muted = true
	await process_frame
	await capture("title")
	var library = game.mountain_library
	library.store.directory = test_dir
	await library.open()
	check(library.panel.visible and not game.active and library.draft!=null,"Mountain library opens paused with a generated preview")
	check(library.draft.seed_value==849205174 and library.draft_field.GENERATOR_ID=="alpine-drainage","Example seed generates physical terrain")
	await capture("library")
	library.seed_input.text = "no seed"
	await library.generate_seed()
	check(library.draft.seed_value==849205174 and "whole seed" in library.status.text,"Invalid seed preserves the working preview with a readable error")
	var initial = library.draft_field.height_checksum
	library.seed_input.text = "Mountain Seed: 849205174"
	await library.generate_seed()
	check(library.draft_field.height_checksum==initial,"Pasted share seed reconstructs the same mountain")
	library.name_input.text = "Bowl Run"
	library.save_draft()
	check(library.saved.size()==1 and library.saved[0].title=="Bowl Run","Naming and saving through UI stores the local mountain")
	await library.generate_random()
	check(library.draft_field.height_checksum!=initial,"Random mountain changes the physical preview")
	await library.load_selected(0)
	check(library.draft_field.height_checksum==initial and library.name_input.text=="Bowl Run","Loading a saved mountain restores terrain and name")
	var path = test_dir.path_join("export.apexmountain")
	check(library.Store.write_file(path,library.draft).is_empty(),"Mountain file exports to a chosen path")
	await library.generate_random()
	await library.import_file(path)
	check(library.draft_field.height_checksum==initial and library.draft.title=="Bowl Run","File import restores the mountain after another seed was selected")
	await library.import_file("res://examples/mountains/849205174.apexmountain")
	check(library.draft.generator_version==1 and library.draft_field.GENERATOR_VERSION==1 and "v1" in library.summary.text,"Old mountain files select the archived generator and display their actual version")
	var legacy_hash = library.draft_field.height_checksum
	library.seed_input.text = library.draft.seed_text()
	await library.generate_seed()
	check(library.draft_field.height_checksum==legacy_hash,"A shared versioned v1 seed reconstructs the old mountain through the UI")
	library.seed_input.text = "849205174"
	await library.generate_seed()
	check(library.draft_field.height_checksum==initial and library.draft.generator_version==4,"Re-entering a bare seed selects the new larger generator")
	library.name_input.text = "Bowl Run"
	library.save_draft()
	check(library.saved.size()==2,"Old and new versions of the same seed coexist in the local library")
	# Verify the real controls open usable filesystem dialogs, including cancel.
	library.export_file()
	await process_frame
	check(library.export_dialog.visible and library.export_dialog.current_file.ends_with(".apexmountain"),"Export opens a named mountain file dialog")
	await capture("export_dialog")
	library.export_dialog.hide()
	game.weather.set_preset("snowfall")
	game.hud.tuning_sliders["edge_grip"].value = 1.9
	library.ski_selected()
	await scene_changed
	game = current_scene
	game.set_physics_process(false)
	game.session.eligible = false
	check(game.current_mountain!=null and game.field.height_checksum==initial and game.active and not game.timed,"Ski button loads the preview as a free-ski session")
	check(game.graphics.level==0 and game.weather.selected_preset=="snowfall" and game.physics_modified and is_equal_approx(game.sim.tuning.edge_grip,1.9),"Mountain changes preserve graphics, weather and modified tuning")
	check(not game.session.eligible and game.session.reference_replay==null and game.session.course_id.begins_with("free-ski-"),"Generated free skiing cannot use benchmark personal bests or ghosts")
	check(game.world.benchmark_markers.is_empty() and game.world.terrain_triangles==4718592,"Generated terrain uses the expanded 4 m mesh without a predefined marker corridor")
	check(game.world.mountain.physics_authority=="alpine-drainage-v4","Scenery identifies the generated physical authority")
	check(game.summit_ready and game.sim.position==game.field.spawn_point(),"Free skiing stages the player at the true highest summit")
	var height_before = game.sim.position.y
	for i in 120: game._physics_process(1.0/120.0)
	check(game.sim.position==game.field.spawn_point() and game.session.elapsed==0,"The summit waits for a chosen descent without advancing the run")
	# Turn with ordinary input, then use the same drop action as Enter/tuck.
	Input.action_press("steer_right")
	for i in 120: game._physics_process(1.0/120.0)
	Input.action_release("steer_right")
	check(game.summit_ready and game.sim.heading<-.5 and game.sim.position.y==height_before,"Steering at the summit selects an aspect while keeping the player at the top")
	game.drop_from_summit()
	check(not game.summit_ready and Vector2(game.sim.position.x,game.sim.position.z).length()>15 and height_before-game.sim.position.y<4,"Dropping in chooses a nearby summit rim without injecting velocity")
	check(game.sim.velocity==Vector3.ZERO,"Summit launch leaves acceleration entirely to gravity")
	game.sim.reset(Vector3(0,game.field.sample(0,-2000).height,-2000),PI)
	game.sim.prime_contacts(game.field)
	game._physics_process(1.0/120.0)
	check(game.active and not game.session.finished and game.session.progress_percent(game.sim.position)>60,"North-face skiing continues normally and advances radial progress")
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		game.restart()
		game.drop_from_summit()
		var p = direction*(game.field.finish_z+1)
		game.sim.reset(Vector3(p.x,game.field.sample(p.x,p.y).height,p.y),atan2(p.x,p.y))
		game.sim.prime_contacts(game.field)
		game._physics_process(1.0/120.0)
		check(not game.active and game.session.finished,"Reaching the base completes free skiing on side "+str(direction))
	game.restart()
	game.set_physics_process(false)
	game.weather.set_preset("clear")
	game.hud.tuning_sliders["edge_grip"].value = 1.6
	game.physics_modified = false
	game.active = false
	await capture("summit")
	# Use the existing survey camera for visual inspection, with the true surface.
	game.workshop.open_library()
	game.workshop.panel.hide()
	game.workshop.focus_point = Vector3(0,0,600)
	game.workshop.survey_height = 900
	game.workshop._update_survey()
	await capture("basins")
	game.workshop.focus_point = Vector3(-2200,0,-1600)
	game.workshop.survey_height = 500
	game.workshop._update_survey()
	check(game.workshop.focus_point.x== -2200 and game.workshop.focus_point.z== -1600,"The survey camera reaches the full north-west mountain")
	var projected = game.workshop.survey.unproject_position(game.workshop.focus_point)
	var picked = game.workshop.pick_snow(projected)
	check(picked is Vector3 and picked.distance_to(game.workshop.focus_point)<.2,"Snow picking works on the remote north-west face")
	await capture("forest")
	game.workshop.close()
	game.hud.show_menu("paused")
	game.restart()
	check(not game.session.eligible and game.sim.position==game.field.spawn_point() and is_equal_approx(game.sim.heading,game.field.spawn_heading()),"Restart on the example seed keeps generated free skiing unranked")
	game.set_physics_process(false)
	var race = Race.new()
	race.title = "Generated basin race"
	race.mountain = Race.mountain_reference(game.field,game.field.seed_value)
	race.start = game.field.launch_point(PI)
	race.heading = PI
	race.finish = Vector3(0,game.field.sample(0,-2810).height,-2810)
	game.workshop.open_library()
	game.workshop.store.directory = test_dir.path_join("races")
	check(game.workshop.import_text(race.share_text()),"Race library imports a race on the generated mountain")
	game.workshop.play_selected()
	game.session.eligible = false
	check(game.timed and game.session.race!=null and game.session.course_id==race.record_identity(),"Generated race starts with its own compatible competitive identity")
	game.active = false
	game.start_run(true)
	await scene_changed
	game = current_scene
	game.set_physics_process(false)
	game.session.eligible = false
	check(game.current_mountain==null and game.field.GENERATOR_ID=="laboratory" and game.field.seed_value==849205174,"Original test face returns to the laboratory even when the generated seed is identical")
	# Import the generated race while another kind of mountain is loaded.
	game.play_custom_race(race)
	await scene_changed
	game = current_scene
	game.set_physics_process(false)
	game.session.eligible = false
	check(game.current_mountain!=null and game.field.height_checksum==initial and game.session.race.identity()==race.identity(),"Shared generated race reloads the correct terrain from the laboratory")
	# The experimental face is opt-in and uses the same owned generation worker.
	var showcase_library = game.mountain_library
	showcase_library.store.directory = test_dir
	await showcase_library.open()
	var showcase_buttons = showcase_library.panel.find_children("*","Button",true,false).filter(func(button): return button.text.begins_with("TECHNICAL SHOWCASE"))
	check(showcase_buttons.size()==1,"The mountain library exposes one Technical Showcase entry")
	showcase_buttons[0].pressed.emit()
	while showcase_library.busy: await process_frame
	check(showcase_library.draft.generator_version==7 and showcase_library.name_input.text=="Technical Showcase" and "south" in showcase_library.summary.text.to_lower(),"Showcase button generates the named south face with clear entry guidance")
	var showcase_hash = showcase_library.draft_field.height_checksum
	showcase_library.seed_input.text = "42 / v6"
	await showcase_library.generate_seed()
	check(showcase_library.draft_field.height_checksum==showcase_hash and "only seed" in showcase_library.status.text,"Unsupported showcase seeds preserve the active preview")
	var showcase_export = test_dir.path_join("showcase.apexmountain")
	check(showcase_library.Store.write_file(showcase_export,showcase_library.draft).is_empty(),"Showcase exports through the existing portable recipe contract")
	await showcase_library.import_file(showcase_export)
	check(showcase_library.draft_field.height_checksum==showcase_hash,"Showcase imports and saves without changing its physical identity")
	showcase_library.ski_selected()
	await scene_changed
	game = current_scene
	game.set_physics_process(false)
	check(game.field.GENERATOR_VERSION==7 and game.summit_ready and not game.session.eligible,"Showcase loads at the original summit as unranked free skiing")
	check(game.world.scenery.obstacle_count==game.field.obstacles.size(),"Showcase renderer includes every physical obstacle")
	var physical_before = [game.field.height_checksum,game.field.obstacle_checksum,game.field.obstacles.duplicate(true)]
	for level in [2,1,0]: game.set_graphics_quality(level)
	check(physical_before==[game.field.height_checksum,game.field.obstacle_checksum,game.field.obstacles],"Showcase quality changes preserve all physical obstacles and terrain")
	check(game.world.snow_material.get_shader_parameter("use_feature_exposure")==true,"Localized cliff and snow-gap exposure survives graphics changes")
	game.drop_from_summit()
	game.restart()
	check(game.summit_ready and game.sim.position==game.field.spawn_point(),"Showcase retry returns to the true summit")
	var showcase_race = Race.new()
	showcase_race.title = "Technical face test"
	showcase_race.mountain = Definition.from_field(game.field).to_reference()
	showcase_race.start = game.field.launch_point(0)
	showcase_race.finish = Vector3(0,game.field.sample(0,2810).height,2810)
	check(showcase_race.validate_surface(game.field).is_empty() and Race.decode(showcase_race.share_text()).has("race"),"Open-route races accept and share the showcase reference")
	var record_after = FileAccess.get_sha256(record_path) if FileAccess.file_exists(record_path) else ""
	check(record_before==record_after,"Tests leave personal bests untouched")
	game.active = false
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	_cleanup(test_dir)
	DirAccess.make_dir_recursive_absolute("res://artifacts/summit_mountain")
	var output = {"checks":checks,"failures":failures,"captures":captures}
	FileAccess.open("res://artifacts/summit_mountain/library_results.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("MOUNTAIN_LIBRARY_RESULTS ",JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	var path = "res://artifacts/summit_mountain/%s.png" % label
	get_root().get_texture().get_image().save_png(path)
	captures.append(path)

func _cleanup(path: String) -> void:
	for child in DirAccess.get_directories_at(path): _cleanup(path.path_join(child))
	for file in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
