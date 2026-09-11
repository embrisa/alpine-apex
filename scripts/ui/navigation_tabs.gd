extends TabContainer
## One retained page per category; scrolling, expansion and focus survive tabs.
var rail: VBoxContainer
var row: HBoxContainer
var buttons: Array[Button] = []
var remembered: Dictionary = {}
var previous = 0
var hud

func attach(parent: Control, owner_hud) -> void:
	hud = owner_hud
	row = HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",32)
	parent.add_child(row)
	var rail_scroll = ScrollContainer.new()
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail_scroll.follow_focus = true
	rail_scroll.custom_minimum_size.x = 208
	row.add_child(rail_scroll)
	rail = VBoxContainer.new()
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.add_theme_constant_override("separation",8)
	rail_scroll.add_child(rail)
	row.add_child(self)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_visible = false
	all_tabs_in_front = false
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	tab_changed.connect(_changed)
	get_viewport().gui_focus_changed.connect(_remember_focus)

func add_page(page: Control, caption: String) -> void:
	page.name = caption
	add_child(page)
	var index = buttons.size()
	var button = hud._button(caption)
	button.name = "Category"+caption.replace(" ","")
	button.toggle_mode = true
	button.button_pressed = index==current_tab
	button.pressed.connect(func():
		current_tab = index
		button.set_pressed_no_signal(true)
	)
	rail.add_child(button)
	buttons.append(button)

func _remember_focus(control: Control) -> void:
	if current_tab>=0 and get_current_tab_control() and get_current_tab_control().is_ancestor_of(control):
		remembered[current_tab] = weakref(control)

func _changed(index: int) -> void:
	var focus = get_viewport().gui_get_focus_owner()
	if focus and previous<get_tab_count() and get_tab_control(previous).is_ancestor_of(focus): remembered[previous] = weakref(focus)
	for i in buttons.size(): buttons[i].set_pressed_no_signal(i==index)
	if index>=0 and index<buttons.size(): rail.get_parent().ensure_control_visible.call_deferred(buttons[index])
	previous = index
	if hud:
		hud.feedback.play("press")
		var page = get_current_tab_control()
		if page: hud.feedback.reveal(page)
	if focus and not focus.is_visible_in_tree(): focus_page.call_deferred()

func focus_page() -> void:
	if remembered.has(current_tab):
		var focus = remembered[current_tab].get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree() and not (focus is BaseButton and focus.disabled):
			focus.grab_focus()
			return
	var candidates = focusable(get_current_tab_control())
	if not candidates.is_empty(): candidates[0].grab_focus()
	elif current_tab<buttons.size(): buttons[current_tab].grab_focus()

func cycle(direction: int) -> void:
	current_tab = posmod(current_tab+direction,get_tab_count())
	focus_page.call_deferred()

static func focusable(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	if node is Control:
		if not node.is_visible_in_tree(): return result
		if node.focus_mode==Control.FOCUS_ALL and not (node is BaseButton and node.disabled): result.append(node)
	for child in node.get_children(): result.append_array(focusable(child))
	return result
