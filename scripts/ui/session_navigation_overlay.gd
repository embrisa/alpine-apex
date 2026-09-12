extends Control
## Numbers exist only on the overhead map, never as floating riding text.
const COLOR = Color("bb9dff")
var tool
var markers: Array[Dictionary] = []
var target = Vector2.ZERO
var valid_target: bool = false

func refresh() -> void:
	markers.clear()
	if tool == null or not tool.panel.visible: hide(); return
	show()
	var camera: Camera3D = tool.workshop.survey
	for entry in tool.model.points():
		if camera.is_position_behind(entry.position): continue
		var screen = camera.unproject_position(entry.position)
		if not get_rect().has_point(screen) or tool.over_panel(screen): continue
		markers.append({"id":entry.id,"screen":screen})
	target = tool.target_screen()
	valid_target = tool.preview is Vector3
	queue_redraw()

func nearest(screen: Vector2) -> int:
	var id = -1
	var distance = 22.0
	for marker in markers:
		var candidate: float = marker.screen.distance_to(screen)
		if candidate < distance:
			distance = candidate
			id = marker.id
	return id

func _draw() -> void:
	var font = ThemeDB.fallback_font
	for marker in markers:
		var color = Color.WHITE if marker.id == tool.selected_id else COLOR
		draw_circle(marker.screen,16.0,Color(.025,.04,.08,.9))
		draw_arc(marker.screen,16.0,0.0,TAU,32,color,2.0,true)
		var text_value = str(marker.id)
		var text_size = font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,16)
		draw_string(font,marker.screen+Vector2(-text_size.x*.5,6.0),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)
	if tool.input_state.terrain_active and (tool.is_controller() or not tool.over_panel(target)):
		var color = COLOR if valid_target else Color("ff937f")
		draw_circle(target,5.0,Color(.025,.04,.08,.7))
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			draw_line(target+direction*9.0,target+direction*21.0,color,2.0,true)
