extends SceneTree
## Production compact-map UI, actual input dispatch, and isolated multi-size captures.
const FocusFixture = preload("res://tests/crash_recovery_focus_fixture.gd")
const DT = 1.0/120.0
var game
var checks = 0
var failures: Array[String] = []
var captures: Array = []
var output: String
var native = false

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ",label)
	if not value: failures.append(label)

func settle(frames: int = 6) -> void:
	for i in frames: await process_frame

func key(code: int) -> void:
	for held in [true,false]:
		var event = InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = held
		Input.parse_input_event(event)
		await process_frame

func pad(code: int) -> void:
	for held in [true,false]:
		var event = InputEventJoypadButton.new()
		event.device = 17
		event.button_index = code
		event.pressed = held
		Input.parse_input_event(event)
		await process_frame

func crash() -> void:
	game.restart()
	game.session.eligible = false
	for i in 30: game._physics_process(DT)
	game.sim.crash("UI recovery fixture")
	game._physics_process(DT)
	game.set_physics_process(false)
	check(game.session.recovering and game.hud.compact_menu.is_crash_actions(),"Crash enters the direct-action view")

func run() -> void:
	set_meta("test_map_fixture","short-course")
	native = DisplayServer.get_name()!="headless"
	output = "res://artifacts/bright_ui/"+("native" if native else "functional")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate()
	var seam = FocusFixture.install(game)
	check(not seam.has("error"),"Controlled focus preserves production notification handling")
	if seam.has("error"): game.free(); quit(1); return
	game.automated = true
	root.add_child(game)
	current_scene = game
	while not game.initialized or game.loading.busy: await process_frame
	game.set_physics_process(false)
	game.automated = false
	game.active = false
	game.crash_fixture_apply_focus(true,"ui-initial-focus")
	game.effects.muted = true
	game.effects.haptic_hardware_enabled = false
	game.hud.feedback.muted = true
	game.hud.feedback.persist = false
	game.session.record_directory = output.path_join("records")
	game.hud.show_menu("title")
	await settle()
	var hud = game.hud
	check(hud.weather_button.get_parent()==hud.compact_menu.bottom and hud.compact_menu.quit_button.get_parent()==hud.compact_menu.bottom,"Settings and Quit Game have dedicated places outside Tools")
	check(hud.compact_menu.tools.find_children("*","Button",false,false).any(func(button): return button.text=="Test Cases"),"Test Cases is placed in Tools")
	check(not hud.footer.visible and not hud.header_logo.visible and hud.menu_edge_shading.all(func(shade): return not shade.visible),"Compact menu leaves the world free of full-screen decoration")
	hud.weather_button.grab_focus()
	await key(KEY_ENTER)
	check(hud.weather_panel.visible and not hud.menu.visible,"Focused Settings confirmation opens Settings without dropping in")
	await key(KEY_ESCAPE)
	await settle()
	check(hud.menu.visible and hud.weather_button.has_focus(),"Back restores the originating card and Settings focus")
	hud.compact_menu.tools_button.pressed.emit()
	await key(KEY_ESCAPE)
	check(hud.menu_tabs.current_tab==0 and not game.active,"Back from Tools returns home without starting skiing")
	game.start_run(false)
	game.active = false
	hud.show_menu("paused")
	var attempt: int = game.session.attempt_id
	await key(KEY_R)
	check(game.active and game.session.attempt_id==attempt+1,"R performs the advertised restart from ordinary pause")
	hud.feedback.emphasize(hud.state_label)
	hud.feedback.reduced_motion = true
	check(hud.feedback.active_emphasis.is_empty() and hud.state_label.scale==Vector2.ONE,"Reduced Motion cancels readout emphasis immediately")
	hud.feedback.reduced_motion = false
	crash()
	await settle()
	check(not hud.compact_menu.header.visible and not hud.compact_menu.bottom.visible and not hud.crash_clock.visible,"Crash displays only the two actions")
	hud.set_input_family("keyboard")
	check(hud.primary.prompt=="Enter" and hud.crash_restart.prompt=="R","Crash keyboard badges use the live action map")
	for family in ["xbox","playstation","gamepad"]:
		hud.set_input_family(family)
		check(hud.primary.prompt==hud.Prompts.binding("begin_run",family) and hud.crash_restart.prompt==hud.Prompts.binding("restart",family),"Crash badges update in place for "+family)
		await capture("device_"+family)
	var time: float = game.session.elapsed
	for i in 12: game._physics_process(DT)
	check(is_equal_approx(game.session.elapsed,time+.1),"Unpaused crash clock still advances")
	await key(KEY_ESCAPE)
	check(game.session.recovery_paused and hud.compact_menu.crash_paused and hud.primary.text=="Return to crash","Escape opens the compact crash-pause card")
	time = game.session.elapsed
	hud.open_settings()
	for i in 12: game._physics_process(DT)
	check(game.session.elapsed==time,"Crash settings retain explicit pause")
	await key(KEY_ESCAPE)
	check(hud.compact_menu.crash_paused and hud.menu.visible,"Back from crash settings returns to the paused card")
	await key(KEY_ESCAPE)
	check(not game.session.recovery_paused and hud.compact_menu.is_crash_actions(),"Back from crash pause restores the two actions")
	game.crash_fixture_apply_focus(false,"ui-focus-out")
	game._physics_process(DT)
	await key(KEY_ENTER)
	check(game.sim.crashed and game.session.elapsed==time,"Focus loss blocks recovery and holds the clock")
	game.crash_fixture_apply_focus(true,"ui-focus-in")
	game._physics_process(DT)
	hud.update_crash_recovery(game.session,"No safe recovery spot")
	attempt = game.session.attempt_id
	await key(KEY_ENTER)
	check(game.sim.crashed and hud.primary.disabled and "No safe recovery spot" in hud.primary.text,"Unavailable Stand Up shows its reason and rejects activation")
	await capture("crash_unavailable")
	await key(KEY_R)
	check(game.active and game.session.attempt_id==attempt+1,"Try again remains available when Stand Up is disabled")
	crash()
	attempt = game.session.attempt_id
	time = game.session.elapsed
	await key(KEY_ENTER)
	check(game.active and not game.sim.crashed and game.session.attempt_id==attempt and game.session.elapsed==time,"Enter stands up within the same attempt and clock")
	check(not game.jump_armed and not game.rider_axes_armed,"Recovery retains held-input neutral gates")
	crash()
	await pad(JOY_BUTTON_A)
	check(game.active and not game.sim.crashed,"Controller south button stands up directly")
	crash()
	attempt = game.session.attempt_id
	await pad(JOY_BUTTON_Y)
	check(game.active and not game.sim.crashed and game.session.attempt_id==attempt+1,"Controller north button retries directly")
	await visual_matrix()
	var result = {"checks":checks,"failures":failures,"captures":captures,"native":native,"fixture":game.field.fixture_descriptor(),"hardware_controller":"pending","performance":"not measured"}
	FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("BRIGHT_UI_RESULTS ",JSON.stringify(result))
	game.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	await settle(10)
	var hud = game.hud
	if hud.menu.visible:
		var safe = Rect2(Vector2.ZERO,hud.root.size)
		check(safe.encloses(hud.menu.get_rect()),label+": menu stays inside the viewport")
		if not hud.compact_menu.is_crash_actions():
			check(hud.menu.size.x<=hud.root.size.x*.36+1 and hud.menu.size.y<=hud.root.size.y*.75+1,label+": card remains compact")
	if not native: return
	await RenderingServer.frame_post_draw
	var snapshot = root.get_texture().get_image()
	snapshot.save_png(output.path_join(label+".png"))
	captures.append({"label":label,"pixels":str(snapshot.get_size())})

func visual_matrix() -> void:
	var hud = game.hud
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(3840,2160),Vector2i(3440,1440)]:
		if native: game.display_settings.apply_display(root,dimensions)
		else: root.size = dimensions
		hud.shell_layout.resize()
		var tag = "%dx%d" % [dimensions.x,dimensions.y]
		game.navigation._select_device(-1)
		game.weather.daylight.set_preset("day")
		game.active = false
		hud.show_menu("title")
		await capture("start_"+tag)
		hud.show_menu("paused")
		await capture("pause_"+tag)
		hud.open_settings()
		hud.settings_tabs.current_tab = 1
		await capture("settings_"+tag)
		if dimensions==Vector2i(1280,720):
			for page in [2,3,4,5,6,7]:
				hud.settings_tabs.current_tab = page
				await capture("settings_page_"+str(page))
			hud.graphics_quality.get_popup().popup()
			await capture("settings_popup")
			hud.graphics_quality.get_popup().hide()
		hud.close_weather()
		crash()
		await capture("crash_"+tag)
		game.toggle_crash_pause()
		await capture("crash_pause_"+tag)
		game.restart()
		for i in 240: game._physics_process(DT)
		await capture("hud_"+tag)
		game.weather.daylight.set_preset("night")
		game.active = false
		hud.show_menu("title")
		hud.feedback.reduced_motion = true
		hud.shell_layout.change("ui_scale",1.4)
		await capture("night_reduced_scaled_"+tag)
		hud.shell_layout.change("ui_scale",1.0)
		hud.feedback.reduced_motion = false
