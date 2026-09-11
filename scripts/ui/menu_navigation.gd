extends Node
## Menu ownership precedes gameplay. SDL logical buttons; no device-specific indices.
const Tabs = preload("res://scripts/ui/navigation_tabs.gd")
const DEADZONE = .60
const RELEASE_ZONE = .35
const INITIAL_REPEAT = .34
const HELD_REPEAT = .095
var game
var family = "keyboard"
var device = -1
var stick = Vector2.ZERO
var held = Vector2i.ZERO
var repeat_left = 0.0
var last_scope: Node
var virtual_keyboard
var last_focus: WeakRef
var popups: Array[Window] = []
signal device_changed

func setup(owner_game) -> void:
	game = owner_game
	# Raw controller events have one owner, including PopupMenu's native input
	# path. Retain keyboard actions and inject explicit UI actions below.
	for action in ["ui_up","ui_down","ui_left","ui_right","ui_accept","ui_cancel","ui_focus_next","ui_focus_prev"]:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion: InputMap.action_erase_event(action,event)
	Input.joy_connection_changed.connect(_connection_changed)
	_scan_windows(game.hud.root)
	get_tree().node_added.connect(_track_window)
	get_window().focus_exited.connect(cancel_repeat)

func cancel_repeat() -> void:
	stick = Vector2.ZERO
	held = Vector2i.ZERO
	repeat_left = 0.0

func _connection_changed(id: int, connected: bool) -> void:
	cancel_repeat()
	if not connected and id==device:
		device = -1
		family = "keyboard"
		device_changed.emit()
	if scope(): ensure_focus()

static func device_family(name_value: String) -> String:
	var name_lower = name_value.to_lower()
	if "dual" in name_lower or "playstation" in name_lower or "ps4" in name_lower or "ps5" in name_lower: return "playstation"
	if "xbox" in name_lower or "xinput" in name_lower: return "xbox"
	return "gamepad"

func _device_used(event: InputEvent) -> void:
	var next = family
	if event is InputEventJoypadButton and event.pressed or event is InputEventJoypadMotion and absf(event.axis_value)>=DEADZONE:
		device = event.device
		next = device_family(Input.get_joy_name(device))
	elif event is InputEventKey and event.pressed or event is InputEventMouseButton and event.pressed or event is InputEventMouseMotion and event.relative.length()>3.0:
		next = "keyboard"
	if next!=family:
		family = next
		device_changed.emit()

func prompts(authoring: bool = false) -> String:
	if family=="keyboard": return "Arrows / Tab  Navigate     Enter  Select     Esc  Back"+("     Mouse  Place gate · WASD  Survey" if authoring else "")
	var confirm = "×" if family=="playstation" else "A" if family=="xbox" else "South"
	var back = "○" if family=="playstation" else "B" if family=="xbox" else "East"
	var shoulders = "L1 / R1" if family=="playstation" else "LB / RB" if family=="xbox" else "Shoulders"
	return "D-pad / LS  Navigate     %s  Select     %s  Back     %s  Categories%s" % [confirm,back,shoulders,"     Mouse  Terrain placement" if authoring else ""]

func _track_window(node: Node) -> void:
	if node is Window and node!=get_tree().root:
		popups.append(node)
		_attach_bridge.call_deferred(node)

func _attach_bridge(window: Window) -> void:
	if not is_instance_valid(window) or window.has_meta("menu_bridge"): return
	window.set_meta("menu_bridge",true)
	window.about_to_popup.connect(_prepare_popup.bind(window))
	var bridge = preload("res://scripts/ui/popup_navigation_bridge.gd").new()
	bridge.navigation = weakref(self)
	window.add_child(bridge)

func _prepare_popup(window: Window) -> void:
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
	if hud.get("hud_editor") and hud.hud_editor.visible: return hud.hud_editor
	if hud.camera_options.preview_active: return hud.root
	for panel in [game.mountain_library.panel,game.workshop.panel,hud.competition.panel,hud.tuning_panel,hud.weather_panel,hud.menu]:
		if panel.visible: return panel
	return null

func ensure_focus() -> Control:
	var current_scope = scope()
	if current_scope==null: return null
	var viewport: Viewport = current_scope if current_scope is Window else get_viewport()
	var focus = viewport.gui_get_focus_owner()
	if focus and focus.is_visible_in_tree() and (focus==current_scope or current_scope.is_ancestor_of(focus)) and not (focus is BaseButton and focus.disabled): return focus
	var controls = Tabs.focusable(current_scope)
	if not controls.is_empty(): controls[0].grab_focus(); return controls[0]
	return null

func route(event: InputEvent) -> bool:
	if event.has_meta("menu_owned"): return false
	_device_used(event)
	var current_scope = _sync_scope()
	if current_scope==null: cancel_repeat(); return false
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
		if current_scope and family!="keyboard": ensure_focus()
	return current_scope

func _process(dt: float) -> void:
	var current_scope = _sync_scope()
	if current_scope==null: return
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
	if hud.camera_options.preview_active: game.set_camera_preview(false)
	elif game.mountain_library.panel.visible: game.mountain_library.close()
	elif not game.workshop.mode.is_empty(): game.workshop.back_pressed()
	elif hud.competition.panel.visible: hud.close_competition()
	elif hud.tuning_panel.visible: game.close_workbench()
	elif hud.weather_panel.visible: hud.close_weather()
	elif hud.menu_mode=="paused": game.resume()
