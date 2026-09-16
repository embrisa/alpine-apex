extends "res://tests/camera_playtest.gd"
## Native v15 profile/menu/preview review. Isolated preferences, always unranked.
func inspect_massif() -> void:
	game.set_process(false)
	game.set_physics_process(false)
	fixture(820,120)
	await present(.5)
	game.active = false
	game.automated = false
	game.application_focused = true
	game.hud.show_menu("paused")
	game.hud.open_settings()
	var ui = game.hud.camera_options
	_select_tab(game.hud.settings_tabs,"Camera")
	var page: ScrollContainer = game.hud.settings_tabs.get_current_tab_control()
	if game.preferences_enabled: camera_failures.append("Native review could write personal preferences")
	await present(.2)
	await camera_capture("settings_connected","native grouped camera settings")
	for group in ui.groups:
		for other in ui.groups: ui.groups[other].button.button_pressed = other==group
		if not ui.groups[group].content.is_visible_in_tree(): camera_failures.append("Group did not expand: "+group)
		await present(.05)
		page.ensure_control_visible(ui.groups[group].button)
		await present(.1)
		await camera_capture("settings_"+group.validate_filename(),"native expandable group")
		for control in ui.groups[group].content.find_children("*","HSlider",true,false):
			if not control.is_visible_in_tree(): continue
			control.grab_focus()
			page.ensure_control_visible(control)
			await present(.05)
			if not page.get_global_rect().encloses(control.get_global_rect()): camera_failures.append("Slider clipped: "+control.name)
	ui.groups["Framing"].button.button_pressed = true
	for key in ["rest_fov","fast_fov","rest_tilt","fast_tilt"]:
		var slider: HSlider = ui.controls[key]
		slider.grab_focus()
		page.ensure_control_visible(slider)
		await present(.05)
		var before: float = slider.value
		var event = InputEventKey.new()
		event.keycode = KEY_RIGHT; event.pressed = true
		Input.parse_input_event(event)
		await present(.05)
		event.pressed = false; Input.parse_input_event(event)
		if slider.value!=before+1: camera_failures.append("Keyboard increment failed: "+key)
		var pad = InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_DPAD_LEFT; pad.pressed = true
		Input.parse_input_event(pad)
		await present(.05)
		pad.pressed = false; Input.parse_input_event(pad)
		if slider.value!=before: camera_failures.append("Synthetic controller increment failed: "+key)
	game.set_camera_preset("save","chase","Native review","")
	game.set_camera_setting("chase","rest_fov",58)
	if game.camera_settings.presets.chase["Native review"].rest_fov!=55: camera_failures.append("Working edit changed saved preset")
	game.set_camera_preset("replace","chase","Native review","")
	game.set_camera_preset("rename","chase","Native review","Native renamed")
	game.set_camera_preset("delete","chase","Native renamed","")
	game.reset_camera_settings()
	for group in ui.groups:
		ui.groups[group].button.button_pressed = group in ["Preview speed","Framing"]
	page.scroll_vertical = 0
	var before = [game.sim.position,game.sim.velocity,game.sim.ticks,game.session.elapsed,game.session.eligible]
	game.set_camera_preview(true)
	ui.preview_speed.value = 200
	await present(2)
	await camera_capture("preview_chase_200","paused riding projection / synthetic camera speed")
	ui.collapse_button.pressed.emit()
	await present(.1)
	await camera_capture("preview_chase_unobstructed","paused full-width projection with controls collapsed")
	ui.collapse_button.pressed.emit()
	ui.view_selector.select(1); ui.view_selector.item_selected.emit(1)
	await present(.5)
	await camera_capture("preview_first_person","independent first-person preview")
	if before!=[game.sim.position,game.sim.velocity,game.sim.ticks,game.session.elapsed,game.session.eligible]: camera_failures.append("Preview changed simulation or session")
	if not ui.preview_active: camera_failures.append("Preview exited unexpectedly")
	game.set_camera_preview(false)
	ui.view_selector.select(0); ui.view_selector.item_selected.emit(0)
	await present(.1)
	await camera_capture("settings_after_preview","settings layout restored")
	game.hud.close_weather(); game.hud.hide_menu()
	game.automated = true
	if "--camera-settings-menu-only" not in OS.get_cmdline_user_args(): await riding_settings_review()
	game.active = false; game.automated = false
	game.reset_camera_settings()
	game.hud.show_menu("paused"); game.hud.open_settings()
	page.scroll_vertical = 0
	await present(.1)
	await camera_capture("settings_reset","reset restores Connected and typed controls")
	game.automated = true
	var report = {"captures":camera_frames,"failures":camera_failures,"actual_pixels":[actual_pixels.x,actual_pixels.y],"hardware_input_verified":false,"preferences_written":game.preferences_enabled,"generator":version,"seed":mountain_seed,"model":game.sim.MODEL_VERSION,"engine":Engine.get_version_info().string,"display":game.display_settings.report(root,actual_pixels),"camera_sha256":FileAccess.get_sha256("res://scripts/presentation/chase_camera.gd"),"settings_sha256":FileAccess.get_sha256("res://scripts/presentation/camera_settings.gd")}
	preload("res://tests/test_report.gd").write(OUTPUT+"/camera_settings_review.json",JSON.stringify(report,"\t"))
	print("CAMERA_SETTINGS_REVIEW ",JSON.stringify({"captures":camera_frames.size(),"failures":camera_failures}))

func riding_settings_review() -> void:
	for preset in game.CameraSettings.BUILT_INS:
		for view in game.CameraSettings.VIEWS: game.camera_settings.apply_preset(view,preset)
		for close in [false,true]:
			for site in [820,1600,2350]:
				for kmh in [0,60,120,160,200]:
					fixture(site,kmh,close)
					await present(.1)
					await camera_capture("%s_%s_%d_%03d" % [preset.to_lower(),"pov" if close else "chase",site,kmh],"frozen terrain/speed fixture")
	var base_output = OUTPUT
	record_motion = "--camera-motion-capture" in OS.get_cmdline_user_args()
	for preset in game.CameraSettings.BUILT_INS:
		for view in game.CameraSettings.VIEWS: game.camera_settings.apply_preset(view,preset)
		OUTPUT = base_output+"/"+preset.to_lower()
		DirAccess.make_dir_recursive_absolute(OUTPUT)
		await skiing_clip("turn_brake",820,120)
		await skiing_clip("jump_land",820,90)
		await skiing_clip("steep",1600,150)
		await skiing_clip("jump_land",820,90,true)
	OUTPUT = base_output
	game.camera_settings.reset()
	if record_motion:
		await bump_clip(false)
		await bump_clip(true)

func camera_capture(label: String, evidence: String) -> void:
	await super.camera_capture(label,evidence)
	camera_frames.back()["settings"] = game.camera_settings.snapshot()
	camera_frames.back()["preview"] = game.hud.camera_options.preview_active
	if game.hud.camera_options.preview_active: camera_frames.back()["preview_speed"] = game.hud.camera_options.preview_speed.value
