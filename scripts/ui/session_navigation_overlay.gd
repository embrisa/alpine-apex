extends Control
## Numbers exist only on the overhead map, never as floating riding text.
const COLOR = Color("bb9dff")
var tool
var markers: Array[Dictionary] = []
var target = Vector2.ZERO
var valid_target: bool = false
var draw_signature: Array = []

func refresh() -> void:
	if tool == null or not tool.panel.visible:
		markers.clear(); draw_signature = []
		hide(); return
	show()
	var camera: Camera3D = tool.workshop.survey
	var next: Array[Dictionary] = []
	var rect = get_rect()
	for entry in tool.model.points():
		if camera.is_position_behind(entry.position): continue
		var screen = camera.unproject_position(entry.position)
		if not rect.has_point(screen) or tool.over_panel(screen): continue
		next.append({"id":entry.id,"screen":screen})
	var next_target: Vector2 = tool.target_screen()
	var next_valid: bool = tool.preview is Vector3
	# Everything _draw reads; an unchanged map keeps its retained drawing.
	var signature: Array = [tool.selected_id,tool.input_state.terrain_active,tool.is_controller(),tool.over_panel(next_target)]
	if next==markers and next_target==target and next_valid==valid_target and signature==draw_signature: return
	markers = next
	target = next_target
	valid_target = next_valid
	draw_signature = signature
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
