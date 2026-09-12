extends SceneTree
## Capped, isolated renderer probe. This is visual/dispatch evidence, never FPS acceptance.
const Blur = preload("res://scripts/presentation/scene_motion_blur.gd")
const Graphics = preload("res://scripts/presentation/pc_graphics_settings.gd")
var checks = 0
var failures: Array[String] = []
var phases: Array = []
var output = "res://artifacts/scene_motion_blur/native"
var scene: Node3D
var camera: Camera3D
var moving: MeshInstance3D
var blur = Blur.new()
var graphics = Graphics.new()
var label: Label

func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures.append(caption); printerr("FAIL: ",caption)
func box(position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new(); mesh.size = size; node.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = color; material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = material; node.position = position
	scene.add_child(node)
	return node

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--blur-output="): output = "res://"+arg.get_slice("=",1)
	DirAccess.make_dir_recursive_absolute(output)
	check(Blur.unavailable_reason().is_empty(),"Forward+ is available")
	if not failures.is_empty(): quit(1); return
	root.size = Vector2i(960,540)
	root.mode = Window.MODE_WINDOWED
	root.title = "Alpine Apex · short motion blur check"
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	graphics.fps_limit = 30; graphics.upscaler = "native"; graphics.msaa = 1
	graphics.apply_viewport(root)
	scene = Node3D.new(); root.add_child(scene)
	var environment = WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.3,0.5,0.75)
	scene.add_child(environment)
	for z in range(-30,9):
		for x in range(-12,13):
			box(Vector3(x,-0.1,z),Vector3(0.98,0.2,0.98),Color(0.82,0.9,0.99) if (x+z)%2 else Color(0.15,0.2,0.25))
	for x in range(-8,9): box(Vector3(x,1,-5),Vector3(0.075,2.0,0.075),Color(0.1,0.42,0.12))
	moving = box(Vector3(0,0.9,-2),Vector3(0.7,1.8,0.4),Color(1,0.24,0.03))
	camera = Camera3D.new(); scene.add_child(camera)
	camera.near = 0.15; camera.far = 100
	camera.current = true
	camera.compositor = Compositor.new(); camera.compositor.compositor_effects = [blur]
	var canvas = CanvasLayer.new(); root.add_child(canvas)
	var backing = ColorRect.new(); backing.position = Vector2(10,10); backing.size = Vector2(490,60); backing.color = Color(0.01,0.02,0.03,1)
	canvas.add_child(backing)
	label = Label.new(); label.position = Vector2(20,16); label.add_theme_font_size_override("font_size",18); canvas.add_child(label)
	for mode in ["native","auto"]:
		for strength in [0.0,50.0,100.0]: await phase(mode,false,strength,false)
	await phase("native",false,0.0,true)
	await phase("native",false,100.0,true)
	if Graphics.has_native_fsr():
		await phase("native",true,50.0,false)
		await phase("auto",true,100.0,false)
	root.size = Vector2i(800,450)
	await phase("native",false,50.0,false)
	check(blur.status().internal_pixels==Vector2i(800,450),"Resize reallocates scratch to actual internal pixels")
	blur.suspend()
	var before: int = blur.status().dispatches
	for i in 5: await process_frame
	check(blur.status().dispatches==before,"Off dispatches no blur pass")
	var report = {"checks":checks,"failures":failures,"phases":phases,"engine":Engine.get_version_info(),"executable":OS.get_executable_path(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"device":RenderingServer.get_video_adapter_name(),"fps_cap":30,"performance_acceptance":false,"fullscreen":"deferred while user is raiding"}
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SCENE_BLUR_NATIVE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"output":output}))
	graphics.frame_generation = false; graphics.apply_viewport(root)
	for i in 4: await process_frame
	scene.queue_free(); canvas.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func phase(mode: String, fg: bool, strength: float, stationary: bool) -> void:
	graphics.upscaler = mode; graphics.frame_generation = fg; graphics.apply_viewport(root)
	graphics.reset_history(); blur.suspend()
	var name = "%s_fg%d_%d_%s_%d" % [mode,int(fg),int(strength),"stationary" if stationary else "moving",root.size.x]
	var before = blur.status()
	var fsr_before = graphics.fsr_status()
	label.text = "HUD · 123 km/h · gate 08 / 16\nMotion-vector scene blur check"
	for i in 32:
		var t = 0.0 if stationary else float(i)/30.0
		camera.position = Vector3(sin(t*1.8)*2.0,2.7,5.0-t*2.0)
		camera.rotation_degrees = Vector3(-24.0,sin(t*2.4)*12.0,0)
		moving.position.x = sin(t*5.0)*2.5
		blur.update_state({"motion_blur_enabled":true,"motion_blur_strength":strength},true,true,false,1.0/30.0,[mode,fg,root.size])
		if i in [12,20,28]:
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output+"/%s_%02d.png" % [name,i])==OK,"Chronological capture saves")
		await process_frame
	await RenderingServer.frame_post_draw
	var status = blur.status()
	check(status.unavailable.is_empty(),name+" shader/buffer availability: "+status.unavailable)
	check((status.dispatches>before.dispatches)==(strength>0.0),name+" real dispatch matches selection")
	var fsr = graphics.fsr_status()
	if Graphics.has_native_fsr():
		check(fsr.get("error","").is_empty(),name+" SDK has no error")
		if fg: check(fsr.get("generated_frames",0)>fsr_before.get("generated_frames",0),name+" generated frames advance")
	phases.append({"name":name,"blur":status,"fidelityfx":fsr,"rendered_frames":32,"output_pixels":root.size,"internal_pixels":status.internal_pixels})
	print("SCENE_BLUR_PHASE ",name," ",JSON.stringify(status))
