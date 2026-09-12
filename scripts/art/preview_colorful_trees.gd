extends SceneTree
## Runs in a generated isolated project. Never loads Alpine Apex's main scene.
var asset_root := ""
var output := ""
var catalog: Dictionary
var stage: Node3D
var camera: Camera3D
var environment: Environment
var floor_mesh: MeshInstance3D
var display_nodes: Array[Node3D] = []
var failures: Array[String] = []
var captures: Array[String] = []
var checks := 0
var interactive := false
var bake := false
var current_lod := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func load_asset(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	check(error == OK, "GLB loads: " + path.get_file())
	if error != OK:
		return Node3D.new()
	var node := document.generate_scene(state) as Node3D
	for child in node.find_children("*", "MeshInstance3D", true, false):
		for surface in child.mesh.get_surface_count():
			var mat: StandardMaterial3D = child.mesh.surface_get_material(surface)
			mat.vertex_color_use_as_albedo = true
	return node

func inspect_meshes(node: Node, record: Dictionary) -> void:
	var triangles := 0
	var surfaces := 0
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = child.mesh
		triangles += mesh.get_faces().size() / 3
		surfaces += mesh.get_surface_count()
		for i in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(i)
			check(arrays[Mesh.ARRAY_COLOR] != null and not arrays[Mesh.ARRAY_COLOR].is_empty(), "Vertex colors retained")
			check(arrays[Mesh.ARRAY_TEX_UV2] != null and not arrays[Mesh.ARRAY_TEX_UV2].is_empty(), "Branch metadata retained")
			check(mesh.surface_get_material(i) is StandardMaterial3D, "Portable PBR material")
			var mat: StandardMaterial3D = mesh.surface_get_material(i)
			if mat.resource_name.contains("Leaves"):
				check(mat.albedo_texture != null, "Leaf albedo texture retained")
				check(mat.normal_enabled and mat.normal_texture != null, "Leaf normal texture retained")
				check(mat.roughness_texture != null, "Leaf roughness texture retained")
	check(triangles == int(record.triangles), "Native triangles match manifest")
	check(surfaces == int(record.surfaces), "Native surfaces match manifest")

func clear_display() -> void:
	for node in display_nodes:
		node.free()
	display_nodes.clear()

func show_family(family: String, lod: int) -> void:
	clear_display()
	var records: Array = catalog.assets.filter(func(a): return family == "all" or a.family == family)
	for i in records.size():
		var record: Dictionary = records[i]
		var node := load_asset(asset_root.path_join("models").path_join(record.models[lod].file))
		stage.add_child(node)
		node.position = Vector3((i - (records.size() - 1) * .5) * 12.0, 0, 0)
		display_nodes.append(node)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0 if records.size() <= 3 else 42.0
	camera.position = Vector3(0, 9, 34)
	camera.look_at(Vector3(0, 6.0, 0))

func capture(name: String) -> void:
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join(name + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "Capture saved " + name)
	captures.append(path)
	print("COLORFUL_TREE_CAPTURE ", name)

func leaf_review() -> void:
	clear_display()
	for i in 2:
		var id := "golden_birch_01" if i == 0 else "autumn_maple_01"
		var node := load_asset(asset_root.path_join("models/" + id + "_leaf.glb"))
		stage.add_child(node)
		node.position.x = -.8 if i == 0 else .8
		display_nodes.append(node)
	camera.position = Vector3(0, .6, 5)
	camera.look_at(Vector3(0, .55, 0))
	camera.size = 1.8
	floor_mesh.visible = false
	await capture("leaf_types")
	floor_mesh.visible = true

func bake_atlases() -> void:
	clear_display()
	floor_mesh.visible = false
	root.size = Vector2i(512, 512)
	root.transparent_bg = true
	environment.background_mode = Environment.BG_CLEAR_COLOR
	var old_color := RenderingServer.get_default_clear_color()
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	DirAccess.make_dir_recursive_absolute(asset_root.path_join("impostors"))
	var baked: Array = []
	for record in catalog.assets:
		var node := load_asset(asset_root.path_join("models").path_join(record.models[0].file))
		stage.add_child(node)
		for mesh_node in node.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh_node.mesh.get_surface_count():
				var mat: StandardMaterial3D = mesh_node.mesh.surface_get_material(surface).duplicate()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh_node.set_surface_override_material(surface, mat)
		var height: float = record.models[0].dimensions_blender_xyz_m[2]
		var atlas := Image.create(4096, 512, false, Image.FORMAT_RGBA8)
		camera.size = height * 1.15
		for view in 8:
			var angle := float(view) * TAU / 8.0
			camera.position = Vector3(sin(angle) * height * 3, height * .5, cos(angle) * height * 3)
			camera.look_at(Vector3(0, height * .5, 0))
			for frame in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			check(img.get_pixel(0, 0).a < .01, "Transparent atlas background")
			atlas.blit_rect(img, Rect2i(0, 0, 512, 512), Vector2i(view * 512, 0))
		var filename: String = record.id + "_atlas.png"
		check(atlas.save_png(asset_root.path_join("impostors").path_join(filename)) == OK, "Impostor atlas saved")
		baked.append({"id": record.id, "file": filename, "views": 8, "tile_size": 512,
			"source_model_sha256": record.models[0].sha256,
			"sha256": FileAccess.get_sha256(asset_root.path_join("impostors").path_join(filename)),
			"view_yaw_degrees": [0,45,90,135,180,225,270,315], "span_m": height * 1.15,
			"center_height_m": height * .5, "lighting": "unlit portable material albedo", "integrated": false})
		node.free()
	FileAccess.open(asset_root.path_join("impostors/manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(baked, "\t") + "\n")
	root.transparent_bg = false
	RenderingServer.set_default_clear_color(old_color)
	root.size = Vector2i(1800, 1000)
	root.msaa_3d = Viewport.MSAA_4X
	environment.background_mode = Environment.BG_COLOR
	floor_mesh.visible = true

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--assets="): asset_root = arg.trim_prefix("--assets=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--interactive": interactive = true
		if arg == "--bake": bake = true
	if asset_root.is_empty() or output.is_empty():
		printerr("Missing --assets or --output")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	catalog = JSON.parse_string(FileAccess.get_file_as_string(asset_root.path_join("manifest.json")))
	root.size = Vector2i(1800, 1000)
	root.title = "Prepared tree assets — isolated review"
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.18, .23, .28)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.7, .78, .9)
	environment.ambient_light_energy = .4
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, -28, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	stage.add_child(sun)
	floor_mesh = MeshInstance3D.new()
	var floor_shape := PlaneMesh.new()
	floor_shape.size = Vector2(200, 200)
	floor_mesh.mesh = floor_shape
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(.76, .82, .87)
	snow.roughness = .85
	floor_mesh.material_override = snow
	stage.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	camera.make_current()
	for record in catalog.assets:
		for model in record.models:
			var node := load_asset(asset_root.path_join("models").path_join(model.file))
			inspect_meshes(node, model)
			node.free()
	if bake:
		await bake_atlases()
	for family in ["golden_birch", "autumn_maple"]:
		for lod in 3:
			show_family(family, lod)
			await capture(family + "_lod" + str(lod))
	await leaf_review()
	show_family("all", 0)
	await capture("collection")
	var report := {"checks": checks, "failures": failures, "captures": captures,
		"manifest_sha256": FileAccess.get_sha256(asset_root.path_join("manifest.json")),
		"renderer": RenderingServer.get_video_adapter_name(), "no_game_session": true,
		"scope": "isolated GLB asset verification; no forest integration or performance acceptance"}
	FileAccess.open(output.path_join("native_validation.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("COLORFUL_NATIVE_RESULTS ", JSON.stringify(report))
	if not interactive:
		quit(0 if failures.is_empty() else 1)

func _process(_delta: float) -> bool:
	if interactive and Input.is_key_pressed(KEY_ESCAPE): quit()
	return false
