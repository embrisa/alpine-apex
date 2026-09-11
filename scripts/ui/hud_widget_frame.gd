extends Control
## Clean, unoutlined instruments with optional backgrounds.
const ThemeStyle = preload("res://scripts/ui/alpine_theme.gd")
var background_enabled = false:
	set(value):
		if background_enabled == value: return
		background_enabled = value
		queue_redraw()
var frame = ThemeStyle.box(Color(.02,.055,.085,.78),Color(.5,.72,.82,.22),0,Vector2(12,6))
func _ready() -> void:
	resized.connect(queue_redraw)
func _draw() -> void:
	if background_enabled: draw_style_box(frame,Rect2(Vector2.ZERO,size))

static func style_content(node: Node) -> void:
	if node is Label:
		node.add_theme_font_size_override("font_size",maxi(11,node.get_theme_font_size("font_size")))
		node.add_theme_constant_override("outline_size",0)
		node.add_theme_color_override("font_shadow_color",Color(.025,.06,.09,.22))
		node.add_theme_constant_override("shadow_offset_x",0)
		node.add_theme_constant_override("shadow_offset_y",1)
	for child in node.get_children(): style_content(child)
