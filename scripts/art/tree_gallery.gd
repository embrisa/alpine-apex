extends Node3D
## Standalone collection review: no game session, input simulation or records.
const FAMILY = ["spruce","fir","pine","birch","dead","broken"]
const Dynamics = preload("res://scripts/core/tree_dynamics.gd")
var assets
var manifest: Dictionary
var camera: Camera3D
var display: Node3D
var heading: Label
var status: Label
var category = "spruce"
var lod = 0
var snow = true
var wind = true
var yaw = .25
var pitch = .16
var distance = 22.0
var focus = Vector3(0,5.3,0)
var automated = false
var focused = false
var selected = 0
var time = 0.0
var records: Array = []
var springs: Array = []
var ticks = 0.0
var captures: Array = []
var state = {"wind_velocity":Vector3(2.8,0,.8),"enabled":true}

func _ready() -> void:
	automated = "--capture" in OS.get_cmdline_user_args()
	get_window().size = Vector2i(1920,1080)
	get_window().title = "Alpine Apex | Tree collection"
	get_viewport().msaa_3d=Viewport.MSAA_4X
	Engine.max_fps = 120
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/trees/manifest.json"))
	assets = load("res://scripts/presentation/alpine_assets.gd").new(load("res://scripts/presentation/cloud_lighting.gd").new(),load("res://scripts/presentation/graphics_quality.gd").preset(2))
	var env = WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.015,.022,.033)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(.68,.78,.88); env.environment.ambient_light_energy=.65
	env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.environment.ssao_enabled=true
	add_child(env)
	var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-40,-28,0); light.light_energy=1.5; light.light_color=Color(1,.94,.86); light.shadow_enabled=true; add_child(light)
	var floor_mesh=MeshInstance3D.new(); floor_mesh.mesh=PlaneMesh.new(); floor_mesh.mesh.size=Vector2(200,200)
	var floor_mat=StandardMaterial3D.new(); floor_mat.albedo_color=Color(.48,.55,.61); floor_mat.roughness=1
	floor_mesh.material_override=floor_mat; floor_mesh.position.y=-.025; add_child(floor_mesh)
	display=Node3D.new(); add_child(display)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.far=250; add_child(camera)
	var canvas=CanvasLayer.new(); add_child(canvas)
	var panel=PanelContainer.new(); panel.position=Vector2(20,16); canvas.add_child(panel)
	var style=StyleBoxFlat.new(); style.bg_color=Color(.02,.025,.035,.90); style.content_margin_left=16; style.content_margin_right=16; style.content_margin_top=10; style.content_margin_bottom=10; panel.add_theme_stylebox_override("panel",style)
	var box=VBoxContainer.new(); panel.add_child(box)
	heading=Label.new(); heading.add_theme_font_size_override("font_size",28); box.add_child(heading)
	var help=Label.new(); help.text="1 Spruce   2 Fir   3 Pine   4 Winter birch   5 Dead snags   6 Broken crowns   A All trees\nDrag: orbit   Wheel: zoom   Left/Right: select   F: close view   L: detail   S: snow   W: wind   Space: branch response   Esc: close"; help.add_theme_font_size_override("font_size",17); box.add_child(help)
	status=Label.new(); box.add_child(status)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--category="): category=arg.trim_prefix("--category=")
	show_category(category)
	if automated: call_deferred("capture_all")

func show_category(value: String) -> void:
	category=value
	for child in display.get_children(): child.free()
	records=[]; springs=[]
	var index=0
	for record in manifest.assets:
		if category!="all" and record.family!=category: continue
		var node=MultiMeshInstance3D.new(); node.multimesh=MultiMesh.new()
		node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		node.multimesh.mesh=assets.mesh(record.id+"_lod%d" % lod)
		node.multimesh.instance_count=1
		var target_height=4.5 if category=="all" else 10.5
		var scale_value=target_height/float(record.height_m)
		var p=Vector3((int(record.variant)-2.5)*8,0,0)
		if category=="all": p=Vector3((FAMILY.find(record.family)-2.5)*6,0,(int(record.variant)-2.5)*8)
		var transform_value=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_value),p)
		node.multimesh.set_instance_transform(0,transform_value)
		display.add_child(node)
		var label=Label3D.new(); label.text="%s %02d / %s m" % [record.family.capitalize(),record.variant,str(record.height_m)]
		label.font_size=36; label.pixel_size=.011
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test=true
		label.position=p+Vector3(0,-.1,1.8 if category=="all" else 2.7); display.add_child(label)
		records.append({"record":record,"anchor":p,"scale":scale_value})
		springs.append(Dynamics.new(record.branches))
		index+=1
	focus=Vector3(0,3.4,0) if category=="all" else Vector3(0,5.2,0)
	distance=30 if category=="all" else 22
	pitch=.65 if category=="all" else .12
	focused=false
	selected=clampi(selected,0,maxi(0,records.size()-1))
	update_camera(); update_heading()

func focus_selected() -> void:
	if records.is_empty(): return
	focused=true
	var broken=records[selected].record.family=="broken"
	focus=records[selected].anchor+Vector3(0,8.8 if broken else 4.5,0)
	distance=4.8 if broken else 9.0
	update_camera()

func update_heading() -> void:
	heading.text="ALPINE APEX / "+("TREE COLLECTION" if category=="all" else str(manifest.families[category].label).to_upper())
	status.text="%d trees | %s | Snow %s | Wind %s | Previews share a display height; labels show actual metres." % [records.size(),["Near","Mid","Far"][lod],"on" if snow else "off","on" if wind else "off"]

func update_camera() -> void:
	camera.size=distance
	camera.position=focus+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*65
	camera.look_at(focus)

func _process(dt: float) -> void:
	if not assets: return
	time+=dt; state.enabled=wind
	assets.update_wind(state,dt,wind)
	ticks+=minf(dt,.1)
	while ticks>=Dynamics.DT:
		for spring in springs: spring.step(Vector3(100,100,100),Vector3(100,100,100),Vector3.ZERO)
		ticks-=Dynamics.DT
	if assets.named_materials.has("FC_Tree"):
		var mat: ShaderMaterial=assets.named_materials.FC_Tree
		mat.set_shader_parameter("snow_coverage",1.0 if snow else 0.0)
		var anchors=PackedVector4Array(); anchors.resize(4)
		var angles=PackedVector4Array(); angles.resize(48)
		for i in mini(4,records.size()):
			var p: Vector3=records[i].anchor; anchors[i]=Vector4(p.x,p.y,p.z,1)
			for b in 12:
				var a: Vector3=springs[i].angles[b]; angles[i*12+b]=Vector4(a.x,a.y,a.z,0)
		mat.set_shader_parameter("contact_anchors",anchors); mat.set_shader_parameter("contact_angles",angles)

func _unhandled_input(event: InputEvent) -> void:
	if automated: return
	if event is InputEventKey and event.pressed:
		if event.keycode>=KEY_1 and event.keycode<=KEY_6: show_category(FAMILY[event.keycode-KEY_1])
		if event.keycode==KEY_A: show_category("all")
		if event.keycode==KEY_ESCAPE: get_tree().quit()
		if event.keycode==KEY_L: lod=(lod+1)%3; show_category(category)
		if event.keycode==KEY_S: snow=not snow
		if event.keycode==KEY_W: wind=not wind
		if event.keycode==KEY_SPACE:
			for spring in springs:
				for bid in 12: spring.impulse(bid,Vector3(1.5,0,.4))
		if event.keycode in [KEY_LEFT,KEY_RIGHT] and not records.is_empty():
			selected=posmod(selected+(-1 if event.keycode==KEY_LEFT else 1),records.size()); focus_selected()
		if event.keycode==KEY_F and not records.is_empty():
			if focused: show_category(category)
			else: focus_selected()
		update_heading()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw-=event.relative.x*.005; pitch=clampf(pitch+event.relative.y*.004,.03,1.4); update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: distance=maxf(3,distance*.9)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: distance=minf(70,distance/ .9)
		update_camera()

func capture(id: String) -> void:
	for frame in 24: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/trees_v2/"+id+".png")
	captures.append(id)
	print("TREE_GALLERY_CAPTURE ",id)

func capture_all() -> void:
	var only=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--category="): only=arg.trim_prefix("--category=")
	wind=false
	for family in FAMILY:
		if only!="" and family!=only: continue
		if not manifest.assets.any(func(a): return a.family==family): continue
		show_category(family); await capture(family)
		if family in ["spruce","birch","dead","broken"]:
			focus=records[0].anchor+Vector3(0,9.0 if family=="broken" else 4.0,0)
			distance=4.5 if family=="broken" else 9.0
			update_camera(); await capture(family+"_detail")
		if family=="broken":
			for i in records.size():
				selected=i; focus_selected(); await capture("broken_%02d_detail" % (i+1))
	if only=="": show_category("all"); await capture("collection")
	FileAccess.open("res://artifacts/trees_v2/gallery.json",FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"pixels":get_viewport().get_texture().get_image().get_size(),"device":RenderingServer.get_video_adapter_name(),"no_game_session":true},"\t"))
	get_tree().quit()
