extends Control
const Settings = preload("res://scripts/presentation/camera_settings.gd")
var profile: Dictionary = Settings.defaults("chase")
var preview_speed = 0.0
func _ready() -> void:
	custom_minimum_size = Vector2(200,105)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func configure(values: Dictionary, kmh: float) -> void:
	profile = values
	preview_speed = kmh
	queue_redraw()
func _draw() -> void:
	var plot = Rect2(8,6,maxf(1,size.x-16),size.y-30)
	for fraction in [0.0,0.5,1.0]:
		var y = plot.end.y-plot.size.y*fraction
		draw_line(Vector2(plot.position.x,y),Vector2(plot.end.x,y),Color(0.45,0.6,0.7,0.25))
	var points = PackedVector2Array()
	for i in 61:
		points.append(Vector2(plot.position.x+plot.size.x*i/60.0,plot.end.y-plot.size.y*Settings.speed_factor(i*5.0,profile)))
	draw_polyline(points,Color(0.75,0.95,0.4),2.0,true)
	var point = Vector2(plot.position.x+plot.size.x*preview_speed/300.0,plot.end.y-plot.size.y*Settings.speed_factor(preview_speed,profile))
	draw_line(Vector2(point.x,plot.position.y),Vector2(point.x,plot.end.y),Color(1,1,1,0.5))
	draw_circle(point,4,Color.WHITE)
	for speed in [0,100,200,300]:
		var caption = str(speed)
		var x = plot.position.x+plot.size.x*speed/300.0
		draw_string(ThemeDB.fallback_font,Vector2(clampf(x-12,0,size.x-28),size.y-3),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.7,0.8,0.85))

