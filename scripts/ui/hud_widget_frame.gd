extends Control
## Each instrument carries contrast with it when moved over bright snow.
const ThemeStyle = preload("res://scripts/ui/alpine_theme.gd")
var frame = ThemeStyle.box(Color(.02,.055,.085,.78),Color(.5,.72,.82,.22),0,Vector2(12,6))
func _ready() -> void:
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_style_box(frame,Rect2(Vector2.ZERO,size))
