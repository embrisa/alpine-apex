extends CanvasLayer
const AlpineTheme = preload("res://scripts/ui/alpine_theme.gd")
## Bound to this world's lifetime. Cancelled tweens cannot reset a later attempt.
var cover = ColorRect.new()
var caption = Label.new()
var tween: Tween
var generation: int = 0

func _ready() -> void:
	layer = 90
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.color = Color("10202b")
	cover.theme = AlpineTheme.create()
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)
	caption.text = "Returning to summit"
	var frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel",AlpineTheme.box(AlpineTheme.PANEL,AlpineTheme.EDGE,24,AlpineTheme.PANEL_CUT))
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	frame.offset_left = -264
	frame.offset_right = 264
	frame.offset_top = -46
	frame.offset_bottom = 46
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(frame)
	caption.custom_minimum_size = Vector2(480,44)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",24)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(caption)
	cover.hide()

func begin(midpoint: Callable, completed: Callable, reduced_motion: bool) -> void:
	cancel()
	var token = generation
	if reduced_motion:
		midpoint.call()
		if token==generation: completed.call()
		return
	cover.modulate.a = 0.0
	cover.show()
	tween = create_tween()
	tween.tween_property(cover,"modulate:a",1.0,0.2)
	tween.tween_callback(func():
		if token==generation: midpoint.call())
	tween.tween_property(cover,"modulate:a",0.0,0.2)
	tween.tween_callback(func():
		if token==generation:
			cover.hide()
			completed.call())

func cancel() -> void:
	generation += 1
	if tween and tween.is_valid(): tween.kill()
	cover.hide()

func _exit_tree() -> void:
	cancel()
