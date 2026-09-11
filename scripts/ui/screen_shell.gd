extends Node
## Responsive layout and presentation-only UI preferences; UI draws at output pixels.
const Store = preload("res://scripts/ui/preference_store.gd")
const PATH = "user://interface_layout_v1.cfg"
signal preferences_changed
var hud
var ui_scale = 1.0
var safe_area = .025
var hud_backgrounds = false
var windows: Array[Control] = []
var origins: Dictionary = {}
var applying_size = false

func setup(owner_hud) -> void:
	hud = owner_hud
	if hud.feedback.persist: restore(Store.read_values(PATH,1))
	get_window().size_changed.connect(resize)
	resize()

func snapshot() -> Dictionary:
	return {"ui_scale":ui_scale,"safe_area":safe_area,"hud_backgrounds":hud_backgrounds}

func restore(values: Dictionary) -> void:
	for key in ["ui_scale","safe_area"]:
		var value = values.get(key,get(key))
		if (value is float or value is int) and is_finite(value): set(key,float(value))
	ui_scale = clampf(ui_scale,.85,1.4)
	safe_area = clampf(safe_area,0.0,.08)
	if values.get("hud_backgrounds") is bool: hud_backgrounds = values.hud_backgrounds
	preferences_changed.emit()

func change(key: String, value: Variant) -> void:
	restore({key:value})
	resize()
	if hud.feedback.persist and Store.write_values(PATH,1,snapshot())!=OK: hud.toast("Could not save interface settings.")

func frame(panel: Control, drawer: bool = false) -> void:
	panel.set_meta("screen_drawer",drawer)
	if panel not in windows:
		windows.append(panel)
		panel.visibility_changed.connect(func():
			if panel.visible:
				var focus = get_viewport().gui_get_focus_owner()
				if focus and not panel.is_ancestor_of(focus): origins[panel] = weakref(focus)
			elif origins.has(panel):
				var focus = origins[panel].get_ref()
				if is_instance_valid(focus): _restore_focus.call_deferred(focus)
		)
	_layout(panel)

func _restore_focus(control: Control) -> void:
	if control.is_visible_in_tree() and control.focus_mode!=Control.FOCUS_NONE: control.grab_focus()

func resize() -> void:
	if applying_size or hud==null: return
	applying_size = true
	var pixels = Vector2(get_window().size)
	var factor = clampf(pixels.y/900.0,1.0,1.8)*ui_scale
	factor = minf(factor,minf(pixels.x/1100.0,pixels.y/660.0))
	get_window().content_scale_size = Vector2i((pixels/maxf(factor,.5)).round())
	for panel in windows:
		if is_instance_valid(panel): _layout(panel)
	applying_size = false
	if hud.has_method("layout_widgets"): hud.layout_widgets()

func _layout(panel: Control) -> void:
	if panel.has_meta("preview_layout") and panel.get_meta("preview_layout"): return
	var logical = Vector2(get_window().content_scale_size)
	var edge = maxf(24.0,logical.x*safe_area)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = edge
	panel.offset_right = -edge
	panel.offset_top = maxf(100.0,logical.y*safe_area)
	panel.offset_bottom = -maxf(66.0,logical.y*safe_area)
	if panel.get_meta("screen_drawer",false):
		panel.anchor_right = 0.0
		panel.offset_right = edge+minf(480.0,logical.x*.36)

static func group(parent: Control, caption: String, hud_owner, expanded: bool = false) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation",12)
	parent.add_child(section)
	var toggle = hud_owner._button(caption)
	toggle.toggle_mode = true
	toggle.button_pressed = expanded
	section.add_child(toggle)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation",18)
	section.add_child(body)
	body.visible = expanded
	toggle.set_meta("group_body",body)
	toggle.toggled.connect(func(value):
		var focus = body.get_viewport().gui_get_focus_owner()
		if not value and focus and body.is_ancestor_of(focus): toggle.grab_focus()
		body.visible = value
		toggle.text = ("−  " if value else "+  ")+caption
	)
	toggle.text = ("−  " if expanded else "+  ")+caption
	return body
