extends SceneTree
## UI lifecycle and native screenshots. Isolated stores; never ranked skiing.
var game
var checks: int = 0
var failures: Array[String] = []
var captures: Array = []
var startup_stages: Array = []
var startup_frames: int = 0
var rendered: bool = false
var performance_report: Dictionary = {}
var style_comparison: Dictionary = {}
var timing = preload("res://tests/validation_timing.gd").new("interface_suite")

func _initialize() -> void: call_deferred("run")

func check(value: bool, caption: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ",caption)
	if not value: failures.append(caption)

func run() -> void:
	timing.mark("scene_setup")
	set_meta("test_map_fixture","short-course") # Compact production integration fixture.
	rendered = DisplayServer.get_name() != "headless"
	# The custom headless display defaults to 64x64, below any supported UI.
	# Layout assertions still need a real logical viewport; no pixels are drawn.
	if not rendered: root.size = Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute("res://artifacts/ui_refresh")
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	current_scene = game
	while not game.initialized or game.loading.busy:
		startup_frames += 1
		if game.loading:
			for stage in game.loading.stage_history:
				if stage not in startup_stages: startup_stages.append(stage)
		await process_frame
	timing.mark("interface_checks")
	game.automated = false
	game.active = false
	game.set_physics_process(false)
	game.session.eligible = false
	game.effects.muted = true
	game.hud.feedback.muted = true
	game.hud.feedback.persist = false
	await settle()
	check(game.hud.menu_tabs.get_tab_count()==3,"Main menu separates Ride, Explore and Tools")
	check(game.hud.settings_tabs.get_tab_count()==8,"Settings separate Display, Graphics, Camera, Controls, Audio, Interface & HUD, Weather and Rider")
	check(game.hud.settings_tabs.get_node("Audio").is_ancestor_of(game.hud.wind_mode),"Audio tab contains the existing wind controls")
	check(game.hud.camera_options.controls.size()==game.CameraSettings.DEFAULTS.size()+game.CameraSettings.SHARED_DEFAULTS.size() and game.hud.camera_options.reset_all.text=="RESET ALL CAMERA SETTINGS","Camera tab exposes FoV, distances, heights, tilt, stabilization and a complete reset")
	check(game.hud.camera_options.readouts.rest_fov.text=="55°" and game.hud.camera_options.readouts.fast_fov.text=="75°" and game.hud.camera_options.readouts.rest_tilt.text=="-45°" and game.hud.camera_options.readouts.fast_tilt.text=="-45°","Lens and tilt defaults use the grounded Connected preset")
	check(game.hud.camera_options.readouts.rest_height.text=="3.00 m" and game.hud.camera_options.readouts.fast_height.text=="3.50 m" and game.hud.camera_options.readouts.vertical_smoothing.text=="50%","Camera default readouts match the lower stabilized view")
	check(game.hud.tuning_tabs.get_tab_count()==4,"Workbench separates handling, forces, camera and speed lab")
	if game.staged_loading:
		check(startup_frames>0 and not startup_stages.is_empty() and game.field.has_method("fixture_descriptor"),"Targeted staged startup draws and reports its actual terrain construction")
	await capture("menu")
	game.hud.menu_tabs.current_tab = 1
	await capture("explore")
	game.hud.menu_tabs.current_tab = 2
	game.hud.weather_button.pressed.emit()
	await settle()
	check(game.hud.weather_panel.visible and not game.hud.menu.visible,"Settings opens as a dedicated window")
	for i in game.hud.settings_tabs.get_tab_count():
		game.hud.settings_tabs.current_tab = i
		await capture("settings_%d" % i)
		if game.hud.settings_tabs.get_tab_title(i) == "Rider":
			var colors = game.hud.appearance_column.find_children("*","ColorPickerButton",true,false)
			if not colors.is_empty():
				colors[0].get_popup().popup_centered()
				await capture("rider_color_popup")
				colors[0].get_popup().hide()
	game.set_audio_muted(true)
	check(game.effects.muted and game.hud.feedback.muted and game.hud.audio_toggle.button_pressed,"Mute includes skiing audio, interface cues and checkbox state")
	game.set_audio_muted(false)
	game.set_motion_effects(false)
	check(not game.hud.feedback.muted and not game.hud.motion_toggle.button_pressed,"Mute and motion controls stay synchronized")
	check(not game.effects.wind.persist,"Scripted UI tests never write personal wind preferences")
	check(not game.effects.sfx.persist,"Scripted UI tests never write personal riding audio preferences")
	game.hud.riding_audio_settings.controls.mode.item_selected.emit(1)
	game.hud.riding_audio_settings.controls.snow.value=.35
	game.hud.riding_audio_settings.controls.adaptive.button_pressed=false
	check(game.effects.sfx.mode==1 and is_equal_approx(game.effects.sfx.snow,.35) and not game.effects.sfx.adaptive,"Audio controls update the live riding mix")
	game.hud.wind_mode.item_selected.emit(1)
	game.hud.wind_volume.value = 0.4
	check(game.effects.wind.mode==1 and is_equal_approx(game.effects.wind.volume,0.4),"Wind controls update playback independently of interface volume")
	game.set_wind_mode(0)
	game.set_wind_volume(1.0)
	game.hud.feedback.reduced_motion = true
	game.hud.feedback.loading_ambience = false
	game.hud.feedback.volume = 0.35
	check(not game.loading.loading_ambience and game.loading.reduced_motion and game.loading.sound_volume==0.35,"Loading receives live interface sound and motion preferences")
	var wind_toggle = game.hud.weather_panel.find_child("LoadingWindAmbience",true,false)
	check(wind_toggle!=null,"Interface exposes a separate loading wind switch")
	game.hud.feedback.reveal(game.hud.weather_panel)
	check(is_equal_approx(game.hud.weather_panel.modulate.a,1.0),"Reduced motion shows panels immediately")
	game.hud.close_weather()
	await settle()
	check(game.hud.menu.visible and game.hud.weather_button.has_focus(),"Back restores the originating compact menu and settings-button focus")
	game.open_workbench()
	for i in game.hud.tuning_tabs.get_tab_count():
		game.hud.tuning_tabs.current_tab = i
		await capture("workbench_%d" % i)
	game.close_workbench()
	game.open_competition()
	await capture("records")
	game.hud.close_competition()
	game.workshop.store.directory = "user://interface_races_%d" % Time.get_ticks_usec()
	game.workshop.open_library()
	await capture("races_saved")
	game.workshop.library_tabs.current_tab = 1
	await capture("races_import")
	var race = game.Race.new()
	var other_field = game.Race.Terrain.new(12981)
	race.title = "Interface import fixture"
	race.mountain = game.Race.mountain_reference(other_field,78342)
	race.start = Vector3(0,other_field.sample(0,25).height,25)
	# The solid finish gate needs a level clearing across its full width.
	race.finish = Vector3(20,other_field.sample(20,240).height,240)
	check(race.validate_surface(other_field).is_empty(),"Shared race import fixture has valid gate seating")
	game.workshop.code_input.text = race.share_text()
	game.workshop.import_from_ui()
	check(game.loading.busy,"Importing a shared race opens loading feedback before reconstruction")
	check(not game.loading.loading_ambience and game.loading.reduced_motion,"Shared-race imports retain loading preferences")
	while game.loading.busy: await process_frame
	check(game.workshop.selected != null and game.workshop.selected.identity()==race.identity(),"Shared race import validates its own terrain and saves to the isolated library")
	game.workshop.code_input.text = "invalid race code"
	await game.workshop.import_from_ui()
	check(not game.loading.busy and game.workshop.races.size()==1,"Invalid race code releases control without changing saved races")
	game.workshop.begin_creation()
	check(not game.hud.has_menu_background(),"Race placement exposes the live mountain without menu coverage")
	await capture("race_placement")
	game.workshop.back_pressed()
	check(game.hud.has_menu_background(),"Returning from placement restores the race library context")
	game.workshop.back_pressed()
	# Loading modal holds both simulation and shortcuts, including direct dispatch.
	game.start_run(false)
	game.session.eligible = false
	var time_before: float = game.session.elapsed
	var position_before: Vector3 = game.sim.position
	game.loading.begin("Shaping your mountain", "Generating the summit, ridges and downhill faces…")
	game._physics_process(1.0/120.0)
	var event = InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_R
	game._unhandled_input(event)
	check(game.session.elapsed==time_before and game.sim.position==position_before and game.loading.busy,"Loading blocks simulation and restart input")
	await capture("loading")
	game.loading.finish()
	if rendered: await review_skiing_hud()
	game.active = false
	game.hud.show_menu("paused")
	if full_mountain_checks(): await mountain_checks()
	if rendered:
		for dimensions in [Vector2i(1280,720),Vector2i(3840,2160)]:
			root.mode = Window.MODE_WINDOWED
			root.size = dimensions
			await settle()
			game.hud.open_settings()
			game.hud.settings_tabs.current_tab = 0
			await capture("display_%dx%d" % [dimensions.x,dimensions.y])
			if dimensions.x==3840 and full_mountain_checks():
				await measure_interface()
				await compare_baseline_style()
			game.hud.close_weather()
	var data = {"checks":checks,"failures":failures,"captures":captures,"staged_startup_frames":startup_frames,"startup_stages":startup_stages,"rendered":rendered,"engine":Engine.get_version_info().string,"interface_performance":performance_report,"style_comparison":style_comparison}
	var file = preload("res://tests/test_report.gd").open_write("res://artifacts/ui_refresh/interface_%s.json" % ("native" if rendered else "headless"))
	file.store_string(JSON.stringify(data,"\t"))
	print("INTERFACE_RESULTS ",JSON.stringify(data))
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	timing.finish()
	quit(0 if failures.is_empty() else 1)

func settle() -> void:
	for i in 5: await process_frame
	if rendered: await create_timer(0.2).timeout

func review_skiing_hud() -> void:
	# Short fixed-input descent in this suite's explicit laboratory; never ranked.
	game.start_speed_lab(90.0)
	game.session.eligible = false
	game.set_process(false)
	var start: Vector3 = game.sim.position
	for frame in 150:
		game.intent = RiderInput.new()
		game.intent.tuck = 0.25
		game.intent.steer = sin(float(frame)/60.0)*0.16
		for tick in 2:
			game.previous_position = game.sim.position
			game.sim.step(1.0/120.0,game.intent,game.world.ski_surface)
			game.skier.step_animation(1.0/120.0,game.sim,game.intent,game.field)
		game._process(1.0/60.0)
		await process_frame
	await capture("skiing_hud")
	check(game.sim.position.distance_to(start)>10.0 and not game.session.eligible,"Rendered HUD review travels downhill in an unranked lab run")
	game.set_process(true)

func capture(label: String) -> void:
	await settle()
	var menu_visible = [game.hud.menu,game.hud.weather_panel,game.hud.tuning_panel,game.hud.competition.panel,game.mountain_library.panel,game.workshop.library].any(func(view): return view.is_visible_in_tree())
	check(game.hud.has_menu_background()==menu_visible,"%s: atmosphere follows menu visibility" % label)
	if menu_visible:
		check(game.hud.root.find_child("TitlePhotography",true,false)==null and (not game.hud.feedback.reduced_motion or not game.hud.menu_fade.visible),"%s: live menu has no photography and respects reduced motion" % label)
	var bounds = root.get_visible_rect()
	for panel in [game.hud.menu,game.hud.weather_panel,game.hud.tuning_panel,game.hud.competition.panel,game.mountain_library.panel,game.workshop.panel]:
		if panel.visible: check(bounds.grow(1.0).encloses(panel.get_global_rect()),"%s: %s stays inside the viewport" % [label,panel.name])
	if not rendered: return
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	image.save_png("res://artifacts/ui_refresh/%s.png" % label)
	captures.append({"label":label,"pixels":[image.get_width(),image.get_height()]})

func measure_interface() -> void:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for i in 120: await process_frame
	var frames: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var previous = Time.get_ticks_usec()
	var memory: int = 0
	for i in 240:
		await process_frame
		var now = Time.get_ticks_usec()
		frames.append((now-previous)/1000.0)
		previous = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		memory = maxi(memory,int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
	performance_report = {"scope":"Settings window over a paused generated mountain; not a skiing benchmark","generator_version":game.current_mountain.generator_version,"device":RenderingServer.get_video_adapter_name(),"quality":game.graphics.label(),"display":game.display_settings.report(root,Vector2i(3840,2160)),"frame_ms":game._timing_summary(frames),"render_cpu_ms":game._timing_summary(cpu),"gpu_ms":game._timing_summary(gpu),"video_memory_bytes":memory,"static_memory_bytes":OS.get_static_memory_usage(),"warmup_frames":120,"capture_overhead_included":false}

func compare_baseline_style() -> void:
	# Optional saved pre-change HUD. Both instances stay resident in both samples.
	var path = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui-baseline-hud="): path = arg.trim_prefix("--ui-baseline-hud=")
	if path.is_empty(): return
	check(ResourceLoader.exists(path),"Saved baseline HUD exists for the requested style comparison")
	if not ResourceLoader.exists(path): return
	var baseline = load(path).new()
	game.add_child(baseline)
	baseline.feedback.muted = true
	baseline.feedback.persist = false
	baseline.feedback.reduced_motion = true
	baseline.set_mountain(game.current_mountain)
	baseline.sync_display(game.display_settings)
	baseline.sync_weather(game.weather)
	baseline.graphics_quality.select(game.graphics.level)
	baseline.show_menu("paused")
	baseline.open_settings()
	game.hud.hide()
	await settle()
	await measure_interface()
	style_comparison.before = performance_report.duplicate(true)
	await capture("style_before_4k")
	baseline.hide()
	game.hud.show()
	await settle()
	await measure_interface()
	style_comparison.after = performance_report.duplicate(true)
	style_comparison.scope = "Same paused mountain, camera and display settings; both HUD instances remain resident; only visible styling changes"
	await capture("style_after_4k")
	baseline.queue_free()
	await settle()

func full_mountain_checks() -> bool: return false

func mountain_checks() -> void:
	# Do one real worker generation and observe its busy lifecycle.
	var library = game.mountain_library
	library.store.directory = "user://interface_suite_%d" % Time.get_ticks_usec()
	library.open()
	check(library.busy and game.loading.busy,"Mountain generation immediately opens the loading overlay")
	check(not game.loading.loading_ambience and game.loading.sound_volume==0.35,"Mountain generation retains loading audio preferences")
	check(library.all_buttons.all(func(button): return button.disabled),"Generation disables every library action")
	await capture("generation")
	while library.busy: await process_frame
	await settle()
	check(library.draft != null and not game.loading.busy,"Generation completes with a preview and releases the modal")
	check(library.draft.generator_version==library.Definition.CURRENT_VERSION,"Ordinary generation selects the current mountain version")
	for i in library.tabs.get_tab_count():
		library.tabs.current_tab = i
		await capture("mountains_%d" % i)
	library.import_dialog.popup_centered_ratio(0.72)
	await capture("mountain_import_dialog")
	library.import_dialog.hide()
	var identity: String = library.draft.identity()
	library.seed_input.text = "bad seed"
	await library.generate_seed()
	check(library.draft.identity()==identity and not library.busy and not game.loading.busy,"Invalid seed preserves the preview and leaves controls usable")
	library.close()
	check(not library.panel.visible and game.hud.menu.visible,"Mountain Back returns to the paused menu")
	var mountain_id: String = library.draft.identity()
	game.load_mountain(library.draft,library.draft_field)
	check(game.transitioning and game.loading.busy,"Loading a generated mountain blocks repeated scene transitions")
	await scene_changed
	game = current_scene
	while not game.initialized or game.loading.busy: await process_frame
	check(not game.loading.loading_ambience and game.loading.reduced_motion and game.loading.sound_volume==0.35,"Scene reload retains loading preferences without writing personal settings")
	check(not game.loading.ambience.playing and game.loading.artwork.texture==null,"Scene completion releases loading art and audio")
	check(game.effects.sfx.mode==1 and is_equal_approx(game.effects.sfx.snow,.35) and not game.effects.sfx.adaptive,"Scene reload preserves riding mode, volume and adaptive mix")
	game.set_physics_process(false)
	game.active = false
	game.effects.muted = true
	game.hud.feedback.muted = true
	check(game.current_mountain.identity()==mountain_id and game.world.terrain_triangles>3000000 and game.world.terrain_triangles<4718592,"Staged mountain load retains exact support and trims unused outer corners")
	check(not game.camera.effects_enabled and not game.timed and not game.session.eligible,"Scene transition retains motion preference and keeps generated skiing unranked")
	game.hud.show_menu("paused")
	await capture("loaded_mountain")
