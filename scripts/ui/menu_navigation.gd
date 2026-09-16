extends Node
## Menu ownership precedes gameplay. SDL logical buttons; no device-specific indices.
const Tabs = preload("res://scripts/ui/navigation_tabs.gd")
const Prompts = preload("res://scripts/ui/controller_prompts.gd")
const DEVICE_DEADZONE = .25
const DEADZONE = .60
const RELEASE_ZONE = .35
const INITIAL_REPEAT = .34
const HELD_REPEAT = .095
var game
var family = "keyboard"
var device = -1
var active_device_name = "Keyboard & mouse"
var stick = Vector2.ZERO
var held = Vector2i.ZERO
var repeat_left = 0.0
var last_scope: Node
var virtual_keyboard
var last_focus: WeakRef
var popups: Array[Window] = []
signal device_changed

func _ready() -> void:
	Input.joy_connection_changed.connect(_connection_changed)
	var pads = _connected_devices()
	var previous = int(get_tree().get_meta("interface_controller",-1))
	if get_tree().get_meta("interface_device","") == "keyboard": _select_device(-1)
	elif previous in pads: _select_device(previous)
	else: _select_device(pads[0] if not pads.is_empty() else -1)

func setup(owner_game) -> void:
	game = owner_game
	# Raw controller events have one owner, including PopupMenu's native input
	# path. Retain keyboard actions and inject explicit UI actions below.
	for action in ["ui_up","ui_down","ui_left","ui_right","ui_accept","ui_cancel","ui_focus_next","ui_focus_prev"]:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion: InputMap.action_erase_event(action,event)
	_scan_windows(game.hud.root)
	get_tree().node_added.connect(_track_window)
	get_window().focus_exited.connect(cancel_repeat)
	# Scope owners announce themselves; per-frame scope scans stop while riding.
	# Any input event also wakes processing (see _device_used).
	var hud = game.hud
	var workshop = game.workshop
	for owner in [hud.menu,hud.weather_panel,hud.competition.panel,hud.tuning_panel,workshop.panel,game.mountain_library.panel,workshop.navigation_panel.panel if workshop.get("navigation_panel") else null,game.loading.overlay if game.loading else null,hud.get("hud_editor"),hud.camera_options.get("preview_toolbar")]:
		if owner is CanvasItem: owner.visibility_changed.connect(wake)
	get_window().focus_entered.connect(wake)

func wake() -> void:
	if not is_processing(): set_process(true)

func cancel_repeat() -> void:
	stick = Vector2.ZERO
	held = Vector2i.ZERO
	repeat_left = 0.0

func _connection_changed(id: int, connected: bool) -> void:
	wake()
	cancel_repeat()
	if connected and device < 0: _select_device(id)
	elif not connected and id == device:
		var pads = _connected_devices()
		pads.erase(id)
		_select_device(pads[0] if not pads.is_empty() else -1)
	var current_scope = scope()
	if current_scope and not _surveying(current_scope): ensure_focus()

func _connected_devices() -> Array[int]:
	return Input.get_connected_joypads()

func _device_info(id: int) -> Dictionary:
	# Synthetic validation events may target a pad that is not physically attached.
	if id not in _connected_devices(): return {"mapped_name":"Gamepad"}
	var info = Input.get_joy_info(id)
	info["mapped_name"] = Input.get_joy_name(id)
	return info

func _select_device(id: int) -> void:
	var next = "keyboard"
	active_device_name = "Keyboard & mouse"
	if id >= 0:
		var info = _device_info(id)
		next = Prompts.device_family(str(info.get("mapped_name","")),info)
		active_device_name = str(info.get("mapped_name","Gamepad"))
	var changed = id != device or next != family
	device = id
	family = next
	get_tree().set_meta("interface_device",family)
	get_tree().set_meta("interface_controller",device)
	if changed: device_changed.emit()

func device_label() -> String:
	return active_device_name

func _device_used(event: InputEvent) -> void:
	wake()
	var pad_used = event is InputEventJoypadButton and event.pressed
	if event is InputEventJoypadMotion:
		# Trigger release/negative rest cannot steal prompts from the keyboard.
		pad_used = absf(event.axis_value) >= DEVICE_DEADZONE if event.axis < JOY_AXIS_TRIGGER_LEFT else event.axis <= JOY_AXIS_TRIGGER_RIGHT and event.axis_value >= DEVICE_DEADZONE
	if pad_used:
		if event.device != device or family == "keyboard": _select_device(event.device)
	elif event is InputEventKey and event.pressed or event is InputEventMouseButton and event.pressed or event is InputEventMouseMotion and event.relative.length()>3.0:
		if family != "keyboard": _select_device(-1)

func prompts(authoring: bool = false) -> String:
	return Prompts.menu(family,authoring)

func _track_window(node: Node) -> void:
	if node is Window and node!=get_tree().root:
		if node not in popups:
			popups.append(node)
			node.visibility_changed.connect(wake)
		_attach_bridge.call_deferred(node)

func _attach_bridge(window: Window) -> void:
	if not is_instance_valid(window) or window.has_meta("menu_bridge"): return
	window.set_meta("menu_bridge",true)
	window.about_to_popup.connect(_prepare_popup.bind(window))
	var bridge = preload("res://scripts/ui/popup_navigation_bridge.gd").new()
	bridge.navigation = weakref(self)
	window.add_child(bridge)

func _prepare_popup(window: Window) -> void:
	# Activation order owns nested dialogs; reparenting must not grow the registry.
	popups.erase(window)
	popups.append(window)
	# PopupMenu already derives its scale from the parent canvas in _pre_popup.
	if window is PopupMenu: return
	var output = get_tree().root
	var factor = float(output.size.y)/maxi(output.content_scale_size.y,1)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_factor = 1.0 if window.is_embedded() else clampf(factor,.5,2.52)
	if window.theme==null: window.theme = game.hud.root.theme

func _scan_windows(node: Node) -> void:
	_track_window(node)
	for child in node.get_children(true): _scan_windows(child)

func top_popup() -> Window:
	for i in range(popups.size()-1,-1,-1):
		var popup = popups[i]
		if not is_instance_valid(popup): popups.remove_at(i)
		elif popup.visible: return popup
	return null

func scope() -> Node:
	if game==null or not game.initialized: return null
	var popup = top_popup()
	if popup: return popup
	var hud = game.hud
	if game.loading and game.loading.busy: return game.loading.overlay
	if game.get("test_cases") and game.test_cases.ui.panel.visible: return game.test_cases.ui.panel
	if hud.get("hud_editor") and hud.hud_editor.visible: return hud.hud_editor
	if hud.camera_options.preview_active: return hud.root
	if game.workshop.mode=="navigation": return game.workshop.navigation_panel.panel
	for panel in [game.mountain_library.panel,game.workshop.panel,hud.competition.panel,hud.tuning_panel,hud.weather_panel,hud.menu]:
		if panel.visible: return panel
	return null

func ensure_focus() -> Control:
	var current_scope = scope()
	if current_scope==null: return null
	if current_scope==game.hud.menu and game.hud.compact_menu.is_crash_actions(): return null
	var viewport: Viewport = current_scope if current_scope is Window else get_viewport()
	var focus = viewport.gui_get_focus_owner()
	if focus and focus.is_visible_in_tree() and (focus==current_scope or current_scope.is_ancestor_of(focus)) and not (focus is BaseButton and focus.disabled): return focus
	var controls = Tabs.focusable(current_scope)
	if not controls.is_empty(): controls[0].grab_focus(); return controls[0]
	return null

func route(event: InputEvent) -> bool:
	if event.has_meta("menu_owned"): return false
	_device_used(event)
	if game and game.initialized and game.workshop.mode=="navigation" and not top_popup() and not game.loading.busy:
		if game.workshop.navigation_panel.route_event(event): return true
	var current_scope = _sync_scope()
	if current_scope==null: cancel_repeat(); return false
	if current_scope==game.hud.menu:
		var hud = game.hud
		if hud.compact_menu.is_crash_actions():
			if _pressed(event,"pause_run") or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B):
				game.toggle_crash_pause()
			elif _pressed(event,"begin_run") and not hud.primary.disabled:
				hud._primary_pressed()
			elif _pressed(event,"restart"):
				hud.restart_requested.emit()
			return event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion
		if _pressed(event,"restart") and hud.crash_restart.is_visible_in_tree():
			hud.restart_requested.emit()
			return true
	if event is InputEventJoypadMotion:
		if event.axis==JOY_AXIS_LEFT_X: stick.x = event.axis_value
		elif event.axis==JOY_AXIS_LEFT_Y: stick.y = event.axis_value
		else: return true
		if stick.length()<RELEASE_ZONE: cancel_repeat()
		elif maxf(absf(stick.x),absf(stick.y))>=DEADZONE:
			var direction = Vector2i(signi(roundi(stick.x)),0) if absf(stick.x)>absf(stick.y) else Vector2i(0,signi(roundi(stick.y)))
			if held!=direction:
				held = direction; repeat_left = INITIAL_REPEAT
				move_focus(direction)
		return true
	if event is InputEventJoypadButton:
		var directions = {JOY_BUTTON_DPAD_LEFT:Vector2i.LEFT,JOY_BUTTON_DPAD_RIGHT:Vector2i.RIGHT,JOY_BUTTON_DPAD_UP:Vector2i.UP,JOY_BUTTON_DPAD_DOWN:Vector2i.DOWN}
		if directions.has(event.button_index):
			if event.pressed:
				held = directions[event.button_index]; repeat_left = INITIAL_REPEAT
				move_focus(held)
			else: cancel_repeat()
		elif event.pressed:
			match event.button_index:
				JOY_BUTTON_A: activate()
				JOY_BUTTON_B, JOY_BUTTON_START: back()
				JOY_BUTTON_LEFT_SHOULDER: cycle(-1)
				JOY_BUTTON_RIGHT_SHOULDER: cycle(1)
		return true
	if event is InputEventKey:
		if current_scope==game.workshop.panel and game.workshop.mode=="create" and game.workshop.owns_survey_key(event): return true
		if game.hud.hud_editor and game.hud.hud_editor.visible and event.pressed:
			var arrows = {KEY_LEFT:Vector2i.LEFT,KEY_RIGHT:Vector2i.RIGHT,KEY_UP:Vector2i.UP,KEY_DOWN:Vector2i.DOWN}
			if arrows.has(event.physical_keycode) and game.hud.hud_editor.handle_direction(arrows[event.physical_keycode]): return true
		if event.is_action_pressed("pause_run") or event.is_action_pressed("ui_cancel"):
			back(); return true
		if event.pressed and not event.echo and event.physical_keycode in [KEY_Q,KEY_E] and not ensure_focus() is LineEdit and not ensure_focus() is TextEdit:
			cycle(-1 if event.physical_keycode==KEY_Q else 1); return true
		# Let real text/GUI controls handle keyboard editing. Block rider shortcuts
		# at the unhandled stage as well, including R and camera shoulder aliases.
	return false

func _sync_scope() -> Node:
	var current_scope = scope()
	if current_scope!=last_scope:
		cancel_repeat()
		last_scope = current_scope
		if current_scope and family!="keyboard" and not _surveying(current_scope): ensure_focus()
	return current_scope

func _surveying(current_scope: Node) -> bool:
	if game.workshop.mode=="navigation":
		return current_scope==game.workshop.navigation_panel.panel and game.workshop.navigation_panel.input_state.terrain_active
	return current_scope==game.workshop.panel and game.workshop.mode=="create" and game.workshop.survey_keyboard_enabled

func _process(dt: float) -> void:
	var current_scope = _sync_scope()
	if current_scope==null:
		# Nothing to focus or repeat: sleep until input, a connection change or
		# a scope owner (panel, popup, overlay, window focus) changes visibility.
		if held==Vector2i.ZERO: set_process(false)
		return
	if not get_window().has_focus() and not (current_scope is Window and current_scope.has_focus()): return
	if held!=Vector2i.ZERO:
		repeat_left -= dt
		if repeat_left<=0.0:
			repeat_left = HELD_REPEAT # At most one repeat per rendered frame.
			move_focus(held)

func _action(action: String) -> void:
	var current_scope = scope()
	var viewport: Viewport = current_scope if current_scope is Window else get_viewport()
	for pressed in [true,false]:
		var event = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		event.set_meta("menu_owned",true)
		viewport.push_input(event)

func move_focus(direction: Vector2i) -> void:
	var popup = top_popup()
	if popup is PopupMenu:
		if direction.y==0: return
		var index = popup.get_focused_item()
		for offset in range(1,popup.item_count+1):
			var candidate = posmod(index+direction.y*offset,popup.item_count)
			if not popup.is_item_disabled(candidate) and not popup.is_item_separator(candidate):
				popup.set_focused_item(candidate)
				popup.scroll_to_item(candidate)
				game.hud.feedback.play("hover")
				return
		return
	if game.hud.get("hud_editor") and game.hud.hud_editor.visible and game.hud.hud_editor.handle_direction(direction): return
	var focus = ensure_focus()
	if focus is Range and direction.x!=0:
		focus.value += direction.x*focus.step
		game.hud.feedback.play("adjust")
		return
	_action("ui_left" if direction.x<0 else "ui_right" if direction.x>0 else "ui_up" if direction.y<0 else "ui_down")
	ensure_focus()

func activate() -> void:
	var popup = top_popup()
	if popup is PopupMenu:
		var index = popup.get_focused_item()
		if index<0 or popup.is_item_disabled(index) or popup.is_item_separator(index): return
		var submenu = popup.get_item_submenu(index)
		if not submenu.is_empty():
			var child = popup.get_node_or_null(submenu)
			if child is PopupMenu: child.popup(Rect2i(popup.position+Vector2i(popup.size.x,0),Vector2i.ZERO))
			return
		var id = popup.get_item_id(index)
		var hide_after: bool = popup.hide_on_checkable_item_selection if popup.is_item_checkable(index) or popup.is_item_radio_checkable(index) else popup.hide_on_item_selection
		if hide_after: popup.hide()
		popup.id_pressed.emit(id if id>=0 else index)
		popup.index_pressed.emit(index)
		game.hud.feedback.play("press")
		return
	var focus = ensure_focus()
	if focus is LineEdit or focus is TextEdit:
		if virtual_keyboard: virtual_keyboard.open(focus)
		return
	_action("ui_accept")

func cycle(direction: int) -> void:
	if top_popup(): return
	if game.hud.get("hud_editor") and game.hud.hud_editor.visible:
		game.hud.hud_editor.select_relative(direction); return
	var current_scope = scope()
	var tabs = _visible_tabs(current_scope)
	if tabs: tabs.cycle(direction)

func _visible_tabs(node: Node) -> Node:
	if node is Tabs and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var found = _visible_tabs(child)
		if found: return found
	return null

func back() -> void:
	cancel_repeat()
	game.hud.feedback.play("back")
	var popup = top_popup()
	if popup:
		if popup is AcceptDialog: popup.canceled.emit()
		popup.hide()
		return
	var hud = game.hud
	if game.loading and game.loading.busy: return
	if hud.get("hud_editor") and hud.hud_editor.visible: hud.hud_editor.back(); return
	if game.get("test_cases") and (game.test_cases.ui.panel.visible or game.test_cases.camera_active): game.test_cases.back()
	elif hud.camera_options.preview_active: game.set_camera_preview(false)
	elif game.mountain_library.panel.visible: game.mountain_library.close()
	elif not game.workshop.mode.is_empty(): game.workshop.back_pressed()
	elif hud.competition.panel.visible: hud.close_competition()
	elif hud.tuning_panel.visible: game.close_workbench()
	elif hud.weather_panel.visible: hud.close_weather()
	elif hud.menu.visible and hud.menu_tabs.current_tab!=0: hud.compact_menu.back_home()
	elif hud.menu_mode=="crashed": game.toggle_crash_pause()
	elif hud.menu_mode=="paused": game.resume()

func _pressed(event: InputEvent, action: String) -> bool:
	if event.is_action_pressed(action): return true
	# Logical menu bindings apply to whichever pad is active, including pad 2+.
	if not event is InputEventJoypadButton or not event.pressed or not InputMap.has_action(action): return false
	for mapped in InputMap.action_get_events(action):
		if mapped is InputEventJoypadButton and mapped.is_match(event): return true
	return false
