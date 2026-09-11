extends Control
var texture: Texture2D
var heading = ""
var markers: Array = []
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("142838"))
	if texture: draw_texture_rect(texture,Rect2(0,36,size.x,size.y-36),false)
	draw_string(ThemeDB.fallback_font,Vector2(12,24),heading,HORIZONTAL_ALIGNMENT_LEFT,size.x-20,16,Color.WHITE)
	for marker in markers:
		var p = Vector2(marker.point[0]*size.x,36+marker.point[1]*(size.y-36))
		draw_circle(p,7,Color("eaffaa"),false,2)
		draw_string(ThemeDB.fallback_font,p+Vector2(10,-8),marker.bone,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("eaffaa"))
