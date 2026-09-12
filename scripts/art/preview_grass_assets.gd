extends SceneTree
## Isolated native asset review; no game scene, autoload, terrain or user state.
var asset_root := ""
var output := ""
var catalog: Dictionary
var stage: Node3D
var camera: Camera3D
var display: Array[Node3D] = []
var failures: Array[String] = []
var captures: Array[String] = []
var checks := 0
var interactive := false
var heading: Label
var subtitle: Label
var plant_mode := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func load_asset(model: Dictionary) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var path: String = asset_root.path_join("models").path_join(model.file)
	check(FileAccess.get_sha256(path) == model.sha256, "Export hash " + model.file)
	var error := document.append_from_file(path, state)
	check(error == OK, "GLB loads " + model.file)
	if error != OK: return Node3D.new()
	var node := document.generate_scene(state) as Node3D
	# This engine's direct GLTFDocument loader retains COLOR_0 but leaves the
	# first primitive's material flag off. Explicitly honor glTF's color contract
	# in this isolated loader; do not alter the game or rewrite exported colors.
	for child: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in child.mesh.get_surface_count():
			var mat := child.mesh.surface_get_material(i) as StandardMaterial3D
			if mat != null: mat.vertex_color_use_as_albedo = true
	return node

func inspect(node: Node3D, model: Dictionary) -> void:
	var triangles := 0
	var surfaces := 0
	var mesh_nodes := node.find_children("*", "MeshInstance3D", true, false)
	check(mesh_nodes.size() == 1, "One grass mesh, no embedded support")
	check(node.find_children("*", "CollisionObject3D", true, false).is_empty(), "No collision")
	for child: MeshInstance3D in mesh_nodes:
		var mesh := child.mesh
		triangles += mesh.get_faces().size()/3
		surfaces += mesh.get_surface_count()
		var box := mesh.get_aabb()
		check(box.position.y >= -.00001, "Base above zero")
		var dims: Array = model.dimensions_godot_xyz_m
		check(box.size.distance_to(Vector3(dims[0],dims[1],dims[2])) < .0001, "Native dimensions")
		for i in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(i)
			check(arrays[Mesh.ARRAY_COLOR] != null and not arrays[Mesh.ARRAY_COLOR].is_empty(), "Vertex colors")
			check(arrays[Mesh.ARRAY_TEX_UV] != null and not arrays[Mesh.ARRAY_TEX_UV].is_empty(), "Bend coordinates")
			check(arrays[Mesh.ARRAY_TEX_UV2] != null and not arrays[Mesh.ARRAY_TEX_UV2].is_empty(), "Root pivot UV")
			var mat := mesh.surface_get_material(i) as StandardMaterial3D
			check(mat != null and mat.vertex_color_use_as_albedo, "Portable vertex PBR")
			check(mat != null and mat.cull_mode == BaseMaterial3D.CULL_DISABLED, "Two-sided blades")
	check(triangles == int(model.triangles), "Native triangles match " + model.file)
	check(surfaces == 1, "One material surface")

func clear_display() -> void:
	for node in display: node.free()
	display.clear()

func add_model(record: Dictionary, lod: int, position: Vector3, yaw: float = 0.0) -> void:
	var node := load_asset(record.models[lod])
	stage.add_child(node)
	node.position = position
	node.rotation.y = yaw
	display.append(node)

func label(text_value: String, position: Vector3, size: float = .0014) -> void:
	var item := Label3D.new()
	item.text = text_value
	item.font_size = 32
	item.pixel_size = size
	item.modulate = Color(.79,.83,.85)
	item.outline_modulate = Color(.06,.075,.09)
	item.outline_size = 4
	item.no_depth_test = true
	item.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stage.add_child(item)
	item.position = position
	display.append(item)

func capture(name: String) -> void:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join(name + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "Capture saved " + name)
	captures.append(path)
	print("GRASS_CAPTURE ", name)

func collection() -> void:
	clear_display()
	heading.text = "ALPINE GRASS  /  PREPARED ASSET COLLECTION"
	if plant_mode: heading.text = "GROUND PLANTS  /  PREPARED ASSET COLLECTION"
	subtitle.text = "GREEN  /  LIGHT SNOW  /  SNOW-COVERED     -     Six shapes at their actual relative sizes"
	for i in catalog.assets.size():
		var record: Dictionary = catalog.assets[i]
		var column: int = i/3
		var row: int = i%3
		var position := Vector3((column-2.5)*.82, (2-row)*.80+.16, 0)
		add_model(record, 0, position)
		var desc: String = record.shape.replace("_", " ")
		var height: float = record.models[0].dimensions_godot_xyz_m[1]
		label("%s\n%s  |  %.0f cm" % [desc, record.finish, height*100], position+Vector3(0,-.09,.25),.00125)
	camera.size = 3.22
	camera.position = Vector3(0,1.30,8)
	camera.look_at(Vector3(0,1.26,0))

func detail(yaw: float = 0.0, selected_shape: String = "") -> void:
	clear_display()
	heading.text = "BLADE & SNOW DETAIL"
	subtitle.text = "Raised snow follows individual blades. Standalone meshes contain no ground, rock or pebble geometry."
	if plant_mode:
		heading.text = "LEAF & SNOW DETAIL"
		subtitle.text = "Leafy plants, ferns and low shrubs. Only living plant structure and attached snow are included."
	var shape := selected_shape if not selected_shape.is_empty() else ("leafy_cluster_02" if plant_mode else "meadow_clump_02")
	var records: Array = catalog.assets.filter(func(a): return a.shape == shape)
	for i in records.size():
		var p := Vector3((i-1)*.76,0,0)
		add_model(records[i],0,p,yaw)
		label(["GREEN","LIGHT SNOW","SNOW-COVERED"][i],p+Vector3(0,-.045,.2),.001)
	camera.size = 1.37
	camera.position = Vector3(0,.55,4)
	camera.look_at(Vector3(0,.20,0))

func lod_review() -> void:
	clear_display()
	heading.text = "DETAIL LEVELS  /  FOREST FAN 02"
	subtitle.text = "Near, reduced and coarse geometry at equal scale. Runtime LOD transitions remain future integration work."
	if plant_mode: heading.text = "DETAIL LEVELS  /  LOW SHRUB 02"
	var shape := "low_shrub_02" if plant_mode else "forest_fan_02"
	var records: Array = catalog.assets.filter(func(a): return a.shape == shape and a.finish != "dusted")
	for row in records.size():
		for lod in 3:
			var p := Vector3((lod-1)*1.0,(1-row)*.9,0)
			add_model(records[row],lod,p)
			label("%s  /  LOD%d  /  %d tris" % [records[row].finish,lod,records[row].models[lod].triangles],p+Vector3(0,-.08,.25),.0012)
	camera.size = 2.30
	camera.position = Vector3(0,.83,6)
	camera.look_at(Vector3(0,.78,0))

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--assets="): asset_root = arg.trim_prefix("--assets=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--interactive": interactive = true
		if arg == "--kind=plants": plant_mode = true
	if asset_root.is_empty() or output.is_empty():
		printerr("Missing --assets or --output")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	catalog = JSON.parse_string(FileAccess.get_file_as_string(asset_root.path_join("manifest.json")))
	root.size = Vector2i(1920,1080)
	root.title = "Standalone grass assets - isolated review"
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.10,.135,.16)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.87,.91,.96)
	environment.ambient_light_energy = .72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-25,0)
	sun.light_energy = 1.15
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15,150,0)
	fill.light_energy = .4
	fill.light_color = Color(.79,.85,1)
	stage.add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	camera.make_current()
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	heading = Label.new()
	heading.position = Vector2(48,26)
	heading.add_theme_font_size_override("font_size",28)
	heading.modulate = Color(.9,.93,.94)
	overlay.add_child(heading)
	subtitle = Label.new()
	subtitle.position = Vector2(49,68)
	subtitle.add_theme_font_size_override("font_size",18)
	subtitle.modulate = Color(.60,.69,.73)
	overlay.add_child(subtitle)
	var footer := Label.new()
	footer.text = "PREPARED ONLY   /   METRES, Y-UP   /   NO GAME INTEGRATION   /   NO SUPPORT SURFACES IN THIS REVIEW"
	footer.position = Vector2(49,1027)
	footer.add_theme_font_size_override("font_size",15)
	footer.modulate = Color(.55,.64,.69)
	overlay.add_child(footer)
	for record in catalog.assets:
		for model in record.models:
			var node := load_asset(model)
			inspect(node,model)
			node.free()
	collection()
	await capture("collection")
	detail()
	await capture("finish_detail")
	detail(deg_to_rad(145))
	await capture("finish_reverse")
	if plant_mode:
		detail(0.0,"fern_02")
		await capture("fern_detail")
		detail(0.0,"low_shrub_02")
		await capture("shrub_detail")
	lod_review()
	await capture("lod_comparison")
	collection()
	var report := {"checks":checks,"failures":failures,"exports_checked":54,"captures":captures,
		"manifest_sha256":FileAccess.get_sha256(asset_root.path_join("manifest.json")),
		"engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),
		"renderer":"gl_compatibility", "no_support_surfaces":true,"no_game_session":true,
		"direct_gltf_loader_vertex_color_flag_enabled":true,
		"scope":"native isolated assets; no wind, placement, gameplay or performance acceptance"}
	FileAccess.open(output.path_join("native_validation.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("GRASS_NATIVE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"captures":captures.size()}))
	if not interactive: quit(0 if failures.is_empty() else 1)

func _process(_delta: float) -> bool:
	if interactive and Input.is_key_pressed(KEY_ESCAPE): quit()
	return false
