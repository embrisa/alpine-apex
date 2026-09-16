extends SceneTree
## Small rendered test: no mountain bake, player preferences, physics or records.
const Settings = preload("res://scripts/presentation/pc_graphics_settings.gd")
var failures: Array[String] = []
var results: Array = []
var scene: Node3D
var camera: Camera3D
var moving: MeshInstance3D
var label: Label
var settings = Settings.new()
var frame: int = 0
var before_count: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	print("PASS: " if value else "FAIL: ",description)
	if not value: failures.append(description)

func box(position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .8
	instance.material_override = material
	instance.position = position
	scene.add_child(instance)
	return instance

func run() -> void:
	check(DisplayServer.get_name()!="headless","Native renderer is active")
	check(Settings.has_native_fsr(),"Custom DX12 FidelityFX engine is present")
	if not failures.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute("res://artifacts/fidelityfx/captures")
	root.size = Vector2i(1280,720)
	root.mode = Window.MODE_WINDOWED
	root.title = "Alpine Apex · FidelityFX integration validation"
	scene = Node3D.new()
	root.add_child(scene)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.15,.3,.48)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.7,.8,1)
	environment.environment.ambient_light_energy = .65
	scene.add_child(environment)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-25,0)
	light.shadow_enabled = true
	scene.add_child(light)
	for z in 12:
		for x in 16:
			box(Vector3(x-7.5,-.15,-z),Vector3(.97,.3,.97),Color(.85,.92,1) if (x+z)%2 else Color(.09,.15,.2))
	for index in 10:
		box(Vector3(index-4.5,.9,-5),Vector3(.08,1.8,.08),Color(.1,.5,.18))
	moving = box(Vector3(0,.65,-2),Vector3(.6,1.3,.6),Color(1,.24,.03))
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0,3,5)
	camera.look_at(Vector3(0,0,-3))
	camera.current = true
	var canvas = CanvasLayer.new()
	root.add_child(canvas)
	var backing = ColorRect.new()
	backing.position = Vector2(20,20)
	backing.size = Vector2(780,94)
	backing.color = Color(.02,.03,.05,.92)
	canvas.add_child(backing)
	label = Label.new()
	label.position = Vector2(36,28)
	label.add_theme_font_size_override("font_size",22)
	canvas.add_child(label)
	settings.display_mode = "windowed"
	settings.render_scale = .75
	settings.fps_limit = 90
	await phase("fsr4",false,"fsr4",90)
	await phase("fsr3",false,"fsr3",90)
	await phase("fsr4",true,"fsr4_fg3",150)
	root.size = Vector2i(1440,810)
	await phase("fsr3",true,"fsr3_fg3_resize",150)
	settings.reset_history()
	camera.position = Vector3(2,3,5)
	camera.look_at(Vector3(0,0,-3))
	await phase("native",true,"native_fg3_reset",90)
	await phase("fsr2",false,"fsr2_fallback",45)
	check(settings.fsr_status().get("generated_frames",0)>0,"SDK dispatched generated frames")
	var report = {"engine":Engine.get_version_info(),"executable":OS.get_executable_path(),
		"executable_sha256":FileAccess.get_sha256(OS.get_executable_path()),"failures":failures,"phases":results,
		"note":"Render and SDK dispatch evidence; full mountain, pacing, visual motion quality and other GPUs require separate validation."}
	preload("res://tests/test_report.gd").write("res://artifacts/fidelityfx/render-results.json",JSON.stringify(report,"\t"))
	print("FIDELITYFX_RESULTS ",JSON.stringify(report))
	settings.frame_generation = false
	settings.apply_viewport(root)
	for i in 5: await process_frame
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func phase(mode: String, fg: bool, name: String, frames: int) -> void:
	settings.upscaler = mode
	settings.frame_generation = fg
	var before: Dictionary = settings.fsr_status()
	settings.apply_viewport(root)
	for i in frames:
		frame += 1
		moving.position.x = sin(frame*.055)*3.0
		moving.rotation.y = frame*.02
		label.text = "%s · %d%% render scale\nHUD at output resolution | Frame %05d" % [name,roundi(root.scaling_3d_scale*100),frame]
		await process_frame
	await RenderingServer.frame_post_draw
	var status: Dictionary = settings.fsr_status()
	var capture = root.get_texture().get_image()
	check(capture.save_png("res://artifacts/fidelityfx/captures/"+name+".png")==OK,name+" captured")
	check(status.get("error","")=="",name+" has no SDK error")
	if mode in ["fsr4","fsr3"]:
		check(str(status.get("active_upscaler_version","")).begins_with("4.1" if mode=="fsr4" else "3.1"),name+" uses requested provider")
		check(status.get("upscale_dispatches",0)>before.get("upscale_dispatches",0),name+" dispatches temporal upscaling")
	check(bool(status.get("frame_generation_active",false))==fg,name+" frame generation state matches selection")
	if fg: check(status.get("generated_frames",0)>before.get("generated_frames",0),name+" generates new frames")
	results.append({"name":name,"status":status,"output_pixels":[capture.get_width(),capture.get_height()],"settings":settings.snapshot()})
