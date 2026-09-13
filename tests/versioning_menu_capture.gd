extends SceneTree
## Bounded menu-only inspection; also runs externally against the exported PCK.
class Harness extends Node:
	var hud
	var navigation
	var initialized = false
	var active = false
	var loading
	var workshop = {"panel":PanelContainer.new(),"mode":""}
	var mountain_library = {"panel":PanelContainer.new()}
	func _input(event: InputEvent) -> void:
		if initialized and navigation.route(event): get_viewport().set_input_as_handled()
	func resume() -> void: active = true

var failures: Array[String] = []
var checks = 0
var game
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ",label)
func frames() -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
func press(button: int) -> void:
	for down in [true,false]:
		var event = InputEventJoypadButton.new()
		event.button_index = button; event.pressed = down
		Input.parse_input_event(event)
		await process_frame
func run() -> void:
	var out = OS.get_environment("ALPINE_VERSION_CAPTURE")
	if out.is_empty(): out = "res://artifacts/versioning/menu"
	DirAccess.make_dir_recursive_absolute(out)
	Engine.max_fps = 60
	var _router = load("res://scripts/core/input_router.gd").new()
	game = Harness.new(); root.add_child(game)
	game.hud = load("res://scripts/ui/hud.gd").new(); game.add_child(game.hud)
	game.hud.tuning_panel = PanelContainer.new(); game.hud.root.add_child(game.hud.tuning_panel); game.hud.tuning_panel.hide()
	for panel in [game.workshop.panel,game.mountain_library.panel]: game.hud.root.add_child(panel); panel.hide()
	game.navigation = load("res://scripts/ui/menu_navigation.gd").new(); game.add_child(game.navigation); game.navigation.setup(game)
	game.initialized = true
	var build = game.hud.BuildIdentity.current()
	check(game.hud.build_version_label.text==game.hud.BuildIdentity.short_label(),"Menu label agrees with runtime identity")
	if OS.has_feature("generation_export"):
		check(build.source=="package","Export uses embedded identity without Git or Python")
		var package = JSON.parse_string(FileAccess.get_file_as_string(OS.get_executable_path().get_base_dir().path_join("BUILD.json")))
		check(package is Dictionary and package.get("build") is Dictionary,"Package includes build receipt")
		if package is Dictionary and package.get("build") is Dictionary:
			for key in ["dev","commit","source_sha256","changes_sha256","compatibility","engine_sha256"]:
				check(build.get(key)==package.build.get(key),"Package/runtime agree on "+key)
	var original_clipboard = DisplayServer.clipboard_get()
	root.mode = Window.MODE_WINDOWED
	for size in [Vector2i(1440,900),Vector2i(960,540)]:
		root.size = size
		for mode in ["title","paused"]:
			game.hud.show_menu(mode)
			game.hud.menu_tabs.current_tab = 0
			await frames()
			var rect = game.hud.build_version_label.get_global_rect()
			check(game.hud.build_version_label.is_visible_in_tree() and root.get_visible_rect().encloses(rect),"Version visible in %s at %s"%[mode,size])
			check(root.get_texture().get_image().save_png(out.path_join("%s_%dx%d.png"%[mode,size.x,size.y]))==OK,"Menu capture saved")
		game.hud.menu_tabs.current_tab = 2
		await frames()
		game.hud.copy_build_button.grab_focus()
		await press(JOY_BUTTON_DPAD_UP)
		await press(JOY_BUTTON_DPAD_DOWN)
		check(root.gui_get_focus_owner()==game.hud.copy_build_button,"Controller reaches copy details")
		await press(JOY_BUTTON_A)
		await frames()
		check(DisplayServer.clipboard_get().replace("\r\n","\n")==game.hud.BuildIdentity.details(),"Controller copies diagnostic details (native Windows line endings)")
		await frames()
		root.get_texture().get_image().save_png(out.path_join("tools_%dx%d.png"%[size.x,size.y]))
	DisplayServer.clipboard_set(original_clipboard)
	var result = {"checks":checks,"failures":failures,"build":build,"human_acceptance":false,"performance_evidence":false}
	FileAccess.open(out.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t",true,true))
	print("VERSIONING_MENU ",JSON.stringify(result))
	game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
