extends Node3D
## Authoring uses the existing rendered world; it never moves the ski solver.
const RetainedContent = preload("res://scripts/ui/retained_screen_content.gd")
const Race = preload("res://scripts/racing/race_definition.gd")
const Store = preload("res://scripts/racing/race_store.gd")
const Beams = preload("res://scripts/presentation/race_beams.gd")
# Navigation keeps its original high-visibility color independently of menu art.
const START_COLOR = Beams.START_COLOR
var game
var store = Store.new()
var mode: String = ""
var return_mode: String = "title"
var survey: Camera3D
var focus_point = Vector3.ZERO
var survey_height: float = 240.0
var panel: PanelContainer
var heading: Label
var library_actions: HFlowContainer
var editor_scroll: ScrollContainer
var survey_keyboard_enabled: bool = false
var library: VBoxContainer
var library_tabs: TabContainer
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
var zone_outline: MeshInstance3D
var suggested_race

func build(owner_game) -> void:
	game = owner_game
	survey = Camera3D.new()
	survey.near = 0.2
	survey.far = 32000.0
	survey.fov = 62.0
	add_child(survey)
	markers = Node3D.new()
	add_child(markers)
	_build_zone_outline()
	cursor = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 1.5
	mesh.height = 3.0
	cursor.mesh = mesh
	cursor.material_override = _material(START_COLOR)
	cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cursor.visible = false
	add_child(cursor)
	_build_ui()
	suggested_race=Race.suggested(game.field,game.world.mountain.seed_value)

func _build_ui() -> void:
	var hud = game.hud
	panel = hud._panel()
	panel.name = "RaceWorkshop"
	var shell = hud._window(panel)
	shell.add_theme_constant_override("separation",14)
	# Only the library owns menu atmosphere; the drawer leaves terrain unobscured.
	hud.menu_backgrounds.erase(panel)
	heading = hud._label("Races",28,hud.WHITE)
	shell.add_child(heading)
	library = VBoxContainer.new()
	library.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(library)
	library_tabs = hud._tabs(library)
	var saved_page = hud._tab(library_tabs,"Saved races")
	var import_page = hud._tab(library_tabs,"Import & share")
	var columns = RetainedContent.new()
	saved_page.add_child(columns)
	var saved_column = VBoxContainer.new()
	saved_column.add_theme_constant_override("separation",16)
	columns.add_child(saved_column)
	saved_column.add_child(hud._label("Saved races",20,hud.WHITE))
	list = ItemList.new()
	list.custom_minimum_size.y = 280
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(select_race)
	saved_column.add_child(list)
	var detail_column = VBoxContainer.new()
	detail_column.add_theme_constant_override("separation",18)
	columns.add_child(detail_column)
	detail_column.add_child(hud._label("Selected race",20,hud.WHITE))
	details = hud._label("",16,hud.MUTED)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_column.add_child(details)
	share_button = hud._button("Copy race code")
	share_button.pressed.connect(copy_selected)
	detail_column.add_child(share_button)
	benchmark_button = hud._button("Ski current mountain" if game.current_mountain else "Restart lab fixture")
	benchmark_button.pressed.connect(func(): close(); game.start_run(game.current_mountain==null))
	detail_column.add_child(benchmark_button)
	if not game.current_mountain:
		hud._note(detail_column,"The lab fixture is an unranked test course. Lab runs do not enter personal records.")
	code_input = TextEdit.new()
	code_input.placeholder_text = "Paste a shared race code here"
	code_input.custom_minimum_size.y = 200
	code_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	hud._note(import_page,"Import a shared race code to add it to your library. Copy a saved race's code from its details.")
	import_page.add_child(code_input)
	var import_button = hud._button("Import race code",true)
	import_button.pressed.connect(import_from_ui)
	# Import is a primary action and remains reachable below the scrolling code.
	library_actions = HFlowContainer.new()
	library_actions.add_theme_constant_override("h_separation",12)
	library_actions.add_theme_constant_override("v_separation",8)
	library_tabs.tab_changed.connect(func(index):
		race_button.visible = index==0
		import_button.visible = index==1
	)
	editor_scroll = ScrollContainer.new()
	editor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	editor_scroll.follow_focus = true
	editor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(editor_scroll)
	editor = VBoxContainer.new()
	editor.add_theme_constant_override("separation",16)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_scroll.add_child(editor)
	editor.add_child(hud._label("Race name",14,hud.LIME))
	name_input = LineEdit.new()
	name_input.placeholder_text = "Name this race"
	name_input.max_length = 60
	name_input.custom_minimum_size.y = 44
	name_input.text_changed.connect(func(_value): _refresh_draft())
	editor.add_child(name_input)
	start_button = hud._button("1  Place start",true)
	start_button.pressed.connect(func(): placing = "start"; _refresh_draft())
	editor.add_child(start_button)
	finish_button = hud._button("2  Place finish")
	finish_button.pressed.connect(func(): placing = "finish"; _refresh_draft())
	editor.add_child(finish_button)
	var here = hud._button("Use skier position")
	here.pressed.connect(func():
		var p: Vector3 = game.sim.position
		p.y = game.field.sample(p.x,p.z).height
		place_point(p)
	)
	editor.add_child(here)
	endpoint_label = hud._label("",14,hud.MUTED)
	endpoint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor.add_child(endpoint_label)
	hud._note(editor,"WASD / arrows pan; mouse wheel zooms outside this drawer. Left-click terrain to place a gate. After using the drawer, right-click terrain to resume camera movement without placing a gate.")
	hud._note(editor,"Choose any route. Cross the 10 m finish gate from either side.")
	status = hud._label("",14,hud.LIME)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.max_lines_visible = 3
	shell.add_child(status)
	shell.add_child(library_actions)
	var create = hud._button("Create race")
	create.pressed.connect(begin_creation)
	library_actions.add_child(create)
	race_button = hud._button("Race selected",true)
	race_button.pressed.connect(play_selected)
	library_actions.add_child(race_button)
	library_actions.add_child(import_button)
	import_button.hide()
	var footer = HBoxContainer.new()
	footer.name = "RaceActions"
	footer.add_theme_constant_override("separation",12)
	shell.add_child(footer)
	var back = hud._button("Back")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(back_pressed)
	footer.add_child(back)
	save_button = hud._button("Save race",true)
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(save_draft)
	footer.add_child(save_button)
	editor_scroll.hide()
	editor.hide()
	save_button.hide()
	panel.hide()
	hud.register_menu_background(library)

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
	_refresh_library()

func _refresh_library(select_id: String = "") -> void:
	mode = "library"
	survey_keyboard_enabled = false
	game.hud.shell_layout.frame(panel)
	heading.text = "Races"
	library_actions.show()
	editor_scroll.hide()
	save_button.hide()
	cursor.hide()
	if zone_outline: zone_outline.hide()
	library_tabs.current_tab = 0
	library.visible = true
	editor.visible = false
	benchmark_button.visible = game.session.race != null or game.current_mountain != null
	races = store.load_all()
	if suggested_race and not races.any(func(r): return r.identity()==suggested_race.identity()): races.push_front(suggested_race)
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
	details.text = "Mountain %d\nStart  %s\nFinish  %s\n\nChoose any route. Cross the 10 m finish gate from either side." % [selected.mountain.seed,_coordinates(selected.start),_coordinates(selected.finish)]
	race_button.disabled = false
	share_button.disabled = false
	if matches_world(selected):
		show_race(selected)
		focus_point = selected.start.lerp(selected.finish,0.5)
		survey_height = clampf(selected.start.distance_to(selected.finish)*1.25,100,_survey_limit())
		_update_survey()
	else:
		show_race(null)
		status.text = "Racing this course loads its saved mountain."

func begin_creation() -> void:
	mode = "create"
	game.hud.shell_layout.frame(panel,true)
	heading.text = "Create race"
	library_actions.hide()
	editor_scroll.show()
	save_button.show()
	survey.make_current()
	_update_survey()
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
	_enable_keyboard_survey()

func place_point(point: Vector3) -> bool:
	if mode!="create": return false
	var error = Race.point_error(point,game.field)
	var yaw=Race.Flavor.downhill_heading(game.field,point)
	if error.is_empty(): error=Race.gate_error(point,yaw,game.field)
	if not error.is_empty():
		status.text = error
		return false
	if placing=="start":
		draft.start = point
		draft.heading=yaw
		has_start = true
		placing = "finish"
	else:
		draft.finish = point
		draft.finish_heading=yaw
		has_finish = true
	_refresh_draft()
	_clear_markers()
	if has_start: _gate_marker(draft.start,"start_gate",draft.heading,false)
	if has_finish: _gate_marker(draft.finish,"finish_gate",draft.finish_heading,false)
	status.text = "Name and save your race, or reposition either endpoint." if has_start and has_finish else "Choose a finish on any face. Click terrain to place it."
	return true

func _refresh_draft() -> void:
	if not draft: return
	draft.title = name_input.text.strip_edges()
	start_button.text = "1  Start · " + ("Selected" if placing=="start" else "Reposition" if has_start else "Place")
	finish_button.text = "2  Finish · " + ("Selected" if placing=="finish" else "Reposition" if has_finish else "Place")
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

func import_from_ui() -> void:
	if game.loading.busy: return
	var text_value = code_input.text
	var decoded = Race.decode(text_value.strip_edges())
	if not decoded.has("race"):
		status.text = decoded.error
		game.hud.feedback.play("error")
		return
	game.loading.configure_feedback(game.hud.feedback)
	game.loading.begin("Importing shared race", "Checking the race's mountain and endpoints…")
	await game.loading.draw_frame()
	var rebuilt = {"field":game.field}
	if not matches_world(decoded.race):
		rebuilt = await game.loading.run_data(Race.reconstruct_surface.bind(decoded.race.mountain))
	var success = import_text(text_value,rebuilt)
	game.loading.finish()
	game.hud.feedback.play("ready" if success else "error")

func import_text(text_value: String, prepared_surface: Dictionary = {}) -> bool:
	var result = Race.decode(text_value.strip_edges())
	if not result.has("race"):
		status.text = result.error
		return false
	var race = result.race
	var rebuilt = prepared_surface
	if rebuilt.is_empty(): rebuilt = {"field":game.field} if matches_world(race) else Race.reconstruct_surface(race.mountain)
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
	survey_keyboard_enabled = false
	if zone_outline: zone_outline.hide()
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
		return
	if mode!="create" or not event is InputEventMouseButton or not event.pressed: return
	# This also protects direct callers; GUI scrolling must never zoom the world.
	if panel.get_global_rect().has_point(event.position): return
	if event.button_index==MOUSE_BUTTON_WHEEL_UP:
		survey_height = maxf(45.0,survey_height*0.82)
	elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
		survey_height = minf(_survey_limit(),survey_height/0.82)
	elif event.button_index==MOUSE_BUTTON_RIGHT:
		_enable_keyboard_survey()
	elif event.button_index==MOUSE_BUTTON_LEFT:
		_enable_keyboard_survey()
		var point = pick_snow(event.position)
		if point is Vector3: place_point(point)
		else: status.text = "Choose snow inside the skiable mountain."

func keyboard_survey_allowed() -> bool:
	return mode=="create" and survey_keyboard_enabled and get_window().has_focus() and get_viewport().gui_get_focus_owner()==null

func _enable_keyboard_survey() -> void:
	get_viewport().gui_release_focus()
	survey_keyboard_enabled = true

func owns_survey_key(event: InputEventKey) -> bool:
	# Consume before GUI navigation: an unfocused arrow key otherwise focuses the
	# drawer, which disables polling on the next frame. Releases belong here too.
	return keyboard_survey_allowed() and event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_LEFT,KEY_DOWN,KEY_RIGHT]

func update_survey(dt: float) -> void:
	if get_viewport().gui_get_focus_owner()!=null or not get_window().has_focus():
		survey_keyboard_enabled = false
	if keyboard_survey_allowed():
		# Physical keyboard state cannot inherit rider axes from a stick or D-pad.
		var x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		var z = float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
		focus_point += (Vector3.LEFT*x+Vector3.BACK*z).limit_length(1.0)*survey_height*dt*0.7
	_update_survey()
	cursor.visible = false
	if mode=="create" and not panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
		var point = pick_snow(get_viewport().get_mouse_position())
		if point is Vector3:
			cursor.position = point+Vector3.UP*1.5
			cursor.visible = true

func _update_survey() -> void:
	if zone_outline: zone_outline.visible = mode=="create"
	var area: Rect2 = game.field.ski_bounds().grow(-25.0)
	focus_point.x = clampf(focus_point.x,area.position.x,area.end.x)
	focus_point.z = clampf(focus_point.z,area.position.y,area.end.y)
	focus_point.y = game.field.sample(focus_point.x,focus_point.z).height
	var zone = Race.Zone.new(game.field)
	if zone.enabled:
		var offset = Vector2(focus_point.x,focus_point.z)-zone.center
		offset = offset.limit_length(zone.radius_m-zone.ENDPOINT_MARGIN_M)
		focus_point.x = zone.center.x+offset.x
		focus_point.z = zone.center.y+offset.y
		focus_point.y = game.field.sample(focus_point.x,focus_point.z).height
	survey.far = maxf(32000.0,_survey_limit()*2.5)
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
			if game.field.has_method("ray_geology") and not game.field.ray_geology(origin,hit).is_empty(): return null
			if not Race.Zone.new(game.field).endpoint_error(hit).is_empty(): return null
			return hit
		previous = p
	return null

func show_race(race) -> void:
	_clear_markers()
	game.world.set_benchmark_markers(race==null and mode.is_empty() and game.current_mountain==null)
	if race:
		var solid=mode.is_empty() and game.session.race==race
		_gate_marker(race.start,"start_gate",race.heading,solid)
		_gate_marker(race.finish,"finish_gate",race.finish_heading,solid)

func _gate_marker(point: Vector3, id: String, yaw: float, solid: bool) -> void:
	var seated=Race.Flavor.gate_seat(game.field,point,yaw)
	if seated.is_empty(): return
	var prop=load("res://assets/graphics/flavor_v1/scenes/"+id+".tscn").instantiate()
	prop.transform=seated.pose; prop.lighting=game.world.cloud_lighting
	markers.add_child(prop); prop.add_foundations(seated.foundations)
	prop.apply_quality(game.graphics.level)
	prop.set_collision_enabled(solid)
	if solid: prop.bind_surface(game.world.ski_surface)
	var finish = id=="finish_gate"
	var beams = Beams.new(); beams.name="FinishBeam" if finish else "StartBeam"
	markers.add_child(beams)
	beams.build(point,finish,game.field)
	# A narrow stripe marks the exact timing plane on the authoritative snow.
	var vertices=PackedVector3Array(); var basis=Basis(Vector3.UP,yaw)
	for i in 10:
		var a=-4.6+i*.92; var b=a+.92
		for local in [Vector3(a,0,-.12),Vector3(b,0,-.12),Vector3(a,0,.12),Vector3(b,0,-.12),Vector3(b,0,.12),Vector3(a,0,.12)]:
			var p=point+basis*local; p.y=game.field.sample(p.x,p.z).height+.04; vertices.append(p)
	var arrays=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=vertices
	var stripe=MeshInstance3D.new(); stripe.mesh=ArrayMesh.new(); stripe.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	stripe.material_override=_material(Beams.marker_color(finish)); stripe.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markers.add_child(stripe)

func _clear_markers() -> void:
	for child in markers.get_children():
		markers.remove_child(child)
		child.queue_free()

func _build_zone_outline() -> void:
	var zone = Race.Zone.new(game.field)
	if not zone.enabled: return
	var vertices = PackedVector3Array()
	for i in 1024:
		var a = TAU*float(i)/1024.0
		var b = TAU*float(i+1)/1024.0
		for pair in [[a,-4.0],[b,-4.0],[a,4.0],[a,4.0],[b,-4.0],[b,4.0]]:
			var p = zone.center+Vector2.from_angle(pair[0])*(zone.radius_m+pair[1])
			vertices.append(Vector3(p.x,game.field.sample(p.x,p.y).height+0.6,p.y))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	zone_outline = MeshInstance3D.new()
	zone_outline.name = "SummitReturnBoundary"
	zone_outline.mesh = mesh
	zone_outline.material_override = _material(Color("c2e76b"))
	zone_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone_outline.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(zone_outline)
	zone_outline.hide()

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
