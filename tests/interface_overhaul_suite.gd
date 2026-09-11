extends SceneTree
## Exercise actual UI events with isolated preferences and an unranked lab.
var game
var checks = 0
var failures: Array[String] = []
var captures: Array = []
var native = false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func settle(frames: int = 4) -> void:
	for i in frames: await process_frame
func pad(button: int) -> void:
	if "--nav-debug" in OS.get_cmdline_user_args():
		print("NAV_BEFORE ",button," scope=",game.navigation.scope()," popup=",game.navigation.top_popup()," focus=",root.gui_get_focus_owner()," options=",game.hud.graphics_quality.get_popup().visible," settings=",game.hud.weather_panel.visible)
	for pressed in [true,false]:
		var event = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	if "--nav-debug" in OS.get_cmdline_user_args():
		print("NAV_AFTER ",button," scope=",game.navigation.scope()," popup=",game.navigation.top_popup()," focus=",root.gui_get_focus_owner()," options=",game.hud.graphics_quality.get_popup().visible," settings=",game.hud.weather_panel.visible)
func run() -> void:
	set_meta("test_lab_fixture",true)
	native = DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute("res://artifacts/interface_overhaul/current")
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	current_scene = game
	while not game.initialized: await process_frame
	game.automated = false
	game.active = false
	game.set_physics_process(false)
	game.session.eligible = false
	game.hud.feedback.muted = true
	await settle()
	check(game.hud.settings_tabs.get_tab_count()==8,"Eight distinct settings domains are present")
	check(game.hud.graphics_quality.item_count==10,"Graphics page exposes ten numbered presets")
	check(game.hud.widget_layout.widgets.size()==12,"HUD registry includes all twelve coherent instrument groups")
	var ticks = game.sim.ticks
	game.hud.menu_tabs.current_tab = 2
	game.hud.weather_button.grab_focus()
	await pad(JOY_BUTTON_A)
	check(game.hud.weather_panel.visible and not game.active,"Controller opens settings without starting skiing")
	await pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(game.hud.settings_tabs.current_tab==1,"Shoulder advances settings categories")
	var camera_view = game.camera.close_view
	await pad(JOY_BUTTON_Y)
	check(game.hud.weather_panel.visible and game.camera.close_view==camera_view and game.sim.ticks==ticks,"Menu north/shoulder inputs do not retry, switch riding camera or tick physics")
	game.hud.graphics_quality.grab_focus()
	await pad(JOY_BUTTON_A)
	check(game.hud.graphics_quality.get_popup().visible,"Controller opens a graphics dropdown")
	await pad(JOY_BUTTON_B)
	check(not game.hud.graphics_quality.get_popup().visible and game.hud.weather_panel.visible,"Back closes only the topmost dropdown")
	var body = game.hud.settings_pages.groups["Snow & particles"]
	var toggle = body.get_parent().get_child(0)
	toggle.grab_focus()
	await pad(JOY_BUTTON_A)
	check(body.visible,"Controller expands advanced settings")
	var slider = game.hud.settings_pages.graphics_controls.snow_sparkle
	slider.grab_focus()
	var before = slider.value
	await pad(JOY_BUTTON_DPAD_LEFT)
	game.hud.settings_pages.flush_changes()
	check(slider.value<before and game.graphics.snow_sparkle==slider.value,"Controller fine adjustment reaches a same-preset material setting")
	toggle.set_pressed(false)
	check(root.gui_get_focus_owner()==toggle,"Collapsing a group returns focus from hidden controls")
	await pad(JOY_BUTTON_B)
	check(game.hud.menu.visible and not game.hud.weather_panel.visible and not game.active,"Back from Settings returns to the menu without resuming")
	game.hud.open_settings()
	game.hud.settings_tabs.current_tab = 2
	var camera_name = game.hud.camera_options.name_input
	game.hud.camera_options.groups["Named presets"].button.button_pressed = true
	await settle()
	camera_name.grab_focus()
	await pad(JOY_BUTTON_A)
	check(game.controller_keyboard.dialog.visible,"Controller text entry opens for a named camera preset")
	await pad(JOY_BUTTON_A)
	game.controller_keyboard.apply()
	game.controller_keyboard.dialog.hide()
	check(camera_name.text.length()>0,"Controller keyboard enters actual field text")
	if "--nav-debug" in OS.get_cmdline_user_args():
		game.queue_free(); await settle(); quit(); return
	game.hud.settings_tabs.current_tab = 5
	var original = game.hud.widget_layout.snapshot()
	await game.hud.hud_editor.open()
	await settle()
	check(game.hud.hud_editor.visible and not game.active,"HUD editor opens a paused sample preview")
	for id in game.hud.widget_layout.widgets:
		var editor = game.hud.hud_editor
		editor.select(id)
		editor.set_mode("move")
		var position = game.hud.widget_layout.values[id].position
		editor.handle_direction(Vector2i.RIGHT if position.x<.5 else Vector2i.LEFT)
		editor.set_mode("resize")
		editor.handle_direction(Vector2i.RIGHT)
		game.hud.widget_layout.values[id].opacity = .55
		game.hud.widget_layout.values[id].visible = false
		editor.refresh()
		check(game.hud.widget_layout.values[id].position!=position and game.hud.widget_layout.values[id].scale>1.0 and not game.hud.widget_layout.widgets[id].node.visible,"Controller edits hidden/selectable HUD widget "+id)
	game.hud.hud_editor.close(false)
	check(game.hud.widget_layout.snapshot()==original,"Cancel restores the entire edit-session layout")
	game.hud.widget_layout.timed = false
	game.hud.widget_layout.menu_visible = false
	game.hud.hide_menu()
	game.hud.layout_widgets()
	check(not game.hud.widget_layout.widgets.time.node.visible and game.hud.widget_layout.widgets.speed.node.visible,"Free skiing hides race-only instruments")
	game.hud.toggle_instruments()
	check(not game.hud.widget_layout.widgets.speed.node.visible and game.hud.widget_layout.snapshot()==original,"Global HUD toggle preserves widget preferences")
	game.hud.toggle_instruments()
	game.hud.show_menu("paused")
	game.hud.open_settings()
	for size in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(3840,2160),Vector2i(3440,1440)]:
		if native: game.display_settings.apply_display(root,size)
		else: root.size = size
		await settle(24)
		if native: check(root.size==size,"Window output matches requested "+str(size))
		game.hud.settings_tabs.current_tab = 1
		await capture("graphics_%dx%d" % [size.x,size.y])
		game.hud.close_weather()
		await capture("menu_%dx%d" % [size.x,size.y])
		game.hud.open_settings()
	await game.hud.hud_editor.open()
	await capture("hud_editor")
	game.hud.hud_editor.close(false)
	if "--timeline" in OS.get_cmdline_user_args(): await transition_timeline()
	if "--matrix" in OS.get_cmdline_user_args(): await matrix()
	var result = {"checks":checks,"failures":failures,"captures":captures,"native":native}
	var report_name = "interaction_results.json" if "--timeline" in OS.get_cmdline_user_args() else "results.json"
	FileAccess.open("res://artifacts/interface_overhaul/current/"+report_name,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("INTERFACE_OVERHAUL_RESULTS ",JSON.stringify(result))
	game.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	await settle(24)
	for panel in [game.hud.menu,game.hud.weather_panel]:
		if panel.visible: check(Rect2(Vector2.ZERO,game.hud.root.size).grow(2).encloses(panel.get_rect()),label+" fits logical viewport")
	if not native: return
	await RenderingServer.frame_post_draw
	var output = root.get_texture().get_image()
	output.save_png("res://artifacts/interface_overhaul/current/"+label+".png")
	captures.append({"label":label,"pixels":str(output.get_size())})

func matrix() -> void:
	game.hud.feedback.reduced_motion = true
	for output in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(3840,2160),Vector2i(3440,1440)]:
		game.display_settings.apply_display(root,output)
		await settle(30)
		var tag = "%dx%d" % [output.x,output.y]
		check(root.size==output,"Matrix output "+tag)
		game.hud.shell_layout.change("ui_scale",1.4 if output.x==1280 else 1.0)
		for mode in ["paused","crashed","finished"]:
			game.hud.show_menu(mode)
			game.hud.menu_tabs.current_tab = 0
			await capture(mode+"_"+tag)
		game.hud.open_settings()
		for page in ["Display","Graphics","Camera","Controls","Audio","Interface & HUD","Weather","Rider"]:
			game.hud.settings_tabs.current_tab = game.hud.settings_tabs.get_node(page).get_index()
			await capture(page.replace(" & ","_").to_lower()+"_basic_"+tag)
		game.hud.settings_tabs.current_tab = 2
		game.hud.camera_options.groups["Named presets"].button.button_pressed = true
		game.controller_keyboard.open(game.hud.camera_options.name_input)
		await capture("text_entry_"+tag)
		game.controller_keyboard.dialog.hide()
		game.hud.settings_tabs.current_tab = 1
		var body = game.hud.settings_pages.groups["Snow & particles"]
		body.get_parent().get_child(0).button_pressed = true
		body.get_meta("fields").get_child(0).get_child(1).get_child(0).grab_focus()
		await capture("graphics_expanded_"+tag)
		body.get_parent().get_child(0).button_pressed = false
		game.hud.settings_tabs.current_tab = 2
		game.hud.camera_options.groups["Framing"].button.button_pressed = true
		game.hud.camera_options.controls.rest_fov.grab_focus()
		await capture("camera_expanded_"+tag)
		await game.hud.hud_editor.open()
		await capture("hud_editor_"+tag)
		game.hud.hud_editor.close(false)
		game.hud.close_weather()
		game.open_workbench()
		await capture("workbench_"+tag)
		game.close_workbench()
		game.open_competition()
		game.hud.competition.tabs.current_tab = 2
		await capture("records_"+tag)
		game.hud.close_competition()
		game.workshop.open_library()
		await capture("races_"+tag)
		game.workshop.begin_creation()
		await capture("race_drawer_"+tag)
		game.workshop.back_pressed()
		game.workshop.back_pressed()
		game.loading.begin("Loading mountain","Reading terrain…")
		await capture("loading_"+tag)
		game.loading.finish()
	game.hud.shell_layout.change("ui_scale",1.0)

func transition_timeline() -> void:
	game.display_settings.apply_display(root,Vector2i(1280,720))
	await settle(30)
	var frames: Array = []
	var entries: Array = []
	var start_ticks = game.sim.ticks
	for reduced in [false,true]:
		game.hud.feedback.reduced_motion = reduced
		game.hud.close_weather()
		game.hud.show_menu("paused")
		game.hud.menu_tabs.current_tab = 2
		game.hud.weather_button.grab_focus()
		await settle(4)
		await pad(JOY_BUTTON_A)
		for phase in ["open_settings","change_category"]:
			if phase=="change_category": await pad(JOY_BUTTON_RIGHT_SHOULDER)
			var started = Time.get_ticks_usec()
			for index in 31:
				await process_frame
				if index not in [0,6,12,20,30]: continue
				await RenderingServer.frame_post_draw
				var page = game.hud.settings_tabs.get_current_tab_control()
				var focus = root.gui_get_focus_owner()
				frames.append(root.get_texture().get_image())
				entries.append({"phase":phase,"reduced_motion":reduced,"frame":index,"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"page_alpha":page.modulate.a,"page_position":str(page.position),"focus":focus.name if focus else "none","ticks":game.sim.ticks})
		game.hud.settings_tabs.current_tab = 5
		await game.hud.hud_editor.open()
		var editor = game.hud.hud_editor
		editor.select("reserve")
		editor.move_button.grab_focus()
		await pad(JOY_BUTTON_A)
		for index in 3:
			await pad(JOY_BUTTON_DPAD_LEFT)
			await RenderingServer.frame_post_draw
			frames.append(root.get_texture().get_image())
			entries.append({"phase":"hud_move","reduced_motion":reduced,"frame":index,"position":str(game.hud.widget_layout.values.reserve.position),"focus":root.gui_get_focus_owner().name,"ticks":game.sim.ticks})
		await pad(JOY_BUTTON_B)
		await pad(JOY_BUTTON_B)
	check(game.sim.ticks==start_ticks and not game.active,"Chronological menu/HUD interaction never advances skiing")
	for index in frames.size():
		var label = "interaction_%02d" % index
		frames[index].save_png("res://artifacts/interface_overhaul/current/"+label+".png")
		entries[index].file = label+".png"
	FileAccess.open("res://artifacts/interface_overhaul/current/interaction_timeline.json",FileAccess.WRITE).store_string(JSON.stringify({"frames":entries,"capture_note":"Readbacks during interaction; PNG encoding deferred until after the sequence. Not an FPS measurement.","hardware_controller":false},"\t"))
	game.hud.feedback.reduced_motion = false
