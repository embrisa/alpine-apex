extends Node
## Drawer focus and deliberate terrain placement share the existing survey camera.
const State = preload("res://scripts/ui/session_navigation_input.gd")
const Overlay = preload("res://scripts/ui/session_navigation_overlay.gd")
const Prompts = preload("res://scripts/ui/controller_prompts.gd")
var workshop
var game
var model
var panel: PanelContainer
var points_list: ItemList
var count_label: Label
var status: Label
var hints: Label
var add_button: Button
var move_button: Button
var remove_button: Button
var show_button: Button
var clear_button: Button
var overlay
var input_state = State.new()
var selected_id: int = -1
var operation: String = "add"
var preview: Variant = null
var device_switched: bool = false
var _preview_camera = Transform3D.IDENTITY
var _preview_screen = Vector2.INF
var _pick_delay: float = 0.0

func build(owner_workshop, state) -> void:
	workshop = owner_workshop
	game = workshop.game
	model = state
	var hud = game.hud
	panel = hud._panel()
	panel.name = "SessionNavigation"
	var shell = hud._window(panel)
	shell.add_theme_constant_override("separation",12)
	hud.menu_backgrounds.erase(panel)
	hud.shell_layout.frame(panel,true)
	shell.add_child(hud._label("Map / Navigation",26,hud.WHITE))
	hud._note(shell,"Personal landmarks · current session only")
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(scroll)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	count_label = hud._label("",16,hud.MUTED)
	content.add_child(count_label)
	points_list = ItemList.new()
	points_list.custom_minimum_size.y = 130
	points_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	points_list.item_selected.connect(func(index): select_point(int(points_list.get_item_metadata(index))))
	content.add_child(points_list)
	var actions = GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation",8)
	actions.add_theme_constant_override("v_separation",8)
	content.add_child(actions)
	add_button = _button(actions,"Add point",begin_add)
	move_button = _button(actions,"Move",begin_move)
	remove_button = _button(actions,"Remove",remove_selected)
	show_button = _button(actions,"Hide beams",func(): model.set_shown(not model.shown))
	clear_button = _button(actions,"Clear all",clear_all)
	_button(actions,"At skier",func(): workshop.focus_point = game.sim.position; workshop._update_survey())
	status = hud._label("",15,hud.LIME)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 42
	content.add_child(status)
	hints = hud._label("",14,hud.MUTED)
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hints)
	_button(shell,"Back",back)
	overlay = Overlay.new()
	overlay.name = "NavigationMapNumbers"
	overlay.tool = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.hide()
	panel.hide()
	model.changed.connect(refresh)
	game.navigation.device_changed.connect(_device_changed)
	get_viewport().gui_focus_changed.connect(_focus_changed)
	get_window().focus_exited.connect(suspend)
	refresh()

func _button(parent: Control, caption: String, action: Callable) -> Button:
	var result: Button = game.hud._button(caption)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func open() -> void:
	operation = "add"
	device_switched = false
	panel.show()
	refresh()
	status.text = "Place points along your descent. Nothing is saved to disk."
	if is_controller(): focus_panel()
	else: enter_terrain()

func close() -> void:
	input_state.reset()
	preview = null
	panel.hide()
	overlay.hide()

func is_controller() -> bool:
	return game.navigation.family != "keyboard"

func over_panel(screen: Vector2) -> bool:
	return panel.visible and panel.get_global_rect().has_point(screen)

func target_screen() -> Vector2:
	if not is_controller(): return get_viewport().get_mouse_position()
	# The reticle lives in the uncovered portion of the output at every UI scale.
	var bounds = get_viewport().get_visible_rect()
	return Vector2((panel.get_global_rect().end.x+bounds.end.x)*.5,bounds.get_center().y)

func refresh() -> void:
	if panel == null: return
	var entries: Array = model.points()
	if model.point(selected_id).is_empty(): selected_id = -1
	points_list.clear()
	for entry in entries:
		points_list.add_item("Point %d   ·   %.0f m altitude" % [entry.id,entry.position.y])
		var index = points_list.item_count-1
		points_list.set_item_metadata(index,entry.id)
		if entry.id == selected_id: points_list.select(index)
	count_label.text = "%d / 32 points%s" % [entries.size()," · LIMIT REACHED" if entries.size()==32 else ""]
	move_button.disabled = selected_id < 0
	remove_button.disabled = selected_id < 0
	clear_button.disabled = entries.is_empty()
	show_button.text = "Hide beams" if model.shown else "Show beams"
	_refresh_hints()

func select_point(id: int) -> void:
	if model.point(id).is_empty(): return
	selected_id = id
	operation = "select"
	status.text = "Point %d selected. Move or remove it from this panel." % id
	refresh()

func begin_add() -> void:
	if model.count() >= model.MAX_POINTS:
		status.text = "All 32 points are in use. Remove a point to add another."
		return
	operation = "add"
	status.text = "Choose terrain for a new navigation point."
	enter_terrain()

func begin_move() -> void:
	if model.point(selected_id).is_empty(): return
	operation = "move"
	status.text = "Move point %d. Back cancels without changing it." % selected_id
	enter_terrain()

func enter_terrain() -> void:
	game.navigation.cancel_repeat()
	get_viewport().gui_release_focus()
	input_state.enter(is_controller())
	_preview_screen = Vector2.INF
	_pick_delay = 0.0
	# Physical held axes cannot be treated as a fresh neutral event on entry.
	if is_controller() and game.navigation.device in Input.get_connected_joypads():
		input_state.stick = Vector2(Input.get_joy_axis(game.navigation.device,JOY_AXIS_LEFT_X),Input.get_joy_axis(game.navigation.device,JOY_AXIS_LEFT_Y))
		input_state.zoom_axis = Input.get_joy_axis(game.navigation.device,JOY_AXIS_RIGHT_Y)
		input_state.axes_armed = input_state.stick.length()<.25 and absf(input_state.zoom_axis)<.25
	_refresh_hints()

func suspend() -> void:
	input_state.reset()
	preview = null
	_preview_screen = Vector2.INF
	if workshop: workshop.cursor.hide()
	_refresh_hints()

func focus_panel() -> void:
	suspend()
	game.navigation.cancel_repeat()
	if panel.visible: add_button.grab_focus()

func _focus_changed(control: Control) -> void:
	if panel.visible and control and (control==panel or panel.is_ancestor_of(control)):
		suspend()

func _device_changed() -> void:
	if not panel.visible: return
	focus_panel()
	device_switched = true
	status.text = "Controls changed. Select Add point or Move selected to place terrain points."

func back() -> void:
	if operation == "move":
		operation = "select"
		focus_panel()
		status.text = "Move cancelled. Point %d is unchanged." % selected_id
	elif input_state.terrain_active:
		focus_panel()
		status.text = "Map controls paused. Choose an action, or Back to leave."
	else:
		workshop.leave_navigation()

func remove_selected() -> void:
	var id = selected_id
	operation = "select"
	if model.remove_point(id): status.text = "Point %d removed." % id
	refresh()

func clear_all() -> void:
	operation = "add"
	selected_id = -1
	model.clear_points()
	status.text = "All personal points cleared."
	refresh()

func confirm_at(screen: Vector2) -> bool:
	if not input_state.terrain_active or over_panel(screen): return false
	overlay.refresh()
	if operation != "move":
		var nearest: int = overlay.nearest(screen)
		if nearest >= 0:
			select_point(nearest)
			focus_panel()
			return true
	var hit = workshop.pick_terrain(screen)
	if not hit is Vector3:
		status.text = "Choose supported terrain inside the skiable mountain."
		return false
	var result: Dictionary = model.move_point(selected_id,game.field,hit) if operation == "move" else model.add_point(game.field,hit)
	if not result.error.is_empty():
		status.text = result.error
		game.hud.feedback.play("error")
		return false
	selected_id = result.id
	status.text = "Point %d %s.%s" % [selected_id,"moved" if operation=="move" else "added"," Beams are hidden; Show beams restores them." if not model.shown else ""]
	if operation == "move":
		operation = "select"
		focus_panel()
	refresh()
	game.hud.feedback.play("success")
	return true

func route_event(event: InputEvent) -> bool:
	if not panel.visible or event.has_meta("menu_owned"): return false
	if device_switched:
		device_switched = false
		return true # A device-change gesture never also places/activates a point.
	if not game.application_focused: suspend(); return true
	if event is InputEventMouseButton and over_panel(event.position):
		if event.pressed: suspend()
		return false # Real GUI consumes drawer clicks and scrolling.
	if event is InputEventMouseButton:
		if not event.pressed: return true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if operation != "move": operation = "add"
			enter_terrain()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if not input_state.terrain_active:
				if operation != "move": operation = "add"
				enter_terrain()
			confirm_at(event.position)
		elif input_state.terrain_active and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			workshop.survey_height = clampf(workshop.survey_height* (.82 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/.82),45.0,workshop._survey_limit())
		return true
	if not input_state.terrain_active: return false
	var action = ""
	if event is InputEventJoypadMotion:
		input_state.motion(event.axis,event.axis_value)
		return true
	if event is InputEventJoypadButton: action = input_state.button(event.button_index,event.pressed)
	elif event is InputEventKey: action = input_state.key(event)
	else: return false
	match action:
		"confirm": confirm_at(target_screen())
		"back": back()
		"panel": focus_panel()
	return true

func update_survey(dt: float) -> void:
	if not game.application_focused: suspend()
	if input_state.terrain_active:
		var direction: Vector2 = input_state.pan()
		workshop.focus_point += Vector3(-direction.x,0,-direction.y)*workshop.survey_height*minf(dt,.1)*.7
		workshop.survey_height = clampf(workshop.survey_height*exp(input_state.zoom()*minf(dt,.1)),45.0,workshop._survey_limit())
	workshop._update_survey()
	_pick_delay = maxf(0.0,_pick_delay-dt)
	var screen = target_screen()
	if not input_state.terrain_active or over_panel(screen): preview = null
	elif (dt==0.0 or _pick_delay<=0.0) and (screen!=_preview_screen or workshop.survey.global_transform!=_preview_camera):
		# A moving survey previews at most 25 Hz; stationary views reuse the hit.
		# Confirm always picks afresh, independent of this presentation cache.
		_preview_screen = screen
		_preview_camera = workshop.survey.global_transform
		_pick_delay = .04
		preview = null
		var hit = workshop.pick_terrain(screen)
		if hit is Vector3:
			var anchored = model.anchor(game.field,hit)
			if anchored.error.is_empty(): preview = anchored.position
	workshop.cursor.visible = preview is Vector3
	if preview is Vector3: workshop.cursor.position = preview+Vector3.UP*1.5
	overlay.refresh()

func prompts() -> String:
	if not is_controller():
		return "WASD / arrows  Pan · Wheel  Zoom · Click  Place / select · Tab  Panel · Esc  Back" if input_state.terrain_active else "Select Add / Move · Right-click terrain  Map controls · Esc  Back"
	var family: String = game.navigation.family
	if not input_state.terrain_active: return Prompts.menu(family)
	return "Left stick  Pan · Right stick ↑↓  Zoom · %s  Place · %s  Panel · %s  Back" % [Prompts.button(JOY_BUTTON_A,family),Prompts.button(JOY_BUTTON_X,family),Prompts.button(JOY_BUTTON_B,family)]

func _refresh_hints() -> void:
	if hints: hints.text = prompts()
