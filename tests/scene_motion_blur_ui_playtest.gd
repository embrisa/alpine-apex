extends SceneTree
## Native camera-controls/focus review without loading a mountain.
var checks = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures.append(caption); printerr("FAIL: ",caption)
func run() -> void:
	Engine.max_fps = 30
	root.size = Vector2i(960,540)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	var hud = preload("res://scripts/ui/hud.gd").new()
	hud.feedback.persist = false; hud.feedback.muted = true
	root.add_child(hud)
	var settings = preload("res://scripts/presentation/camera_settings.gd").new()
	hud.camera_setting_requested.connect(func(view,key,value): settings.set_value(view,key,value); hud.sync_camera_settings(settings))
	hud.open_settings()
	for i in hud.settings_tabs.get_tab_count():
		if hud.settings_tabs.get_tab_title(i)=="Camera": hud.settings_tabs.current_tab = i
	var ui = hud.camera_options
	ui.groups["Motion effects"].button.button_pressed = true
	ui.groups["Motion effects"].content.show()
	DirAccess.make_dir_recursive_absolute("res://artifacts/scene_motion_blur/ui")
	for view in ["chase","first_person"]:
		ui.view = view
		settings.update_profile(view,{"motion_blur_enabled":view=="chase","motion_blur_strength":50.0})
		hud.sync_camera_settings(settings)
		for i in 4: await process_frame
		ui.controls.motion_blur_enabled.grab_focus()
		for i in 4: await process_frame
		check(root.gui_get_focus_owner()==ui.controls.motion_blur_enabled,"Motion blur toggle receives focus in "+view)
		var scroll = ui.controls.motion_blur_enabled.get_parent()
		while scroll and not scroll is ScrollContainer: scroll = scroll.get_parent()
		if scroll: scroll.ensure_control_visible(ui.motion_blur_note)
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/scene_motion_blur/ui/"+view+".png")==OK,"Camera motion-controls capture")
	check(not ui.controls.motion_blur_enabled.disabled,"Native Forward+ presents an available toggle")
	FileAccess.open("res://artifacts/scene_motion_blur/ui/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"human_controller_acceptance":false},"\t"))
	print("SCENE_BLUR_UI_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	hud.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
