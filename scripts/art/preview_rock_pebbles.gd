extends SceneTree
## Isolated GLTFDocument review; no game imports, autoloads or personal state.
var asset_root := ""
var output := ""
var catalog: Dictionary
var stage: Node3D
var display: Node3D
var camera: Camera3D
var heading: Label
var subtitle: Label
var failures: Array[String] = []
var checks := 0
var captures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func load_asset(model: Dictionary) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var path := asset_root.path_join("models").path_join(model.file)
	check(FileAccess.get_sha256(path) == model.sha256, "Hash " + model.file)
	var error := doc.append_from_file(path, state)
	check(error == OK, "GLB load " + model.file)
	if error != OK: return Node3D.new()
	var node := doc.generate_scene(state) as Node3D
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1, "Single mesh " + model.file)
	check(node.find_children("*", "CollisionObject3D", true, false).is_empty(), "No physics nodes")
	for child: MeshInstance3D in meshes:
		check(child.mesh.get_surface_count() == 1, "One surface")
		check(child.mesh.get_faces().size() / 3 == int(model.triangles), "Triangle count")
		var box := child.mesh.get_aabb()
		var dims: Array = model.dimensions_godot_xyz_m
		check(box.size.distance_to(Vector3(dims[0],dims[1],dims[2])) < .00001, "Dimensions")
		check(absf(box.position.y) < .00001, "Base at zero")
		var arrays := child.mesh.surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_COLOR] != null and not arrays[Mesh.ARRAY_COLOR].is_empty(), "Color channel")
		var mat := child.mesh.surface_get_material(0) as StandardMaterial3D
		check(mat != null, "PBR material")
		if mat != null:
			# Direct GLTFDocument needs the COLOR_0 switch in the current editor.
			mat.vertex_color_use_as_albedo = true
			check(mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Opaque")
			check(mat.cull_mode == BaseMaterial3D.CULL_BACK, "Backface culling")
	return node

func reset_display() -> void:
	if display != null: display.free()
	display = Node3D.new()
	stage.add_child(display)

func add_model(record: Dictionary, lod: int, position: Vector3, yaw: float = 0) -> void:
	var node := load_asset(record.models[lod])
	display.add_child(node)
	node.position = position
	node.rotation.y = yaw

func label(text: String, position: Vector3) -> void:
	var item := Label3D.new()
	item.text = text
	item.font_size = 28
	item.pixel_size = .0008
	item.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	item.no_depth_test = true
	item.modulate = Color(.85,.89,.91)
	display.add_child(item)
	item.position = position

func capture(name: String) -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join(name + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "Capture " + name)
	captures.append(path)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--assets="): asset_root = arg.trim_prefix("--assets=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if asset_root.is_empty() or output.is_empty():
		printerr("Missing --assets or --output")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	catalog = JSON.parse_string(FileAccess.get_file_as_string(asset_root.path_join("manifest.json")))
	root.size = Vector2i(1280,800)
	root.title = "Cosmetic rock pebbles - isolated asset review"
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.06,.08,.1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.82,.87,.95)
	environment.ambient_light_energy = .65
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-25,0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	stage.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	camera.make_current()
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	heading = Label.new()
	heading.position = Vector2(36,25)
	heading.add_theme_font_size_override("font_size",25)
	overlay.add_child(heading)
	subtitle = Label.new()
	subtitle.position = Vector2(37,65)
	subtitle.add_theme_font_size_override("font_size",16)
	subtitle.modulate = Color(.65,.73,.78)
	overlay.add_child(subtitle)
	for record in catalog.assets:
		for model in record.models:
			var node := load_asset(model)
			node.free()
	reset_display()
	heading.text = "ROCK DETAIL  /  GRAVEL, PEBBLES & SHALE CHIPS"
	subtitle.text = "Actual relative sizes, 5-28 cm  |  80 triangles each  |  Cosmetic meshes, no collision"
	for i in catalog.assets.size():
		var record: Dictionary = catalog.assets[i]
		var p := Vector3((i%3-1)*.44, 0, (i/3-1)*.37)
		add_model(record,0,p,.3)
		label("%s / %.0f cm" % [record.id,record.models[0].dimensions_godot_xyz_m[0]*100],p+Vector3(0,-.03,.15))
	camera.size = 1.45
	camera.position = Vector3(0,1.7,2.5)
	camera.look_at(Vector3.ZERO)
	await capture("collection")
	reset_display()
	heading.text = "GEOMETRY LEVELS  /  SAME PHYSICAL SIZE"
	subtitle.text = "80 / 40 / 16 triangles  |  Runtime transition distances will be measured during integration"
	for row in 2:
		var record: Dictionary = catalog.assets[5 if row == 0 else 8]
		for lod in 3:
			var p := Vector3((lod-1)*.42,0,(row-.5)*.4)
			add_model(record,lod,p,.3)
			label("%s / LOD%d" % [record.id,lod],p+Vector3(0,-.03,.15))
	camera.size = 1.15
	await capture("lod_comparison")
	reset_display()
	heading.text = "SURFACE DETAIL  /  ISOLATED ARRANGEMENT"
	subtitle.text = "Visual density example on a review plane  |  Production rock masking, snow and FPS remain integration work"
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.3,2.3)
	floor_node.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.31,.32,.33)
	material.roughness = 1
	floor_node.material_override = material
	display.add_child(floor_node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 914
	for i in 220:
		var selected := rng.randi_range(0,5) if i%7 != 0 else rng.randi_range(6,8)
		var record: Dictionary = catalog.assets[selected]
		add_model(record,0,Vector3(rng.randf_range(-1,1),-.004,rng.randf_range(-1,1)),rng.randf_range(0,TAU))
	camera.size = 2.1
	camera.position = Vector3(0,2.2,2.8)
	camera.look_at(Vector3.ZERO)
	await capture("surface_detail")
	var report := {"checks":checks,"failures":failures,"models_checked":27,"captures":captures,
		"manifest_sha256":FileAccess.get_sha256(asset_root.path_join("manifest.json")),
		"engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),
		"renderer":"gl_compatibility","scope":"Isolated asset review; no game terrain or performance acceptance"}
	FileAccess.open(output.path_join("native_validation.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("PEBBLE_NATIVE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"captures":captures.size()}))
	quit(0 if failures.is_empty() else 1)
