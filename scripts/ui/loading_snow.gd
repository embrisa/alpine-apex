extends Control
## Thirty-two small 2D motes; no particle simulation or full-screen particle loop.
const COUNT = 32
var motes: Array[Vector4] = []
var visual_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng = RandomNumberGenerator.new()
	rng.seed = 902174
	for i in COUNT:
		motes.append(Vector4(rng.randf(),rng.randf(),rng.randf_range(0.7,1.7),rng.randf_range(0.0,TAU)))
	hide()

func update_motion(seconds: float, enabled: bool) -> void:
	visible = enabled
	if not enabled: return
	visual_time = seconds
	queue_redraw()

func _draw() -> void:
	for mote in motes:
		var x = fposmod(mote.x + visual_time * 0.008 * mote.z,1.0)
		var y = fposmod(mote.y - visual_time * 0.012 * mote.z,1.0)
		var position_uv = Vector2(x,y)
		position_uv.x += sin(visual_time * 0.22 + mote.w) * 0.006
		# Soft entrances/exits, and a clear left reading rail and bottom caption.
		var alpha = smoothstep(0.36,0.63,x) * smoothstep(0.0,0.08,y) * (1.0-smoothstep(0.82,0.95,y))
		alpha *= smoothstep(0.0,0.06,x) * (1.0-smoothstep(0.94,1.0,x)) * 0.32
		var point = position_uv * size
		var radius = mote.z * maxf(size.y / 900.0,0.75)
		draw_circle(point,radius*2.5,Color(0.87,0.94,1.0,alpha*0.10),true,-1.0,true)
		draw_circle(point,radius*1.5,Color(0.92,0.97,1.0,alpha*0.24),true,-1.0,true)
		draw_circle(point,radius*0.6,Color(1.0,0.98,0.92,alpha),true,-1.0,true)
