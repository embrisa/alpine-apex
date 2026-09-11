extends Control
signal seek_requested(time: float)
signal selection_changed
signal edited
var project
var variant_id = ""
var region_id = ""
var bone = "Hips"
var channel = 0
var curve_view = false
var cursor = 0.0
var selected: Array = []
var dragging = ""
var before: Dictionary = {}
var start_mouse = Vector2.ZERO
var start_keys: Dictionary = {}
var handles: Array = []
var key_hits: Array = []
var region_hits: Array = []
var low = -1.0
var high = 1.0
var tangent_key = ""

func _ready() -> void:
	custom_minimum_size = Vector2(250,100)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

func region() -> Dictionary:
	if project==null: return {}
	for value in project.variant(variant_id).get("regions",[]):
		if value.id==region_id: return value
	return {}

func keys() -> Array:
	var r = region()
	if r.is_empty() or not r.tracks.has(bone): return []
	return r.tracks[bone][channel]

func key_by_id(id: String) -> Dictionary:
	for k in keys():
		if k.id==id: return k
	return {}

func x(time: float) -> float: return 48+time/maxf(.0167,project.variant(variant_id).duration)*(size.x-64)
func t(pixel: float) -> float: return clampf((pixel-48)/(size.x-64)*project.variant(variant_id).duration,0,project.variant(variant_id).duration)
func y(value: float) -> float: return remap(value,low,high,size.y-25,40)
func v(pixel: float) -> float: return remap(pixel,size.y-25,40,low,high)

func _draw() -> void:
	draw_style_box(preload("res://scripts/ui/alpine_theme.gd").box(Color("112532"),Color("36566b"),0,Vector2.ZERO),Rect2(Vector2.ZERO,size))
	key_hits.clear(); region_hits.clear(); handles.clear()
	if project==null or variant_id.is_empty(): return
	var duration: float = project.variant(variant_id).duration
	var frames = roundi(duration*60)
	var step = maxi(1,ceili(frames/float(maxi(1,int(size.x/65)))))
	for frame in range(0,frames+1,step):
		var px = x(frame/60.0)
		draw_line(Vector2(px,27),Vector2(px,size.y-10),Color("294353"))
		draw_string(ThemeDB.fallback_font,Vector2(px,19),str(frame),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("9ab5c8"))
	if curve_view: _draw_curve()
	else:
		var row = 42.0
		for r in project.variant(variant_id).regions:
			if row>size.y-30: break
			var rect = Rect2(Vector2(x(r.start),row),Vector2(maxf(8,x(r.end)-x(r.start)),27))
			var tint = Color("365c66") if r.id!=region_id else Color("65885b")
			if r.muted: tint = Color("3b424b")
			draw_rect(rect,tint); region_hits.append({"rect":rect,"id":r.id})
			draw_line(rect.position,rect.position+Vector2(0,27),Color("d3f898"),3)
			draw_line(Vector2(rect.end.x,row),rect.end,Color("d3f898"),3)
			draw_string(ThemeDB.fallback_font,rect.position+Vector2(5,18),r.name,HORIZONTAL_ALIGNMENT_LEFT,maxf(0,rect.size.x-10),12,Color.WHITE)
			if r.id==region_id:
				for k in keys():
					var p = Vector2(x(k.t),row+36)
					draw_circle(p,5,Color("d9ff9f") if selected.has(k.id) else Color("8faabb"))
					key_hits.append({"p":p,"id":k.id})
			row += 49
		if project.variant(variant_id).regions.is_empty():
			draw_string(ThemeDB.fallback_font,Vector2(55,70),"Pose the skier to add a correction. Original motion stays underneath.",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("9ab5c8"))
	draw_line(Vector2(x(cursor),24),Vector2(x(cursor),size.y-5),Color("f4f6df"),2)

func _draw_curve() -> void:
	var track = keys()
	if dragging.is_empty():
		low = -.25; high = .25
		for k in track: low = minf(low,k.v-.15); high = maxf(high,k.v+.15)
	draw_line(Vector2(48,y(0)),Vector2(size.x-10,y(0)),Color("527183"))
	for value in [low,0.0,high]:
		draw_string(ThemeDB.fallback_font,Vector2(2,y(value)),"%.1f"%(rad_to_deg(value) if channel<3 else value),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("a5bcca"))
	var points = PackedVector2Array()
	for px in range(48,int(size.x-15),2): points.append(Vector2(px,y(project.curve(track,t(px)))))
	if points.size()>1: draw_polyline(points,Color("bbeb82"),2,true)
	for k in track:
		var p = Vector2(x(k.t),y(k.v))
		key_hits.append({"p":p,"id":k.id})
		if selected.has(k.id):
			for side in [-1,1]:
				var dt: float = project.variant(variant_id).duration*.06*side
				var slope: float = k["in"] if side<0 else k.out
				var handle = Vector2(x(k.t+dt),y(k.v+slope*dt))
				draw_line(p,handle,Color("81b8dc"),1)
				draw_circle(handle,4,Color("81b8dc"))
				handles.append({"p":handle,"id":k.id,"side":"in" if side<0 else "out","dt":dt})
		draw_circle(p,5,Color.WHITE if selected.has(k.id) else Color("c1e58f"))

func _gui_input(event: InputEvent) -> void:
	if project==null: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		grab_focus()
		if not event.pressed:
			if not dragging.is_empty() and not before.is_empty():
				project.commit("Edit "+dragging,before); edited.emit()
			dragging = ""; before = {}; queue_redraw(); accept_event(); return
		start_mouse = event.position
		for handle in handles:
			if handle.p.distance_to(event.position)<9:
				dragging = handle.side; tangent_key = handle.id; before = project.snapshot()
				start_keys = {"dt":handle.dt}; accept_event(); return
		for hit in key_hits:
			if hit.p.distance_to(event.position)<10:
				if not event.shift_pressed and not selected.has(hit.id): selected.clear()
				if event.shift_pressed and selected.has(hit.id): selected.erase(hit.id)
				elif not selected.has(hit.id): selected.append(hit.id)
				dragging = "keys"; before = project.snapshot(); start_keys = {}
				for id in selected: start_keys[id] = key_by_id(id).duplicate(true)
				selection_changed.emit(); queue_redraw(); accept_event(); return
		for hit in region_hits:
			if hit.rect.grow(5).has_point(event.position):
				region_id = hit.id; selected.clear(); selection_changed.emit()
				if absf(hit.rect.position.x-event.position.x)<7: dragging = "start"
				elif absf(hit.rect.end.x-event.position.x)<7: dragging = "end"
				if not dragging.is_empty(): before = project.snapshot()
				queue_redraw(); accept_event(); return
		if event.double_click and curve_view and not region().is_empty():
			var before_add = project.snapshot()
			insert_key(roundf(t(event.position.x)*60)/60,v(event.position.y))
			project.commit("Insert key",before_add); edited.emit()
		else: seek_requested.emit(roundf(t(event.position.x)*60)/60)
		accept_event()
	elif event is InputEventMouseMotion and not dragging.is_empty():
		if dragging in ["start","end"]:
			var r = region(); var at = roundf(t(event.position.x)*60)/60
			project.resize_region(r,at if dragging=="start" else r.start,at if dragging=="end" else r.end,project.variant(variant_id).duration)
		elif dragging in ["in","out"]:
			var k = key_by_id(tangent_key)
			k[dragging] = (v(event.position.y)-float(k.v))/float(start_keys.dt)
			k.mode = "cubic"
		else:
			var dt = roundf((t(event.position.x)-t(start_mouse.x))*60)/60
			var dv = v(event.position.y)-v(start_mouse.y) if curve_view else 0.0
			var minimum = -INF; var maximum = INF
			for id in selected:
				var at: float = start_keys[id].t
				minimum = maxf(minimum,-at); maximum = minf(maximum,project.variant(variant_id).duration-at)
				for other in keys():
					if other.id in selected: continue
					if other.t<at: minimum = maxf(minimum,float(other.t)+1.0/60-at)
					if other.t>at: maximum = minf(maximum,float(other.t)-1.0/60-at)
			dt = clampf(dt,minimum,maximum)
			for id in selected:
				var k = key_by_id(id)
				k.t = clampf(float(start_keys[id].t)+dt,0,project.variant(variant_id).duration)
				k.v = float(start_keys[id].v)+dv
			keys().sort_custom(func(a,b): return a.t<b.t)
			_expand_bounds()
		queue_redraw(); edited.emit(); accept_event()

func insert_key(at: float, value: float) -> void:
	var r = region()
	if r.is_empty(): return
	if not r.tracks.has(bone): r.tracks[bone] = [[],[],[],[],[],[]]
	for k in keys():
		if absf(float(k.t)-at)<.00001: k.v = value; selected = [k.id]; return
	var k = project.key(at,value); keys().append(k); keys().sort_custom(func(a,b): return a.t<b.t); selected = [k.id]
	_expand_bounds()

func _expand_bounds() -> void:
	var r = region()
	for channels in r.get("tracks",{}).values():
		for track in channels:
			for k in track: r.start = minf(r.start,k.t); r.end = maxf(r.end,k.t)

func delete_keys() -> void:
	var before_delete = project.snapshot()
	for i in range(keys().size()-1,-1,-1):
		if selected.has(keys()[i].id): keys().remove_at(i)
	selected.clear(); project.commit("Delete keys",before_delete); edited.emit()

func copy_keys() -> void:
	project.clipboard.clear()
	for k in keys():
		if selected.has(k.id): project.clipboard.append(k.duplicate(true))

func paste_keys() -> void:
	if project.clipboard.is_empty() or region().is_empty(): return
	var before_paste = project.snapshot()
	var origin: float = project.clipboard[0].t
	for source in project.clipboard:
		var at = clampf(cursor+float(source.t)-origin,0,project.variant(variant_id).duration)
		insert_key(at,source.v)
		var k = key_by_id(selected[0]); k.mode = source.mode; k["in"] = source["in"]; k.out = source.out
	project.commit("Paste keys",before_paste); edited.emit()

func interpolation(mode: String) -> void:
	var before_edit = project.snapshot()
	for id in selected: key_by_id(id).mode = mode
	project.commit("Change interpolation",before_edit); edited.emit()
