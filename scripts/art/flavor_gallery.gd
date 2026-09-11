extends Node3D
## Interactive source review. This gallery never creates a race or a record.
var manifest: Dictionary
var prop: Node3D
var camera: Camera3D
var title: Label
var details: Label
var selected = 0
var lod = 0
var snowy = true
var yaw = .35
var pitch = .18
var zoom = 1.0

func _ready() -> void:
	get_window().size=Vector2i(1600,1000)
	get_window().title="Alpine Apex | Mountain curiosities"
	Engine.max_fps=120
	get_viewport().msaa_3d=Viewport.MSAA_4X
	manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/flavor_v1/manifest.json"))
	var environment=WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.10,.14,.19)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.69,.79,.92)
	environment.environment.ambient_light_energy=.45
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.environment.ssao_enabled=true; add_child(environment)
	var sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-42,-32,0)
	sun.light_color=Color(1,.94,.86); sun.light_energy=1.1; sun.shadow_enabled=true; add_child(sun)
	var ground=MeshInstance3D.new(); ground.mesh=PlaneMesh.new(); ground.mesh.size=Vector2(200,200)
	var mat=StandardMaterial3D.new(); mat.albedo_color=Color(.22,.29,.36); mat.roughness=.96
	ground.material_override=mat; ground.position.y=-.035; add_child(ground)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.far=250; add_child(camera)
	_ui()
	show_asset(0)
	if "--capture" in OS.get_cmdline_user_args(): call_deferred("capture_all")

func _ui() -> void:
	var canvas=CanvasLayer.new(); add_child(canvas)
	var panel=PanelContainer.new(); panel.position=Vector2(24,24); panel.custom_minimum_size=Vector2(305,0); canvas.add_child(panel)
	var style=StyleBoxFlat.new(); style.bg_color=Color(.025,.037,.052,.95)
	style.content_margin_left=20; style.content_margin_right=20; style.content_margin_top=18; style.content_margin_bottom=18
	style.corner_radius_top_left=12; style.corner_radius_top_right=12; style.corner_radius_bottom_left=12; style.corner_radius_bottom_right=12
	panel.add_theme_stylebox_override("panel",style)
	var box=VBoxContainer.new(); box.add_theme_constant_override("separation",7); panel.add_child(box)
	var eyebrow=Label.new(); eyebrow.text="ALPINE APEX"; eyebrow.add_theme_color_override("font_color",Color(.73,.88,.60)); box.add_child(eyebrow)
	var heading=Label.new(); heading.text="Mountain curiosities"; heading.add_theme_font_size_override("font_size",24); box.add_child(heading)
	var sub=Label.new(); sub.text="12 discoveries and race assets"; box.add_child(sub)
	box.add_child(HSeparator.new())
	for i in manifest.assets.size():
		var button=Button.new(); button.text=manifest.assets[i].label; button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y=34; button.pressed.connect(show_asset.bind(i)); box.add_child(button)
	box.add_child(HSeparator.new())
	var help=Label.new(); help.text="Drag to orbit · Wheel to zoom\n← → Browse · L Detail · S Snow\nEsc Close"; box.add_child(help)
	var label_panel=VBoxContainer.new(); label_panel.position=Vector2(365,30); canvas.add_child(label_panel)
	title=Label.new(); title.add_theme_font_size_override("font_size",30); label_panel.add_child(title)
	details=Label.new(); details.add_theme_font_size_override("font_size",16); label_panel.add_child(details)
	title.add_theme_color_override("font_color",Color(.055,.085,.12))
	details.add_theme_color_override("font_color",Color(.10,.15,.20))

func show_asset(index: int) -> void:
	selected=posmod(index,manifest.assets.size())
	if prop: prop.free()
	var record=manifest.assets[selected]
	prop=load("res://assets/graphics/flavor_v1/scenes/"+record.id+".tscn").instantiate(); add_child(prop)
	prop.set_detail(lod)
	prop.set_snow(record.snow_amount if snowy else 0.0)
	yaw=.35; pitch=.18; zoom=1.0
	update_view()

func update_view() -> void:
	var record=manifest.assets[selected]
	var size=Vector3(record.dimensions_m[0],record.dimensions_m[1],record.dimensions_m[2])
	var span=maxf(size.x*.85,maxf(size.y*1.5,size.z*1.35))*zoom
	camera.size=maxf(span,.5)
	# Offset along the camera's horizontal axis so the object remains right of
	# the sidebar throughout a full orbit, including its rear view.
	var aim=Vector3(-cos(yaw)*span*.17,size.y*.58,sin(yaw)*span*.17)
	camera.position=aim+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*45
	camera.look_at(aim)
	title.text=record.label
	var snow_label="Authored snow in base asset" if record.snow_amount==0 else ("Snow treatment on" if snowy else "Base material")
	details.text="%.2f × %.2f × %.2f m  ·  %s detail  ·  %s triangles\n%s" % [size.x,size.y,size.z,["Near","Mid","Far"][lod],str(record.models[lod].triangles),
		"10 m clear passage · 4.5 m overhead clearance · solid supports" if record.has("clearance_m") else snow_label]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw-=event.relative.x*.007; pitch=clampf(pitch+event.relative.y*.005,-.1,1.2); update_view()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: zoom=maxf(.35,zoom*.9); update_view()
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom=minf(3,zoom/ .9); update_view()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE: get_tree().quit()
			KEY_LEFT: show_asset(selected-1)
			KEY_RIGHT: show_asset(selected+1)
			KEY_L: lod=(lod+1)%3; prop.set_detail(lod); update_view()
			KEY_S: snowy=not snowy; prop.set_snow(manifest.assets[selected].snow_amount if snowy else 0); update_view()

func capture_all() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/flavor_v1/gallery")
	for i in manifest.assets.size():
		show_asset(i)
		for frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/flavor_v1/gallery/"+manifest.assets[i].id+".png")
		lod=2; prop.set_detail(lod); update_view()
		for frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/flavor_v1/gallery/"+manifest.assets[i].id+"_far.png")
		lod=0
	# Generated geometry and signs must also read from behind and at low detail.
	for id in ["start_gate","finish_gate","alpine_refuge","marmot_monument"]:
		for i in manifest.assets.size():
			if manifest.assets[i].id==id: show_asset(i); break
		yaw=PI+.35; update_view()
		for frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/flavor_v1/gallery/"+id+"_rear.png")
		lod=2; prop.set_detail(lod); yaw=.35; update_view()
		for frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/flavor_v1/gallery/"+id+"_far.png")
		lod=0
	print("FLAVOR_GALLERY_CAPTURED ",manifest.assets.size())
	get_tree().quit()
