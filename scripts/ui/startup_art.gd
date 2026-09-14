extends Control
## Retained low-angle ridges for missing photography; no world camera.
var seconds: float = 0.0
var reduced_motion: bool = false
var ridges_enabled: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func update_visual(time: float, reduced: bool) -> void:
	if seconds == time and reduced_motion == reduced: return
	seconds = time
	reduced_motion = reduced
	queue_redraw()

func _draw() -> void:
	# Off-centre summits frame the approved brand without competing with its geometry.
	var shift = 0.0 if reduced_motion else (1.0-exp(-seconds*1.1))*0.008
	var ridges = [
		[Vector2(-.1,.64),Vector2(.17,.37),Vector2(.30,.45),Vector2(.48,.57),Vector2(.73,.32),Vector2(1.1,.62)],
		[Vector2(-.1,.88),Vector2(.10,.57),Vector2(.22,.63),Vector2(.39,.78),Vector2(.78,.53),Vector2(1.1,.77)],
		[Vector2(-.1,1.0),Vector2(.18,.85),Vector2(.36,.91),Vector2(.69,.74),Vector2(1.1,.94)]
	]
	var colors = [Color("233c4b"),Color("102a3a"),Color("091d2c")]
	for layer in (ridges.size() if ridges_enabled else 0):
		var ridge: Array = ridges[layer]
		var points = PackedVector2Array()
		for point in ridge: points.append((point+Vector2(shift*layer,0))*size)
		points.append(Vector2(size.x*1.2,size.y*1.2)); points.append(Vector2(-size.x*.2,size.y*1.2))
		draw_colored_polygon(points,colors[layer])
		for i in range(1,ridge.size()-1):
			var a: Vector2 = (ridge[i-1]+Vector2(shift*layer,0))*size
			var b: Vector2 = (ridge[i]+Vector2(shift*layer,0))*size
			if b.y < a.y:
				var tip = b+Vector2(size.x*.035,size.y*.09)
				draw_colored_polygon(PackedVector2Array([a,b,tip]),Color(0.48,0.65,0.71,0.12-layer*.025))
				draw_line(a,b,Color(0.60,0.76,0.80,0.19-layer*.04),maxf(1.0,size.y/1080.0),true)
