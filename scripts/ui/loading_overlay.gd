extends CanvasLayer
## Stage labels never pretend to measure unknown generation work.
var overlay: ColorRect
var title: Label
var detail: Label
var elapsed: Label
var bar: ProgressBar
var pulse: Control
var started: int = 0
var phase: float = 0.0
var busy: bool = false
var previous_focus: WeakRef
var reduced_motion: bool = false
var stage_history: Array[String] = []
var worker: Thread

func _ready() -> void:
	layer = 100
	if DisplayServer.get_name() != "headless" and "--script" not in OS.get_cmdline_args() and "-s" not in OS.get_cmdline_args() and "--autoplay" not in OS.get_cmdline_user_args():
		var config = ConfigFile.new()
		if config.load("user://interface_preferences.cfg") == OK:
			reduced_motion = bool(config.get_value("ui","reduced_motion",false))
	overlay = ColorRect.new()
	overlay.color = Color("081820")
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.focus_mode = Control.FOCUS_ALL
	add_child(overlay)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var col = VBoxContainer.new()
	col.custom_minimum_size.x = 560
	col.add_theme_constant_override("separation",20)
	center.add_child(col)
	col.add_child(_label("▲  ALPINE APEX     /     PREPARING YOUR DESCENT",14,Color("c2e76b")))
	title = _label("Finding your mountain",36)
	col.add_child(title)
	detail = _label("",17,Color("9eb4bf"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.y = 52
	col.add_child(detail)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 5
	var background = StyleBoxFlat.new()
	background.bg_color = Color("203944")
	bar.add_theme_stylebox_override("background",background)
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color("c2e76b")
	bar.add_theme_stylebox_override("fill",fill)
	col.add_child(bar)
	pulse = ColorRect.new()
	pulse.color = Color("c2e76b")
	pulse.size = Vector2(96,5)
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(pulse)
	elapsed = _label("",13,Color("9eb4bf"))
	col.add_child(elapsed)
	col.add_child(_label("READ THE TERRAIN. CHOOSE YOUR LINE.",12,Color("9eb4bf")))
	overlay.hide()
	set_process(false)

func _label(value: String, font_size: int, color: Color = Color("eef4f1")) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	return label

func begin(caption: String, message: String) -> void:
	if not busy:
		started = Time.get_ticks_msec()
		var focus = get_viewport().gui_get_focus_owner()
		previous_focus = weakref(focus) if focus else null
		stage_history.clear()
	busy = true
	title.text = caption
	stage(message)
	overlay.show()
	overlay.grab_focus()
	set_process(true)
	_process(0.0)

func stage(message: String, percent: float = -1.0) -> void:
	detail.text = message
	if stage_history.is_empty() or stage_history.back() != message: stage_history.append(message)
	bar.value = maxf(0.0,percent)
	pulse.visible = percent < 0.0

func finish() -> void:
	busy = false
	overlay.hide()
	set_process(false)
	if previous_focus:
		var focus = previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()
	previous_focus = null

func draw_frame() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func run_data(work: Callable):
	worker = Thread.new()
	if worker.start(work) != OK:
		worker = null
		return work.call()
	while worker.is_alive(): await get_tree().process_frame
	var result = worker.wait_to_finish()
	worker = null
	return result

func _exit_tree() -> void:
	if worker and worker.is_started(): worker.wait_to_finish()

func _process(dt: float) -> void:
	phase += dt
	pulse.position.x = (bar.size.x-pulse.size.x)*(0.5 if reduced_motion else (sin(phase*2.8)*0.5+0.5))
	elapsed.text = "WORKING  ·  %.1f s elapsed" % ((Time.get_ticks_msec()-started)/1000.0)

func _input(_event: InputEvent) -> void:
	if busy: get_viewport().set_input_as_handled()
