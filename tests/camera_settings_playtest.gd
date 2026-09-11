extends "res://tests/camera_playtest.gd"
## Native camera settings review, using isolated presentation preferences.
func inspect_massif() -> void:
	game.set_process(false)
	fixture(820,0)
	await present(0.5)
	game.active = false
	game.automated = false
	game.hud.show_menu("paused")
	game.hud.open_settings()
	for i in game.hud.settings_tabs.get_tab_count():
		if game.hud.settings_tabs.get_tab_title(i) == "Camera": game.hud.settings_tabs.current_tab = i
	var page: ScrollContainer = game.hud.settings_tabs.get_current_tab_control()
	await present(0.2)
	await camera_capture("camera_menu_defaults","native settings menu")
	if game.preferences_enabled: camera_failures.append("Scripted menu review could write personal preferences")
	var eligibility: bool = game.session.eligible
	var custom_lens = {"rest_fov":85.0,"fast_fov":100.0,"chase_pitch_offset":8.0,"first_person_pitch_offset":-5.0}
	for key in custom_lens: game.hud.camera_setting_controls[key].value = custom_lens[key]
	game.hud.camera_setting_controls.rest_distance.value = 4.5
	game.hud.camera_setting_controls.fast_distance.value = 10.0
	game.hud.camera_setting_controls.rest_height.value = 4.0
	game.hud.camera_setting_controls.fast_height.value = 6.5
	game.hud.camera_setting_controls.vertical_smoothing.value = 75.0
	await present(0.5)
	await camera_capture("camera_menu_custom","native settings signals / 4.5 m and 10 m")
	if game.camera_settings.rest_distance != 4.5 or game.camera_settings.fast_distance != 10.0:
		camera_failures.append("Menu controls did not reach the camera")
	if game.camera_settings.rest_height != 4.0 or game.camera_settings.fast_height != 6.5 or game.camera_settings.vertical_smoothing != 75.0:
		camera_failures.append("Height and stabilization menu controls did not reach the camera")
	if game.session.eligible != eligibility: camera_failures.append("Camera settings changed record eligibility")
	for key in custom_lens:
		if game.camera_settings.get(key) != custom_lens[key]: camera_failures.append("Lens/tilt control did not reach the camera: " + key)
	# Exercise native focus-following, keyboard adjustment and gamepad UI events.
	for key in custom_lens:
		var slider: HSlider = game.hud.camera_setting_controls[key]
		slider.grab_focus()
		await present(0.1)
		var before: float = slider.value
		var key_right = InputEventKey.new()
		key_right.keycode = KEY_RIGHT
		key_right.pressed = true
		Input.parse_input_event(key_right)
		await present(0.05)
		key_right.pressed = false
		Input.parse_input_event(key_right)
		if game.camera_settings.get(key) != before+1.0: camera_failures.append("Keyboard did not adjust lens/tilt: " + key)
		var pad_left = InputEventJoypadButton.new()
		pad_left.button_index = JOY_BUTTON_DPAD_LEFT
		pad_left.pressed = true
		Input.parse_input_event(pad_left)
		await present(0.05)
		pad_left.pressed = false
		Input.parse_input_event(pad_left)
		if game.camera_settings.get(key) != before: camera_failures.append("Gamepad event did not adjust lens/tilt: " + key)
		if not page.get_global_rect().encloses(slider.get_global_rect()): camera_failures.append("Focused lens/tilt slider did not scroll into view: " + key)
	await camera_capture("camera_menu_tilt","native tilt controls / focus scroll / signed degree readouts")
	var visible_rect = game.hud.root.get_global_rect()
	for control in game.hud.camera_setting_controls.values() + game.hud.camera_setting_readouts.values() + [game.hud.camera_reset_button]:
		page.ensure_control_visible(control)
		await present(0.05)
		if not visible_rect.encloses(control.get_global_rect()): camera_failures.append("Camera control clipped outside the viewport")
		if not page.get_global_rect().encloses(control.get_global_rect()): camera_failures.append("Camera control cannot be scrolled fully into view")
	await camera_capture("camera_menu_smoothing","native scroll to smoothing and reset")
	game.hud.camera_setting_controls.vertical_smoothing.grab_focus()
	var key_event = InputEventKey.new()
	key_event.keycode = KEY_RIGHT
	key_event.pressed = true
	Input.parse_input_event(key_event)
	await present(0.05)
	key_event.pressed = false
	Input.parse_input_event(key_event)
	if game.camera_settings.vertical_smoothing != 76.0: camera_failures.append("Focused smoothing slider did not respond to keyboard")
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE: camera_failures.append("Camera settings did not release the cursor")
	game.hud.close_weather()
	game.hud.hide_menu()
	game.automated = true
	if "--camera-settings-menu-only" not in OS.get_cmdline_user_args():
		await riding_settings_review()
	game.active = false
	game.automated = false
	game.hud.open_settings()
	game.hud.camera_reset_button.pressed.emit()
	page.scroll_vertical = 0
	await present(0.2)
	await camera_capture("camera_menu_reset","native reset button")
	if game.camera_settings.snapshot() != game.CameraSettings.DEFAULTS: camera_failures.append("Reset did not restore all camera defaults")
	game.automated = true
	var report = {"captures":camera_frames,"failures":camera_failures,"actual_pixels":[actual_pixels.x,actual_pixels.y],"hardware_input_verified":false,"preferences_written":false,"generator":version,"seed":mountain_seed,"model":game.sim.MODEL_VERSION,"engine":Engine.get_version_info().string,"display":game.display_settings.report(root,actual_pixels),"camera_sha256":FileAccess.get_sha256("res://scripts/presentation/chase_camera.gd"),"settings_sha256":FileAccess.get_sha256("res://scripts/presentation/camera_settings.gd")}
	FileAccess.open(OUTPUT+"/camera_settings_review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CAMERA_SETTINGS_REVIEW ",JSON.stringify({"captures":camera_frames.size(),"failures":camera_failures}))

func riding_settings_review() -> void:
	var configured: Dictionary = game.camera_settings.snapshot()
	var profiles = [
		{"label":"defaults"},
		{"label":"custom","values":configured},
		{"label":"narrow","values":{"rest_fov":50.0,"fast_fov":50.0}},
		{"label":"wide","values":{"rest_fov":120.0,"fast_fov":120.0}},
		{"label":"tilt_down","values":{"chase_pitch_offset":-30.0,"first_person_pitch_offset":-30.0}},
		{"label":"tilt_up","values":{"chase_pitch_offset":30.0,"first_person_pitch_offset":30.0}},
	]
	for profile in profiles:
		game.camera_settings.reset()
		game.camera_settings.restore(profile.get("values",{}))
		for close in [false,true]:
			for kmh in [0,200]:
				fixture(820,kmh,close)
				await present(0.3)
				await camera_capture("%s_%s_%03d" % [profile.label,"pov" if close else "chase",kmh],"frozen speed / configurable lens and tilt")
	# Both defaults and menu-selected preferences get complete moving clips.
	# Separate folders prevent either profile from replacing the other's evidence.
	if "--camera-motion-capture" in OS.get_cmdline_user_args():
		var base_output = OUTPUT
		record_motion = true
		for custom in [false,true]:
			game.camera_settings.reset()
			if custom: game.camera_settings.restore(configured)
			OUTPUT = base_output + ("/custom_motion" if custom else "/default_motion")
			DirAccess.make_dir_recursive_absolute(OUTPUT)
			for close in [false,true]: await skiing_clip("jump_land",820,90,close)
		OUTPUT = base_output

func camera_capture(label: String, evidence: String) -> void:
	await super.camera_capture(label,evidence)
	camera_frames.back()["settings"] = game.camera_settings.snapshot()
	camera_frames.back()["first_person"] = game.camera.close_view
