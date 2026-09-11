extends SceneTree
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

var game
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, caption: String) -> void:
	print("PASS: " if value else "FAIL: ",caption)
	if not value: failures.append(caption)
func press(button: int) -> void:
	if "--nav-debug" in OS.get_cmdline_user_args(): print("NAV_BEFORE ",button," popup=",game.navigation.top_popup()," scope=",game.navigation.scope()," focus=",root.gui_get_focus_owner()," dropdown=",game.hud.graphics_quality.get_popup().visible," settings=",game.hud.weather_panel.visible)
	for pressed in [true,false]:
		var event = InputEventJoypadButton.new()
		event.button_index = button; event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	if "--nav-debug" in OS.get_cmdline_user_args(): print("NAV_AFTER ",button," popup=",game.navigation.top_popup()," scope=",game.navigation.scope()," focus=",root.gui_get_focus_owner()," dropdown=",game.hud.graphics_quality.get_popup().visible," settings=",game.hud.weather_panel.visible)
func run() -> void:
	var _router = preload("res://scripts/core/input_router.gd").new()
	game = Harness.new()
	root.add_child(game)
	game.hud = load("res://scripts/ui/hud.gd").new()
	game.add_child(game.hud)
	game.hud.tuning_panel = PanelContainer.new()
	game.hud.root.add_child(game.hud.tuning_panel)
	game.hud.tuning_panel.hide()
	for panel in [game.workshop.panel,game.mountain_library.panel]: game.hud.root.add_child(panel); panel.hide()
	game.navigation = load("res://scripts/ui/menu_navigation.gd").new()
	game.add_child(game.navigation)
	game.navigation.setup(game)
	var keyboard = load("res://scripts/ui/controller_keyboard.gd").new()
	game.add_child(keyboard); keyboard.setup(game.hud)
	game.navigation.virtual_keyboard = keyboard
	game.initialized = true
	for i in 4: await process_frame
	game.hud.open_settings()
	game.hud.settings_tabs.current_tab = 1
	game.hud.graphics_quality.grab_focus()
	await press(JOY_BUTTON_A)
	check(game.hud.graphics_quality.get_popup().visible,"South opens dropdown")
	await press(JOY_BUTTON_B)
	check(not game.hud.graphics_quality.get_popup().visible and game.hud.weather_panel.visible,"East closes only dropdown")
	game.hud.graphics_quality.select(0)
	await press(JOY_BUTTON_A)
	await press(JOY_BUTTON_DPAD_DOWN)
	check(game.hud.graphics_quality.get_popup().get_focused_item()==1,"D-pad advances popup selection")
	await press(JOY_BUTTON_A)
	check(not game.hud.graphics_quality.get_popup().visible and game.hud.graphics_quality.selected==1,"South selects the focused dropdown value once")
	game.hud.graphics_quality.get_popup().hide()
	var group = game.hud.settings_pages.groups["Snow & particles"]
	var toggle = group.get_parent().get_child(0)
	toggle.grab_focus()
	await press(JOY_BUTTON_A)
	check(group.visible,"South expands advanced group")
	game.hud.camera_options.groups["Named presets"].button.button_pressed = true
	game.hud.settings_tabs.current_tab = 2
	game.hud.camera_options.name_input.grab_focus()
	await press(JOY_BUTTON_A)
	check(keyboard.dialog.visible,"South opens virtual keyboard")
	await press(JOY_BUTTON_A)
	check(keyboard.field.text.length()>0,"South enters focused character")
	keyboard.dialog.hide()
	# Child dialogs must be topmost even when their parent was created later.
	var late_dialog = ConfirmationDialog.new()
	var late_field = LineEdit.new()
	late_field.text = "nested"
	late_dialog.add_child(late_field)
	root.add_child(late_dialog)
	for i in 3: await process_frame
	late_dialog.popup_centered(Vector2i(650,180))
	keyboard.open(late_field)
	for i in 3: await process_frame
	check(game.navigation.popups.count(keyboard.dialog)==1,"Reparenting text entry retains one popup registration")
	check(game.navigation.top_popup()==keyboard.dialog,"Reopened child text entry owns focus above a later-created parent dialog")
	await press(JOY_BUTTON_B)
	check(not keyboard.dialog.visible and late_dialog.visible,"Back closes only child text entry")
	await press(JOY_BUTTON_B)
	check(not late_dialog.visible and game.hud.weather_panel.visible,"Back closes the parent dialog before Settings")
	# Return the reusable keyboard to the root before freeing its temporary parent.
	keyboard.dialog.reparent(root)
	late_dialog.queue_free()
	await process_frame
	game.hud.settings_tabs.current_tab = 1
	await process_frame
	var slider = game.hud.settings_pages.graphics_controls.snow_sparkle
	slider.grab_focus()
	slider.value = 6.0
	var original = slider.value
	var motion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X; motion.axis_value = -.8
	# Exercise elapsed-time repeat deterministically: a connected physical pad may
	# report its centered state between synthetic SDL events.
	game.navigation.set_process(false)
	Input.parse_input_event(motion.duplicate())
	Input.flush_buffered_events()
	check(slider.value==original-slider.step,"Stick direction adjusts a slider once on activation")
	game.navigation._process(.18)
	check(slider.value==original-slider.step,"Held stick observes its initial repeat delay")
	game.navigation._process(.3)
	check(slider.value<original-slider.step,"Held stick repeats fine slider adjustments")
	game.navigation.set_process(true)
	motion.axis_value = 0.0; Input.parse_input_event(motion.duplicate())
	await process_frame
	check(game.navigation.held==Vector2i.ZERO,"Stick centering clears held repeat")
	game.navigation.family = "keyboard"
	motion.axis_value = .12; Input.parse_input_event(motion.duplicate())
	await process_frame
	check(game.navigation.family=="keyboard" and game.navigation.held==Vector2i.ZERO,"Analog noise cannot change device prompts or focus")
	game.navigation.family = "gamepad"; game.navigation.device = 3
	game.navigation.held = Vector2i.LEFT
	game.navigation._connection_changed(3,false)
	check(game.navigation.family=="keyboard" and game.navigation.held==Vector2i.ZERO,"Disconnect cancels repeat and restores keyboard prompts")
	game.navigation.held = Vector2i.RIGHT
	root.focus_exited.emit()
	check(game.navigation.held==Vector2i.ZERO,"Focus loss cancels held navigation")
	slider.grab_focus()
	game.hud.settings_tabs.cycle(1)
	await process_frame
	game.hud.settings_tabs.cycle(-1)
	await process_frame
	check(root.gui_get_focus_owner()==slider,"Returning to a category restores its previous control")
	var disabled = game.hud.settings_pages.output_controls.resolution
	game.hud.settings_tabs.current_tab = 0
	game.hud.settings_pages.output_draft = {"display_mode":"fullscreen"}
	game.hud.settings_pages._sync_output_choices()
	disabled.grab_focus()
	check(game.navigation.ensure_focus()!=disabled,"Disabled output choices cannot retain controller focus")
	game.hud.settings_tabs.current_tab = 5
	await game.hud.hud_editor.open()
	await process_frame
	var editor = game.hud.hud_editor
	editor.select("reserve")
	editor.move_button.grab_focus()
	await press(JOY_BUTTON_A)
	var position = game.hud.widget_layout.values.reserve.position
	await press(JOY_BUTTON_DPAD_LEFT)
	check(editor.mode=="move" and game.hud.widget_layout.values.reserve.position!=position,"Actual controller buttons enter HUD Move and change position")
	await press(JOY_BUTTON_B)
	check(editor.visible and editor.mode.is_empty(),"HUD Back exits Move before closing the editor")
	editor.controls.visible.grab_focus()
	await press(JOY_BUTTON_A)
	check(not game.hud.widget_layout.values.reserve.visible,"Controller toggles selected HUD visibility")
	await press(JOY_BUTTON_B)
	check(not editor.visible and game.hud.widget_layout.values.reserve.visible,"Editor Back restores its snapshot and returns to Settings")
	if DisplayServer.get_name()!="headless":
		root.mode = Window.MODE_WINDOWED; root.borderless = true; root.size = Vector2i(3840,2160)
		for i in 20: await process_frame
		game.hud.settings_tabs.current_tab = 1
		game.hud.graphics_quality.grab_focus()
		await press(JOY_BUTTON_A)
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		var popup = game.hud.graphics_quality.get_popup()
		DirAccess.make_dir_recursive_absolute("res://artifacts/interface_overhaul/popups")
		popup.get_texture().get_image().save_png("res://artifacts/interface_overhaul/popups/preset_4k.png")
		check(popup.get_texture().get_image().get_height()>=int(popup.size.y*1.79),"Embedded popup typography follows the 4K UI canvas scale")
		print("POPUP_SCALE factor=",popup.content_scale_factor," logical=",popup.get_visible_rect()," output=",popup.size," UI_factor=",float(root.size.y)/root.content_scale_size.y," embedded=",popup.is_embedded()," image=",popup.get_texture().get_size())
		await press(JOY_BUTTON_B)
	print("MENU_NAVIGATION_RESULTS ",JSON.stringify({"failures":failures}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
