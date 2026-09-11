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
	DirAccess.make_dir_recursive_absolute("res://artifacts/summit_mountain")
	test_dir = "user://mountain_ui_test_%d" % Time.get_ticks_usec()
	var record_path = "user://benchmark_v1_competition_v2.apexrun"
	var record_before = FileAccess.get_sha256(record_path) if FileAccess.file_exists(record_path) else ""
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await wait_until_ready()
	game.set_physics_process(false)
	game.set_graphics_quality(0)
	game.effects.muted = true
	await process_frame
	check(game.current_mountain!=null and game.field.GENERATOR_VERSION==Definition.CURRENT_VERSION and game.field.seed_value==Definition.DEFAULT_SEED,"Normal startup opens the current default mountain")
	check(not game.active and game.hud.menu.visible and not game.timed and not game.session.eligible,"Default startup waits at the menu with an unranked free-ski session")
	game.hud.primary.pressed.emit()
	check(game.active and game.summit_ready and not game.timed,"Drop In stages summit free skiing on the default mountain")
	game.active = false
	game.hud.show_menu("title")
	await capture("title")
	var library = game.mountain_library
	library.store.directory = test_dir
	await library.open()
	_select_tab(library.tabs,"Create")
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
	var random_seed = library.draft.seed_value
	_select_tab(library.tabs,"Saved")
	await library.load_selected(0)
	check(library.draft_field.height_checksum==initial and library.name_input.text=="Bowl Run","Loading a saved mountain restores terrain and name")
	var path = test_dir.path_join("export.apexmountain")
	check(library.Store.write_file(path,library.draft).is_empty(),"Mountain file exports to a chosen path")
	# Revisit the generated seed through the public control before importing;
	# random selection itself was already exercised above.
	_select_tab(library.tabs,"Create")
	library.seed_input.text = str(random_seed)
	await library.generate_seed()
	await library.import_file(path)
	check(library.draft_field.height_checksum==initial and library.draft.title=="Bowl Run","File import restores the mountain after another seed was selected")
	await library.import_file("res://examples/mountains/849205174.apexmountain")
	check(library.draft_field.height_checksum==initial and not library.status.text.is_empty(),"Old mountain files are rejected and preserve the current draft")
	check(library.preset_control.selected==1,"Standard is the default richness")
	for index in 4:
		library._preset_changed(index)
		check(library.generation_settings()==library.Settings.preset(index),"Preset controls apply all four density factors")
	library.advanced_toggle.button_pressed = true
	check(library.settings_controls.tree_spacing.is_visible_in_tree(),"Expanded generation details expose spacing")
	library.settings_controls.tree_spacing.value = .5
	check(library.preset_control.selected==4 and library.generation_settings().tree_spacing==.5,"Spacing selects Custom independently")
	var precise = library.Settings.preset(); precise.snow_feature_density = 1.01
	library._apply_settings(precise)
	check(library.generation_settings()==precise,"Imported hundredth-precision settings remain editable without rounding")
	library._preset_changed(4)
	check(library.advanced_toggle.button_pressed and library.advanced_panel.visible,"Custom exposes the advanced controls consistently")
	await capture("richness_custom")
	library.advanced_toggle.button_pressed = false
	library._apply_settings(library.Settings.preset())
	var previous_draft = library.draft
	var generate_control = library.all_buttons.filter(func(button): return button.text=="GENERATE SEED")[0]
	for cancellation_stage in ["recipe","preview"]:
		library.seed_input.text = "73810291" if cancellation_stage=="recipe" else "849205174"
		generate_control.pressed.emit()
		while library.busy and (not game.loading.worker_snapshot_active or library.generation_job.snapshot().stage!=cancellation_stage): await process_frame
		var cancel_start = Time.get_ticks_usec(); game.loading.cancel_button.pressed.emit()
		while library.busy: await process_frame
		check(library.draft==previous_draft and library.draft_field.height_checksum==initial and not game.loading.overlay.visible and game.loading.worker==null,"Cancelling "+cancellation_stage+" retains the previous preview and joins the worker")
		check(Time.get_ticks_usec()-cancel_start<2000000,"UI cancellation reaches a bounded checkpoint")
	library.seed_input.text = "849205174"
	await library.generate_seed()
	library.name_input.text = "Bowl Run"
	library.save_draft()
	check(library.saved.size()==1,"Saving the same current recipe updates one entry")
	# Verify the real controls open usable filesystem dialogs, including cancel.
	_select_tab(library.tabs,"Share")
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
	await wait_until_ready()
	game.set_physics_process(false)
	game.session.eligible = false
	check(game.current_mountain!=null and game.field.height_checksum==initial and game.active and not game.timed,"Ski button loads the preview as a free-ski session")
	check(game.graphics.level==0 and game.weather.selected_preset=="snowfall" and game.physics_modified and is_equal_approx(game.sim.tuning.edge_grip,1.9),"Mountain changes preserve graphics, weather and modified tuning")
	check(not game.session.eligible and game.session.reference_replay==null and game.session.course_id.begins_with("free-ski-"),"Generated free skiing cannot use benchmark personal bests or ghosts")
	check(game.world.benchmark_markers.is_empty() and game.world.terrain_triangles>3000000 and game.world.terrain_triangles<4718592,"Generated terrain uses the retained 4 m mesh without a predefined marker corridor")
	check(game.world.mountain.physics_authority=="alpine-drainage-v%d" % Definition.CURRENT_VERSION,"Scenery identifies the generated physical authority")
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
		while game.returning_to_summit: await process_frame
		check(game.summit_ready and game.sim.position==game.field.spawn_point() and not game.session.eligible,"Reaching the base returns to unranked summit free skiing on side "+str(direction))
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
	game.start_run(false)
	check(game.current_mountain!=null and game.field.GENERATOR_VERSION==Definition.CURRENT_VERSION and game.session.race==null and game.summit_ready,"Returning from a race keeps the selected mountain and stages summit free skiing")
	game.play_custom_race(race)
	game.session.eligible = false
	check(game.field.height_checksum==initial and game.session.race.identity()==race.identity(),"Shared race uses the selected v11 terrain")
	var showcase_library = game.mountain_library
	showcase_library.store.directory = test_dir
	await showcase_library.open()
	_select_tab(showcase_library.tabs,"Create")
	var showcase_buttons = showcase_library.panel.find_children("*","Button",true,false).filter(func(button): return button.text.to_upper()=="DEFAULT MOUNTAIN")
	check(showcase_buttons.size()==1,"The library exposes one Default Mountain entry")
	showcase_buttons[0].pressed.emit()
	while showcase_library.busy: await process_frame
	check(showcase_library.draft.generator_version==Definition.CURRENT_VERSION and showcase_library.name_input.text=="Default Mountain" and "six alpine faces" in showcase_library.summary.text.to_lower(),"Default button generates the named all-face mountain")
	var showcase_hash = showcase_library.draft_field.height_checksum
	showcase_library.seed_input.text = "42 / v6"
	await showcase_library.generate_seed()
	check(showcase_library.draft_field.height_checksum==showcase_hash and "unsupported" in showcase_library.status.text,"Unsupported showcase seeds preserve the active preview")
	var showcase_export = test_dir.path_join("showcase.apexmountain")
	check(showcase_library.Store.write_file(showcase_export,showcase_library.draft).is_empty(),"Showcase exports through the existing portable recipe contract")
	await showcase_library.import_file(showcase_export)
	check(showcase_library.draft_field.height_checksum==showcase_hash,"Showcase imports and saves without changing its physical identity")
	showcase_library.ski_selected()
	await scene_changed
	game = current_scene
	await wait_until_ready()
	game.set_physics_process(false)
	check(game.field.GENERATOR_VERSION==Definition.CURRENT_VERSION and game.summit_ready and not game.session.eligible,"Showcase loads at the original summit as unranked free skiing")
	check(game.world.scenery.obstacle_count==game.field.tree_data.size(),"Showcase renderer includes every physical obstacle")
	var physical_before = [game.field.height_checksum,game.field.obstacle_checksum,game.field.tree_data.positions.duplicate()]
	for level in [2,1,0]:
		game.set_graphics_quality(level)
		Engine.max_fps = 30
		await process_frame
	check(physical_before==[game.field.height_checksum,game.field.obstacle_checksum,game.field.tree_data.positions],"Showcase quality changes preserve all physical obstacles and terrain")
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
	var used_staged_loading: bool = game.staged_loading
	game.queue_free()
	await process_frame
	_cleanup(test_dir)
	DirAccess.make_dir_recursive_absolute("res://artifacts/summit_mountain")
	var output = {"checks":checks,"failures":failures,"captures":captures,"staged_loading":used_staged_loading,"height_sha256":initial,"obstacle_sha256":physical_before[1]}
	FileAccess.open("res://artifacts/summit_mountain/library_results.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("MOUNTAIN_LIBRARY_RESULTS ",JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)

func wait_until_ready() -> void:
	# The final loading checkpoint still yields after initialized becomes true.
	# Manual physics ticks are correctly ignored until that overlay finishes.
	while not game.initialized or (game.loading and game.loading.busy):
		Engine.max_fps = 30
		await process_frame
	Engine.max_fps = 30
	game.set_physics_process(false)

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

func _select_tab(tabs: TabContainer, caption: String) -> void:
	for index in tabs.get_tab_count():
		if tabs.get_tab_title(index)==caption:
			tabs.current_tab = index
			return
	assert(false,"Missing tab: "+caption)
