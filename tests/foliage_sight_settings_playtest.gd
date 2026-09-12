extends SceneTree
## Native settings signals and screenshots; isolated lab, no personal preferences.
var output = "res://artifacts/orchestration_20260912/forest/settings_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
var game
var failures=[]
func _initialize() -> void: call_deferred("run")
func present(frames: int = 30) -> void:
	for frame in frames:
		game._process(1.0/60)
		await process_frame
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label+".png")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
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
	page.ensure_control_visible(game.hud.camera_options.controls.forest_visibility_strength)
	await present(5); await capture("defaults")
	var slider: HSlider=game.hud.camera_options.controls.forest_visibility_strength
	slider.value=100; await present(5); await capture("strength_100")
	slider.value=50
	slider.grab_focus(); await present(5)
	var event=InputEventKey.new(); event.keycode=KEY_RIGHT; event.pressed=true
	Input.parse_input_event(event); await present(3)
	event.pressed=false; Input.parse_input_event(event)
	if game.camera_settings.shared.forest_visibility_strength!=51: failures.append("Keyboard strength adjustment failed")
	var pad=InputEventJoypadButton.new(); pad.button_index=JOY_BUTTON_DPAD_LEFT; pad.pressed=true
	Input.parse_input_event(pad); await present(3)
	pad.pressed=false; Input.parse_input_event(pad)
	if game.camera_settings.shared.forest_visibility_strength!=50: failures.append("Gamepad event strength adjustment failed")
	if game.hud.camera_options.controls.has("forest_visibility_size"): failures.append("Removed opening size control remains")
	if game.camera_settings.shared.forest_visibility!=60: failures.append("Strength changed reach")
	if not page.get_global_rect().encloses(slider.get_global_rect()): failures.append("Strength slider is clipped")
	await present(5); await capture("strength_50")
	game.hud.close_weather(); game.hud.hide_menu(); game.active=true; game.camera.reset()
	for close in [true,false]:
		game.camera.close_view=close
		await present(90)
		if not is_equal_approx(game.world.assets.foliage_sight.parameters.w,.5): failures.append("Strength did not reach riding camera")
		game.set_camera_setting("shared","forest_visibility",100)
		await present(30)
		if not is_equal_approx(game.world.assets.foliage_sight.parameters.w,.5): failures.append("Reach changed riding strength")
		game.set_camera_setting("shared","forest_visibility",60)
	game.active=false; game.hud.show_menu("paused"); game.hud.open_settings()
	_select_tab(game.hud.settings_tabs,"Camera")
	await present(100)
	if game.world.assets.foliage_sight.parameters.x!=0: failures.append("Menu foliage did not restore")
	var paused_ticks = game.sim.ticks
	game.set_camera_preview(true)
	await present(100)
	if not game.hud.camera_options.preview_active: failures.append("Preview failed to start")
	for index in 2:
		game.hud.camera_options.view_selector.item_selected.emit(index)
		for strength in [0.0,25.0,50.0,75.0,100.0]:
			game.set_camera_setting("shared","forest_visibility_strength",strength)
			await present(30)
			if game.world.assets.foliage_sight.parameters.w!=strength/100: failures.append("Preview strength did not apply")
			if game.world.assets.foliage_sight.parameters.x!=1: failures.append("Preview aid did not activate")
		await capture("preview_"+str(index))
	if game.sim.ticks!=paused_ticks: failures.append("Preview advanced simulation")
	game.set_camera_preview(false)
	await present(100)
	if game.world.assets.foliage_sight.parameters.x!=0: failures.append("Preview exit did not restore menu foliage")
	game.hud.camera_options.reset_all.pressed.emit()
	_select_tab(game.hud.settings_tabs,"Camera")
	await present(30); page.ensure_control_visible(slider)
	await present(5); await capture("reset")
	if game.camera_settings.shared.forest_visibility_strength!=100 or game.camera_settings.shared.forest_visibility!=60: failures.append("Reset failed")
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"settings":game.camera_settings.snapshot(),"preferences_written":game.preferences_enabled,"hardware_input_verified":false,"actual_pixels":root.get_texture().get_image().get_size(),"output":output},"\t"))
	print("SIGHT_SETTINGS_REVIEW ",JSON.stringify({"failures":failures}))
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func _select_tab(tabs: TabContainer, caption: String) -> void:
	for index in tabs.get_tab_count():
		if tabs.get_tab_title(index)==caption:
			tabs.current_tab = index
			return
	assert(false,"Missing tab: "+caption)
