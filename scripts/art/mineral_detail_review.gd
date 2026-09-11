extends Control
## Actual imported game materials, with identical cameras and lighting.

var views: Array[SubViewport] = []
var cameras: Array[Camera3D] = []
var yaw := .60
var pitch := .48
var zoom := 5.5
var automated := false
var with_grass := false

func _ready() -> void:
	automated = "--capture" in OS.get_cmdline_user_args()
	with_grass = "--grass" in OS.get_cmdline_user_args()
	get_window().size = Vector2i(2040, 1020)
	get_window().title = "Alpine Apex | Rock detail comparison"
	var background := ColorRect.new()
	background.color = Color("141a20")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var title := Label.new()
	title.text = "ROCK DETAIL / ORIGINAL EXPORT → REBUILT BARE ROCK → OPTIONAL " + ("MOSS + GRASS" if with_grass else "MOSS")
	title.position = Vector2(32, 23)
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)
	var file := "medium/mineral_medium_sedimentary_01.glb"
	for index in range(3):
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1600,1200)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_4X
		add_child(viewport)
		views.append(viewport)
		var root := Node3D.new()
		viewport.add_child(root)
		var world := WorldEnvironment.new()
		world.environment = Environment.new()
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color("252e36")
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color(.74,.80,.89)
		world.environment.ambient_light_energy = .48
		world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		world.environment.ssao_enabled = true
		root.add_child(world)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-48,-35,0)
		sun.light_energy = 1.7
		sun.light_color = Color(1,.93,.84)
		sun.shadow_enabled = true
		root.add_child(sun)
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(200,200)
		ground.mesh = plane
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(.16,.19,.22)
		mat.roughness = .95
		ground.material_override = mat
		ground.position.y = -.02
		root.add_child(ground)
		var pack := "minerals" if index == 0 else "minerals_v3"
		var asset_path := "res://assets/graphics/"+pack+"/"+file
		if index == 2 and with_grass: asset_path = "res://assets/graphics/minerals_v3/moss_grass/medium/mineral_medium_sedimentary_01_moss_grass.tscn"
		var asset := (load(asset_path) as PackedScene).instantiate() as Node3D
		root.add_child(asset)
		var mesh := find_mesh(asset)
		var bounds := mesh.mesh.get_aabb()
		var span := maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
		asset.scale = Vector3.ONE*(4.0/span)
		if index == 2:
			assert(mesh.has_meta("optional_moss_material"))
			mesh.set_surface_override_material(0, mesh.get_meta("optional_moss_material") as Material)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.far = 100
		root.add_child(camera)
		cameras.append(camera)
		var rect := TextureRect.new()
		rect.texture = viewport.get_texture()
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.position = Vector2(index*680,135)
		rect.size = Vector2(680,720)
		add_child(rect)
		var label := Label.new()
		label.text = ["PREVIOUS PACK", "REBUILT / BARE ROCK", "OPTIONAL MOSS + GRASS" if with_grass else "REBUILT / OPTIONAL MOSS"][index]
		label.position = Vector2(index*680+28,101)
		label.add_theme_font_size_override("font_size",24)
		add_child(label)
		var caption := Label.new()
		var triangles: int = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3
		caption.text = [("%s triangles • shared 1K maps" % triangles), ("%s triangles • unique 4K normal bake" % triangles), "Optional static grass tufts + patchy moss" if with_grass else "Same mesh and bakes • moss material variant"][index]
		caption.position = Vector2(index*680+28,865)
		caption.add_theme_font_size_override("font_size",20)
		add_child(caption)
	var help := Label.new()
	help.text = "Same lighting and display span. Drag to orbit all views; wheel to zoom. Escape closes the review.\nThe 2 m sedimentary asset is shown here. Geometry and materials were rebuilt; this is not a lighting-only comparison."
	help.position = Vector2(32,935)
	help.add_theme_font_size_override("font_size",18)
	add_child(help)
	update_cameras()
	if automated: capture()

func find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var found := find_mesh(child)
		if found: return found
	return null

func update_cameras() -> void:
	for camera in cameras:
		camera.size = zoom
		camera.position = Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*15
		camera.look_at(Vector3(0,.8,0))

func _unhandled_input(event: InputEvent) -> void:
	if automated: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: get_tree().quit()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x*.007
		pitch = clampf(pitch+event.relative.y*.005,.15,1.35)
		update_cameras()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom = maxf(2.5,zoom-.3)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(9,zoom+.3)
		update_cameras()

func capture() -> void:
	for frame in range(30): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/minerals_v3/comparison"+("_grass" if with_grass else "")+".png")
	for index in range(views.size()):
		views[index].get_texture().get_image().save_png("res://artifacts/minerals_v3/"+["previous","bare","grass" if with_grass else "moss"][index]+".png")
	print("DETAIL_REVIEW_CAPTURE 2040x1020; close views 1600x1200")
	get_tree().quit()
