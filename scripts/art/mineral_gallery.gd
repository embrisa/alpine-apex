extends Node3D
## Standalone asset review. It creates no race/session and writes no records.

const CATEGORIES = ["small", "medium", "large", "huge_boulders", "cliffs"]
const FAMILIES = ["rounded", "fractured", "sedimentary", "outcrop", "cliff", "glacier"]
var manifest: Dictionary
var display: Node3D
var camera: Camera3D
var heading: Label
var category_index := 1
var yaw := 0.0
var pitch := 1.0
var distance := 34.0
var automated := false
var moss := false

func _ready() -> void:
	automated = "--capture" in OS.get_cmdline_user_args()
	get_window().size = Vector2i(1400,1800)
	get_window().title = "Alpine Apex | Mineral asset library"
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/minerals_v3/manifest.json"))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.10,.15,.23)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.64,.76,.91)
	environment.environment.ambient_light_energy = .65
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.ssao_enabled = true
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53,-32,0)
	sun.light_energy = 1.65
	sun.light_color = Color(1,.93,.84)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(180,180)
	ground.mesh = plane
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(.64,.72,.80)
	snow.roughness = .90
	ground.material_override = snow
	ground.position.y = -.04
	add_child(ground)
	display = Node3D.new()
	add_child(display)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = distance
	camera.far = 300
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(26,22)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	panel.add_child(margin)
	var text := VBoxContainer.new()
	margin.add_child(text)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size",28)
	text.add_child(heading)
	var help := Label.new()
	help.text = "1 Small   2 Medium   3 Large   4 Huge boulders   5 Cliffs\nDrag to orbit | Wheel to zoom | M: optional moss | Equal-sized previews; labels show actual metres."
	help.add_theme_font_size_override("font_size",16)
	text.add_child(help)
	show_category(category_index)
	if "--formations-only" in OS.get_cmdline_user_args(): show_category(3)
	if automated: capture_all()

func show_category(index: int) -> void:
	category_index = index
	for child in display.get_children(): child.free()
	heading.text = "ALPINE APEX / " + CATEGORIES[index].replace("_"," ").to_upper() + " / DETAIL v3"
	var families: Array = manifest.get("category_families", {}).get(CATEGORIES[index], FAMILIES)
	for row: Dictionary in manifest.assets:
		if row.category != CATEGORIES[index]: continue
		var object := (load("res://"+row.path) as PackedScene).instantiate() as Node3D
		display.add_child(object)
		var dims: Array = row.dimensions_godot_xyz_m
		var span := maxf(float(dims[0]),maxf(float(dims[1]),float(dims[2])))
		object.scale = Vector3.ONE*(2.9/span)
		object.position = Vector3((int(row.variant)-2.5)*4.4,0,(families.find(row.family)-2.5)*5.2)
		apply_moss(object)
		var label := Label3D.new()
		label.text = "%s %02d | %s m" % [row.family, int(row.variant), str(snappedf(span,.01))]
		label.font_size = 40
		label.pixel_size = .008
		label.modulate = Color(.07,.11,.17)
		label.outline_size = 0
		label.no_depth_test = true
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		display.add_child(label)
		label.position = object.position+Vector3(0,.06,2.15)
	update_camera()

func apply_moss(node: Node) -> void:
	if node is MeshInstance3D and node.has_meta("optional_moss_material"):
		node.set_surface_override_material(0,node.get_meta("optional_moss_material") as Material if moss else null)
	for child in node.get_children(): apply_moss(child)

func update_camera() -> void:
	camera.size = distance
	camera.position = Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*45
	camera.look_at(Vector3.ZERO)

func _unhandled_input(event: InputEvent) -> void:
	if automated: return
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5]: show_category(event.keycode-KEY_1)
		if event.keycode == KEY_ESCAPE: get_tree().quit()
		if event.keycode == KEY_M:
			moss = not moss
			apply_moss(display)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x*.007
		pitch = clampf(pitch+event.relative.y*.005,.2,1.45)
		update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(8,distance-1.5)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(50,distance+1.5)
		update_camera()

func capture_all() -> void:
	var filter_category := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--category="): filter_category = arg.trim_prefix("--category=")
	for index in range(CATEGORIES.size()):
		if "--formations-only" in OS.get_cmdline_user_args() and index < 3: continue
		if not filter_category.is_empty() and CATEGORIES[index] != filter_category: continue
		yaw = .24 if index >= 3 else 0.0
		pitch = .92 if index >= 3 else 1.0
		show_category(index)
		for frame in range(24): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("res://artifacts/minerals_v3/godot_"+CATEGORIES[index]+".png")
		print("MINERAL_GALLERY_CAPTURE ",CATEGORIES[index]," ",image.get_size())
	get_tree().quit()
