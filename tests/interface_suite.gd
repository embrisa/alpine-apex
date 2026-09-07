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

func _initialize() -> void: call_deferred("run")

func check(value: bool, caption: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ",caption)
	if not value: failures.append(caption)

func run() -> void:
	rendered = DisplayServer.get_name() != "headless"
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
	game.automated = false
	game.active = false
	game.set_physics_process(false)
	game.session.eligible = false
	game.effects.muted = true
	game.hud.feedback.muted = true
	game.hud.feedback.persist = false
	await settle()
	check(game.hud.menu_tabs.get_tab_count()==3,"Main menu separates Ride, Explore and Tools")
	check(game.hud.settings_tabs.get_tab_count()==5,"Settings separate display, weather, rider, interface and controls")
	check(game.hud.tuning_tabs.get_tab_count()==4,"Workbench separates handling, forces, camera and speed lab")
	if game.staged_loading:
		check(startup_frames>8 and startup_stages.size()>5,"Real staged startup draws between terrain sections and reports scenery stages")
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
	game.set_audio_muted(true)
	check(game.effects.muted and game.hud.feedback.muted and game.hud.audio_toggle.button_pressed,"Mute includes skiing audio, interface cues and checkbox state")
	game.set_audio_muted(false)
	game.set_motion_effects(false)
	check(not game.hud.feedback.muted and not game.hud.motion_toggle.button_pressed,"Mute and motion controls stay synchronized")
	game.hud.feedback.reduced_motion = true
	game.hud.feedback.reveal(game.hud.weather_panel)
	check(is_equal_approx(game.hud.weather_panel.modulate.a,1.0),"Reduced motion shows panels immediately")
	game.hud.close_weather()
	await settle()
	check(game.hud.menu.visible and game.hud.weather_button.has_focus(),"Back restores the Tools tab and settings-button focus")
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
	race.finish = Vector3(0,other_field.sample(0,240).height,240)
	game.workshop.code_input.text = race.share_text()
	game.workshop.import_from_ui()
	check(game.loading.busy,"Importing a shared race opens loading feedback before reconstruction")
	while game.loading.busy: await process_frame
	check(game.workshop.selected != null and game.workshop.selected.identity()==race.identity(),"Shared race import validates its own terrain and saves to the isolated library")
	game.workshop.code_input.text = "invalid race code"
	await game.workshop.import_from_ui()
	check(not game.loading.busy and game.workshop.races.size()==1,"Invalid race code releases control without changing saved races")
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
	game.active = false
	game.hud.show_menu("paused")
	# Do one real worker generation and observe its busy lifecycle.
	var library = game.mountain_library
	library.store.directory = "user://interface_suite_%d" % Time.get_ticks_usec()
	library.open()
	check(library.busy and game.loading.busy,"Mountain generation immediately opens the loading overlay")
	check(library.all_buttons.all(func(button): return button.disabled),"Generation disables every library action")
	await capture("generation")
	while library.busy: await process_frame
	await settle()
	check(library.draft != null and not game.loading.busy,"Generation completes with a preview and releases the modal")
	check(library.draft.generator_version==4,"Ordinary generation retains version 4")
	for i in library.tabs.get_tab_count():
		library.tabs.current_tab = i
		await capture("mountains_%d" % i)
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
	game.set_physics_process(false)
	game.active = false
	game.effects.muted = true
	game.hud.feedback.muted = true
	check(game.current_mountain.identity()==mountain_id and game.world.terrain_triangles==4718592,"Staged mountain load retains the exact v4 terrain and all 576 sections")
	check(not game.camera.effects_enabled and not game.timed and not game.session.eligible,"Scene transition retains motion preference and keeps generated skiing unranked")
	game.hud.show_menu("paused")
	await capture("loaded_mountain")
	if rendered:
		for dimensions in [Vector2i(1280,720),Vector2i(3840,2160)]:
			root.mode = Window.MODE_WINDOWED
			root.size = dimensions
			await settle()
			game.hud.open_settings()
			game.hud.settings_tabs.current_tab = 0
			await capture("display_%dx%d" % [dimensions.x,dimensions.y])
			if dimensions.x==3840: await measure_interface()
			game.hud.close_weather()
	var data = {"checks":checks,"failures":failures,"captures":captures,"staged_startup_frames":startup_frames,"startup_stages":startup_stages,"rendered":rendered,"engine":Engine.get_version_info().string,"interface_performance":performance_report}
	var file = FileAccess.open("res://artifacts/ui_refresh/interface_%s.json" % ("native" if rendered else "headless"),FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t"))
	print("INTERFACE_RESULTS ",JSON.stringify(data))
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func settle() -> void:
	for i in 5: await process_frame
	if rendered: await create_timer(0.2).timeout

func capture(label: String) -> void:
	await settle()
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
	performance_report = {"scope":"Settings window over a paused v4 summit; not a skiing benchmark; other editor/test processes may be running","device":RenderingServer.get_video_adapter_name(),"quality":game.graphics.label(),"display":game.display_settings.report(root,Vector2i(3840,2160)),"frame_ms":game._timing_summary(frames),"render_cpu_ms":game._timing_summary(cpu),"gpu_ms":game._timing_summary(gpu),"video_memory_bytes":memory,"static_memory_bytes":OS.get_static_memory_usage(),"warmup_frames":120,"capture_overhead_included":false}
