extends SceneTree
## Native material/LOD and spring-response inspection. Never writes player records.
const Motion = preload("res://scripts/presentation/tree_motion.gd")
var output = "res://artifacts/treedesigner/native"
var game
var stage: Node3D
var row: Node3D
var motion
var captures: Array = []
var reaction_peak = 0.0
var before_pixels: Image
var contact_changed_pixels = 0
var benchmark_frames: Array[float] = []
var gpu: Array[float] = []
var cpu: Array[float] = []
var collection_mode = false

func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	set_meta("test_lab_fixture",true)
	collection_mode = "--collection" in OS.get_cmdline_user_args()
	if collection_mode: output="res://artifacts/trees_v2/native"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-label="): output="res://artifacts/foliage_v3/"+arg.get_slice("=",1).validate_filename()
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.start_speed_lab(35)
	game.active = false
	game.session.eligible = false
	game.effects.stop_audio()
	game.effects.hide()
	game.weather_effects.hide()
	game.skier.hide()
	game.hud.hide()
	game.speed_periphery.hide()
	game.world.scenery.hide()
	game.set_graphics_quality(2)
	game.display_settings.apply_display(root,Vector2i(1920,1080))
	game.display_settings.upscaler = "native"
	game.display_settings.apply_viewport(root)
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	game.world.update_weather(game.weather.state,0,false)
	stage = Node3D.new(); root.add_child(stage); stage.position = Vector3(0,3000,300)
	var ground = MeshInstance3D.new(); var plane = PlaneMesh.new(); plane.size = Vector2(160,160)
	ground.mesh = plane; ground.material_override = game.world.assets.terrain_material(); stage.add_child(ground)
	row = Node3D.new(); stage.add_child(row)
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size = 18
	game.camera.global_position = stage.position+Vector3(0,10,-27)
	game.camera.look_at(stage.position+Vector3(0,4.7,0))
	for lod in [0,1,2]:
		for child in row.get_children(): child.free()
		for variant in [1,2,3]:
			var tree = MeshInstance3D.new()
			var id="forest_spruce_%02d" % variant if collection_mode else "td_spruce_%d" % variant
			tree.mesh = game.world.assets.mesh(id+"_lod%d" % lod)
			row.add_child(tree); tree.position.x = (variant-2)*7.5
			if collection_mode: tree.scale=Vector3.ONE*10.5/float(game.world.assets.tree_record(id).height_m)
		await capture("spruce_gallery_lod%d" % lod)
	for child in row.get_children(): child.free()
	# Exercise the same instanced rendering path as the mountain forest.
	var tree = MultiMeshInstance3D.new()
	tree.multimesh = MultiMesh.new()
	tree.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var first_id="forest_spruce_01" if collection_mode else "td_spruce_1"
	var tree_scale=10.5/float(game.world.assets.tree_record(first_id).height_m) if collection_mode else 1.0
	tree.multimesh.mesh = game.world.assets.mesh(first_id+"_lod0")
	tree.multimesh.instance_count = 1
	tree.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*tree_scale),Vector3.ZERO))
	row.add_child(tree)
	game.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov = 55
	game.camera.global_position = stage.position+Vector3(-5.0,3.3,-6.0)
	game.camera.look_at(stage.position+Vector3(-.35,2.5,0))
	await capture("spruce_detail")
	motion = Motion.new(game.world.assets,"res://assets/graphics/trees/branches.json" if collection_mode else "res://assets/graphics/treedesigner_branches.json")
	motion.add_tree(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*tree_scale),stage.position),first_id if collection_mode else 1)
	var material: ShaderMaterial = game.world.assets.named_materials["FC_Tree" if collection_mode else "TD_Conifer"]
	material.set_shader_parameter("wind_strength",0.0)
	await capture("contact_rest")
	before_pixels = root.get_texture().get_image()
	var capsule = MeshInstance3D.new(); capsule.mesh = CapsuleMesh.new()
	capsule.mesh.radius=.30; capsule.mesh.height=1.7
	var probe_mat = StandardMaterial3D.new(); probe_mat.albedo_color = Color(.85,.38,.06)
	capsule.material_override=probe_mat; stage.add_child(capsule)
	for frame in 90:
		var actor = stage.position+Vector3(-1.25,0,-4.0+float(frame)/60.0*5.0)
		capsule.global_position = actor+Vector3.UP*.9
		motion.update(actor,Vector3(0,0,5),1.0/60.0,true)
		for angle in motion.angles: reaction_peak = maxf(reaction_peak,Vector3(angle.x,angle.y,angle.z).length())
		await process_frame
		await motion_frame("contact",frame)
		if frame in [30,45,60]: await capture("contact_%02d" % frame)
		if frame==45:
			capsule.hide()
			await capture("contact_bent")
			var bent = root.get_texture().get_image()
			# Fixed lighting/camera, hidden probe: changed pixels must come from
			# the tree's actual instanced shader deformation and its shadow.
			for y in range(180,850,2):
				for x in range(500,1400,2):
					var delta = bent.get_pixel(x,y)-before_pixels.get_pixel(x,y)
					if absf(delta.r)+absf(delta.g)+absf(delta.b)>.10: contact_changed_pixels+=1
			capsule.show()
	capsule.hide()
	for frame in 360:
		motion.update(stage.position+Vector3(-1.25,0,8),Vector3.ZERO,1.0/60.0,true)
		await process_frame
		await motion_frame("recovery",frame)
	await capture("contact_recovered")
	var recovery_peak = 0.0
	for angle in motion.angles: recovery_peak=maxf(recovery_peak,angle.length())
	# Show wind at the same fixed camera. Normal motion follows geometry.
	for frame in 90:
		game.world.assets.update_wind(game.weather.state,1.0/60.0,true)
		await process_frame
		await motion_frame("wind",frame)
		if frame in [0,45,89]: await capture("wind_%02d" % frame)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for frame in 90: await process_frame
	for frame in 240:
		var begin = Time.get_ticks_usec()
		game.world.assets.update_wind(game.weather.state,1.0/120.0,true)
		await process_frame
		benchmark_frames.append((Time.get_ticks_usec()-begin)/1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
	var report = {"actual_pixels":root.get_texture().get_image().get_size(),"device":RenderingServer.get_video_adapter_name(),
		"captures":captures,"reaction_peak_rad":reaction_peak,"recovered_peak_rad":recovery_peak,
		"contact_changed_sampled_pixels":contact_changed_pixels,"contact_render_path":"MultiMeshInstance3D",
		"unranked":not game.session.eligible,"frame_ms":timing(benchmark_frames),"render_gpu_ms":timing(gpu),"render_cpu_ms":timing(cpu),
		"scope":"Single-tree closeup at 1920x1080 native; full forest performance is measured separately",
		"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TREEDESIGNER_RENDER ",JSON.stringify(report))
	stage.queue_free(); game.queue_free(); await process_frame
	quit(0 if reaction_peak>.03 and recovery_peak<.003 and contact_changed_pixels>100 else 1)

func motion_frame(prefix: String, frame: int) -> void:
	if "--motion-frames" in OS.get_cmdline_user_args() and frame%3==0:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(output+"/%s_motion_%03d.jpg" % [prefix,frame],.94)

func capture(id: String) -> void:
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+id+".png")
	captures.append(id)

func timing(samples: Array[float]) -> Dictionary:
	samples.sort()
	var sum = 0.0
	for x in samples: sum+=x
	return {"frames":samples.size(),"mean":sum/maxi(1,samples.size()),"p95":samples[int(samples.size()*.95)],"p99":samples[int(samples.size()*.99)]}
