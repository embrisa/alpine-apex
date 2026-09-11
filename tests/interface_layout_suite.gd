extends SceneTree
const HUD = preload("res://scripts/ui/hud.gd")
const Settings = preload("res://scripts/presentation/pc_graphics_settings.gd")
var hud
var failures: Array[String] = []
var checks = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func settle() -> void:
	for i in 4: await process_frame
func run() -> void:
	hud = HUD.new()
	root.add_child(hud)
	await settle()
	hud.feedback.persist = false
	hud.feedback.reduced_motion = true
	hud.sync_display(Settings.new())
	check(hud.widget_layout.widgets.size()==12,"Registry covers all instrument groups")
	var original = hud.widget_layout.snapshot()
	var backgrounds = hud.root.find_child("HUDBackgrounds",true,false)
	check(not hud.shell_layout.hud_backgrounds and not backgrounds.button_pressed,"HUD backgrounds default off in the live setting")
	for enabled in [true,false]:
		backgrounds.button_pressed = enabled
		check(hud.widget_layout.widgets.values().all(func(widget): return widget.node.background_enabled==enabled) and hud.widget_layout.snapshot()==original,"Background toggle updates every instrument without changing layout: "+str(enabled))
		var interface_path = "user://overhaul_interface_test.cfg"
		check(hud.shell_layout.Store.write_values(interface_path,1,hud.shell_layout.snapshot())==OK,"Interface preference saves atomically: "+str(enabled))
		var restored = preload("res://scripts/ui/screen_shell.gd").new()
		restored.restore(restored.Store.read_values(interface_path,1))
		check(restored.hud_backgrounds==enabled,"Background preference survives a fresh store load: "+str(enabled))
		restored.free()
	hud.shell_layout.restore({"hud_backgrounds":"false"})
	check(not hud.shell_layout.hud_backgrounds,"Malformed background preference cannot enable panels")
	hud.hide_menu()
	check(not hud.footer.visible and hud.menu_edge_shading.all(func(shade): return not shade.visible),"Riding HUD has no footer or screen-edge background")

	for size in [Vector2(1280,720),Vector2(1440,900),Vector2(1920,1080),Vector2(3840,2160),Vector2(3440,1440)]:
		root.size = size
		await settle()
		hud.open_settings()
		await settle()
		check(Rect2(Vector2.ZERO,hud.root.size).grow(1).encloses(hud.weather_panel.get_rect()),"Settings fit "+str(size))
		hud.widget_layout.menu_visible = false
		hud.widget_layout.timed = true
		for id in hud.widget_layout.widgets:
			hud.widget_layout.values[id].scale = 2.0
			hud.widget_layout.values[id].position = Vector2.ONE
			hud.widget_layout.values[id].visible = true
		hud.widget_layout.apply(size)
		for id in hud.widget_layout.widgets:
			var widget = hud.widget_layout.widgets[id]
			check(Rect2(Vector2.ZERO,size).encloses(Rect2(widget.node.position,widget.size*widget.node.scale)),"Scaled widget %s remains bounded at %s" % [id,size])
		hud.widget_layout.restore(original)
	var invalid = original.duplicate(true)
	invalid.speed.scale = NAN
	invalid.speed.position = Vector2.INF
	invalid.speed.visible = "bad"
	hud.widget_layout.restore(invalid)
	check(hud.widget_layout.values.speed==original.speed,"Malformed HUD values retain finite defaults")
	hud.open_settings()
	await hud.hud_editor.open()
	await settle()
	check(hud.hud_editor.visible and hud.widget_layout.preview,"HUD preview owns real composite widgets")
	for enabled in [true,false]:
		hud.shell_layout.restore({"hud_backgrounds":enabled})
		hud.shell_layout.resize()
		check(backgrounds.button_pressed==enabled and hud.widget_layout.widgets.values().all(func(widget): return widget.node.background_enabled==enabled),"Restore synchronizes the setting and live editor preview: "+str(enabled))
	hud.hud_editor.select("reserve")
	hud.hud_editor.set_mode("move")
	hud.hud_editor.handle_direction(Vector2i.LEFT)
	hud.hud_editor.set_mode("resize")
	hud.hud_editor.handle_direction(Vector2i.UP)
	check(hud.widget_layout.values.reserve!=original.reserve,"Controller moves and scales the selected composite")
	for id in hud.widget_layout.widgets:
		# Isolate each hit target so overlapping user layouts cannot select a sibling.
		for other in hud.widget_layout.widgets: hud.widget_layout.values[other].visible = other==id
		hud.hud_editor.select(id)
		var widget = hud.widget_layout.widgets[id]
		var start = widget.node.position+widget.size*widget.node.scale*.5
		var before = hud.widget_layout.values[id].position
		var button = InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT; button.pressed = true; button.position = start
		hud.hud_editor.canvas._gui_input(button)
		var drag = InputEventMouseMotion.new()
		drag.position = start+Vector2(64 if before.x<.5 else -64,0)
		hud.hud_editor.canvas._gui_input(drag)
		button.pressed = false; button.position = drag.position
		hud.hud_editor.canvas._gui_input(button)
		check(hud.widget_layout.values[id].position!=before and not hud.hud_editor.canvas.dragging,"Mouse selects, moves and releases composite widget "+id)
	hud.hud_editor.close(false)
	check(hud.widget_layout.snapshot()==original and not hud.widget_layout.preview,"Cancel restores every HUD field and live ownership")
	var path = "user://overhaul_hud_test.cfg"
	hud.widget_layout.values.speed.opacity = .4
	check(hud.widget_layout.save_preferences(path)==OK,"HUD layout saves atomically outside race identity")
	hud.widget_layout.restore({})
	hud.widget_layout.load_preferences(path)
	check(hud.widget_layout.values.speed.opacity==.4,"HUD layout survives a fresh load")
	print("INTERFACE_LAYOUT_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	hud.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
