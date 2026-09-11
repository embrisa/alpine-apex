extends Control
var editor
var dragging = false
var drag_offset = Vector2.ZERO

func _draw() -> void:
	if editor==null: return
	var layout = editor.hud.widget_layout
	var margin = size*layout.safe_area
	draw_rect(Rect2(margin,size-margin*2),Color(.5,.8,.9,.6),false,1.5)
	if editor.snapping:
		draw_line(Vector2(size.x*.5,margin.y),Vector2(size.x*.5,size.y-margin.y),Color(.6,.8,1,.3),1)
		draw_line(Vector2(margin.x,size.y*.5),Vector2(size.x-margin.x,size.y*.5),Color(.6,.8,1,.3),1)
	for id in layout.widgets:
		var widget = layout.widgets[id]
		if id!=editor.selected: continue
		var rect = Rect2(widget.node.position,widget.size*widget.node.scale)
		draw_rect(rect.grow(5),Color(.65,.9,1,.9),false,3)
		if not layout.values[id].visible: draw_rect(rect,Color(.65,.9,1,.12))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			var ids = editor.hud.widget_layout.widgets.keys()
			ids.reverse()
			for id in ids:
				var widget = editor.hud.widget_layout.widgets[id]
				if widget.node.visible and Rect2(widget.node.position,widget.size*widget.node.scale).has_point(event.position):
					editor.select(id)
					drag_offset = event.position-widget.node.position
					accept_event()
					return
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		editor.hud.widget_layout.move_pixel(editor.selected,event.position-drag_offset,size,editor.snapping)
		editor.refresh()
		accept_event()
