extends SceneTree
## Native settings signals and screenshots; isolated lab, no personal preferences.
const OUTPUT="res://artifacts/foliage_v3/sight_size_settings"
var game
var failures=[]
func _initialize() -> void: call_deferred("run")
func present(frames: int = 30) -> void:
	for frame in frames:
		game._process(1.0/60)
		await process_frame
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	set_meta("test_lab_fixture",true)
	game=load("res://main.tscn").instantiate(); game.automated=true
	root.add_child(game); current_scene=game
	while not game.initialized: await process_frame
	game.set_physics_process(false); game.set_process(false)
	game.display_settings.frame_generation=false; game.display_settings.fps_limit=60
	game.display_settings.apply_display(root,Vector2i(3840,2160)); game.display_settings.apply_viewport(root)
	game.start_run(false); game.summit_ready=false; game.session.eligible=false
	game.automated=false; game.active=false
	if game.preferences_enabled: failures.append("Personal preferences enabled")
	game.hud.show_menu("paused"); game.hud.open_settings()
	_select_tab(game.hud.settings_tabs,"Camera")
	await present()
	game.hud.camera_options.groups["Forest visibility · both views"].button.button_pressed=true
	var page=game.hud.settings_tabs.get_current_tab_control() as ScrollContainer
	await present(5)
	page.ensure_control_visible(game.hud.camera_options.controls.forest_visibility_size)
	await present(5); await capture("defaults")
	var slider: HSlider=game.hud.camera_options.controls.forest_visibility_size
	slider.value=100; await present(5); await capture("full_screen")
	slider.value=50
	slider.grab_focus(); await present(5)
	var event=InputEventKey.new(); event.keycode=KEY_RIGHT; event.pressed=true
	Input.parse_input_event(event); await present(3)
	event.pressed=false; Input.parse_input_event(event)
	if game.camera_settings.shared.forest_visibility_size!=51: failures.append("Keyboard size adjustment failed")
	var pad=InputEventJoypadButton.new(); pad.button_index=JOY_BUTTON_DPAD_LEFT; pad.pressed=true
	Input.parse_input_event(pad); await present(3)
	pad.pressed=false; Input.parse_input_event(pad)
	if game.camera_settings.shared.forest_visibility_size!=50: failures.append("Gamepad event size adjustment failed")
	if game.camera_settings.shared.forest_visibility!=60: failures.append("Size changed reach")
	if not page.get_global_rect().encloses(slider.get_global_rect()): failures.append("Size slider is clipped")
	await present(5); await capture("size_50")
	game.hud.close_weather(); game.hud.hide_menu(); game.active=true; game.camera.reset()
	for close in [true,false]:
		game.camera.close_view=close
		await present(90)
		if not is_equal_approx(game.world.assets.foliage_sight.window.z,.25): failures.append("Size did not reach riding camera")
		game.set_camera_setting("shared","forest_visibility",100)
		await present(30)
		if not is_equal_approx(game.world.assets.foliage_sight.window.z,.25): failures.append("Reach resized riding opening")
		game.set_camera_setting("shared","forest_visibility",60)
	game.active=false; game.hud.show_menu("paused"); game.hud.open_settings()
	game.hud.camera_options.reset_all.pressed.emit()
	_select_tab(game.hud.settings_tabs,"Camera")
	await present(30); page.ensure_control_visible(slider)
	await present(5); await capture("reset")
	if game.camera_settings.shared.forest_visibility_size!=88 or game.camera_settings.shared.forest_visibility!=60: failures.append("Reset failed")
	FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"settings":game.camera_settings.snapshot(),"preferences_written":game.preferences_enabled,"hardware_input_verified":false,"actual_pixels":root.get_texture().get_image().get_size()},"\t"))
	print("SIGHT_SETTINGS_REVIEW ",JSON.stringify({"failures":failures}))
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func _select_tab(tabs: TabContainer, caption: String) -> void:
	for index in tabs.get_tab_count():
		if tabs.get_tab_title(index)==caption:
			tabs.current_tab = index
			return
	assert(false,"Missing tab: "+caption)
