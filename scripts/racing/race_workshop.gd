extends Node3D
## Authoring uses the existing rendered world; it never moves the ski solver.
const Race = preload("res://scripts/racing/race_definition.gd")
const Store = preload("res://scripts/racing/race_store.gd")
var game
var store = Store.new()
var mode: String = ""
var return_mode: String = "title"
var survey: Camera3D
var focus_point = Vector3.ZERO
var survey_height: float = 240.0
var panel: PanelContainer
var library: VBoxContainer
var editor: VBoxContainer
var list: ItemList
var details: Label
var status: Label
var name_input: LineEdit
var code_input: TextEdit
var start_button: Button
var finish_button: Button
var save_button: Button
var race_button: Button
var share_button: Button
var benchmark_button: Button
var endpoint_label: Label
var races: Array = []
var selected = null
var draft = null
var has_start: bool = false
var has_finish: bool = false
var placing: String = "start"
var markers: Node3D
var cursor: MeshInstance3D
var instrument_visibility: Array = []

func build(owner_game) -> void:
	game = owner_game
	survey = Camera3D.new()
	survey.near = 0.2
	survey.far = 8500.0
	survey.fov = 62.0
	add_child(survey)
	markers = Node3D.new()
	add_child(markers)
	cursor = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 1.5
	mesh.height = 3.0
	cursor.mesh = mesh
	cursor.material_override = _material(game.hud.LIME)
	cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cursor.visible = false
	add_child(cursor)
	_build_ui()

func _build_ui() -> void:
	var hud = game.hud
	panel = hud._panel()
	panel.add_theme_stylebox_override("panel",hud._style(Color(0.035,0.095,0.13,0.94),Color(0.55,0.69,0.73,0.2),20))
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 28
	panel.offset_right = 424
	panel.offset_top = 135
	panel.offset_bottom = -60
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation",10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	col.add_child(hud._label("YOUR MOUNTAIN. YOUR RACE.",20,hud.WHITE))
	var intro = hud._label("Start here. Finish there.\nFind the fastest route.",15,hud.MUTED)
	col.add_child(intro)
	library = VBoxContainer.new()
	library.add_theme_constant_override("separation",8)
	col.add_child(library)
	var create = hud._button("+  CREATE IN THE WORLD",true)
	create.pressed.connect(begin_creation)
	library.add_child(create)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(324,80)
	list.item_selected.connect(select_race)
	library.add_child(list)
	details = hud._label("",12,hud.MUTED,true)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.y = 75
	library.add_child(details)
	var actions = HBoxContainer.new()
	library.add_child(actions)
	race_button = hud._button("RACE IT",true)
	race_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	race_button.pressed.connect(play_selected)
	actions.add_child(race_button)
	share_button = hud._button("COPY TO SHARE")
	share_button.add_theme_font_size_override("font_size",13)
	share_button.pressed.connect(copy_selected)
	actions.add_child(share_button)
	code_input = TextEdit.new()
	code_input.placeholder_text = "Paste a shared race code here"
	code_input.custom_minimum_size = Vector2(324,55)
	code_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	library.add_child(code_input)
	var import_button = hud._button("IMPORT RACE CODE")
	import_button.custom_minimum_size.y = 38
	import_button.pressed.connect(func(): import_text(code_input.text))
	library.add_child(import_button)
	benchmark_button = hud._button("RACE THE ORIGINAL TEST FACE")
	benchmark_button.custom_minimum_size.y = 34
	benchmark_button.add_theme_font_size_override("font_size",13)
	benchmark_button.pressed.connect(func(): close(); game.start_run(true))
	library.add_child(benchmark_button)
	editor = VBoxContainer.new()
	editor.add_theme_constant_override("separation",12)
	col.add_child(editor)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Race name, e.g. Ravine Rush"
	name_input.max_length = 60
	name_input.custom_minimum_size.y = 42
	name_input.text_changed.connect(func(_value): _refresh_draft())
	editor.add_child(name_input)
	start_button = hud._button("1  PLACE START ON THE SNOW",true)
	start_button.pressed.connect(func(): placing = "start"; start_button.release_focus(); _refresh_draft())
	editor.add_child(start_button)
	finish_button = hud._button("2  PLACE FINISH ON THE SNOW")
	finish_button.pressed.connect(func(): placing = "finish"; finish_button.release_focus(); _refresh_draft())
	editor.add_child(finish_button)
	var here = hud._button("USE SKIER POSITION")
	here.custom_minimum_size.y = 38
	here.pressed.connect(func():
		var p: Vector3 = game.sim.position
		p.y = game.field.sample(p.x,p.z).height
		place_point(p)
	)
	editor.add_child(here)
	endpoint_label = hud._label("",12,hud.MUTED,true)
	editor.add_child(endpoint_label)
	editor.add_child(hud._label("Click snow to place the selected endpoint.\nWASD / arrows pan · scroll to zoom\nNo checkpoints. Arrive from any direction.",12,hud.WHITE))
	save_button = hud._button("SAVE RACE",true)
	save_button.pressed.connect(save_draft)
	editor.add_child(save_button)
	status = hud._label("",13,hud.LIME)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 324
	col.add_child(status)
	var back = hud._button("BACK / ESC")
	back.custom_minimum_size.y = 38
	back.pressed.connect(back_pressed)
	col.add_child(back)
	panel.visible = false

func open_library() -> void:
	if not mode.is_empty() or game.mountain_library.panel.visible: return
	return_mode = "paused" if game.active or game.hud.menu_mode=="racing" else game.hud.menu_mode
	game.active = false
	game.hud.hide_menu()
	game.hud.tuning_panel.visible = false
	game.hud.debug_panel.visible = false
	game.vectors.visible = false
	instrument_visibility.clear()
	for control in game.hud.hud_controls:
		instrument_visibility.append(control.visible)
		control.visible = false
	focus_point = game.sim.position+Vector3(0,0,120)
	survey_height = 240.0
	mode = "library"
	panel.visible = true
	survey.current = true
	_update_survey()
	_refresh_library()

func _refresh_library(select_id: String = "") -> void:
	mode = "library"
	library.visible = true
	editor.visible = false
	benchmark_button.visible = game.session.race != null or game.current_mountain != null
	races = store.load_all()
	list.clear()
	selected = null
	for race in races: list.add_item(race.title)
	status.text = store.warning
	if not races.is_empty():
		var index = 0
		for i in races.size():
			if races[i].identity()==select_id: index = i
		list.select(index)
		select_race(index)
	else:
		details.text = "No saved races yet.\nCreate one, or import a friend's code."
		race_button.disabled = true
		share_button.disabled = true
		show_race(game.session.race)

func select_race(index: int) -> void:
	if index<0 or index>=races.size(): return
	selected = races[index]
	details.text = "MOUNTAIN  %d\nSTART   %s\nFINISH  %s\n12 m finish radius · open route" % [selected.mountain.seed,_coordinates(selected.start),_coordinates(selected.finish)]
	race_button.disabled = false
	share_button.disabled = false
	if matches_world(selected):
		show_race(selected)
		focus_point = selected.start.lerp(selected.finish,0.5)
		survey_height = clampf(selected.start.distance_to(selected.finish)*1.25,100,_survey_limit())
		_update_survey()
	else:
		show_race(null)
		status.text = "Race it loads the mountain saved with this race."

func begin_creation() -> void:
	mode = "create"
	library.visible = false
	editor.visible = true
	draft = Race.new()
	draft.mountain = Race.mountain_reference(game.field,game.world.mountain.seed_value)
	has_start = false
	has_finish = false
	placing = "start"
	name_input.text = ""
	_clear_markers()
	status.text = "Choose a starting position in the world."
	_refresh_draft()

func place_point(point: Vector3) -> bool:
	if mode!="create": return false
	var error = Race.point_error(point,game.field)
	if not error.is_empty():
		status.text = error
		return false
	if placing=="start":
		draft.start = point
		has_start = true
		placing = "finish"
	else:
		draft.finish = point
		has_finish = true
	if has_start and has_finish:
		var delta: Vector3 = draft.finish-draft.start
		draft.heading = atan2(delta.x,delta.z)
	_refresh_draft()
	_clear_markers()
	if has_start: _marker(draft.start,"START",game.hud.LIME,3.0)
	if has_finish: _marker(draft.finish,"FINISH",Color("ffa96b"),Race.FINISH_RADIUS)
	status.text = "Name and save your race, or reposition either endpoint." if has_start and has_finish else "Now choose a finish on any face. Pan with WASD / arrows."
	return true

func _refresh_draft() -> void:
	if not draft: return
	draft.title = name_input.text.strip_edges()
	start_button.text = "1  START  ·  " + ("CLICK SNOW" if placing=="start" else "REPOSITION" if has_start else "PLACE")
	finish_button.text = "2  FINISH  ·  " + ("CLICK SNOW" if placing=="finish" else "REPOSITION" if has_finish else "PLACE")
	endpoint_label.text = "MOUNTAIN  %d\nSTART   %s\nFINISH  %s" % [draft.mountain.seed,_coordinates(draft.start) if has_start else "—",_coordinates(draft.finish) if has_finish else "—"]
	save_button.disabled = not (has_start and has_finish and not draft.title.is_empty())

func save_draft() -> void:
	if not has_start or not has_finish: return
	_refresh_draft()
	var result = Race.decode(draft.share_text())
	if not result.has("race"):
		status.text = result.error
		return
	var error: String = result.race.validate_surface(game.field)
	if error.is_empty(): error = store.save(result.race)
	if not error.is_empty():
		status.text = error
		return
	_refresh_library(result.race.identity())
	status.text = "Saved locally. Race it, or copy the code to share."

func import_text(text_value: String) -> bool:
	var result = Race.decode(text_value.strip_edges())
	if not result.has("race"):
		status.text = result.error
		return false
	var race = result.race
	var rebuilt = {"field":game.field} if matches_world(race) else Race.reconstruct_surface(race.mountain)
	if not rebuilt.has("field"):
		status.text = rebuilt.error
		return false
	var field = rebuilt.field
	var error: String = race.validate_surface(field)
	if error.is_empty(): error = store.save(race)
	if not error.is_empty():
		status.text = error
		return false
	code_input.text = ""
	_refresh_library(race.identity())
	status.text = "Imported and saved. Ready to race."
	return true

func copy_selected() -> void:
	if not selected: return
	DisplayServer.clipboard_set(selected.share_text())
	status.text = "Copied. Send the code; your friend can paste and import it here."

func play_selected() -> void:
	if selected: game.play_custom_race(selected)

func matches_world(race) -> bool:
	return race.mountain == Race.mountain_reference(game.field,game.world.mountain.seed_value)

func back_pressed() -> void:
	if mode=="create":
		draft = null
		_refresh_library()
	else:
		close()
		game.hud.show_menu(return_mode,game.sim.crash_reason if game.sim.crashed else game.Session.format_time(game.session.elapsed))

func close() -> void:
	mode = ""
	panel.visible = false
	cursor.visible = false
	game.camera.current = true
	game.camera.reset()
	game.weather_effects.reset()
	for i in instrument_visibility.size():
		game.hud.hud_controls[i].visible = instrument_visibility[i]
	instrument_visibility.clear()
	show_race(game.session.race)

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_run"):
		back_pressed()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:
			survey_height = maxf(45.0,survey_height*0.82)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			survey_height = minf(_survey_limit(),survey_height/0.82)
		elif event.button_index==MOUSE_BUTTON_LEFT and mode=="create":
			get_viewport().gui_release_focus()
			var point = pick_snow(event.position)
			if point is Vector3: place_point(point)
			else: status.text = "Choose snow inside the skiable mountain."
		elif event.button_index==MOUSE_BUTTON_LEFT:
			get_viewport().gui_release_focus()

func update_survey(dt: float) -> void:
	var focused = game.hud.root.get_viewport().gui_get_focus_owner()
	if not focused is LineEdit and not focused is TextEdit:
		var x = Input.get_axis("steer_left","steer_right")
		var z = Input.get_axis("brake","tuck")
		focus_point += (Vector3.LEFT*x+Vector3.BACK*z)*survey_height*dt*0.7
	_update_survey()
	cursor.visible = false
	if mode=="create" and not panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
		var point = pick_snow(get_viewport().get_mouse_position())
		if point is Vector3:
			cursor.position = point+Vector3.UP*1.5
			cursor.visible = true

func _update_survey() -> void:
	var area: Rect2 = game.field.ski_bounds().grow(-25.0)
	focus_point.x = clampf(focus_point.x,area.position.x,area.end.x)
	focus_point.z = clampf(focus_point.z,area.position.y,area.end.y)
	focus_point.y = game.field.sample(focus_point.x,focus_point.z).height
	survey.far = maxf(8500.0,_survey_limit()*2.5)
	survey.position = focus_point+Vector3(0,survey_height,-survey_height*0.60)
	survey.look_at(focus_point)

func pick_snow(screen: Vector2) -> Variant:
	var origin = survey.project_ray_origin(screen)
	var direction = survey.project_ray_normal(screen)
	var previous = origin
	for i in range(1,ceili(_survey_limit()*2.5/8.0)+1):
		var p = origin+direction*float(i)*8.0
		if game.field.ski_bounds().has_point(Vector2(p.x,p.z)) and p.y<=float(game.field.sample(p.x,p.z).height):
			var low = previous
			var high = p
			for j in range(14):
				var mid = low.lerp(high,0.5)
				if mid.y>float(game.field.sample(mid.x,mid.z).height): low = mid
				else: high = mid
			var hit = low.lerp(high,0.5)
			hit.y = game.field.sample(hit.x,hit.z).height
			return hit
		previous = p
	return null

func show_race(race) -> void:
	_clear_markers()
	game.world.set_benchmark_markers(race==null and mode.is_empty() and game.current_mountain==null)
	if race:
		_marker(race.start,"START",game.hud.LIME,3.0)
		_marker(race.finish,"FINISH",Color("ffa96b"),Race.FINISH_RADIUS)

func _clear_markers() -> void:
	for child in markers.get_children():
		markers.remove_child(child)
		child.queue_free()

func _marker(point: Vector3, caption: String, color: Color, radius: float) -> void:
	var vertices = PackedVector3Array()
	for i in range(64):
		var a = TAU*float(i)/64.0
		var b = TAU*float(i+1)/64.0
		for pair in [[a,radius-0.35],[b,radius-0.35],[a,radius+0.35],[a,radius+0.35],[b,radius-0.35],[b,radius+0.35]]:
			var p = point+Vector3(cos(pair[0])*pair[1],0,sin(pair[0])*pair[1])
			p.y = game.field.sample(p.x,p.z).height+0.16
			vertices.append(p)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var ring = MeshInstance3D.new()
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	ring.mesh = mesh
	ring.material_override = _material(color)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markers.add_child(ring)
	var label = Label3D.new()
	label.text = caption
	label.position = point+Vector3.UP*8.0
	label.font_size = 64
	label.pixel_size = 0.0006
	label.fixed_size = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.no_depth_test = true
	markers.add_child(label)
	var post = MeshInstance3D.new()
	var post_mesh = CylinderMesh.new()
	post_mesh.top_radius = 0.20
	post_mesh.bottom_radius = 0.20
	post_mesh.height = 6.0
	post.mesh = post_mesh
	post.position = point+Vector3(radius,0,0)
	post.position.y = game.field.sample(post.position.x,post.position.z).height+3.0
	post.material_override = _material(color)
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markers.add_child(post)

func _material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _coordinates(point: Vector3) -> String:
	return "%.1f / %.1f / %.1f m" % [point.x,point.y,point.z]

func _survey_limit() -> float:
	return maxf(1500.0,game.field.bounds().size.length()*.8)
