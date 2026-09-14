extends PanelContainer
## Frozen gameplay preview; edits never advance the solver or mutate race identity.
var hud
var selected = "speed"
var original: Dictionary = {}
var opening = false
var mode = ""
var coarse = false
var snapping = false
var ids: Array = []
var list: ItemList
var stage: Control
var preview_space: Control
var photograph: TextureRect
var canvas: Control
var controls: Dictionary = {}
var status: Label
var move_button: Button
var resize_button: Button
var context: OptionButton
var sample_text: Dictionary = {}
var original_timed = false

func setup(owner_hud) -> void:
	hud = owner_hud
	name = "HUDEditor"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel",hud._style(hud.AlpineTheme.PANEL,hud.MUTED,24))
	var shell = VBoxContainer.new()
	shell.add_theme_constant_override("separation",16)
	add_child(shell)
	shell.add_child(hud._label("Edit HUD",30,hud.WHITE))
	var row = HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",20)
	shell.add_child(row)
	var left = VBoxContainer.new()
	left.custom_minimum_size.x = 190
	row.add_child(left)
	left.add_child(hud._label("Instruments",18,hud.WHITE))
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(190,180)
	left.add_child(list)
	ids = hud.widget_layout.widgets.keys()
	for id in ids: list.add_item(hud.widget_layout.widgets[id].label)
	list.item_selected.connect(func(index): select(ids[index]))
	context = OptionButton.new()
	for label in ["Timed race","Free ski","Low reserve","Near finish"]: context.add_item(label)
	left.add_child(context)
	context.item_selected.connect(func(_index): _sample(); refresh())
	preview_space = Control.new()
	preview_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(preview_space)
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_space.add_child(stage)
	photograph = TextureRect.new()
	photograph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photograph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photograph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(photograph)
	var right_scroll = ScrollContainer.new()
	right_scroll.custom_minimum_size.x = 225
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.follow_focus = true
	row.add_child(right_scroll)
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",12)
	right_scroll.add_child(right)
	var visibility = CheckButton.new()
	visibility.text = "Visible"
	visibility.toggled.connect(func(value): hud.widget_layout.values[selected].visible = value; refresh())
	right.add_child(visibility)
	controls.visible = visibility
	for item in [["scale","Size",.5,2.0,.05],["opacity","Opacity",0.0,1.0,.05]]:
		right.add_child(hud._label(item[1],16,hud.WHITE))
		var slider = HSlider.new()
		slider.min_value = item[2]; slider.max_value = item[3]; slider.step = item[4]
		slider.custom_minimum_size.y = 36
		var key: String = item[0]
		slider.value_changed.connect(func(value): hud.widget_layout.values[selected][key] = value; refresh())
		right.add_child(slider)
		controls[key] = slider
	move_button = hud._button("Move")
	move_button.toggle_mode = true
	move_button.pressed.connect(func(): set_mode("" if mode=="move" else "move"))
	right.add_child(move_button)
	resize_button = hud._button("Resize")
	resize_button.toggle_mode = true
	resize_button.pressed.connect(func(): set_mode("" if mode=="resize" else "resize"))
	right.add_child(resize_button)
	for label in ["Coarse steps","Snap to grid"]:
		var toggle = CheckButton.new()
		toggle.text = label
		toggle.toggled.connect(func(value):
			if label=="Coarse steps": coarse = value
			else: snapping = value
			canvas.queue_redraw()
		)
		right.add_child(toggle)
	var reset_widget = hud._button("Reset instrument")
	reset_widget.pressed.connect(func(): hud.widget_layout.reset_widget(selected); refresh())
	right.add_child(reset_widget)
	var reset_all = hud._button("Reset layout")
	reset_all.pressed.connect(func(): hud.widget_layout.restore({}); refresh())
	right.add_child(reset_all)
	status = hud._note(shell,"")
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation",16)
	shell.add_child(actions)
	var cancel = hud._button("Cancel")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func(): close(false))
	actions.add_child(cancel)
	var apply = hud._button("Apply layout",true)
	apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply.pressed.connect(func(): close(true))
	actions.add_child(apply)
	canvas = preload("res://scripts/ui/hud_editor_canvas.gd").new()
	canvas.editor = self
	stage.add_child(canvas)
	preview_space.resized.connect(_fit)
	hide()
	hud.register_menu_background(self)

func open() -> void:
	if opening or visible: return
	opening = true
	original = hud.widget_layout.snapshot()
	original_timed = hud.widget_layout.timed
	stage.size = hud.root.size
	hud.root.hide()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		photograph.texture = ImageTexture.create_from_image(hud.get_viewport().get_texture().get_image())
	hud.root.show()
	hud.weather_panel.hide()
	hud.widget_layout.preview = true
	for id in ids:
		var widget = hud.widget_layout.widgets[id]
		widget.node.reparent(stage)
	stage.move_child(canvas,stage.get_child_count()-1)
	show()
	_sample()
	_fit()
	select(selected)
	list.grab_focus()
	opening = false

func _sample() -> void:
	hud.widget_layout.timed = context.selected!=1
	for label in [hud.speed_label,hud.timer_label,hud.pb_label,hud.state_label,hud.split_label,hud.altitude_label,hud.conditions,hud.fps_label,hud.toast_label,hud.summit_return_label,hud.mode_label]:
		if not sample_text.has(label): sample_text[label] = {"text":label.text,"visible":label.visible}
	hud.speed_label.text = "128"
	hud.speed_dial.speed = 128.0
	hud.speed_dial.queue_redraw()
	hud.timer_label.text = "01:24.680"
	hud.pb_label.text = "PERSONAL BEST  01:26.340"
	hud.split_label.text = "75%  ·  −00:01.660\nAHEAD OF PERSONAL BEST"
	hud.state_label.text = "LOW IMPACT RESERVE" if context.selected==2 else "CARVING"
	hud.impact_bar.value = 24 if context.selected==2 else 86
	hud.progress.value = 94 if context.selected==3 else 75
	hud.altitude_label.text = "3 260 m  ·  CLEAR  ·  DAY"
	hud.conditions.text = "NORTH FACE"
	hud.fps_label.text = "120 rendered FPS"
	hud.mode_label.show()
	hud.mode_label.text = "TIMED RACE" if hud.widget_layout.timed else "FREE SKI"
	hud.toast_label.text = "PERSONAL BEST"
	hud.toast_label.show()
	hud.summit_return_label.text = "Summit return · 80 m"
	hud.summit_return_label.show()

func _fit() -> void:
	if stage==null or preview_space.size.x<=0: return
	stage.size = hud.root.size
	var factor = minf(preview_space.size.x/stage.size.x,preview_space.size.y/stage.size.y)
	stage.scale = Vector2.ONE*factor
	stage.position = (preview_space.size-stage.size*factor)*.5
	canvas.size = stage.size
	refresh()

func select(id: String) -> void:
	selected = id
	list.select(ids.find(id))
	set_mode("")
	refresh()

func select_relative(direction: int) -> void:
	select(ids[posmod(ids.find(selected)+direction,ids.size())])

func set_mode(value: String) -> void:
	mode = value
	move_button.set_pressed_no_signal(mode=="move")
	resize_button.set_pressed_no_signal(mode=="resize")
	refresh()

func handle_direction(direction: Vector2i) -> bool:
	if mode.is_empty(): return false
	var value = hud.widget_layout.values[selected]
	if mode=="move":
		var node = hud.widget_layout.widgets[selected].node
		hud.widget_layout.move_pixel(selected,node.position+Vector2(direction)*(24.0 if coarse else 8.0 if snapping else 4.0),stage.size,snapping)
	else:
		value.scale = clampf(value.scale+(direction.x-direction.y)*(.1 if coarse else .025),.5,2.0)
	refresh()
	return true

func refresh() -> void:
	if not controls.has("visible") or not hud.widget_layout.values.has(selected): return
	var value = hud.widget_layout.values[selected]
	controls.visible.set_pressed_no_signal(value.visible)
	controls.scale.set_value_no_signal(value.scale)
	controls.opacity.set_value_no_signal(value.opacity)
	hud.widget_layout.safe_area = hud.shell_layout.safe_area
	if visible: hud.widget_layout.apply(stage.size)
	canvas.queue_redraw()
	status.text = "%s · Size %d%% · Opacity %d%%\n%s" % [hud.widget_layout.widgets[selected].label,roundi(value.scale*100),roundi(value.opacity*100),"Directions adjust · Back exits "+mode if not mode.is_empty() else "Select an instrument, then Move or Resize. Shoulders select instruments. Drag with the mouse."]

func back() -> void:
	if not mode.is_empty(): set_mode("")
	else: close(false)

func close(apply: bool) -> void:
	if apply and hud.feedback.persist and hud.widget_layout.save_preferences()!=OK:
		status.text = "Could not save layout. Check disk space and try again."
		hud.feedback.play("error")
		return
	if not apply: hud.widget_layout.restore(original)
	for id in ids: hud.widget_layout.widgets[id].node.reparent(hud.root)
	for label in sample_text:
		label.text = sample_text[label].text
		label.visible = sample_text[label].visible
	sample_text.clear()
	hud.widget_layout.preview = false
	hud.widget_layout.timed = original_timed
	photograph.texture = null
	hide()
	hud.weather_panel.show()
	hud.layout_widgets()
	hud.feedback.play("ready" if apply else "back")
