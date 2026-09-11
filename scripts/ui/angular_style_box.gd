extends StyleBox
## Shared silhouette in logical UI pixels. Native Controls retain their hit boxes.
@export var bg_color: Color = Color.TRANSPARENT
@export var border_color: Color = Color.TRANSPARENT
@export var border_width: float = 1.0
@export var cut: Vector2 = Vector2(12,6)
@export var marker_color: Color = Color.TRANSPARENT
@export var expand_top: float = 0.0

static func outline(rect: Rect2, corner: Vector2) -> PackedVector2Array:
	var scale_factor = minf(1.0,minf(rect.size.x / maxf(corner.x*2.0,0.001),rect.size.y / maxf(corner.y*2.0,0.001)))
	var bevel = corner * maxf(0.0,scale_factor)
	var p = rect.position
	var e = rect.end
	return PackedVector2Array([p+Vector2(bevel.x,0),Vector2(e.x,p.y),e-Vector2(0,bevel.y),e-Vector2(bevel.x,0),Vector2(p.x,e.y),p+Vector2(0,bevel.y)])

func _draw(item: RID, rect: Rect2) -> void:
	rect = _get_draw_rect(rect)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0: return
	# Keep antialiased strokes inside the Control, including scroll/tab clipping.
	var width = minf(border_width,minf(rect.size.x,rect.size.y)*0.5)
	var edge = border_color if border_color.a > 0.0 else bg_color
	var inset = width*0.5
	var points = outline(rect.grow(-inset),cut)
	if bg_color.a > 0.0:
		RenderingServer.canvas_item_add_polygon(item,points,PackedColorArray([bg_color]))
	if edge.a > 0.0:
		var perimeter = points.duplicate()
		perimeter.append(points[0])
		RenderingServer.canvas_item_add_polyline(item,perimeter,PackedColorArray([edge]),width,true)
	if marker_color.a > 0.0 and rect.size.x >= 32.0 and rect.size.y >= 12.0:
		var origin = rect.position+Vector2(12,rect.size.y-4)
		RenderingServer.canvas_item_add_polygon(item,PackedVector2Array([origin+Vector2(4,0),origin+Vector2(20,0),origin+Vector2(16,2),origin+Vector2(0,2)]),PackedColorArray([marker_color]))

func _get_minimum_size() -> Vector2:
	return Vector2.ZERO

func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow_individual(0,expand_top,0,0)

func _test_mask(point: Vector2, rect: Rect2) -> bool:
	return rect.has_point(point)
