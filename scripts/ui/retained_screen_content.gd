extends BoxContainer
## Related retained-screen columns share their page's vertical scroll.
@export var stack_below: float = 900.0

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",24)
	resized.connect(_fit_columns)
	_fit_columns()

func _fit_columns() -> void:
	vertical = size.x < stack_below
	for child in get_children():
		if child is Control:
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			child.size_flags_stretch_ratio = 1.0 if vertical else (1.65 if child.get_index()>0 else 1.0)

class TerrainPreview extends "res://scripts/ui/mountain_preview.gd":
	## Keep the map centered and large instead of reserving a fixed legend column.
	func _ready() -> void:
		resized.connect(func(): custom_minimum_size.y = clampf(size.x*.8,360.0,640.0))

	func _draw() -> void:
		draw_style_box(background,Rect2(Vector2.ZERO,size))
		if not texture or not terrain: return
		var area: Rect2 = terrain.bounds()
		var ratio = area.size.x/area.size.y
		var height_value = minf(size.y-56.0,(size.x-32.0)/ratio)
		var extent = Vector2(height_value*ratio,height_value)
		var rect = Rect2(Vector2((size.x-extent.x)*.5,16),extent)
		draw_texture_rect(texture,rect,false)
		draw_rect(rect,Color("789395"),false,1)
		var features: Array = terrain.features
		if terrain.has_method("environment_weight"):
			features = [{"name":"Summit","position":Vector2.ZERO}]
			for face in terrain.faces:
				features.append({"name":"Face %d" % [face.index+1],"position":face.to_world(Vector2(0,1400))})
		for feature in features:
			var point = rect.position+(feature.position-area.position)/area.size*rect.size
			draw_circle(point,4,Color("c2e76b"))
			if font:
				var caption: String = feature.name
				var width_value = minf(font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x,size.x-24)
				var origin = Vector2(clampf(point.x+8,8,size.x-width_value-8),clampf(point.y-7,20,size.y-40))
				draw_style_box(background,Rect2(origin-Vector2(4,13),Vector2(width_value+8,19)))
				draw_string(font,origin,caption,HORIZONTAL_ALIGNMENT_LEFT,width_value,12,Color("eef4f1"))
		if font:
			draw_string(font,Vector2(16,size.y-14),"N ↑   ·   50 m contours" if terrain.is_summit_mountain() else "Summit ↓ lower basin   ·   50 m contours",HORIZONTAL_ALIGNMENT_LEFT,size.x-32,12,Color("9eb4bf"))
