extends SceneTree
## Real main-scene readiness and static dense-area samples; never saves records.
var version = 16
var preset_index = 1
var repetitions = 3
var spacing = 1.0
var suffix = ""
var report: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile-version="): version = int(arg.get_slice("=",1))
		if arg.begins_with("--profile-preset="): preset_index = int(arg.get_slice("=",1))
		if arg.begins_with("--profile-repetitions="): repetitions = int(arg.get_slice("=",1))
		if arg.begins_with("--profile-spacing="): spacing = float(arg.get_slice("=",1))
	suffix = "" if is_equal_approx(spacing,1.0) else "_spacing%d" % roundi(spacing*100)
	root.borderless = true; root.position = DisplayServer.screen_get_position(root.current_screen); root.size = Vector2i(3840,2160); root.content_scale_size = Vector2i(3840,2160)
	root.title = "Alpine Apex | Generation loading profile"
	Engine.max_fps = 120
	DirAccess.make_dir_recursive_absolute("res://artifacts/generation_v16")
	report = {"version":version,"preset":preset_index,"engine":Engine.get_version_info().string,"unranked":true,"tree_spacing":spacing,"runs":[],"output_pixels":[3840,2160],"camera_fixture":"ground_clamped_dense48_v2"}
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for repetition in repetitions:
		root.borderless = true; root.size = Vector2i(3840,2160)
		await process_frame
		var begin = Time.get_ticks_usec()
		var worker = Thread.new()
		var work: Callable
		if version==14: work = load("res://scripts/world/mountain_cache_v14.gd").generate.bind(849205174)
		else:
			var settings = load("res://scripts/world/generation_settings.gd").preset(preset_index); settings.tree_spacing = spacing
			work = load("res://scripts/world/mountain_cache_v16.gd").generate.bind(849205174,settings)
		worker.start(work)
		while worker.is_alive(): await process_frame
		var field = worker.wait_to_finish()
		if field==null: quit(3); return
		var physical_ms = (Time.get_ticks_usec()-begin)/1000.0
		var definition = load("res://scripts/world/mountain_definition.gd").from_field(field)
		set_meta("mountain_to_load",{"definition":definition,"field":field})
		var game = load("res://scripts/main.gd").new(); root.add_child(game)
		while not game.initialized or game.loading.busy: await process_frame
		await RenderingServer.frame_post_draw
		var actual_pixels = root.get_texture().get_size()
		if actual_pixels!=Vector2(3840,2160): printerr("Invalid rendered size ",actual_pixels); quit(4); return
		var row = {"repetition":repetition+1,"time_to_ski_ms":(Time.get_ticks_usec()-begin)/1000.0,"physical_ms":physical_ms,"scene_ms":game.world.generation_ms,"physical_cache":field.cache_hit,"memory_peak":OS.get_static_memory_peak_usage(),"trees":field.tree_data.size() if "tree_data" in field else field.obstacles.size(),"minerals":field.geology.placements.size(),"graphics":game.display_settings.snapshot(),"fsr":game.display_settings.fsr_status()}
		if "preparation" in game.world and game.world.preparation:
			row.preparation_cache = game.world.preparation.cache_hit
			row.stages = field.job.snapshot().timings_ms
			row.construction = game.world.build_timings
		row.actual_pixels = [int(actual_pixels.x),int(actual_pixels.y)]
		row.internal_pixels = [roundi(actual_pixels.x*root.scaling_3d_scale),roundi(actual_pixels.y*root.scaling_3d_scale)]
		row.height_sha256 = field.height_checksum; row.obstacle_sha256 = field.obstacle_checksum
		print("GENERATION_RENDER_READY ",JSON.stringify(row))
		if version==16 and preset_index==1 and repetition==0:
			await game.mountain_library.open()
			var library = game.mountain_library
			library.advanced_toggle.button_pressed = false
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/generation_v16/controls_standard.png")
			library._preset_changed(4); library.settings_controls.tree_population.value = 1.01; library.settings_controls.tree_spacing.value = .67
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/generation_v16/controls_custom.png")
			var scroll = library.tabs.get_current_tab_control()
			scroll.ensure_control_visible(library.estimates_label)
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/generation_v16/controls_estimates.png")
			row.controls = {"form_height":scroll.size.y,"custom_values":library.generation_settings(),"advanced_visible":library.advanced_panel.visible}
			library._apply_settings(field.generation_settings); library.advanced_toggle.button_pressed = false
			library.close()
		game.active = false; game.set_process(false); game.set_physics_process(false)
		game.hud.root.hide()
		var camera = root.get_camera_3d()
		camera.far = 16000
		if repetition==0:
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/generation_v16/v%d_p%d%s_summit.png" % [version,preset_index,suffix])
		var dense: Array = []
		for face_index in [0,2,4]:
			var face = field.faces[face_index]
			var patch = dense_patch(field,face_index)
			var local: Vector2 = face.to_local(patch.center)
			var p: Vector2 = face.to_world(local)
			var forward = Vector3(sin(face.heading),0,cos(face.heading))
			var target = Vector3(p.x,field.sample(p.x,p.y).height+1.5,p.y)
			_viewpoint(field,face,local,camera,forward)
			for frame in 180: await process_frame
			var samples: Array[float] = []; var gpu: Array[float] = []; var cpu: Array[float] = []
			var previous = Time.get_ticks_usec(); var peak_video: int = 0
			for frame in 360:
				await process_frame
				var now = Time.get_ticks_usec(); samples.append((now-previous)/1000.0); previous = now
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
				peak_video = maxi(peak_video,int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
			var moving: Array[float] = []; var moving_gpu: Array[float] = []; var moving_cpu: Array[float] = []
			for frame in 120:
				_viewpoint(field,face,local+Vector2(-45,0),camera,forward)
				await process_frame
			previous = Time.get_ticks_usec()
			for frame in 360:
				_viewpoint(field,face,local+Vector2(-45+90.0*(frame+1)/360,0),camera,forward)
				await process_frame
				var now = Time.get_ticks_usec(); moving.append((now-previous)/1000.0); previous = now
				moving_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				moving_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
				peak_video = maxi(peak_video,int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
			var sample_pixels = root.get_texture().get_size()
			if sample_pixels!=Vector2(3840,2160): printerr("Invalid dense-view rendered size ",sample_pixels); quit(4); return
			dense.append({"actual_pixels":[int(sample_pixels.x),int(sample_pixels.y)],"face":face_index,"patch":patch,"camera_clearance_m":camera.position.y-_height(field,camera.position.x,camera.position.z),"frame_ms":distribution(samples),"gpu_ms":distribution(gpu),"render_cpu_ms":distribution(cpu),"video_memory_bytes":peak_video,
				"camera_traversal":{"distance_m":90,"frame_ms":distribution(moving),"gpu_ms":distribution(moving_gpu),"render_cpu_ms":distribution(moving_cpu)}})
			if repetition==0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/generation_v16/v%d_p%d%s_face%d.png" % [version,preset_index,suffix,face_index])
		row.dense = dense
		report.runs.append(row)
		preload("res://tests/test_report.gd").write("res://artifacts/generation_v16/render_v%d_p%d%s.json" % [version,preset_index,suffix],JSON.stringify(report,"\t"))
		game.queue_free(); field = null; definition = null
		for frame in 12: await process_frame
	print("GENERATION_RENDER_COMPLETE")
	quit()

func distribution(values: Array[float]) -> Dictionary:
	values.sort(); var sum = 0.0
	for value in values: sum += value
	return {"mean":sum/maxi(1,values.size()),"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)],"max":values[-1],"samples":values.size()}

func _viewpoint(field, face, q: Vector2, camera, forward: Vector3) -> void:
	var p: Vector2 = face.to_world(q)
	var target = Vector3(p.x,field.height_at(p.x,p.y) if field.has_method("height_at") else field.sample(p.x,p.y).height,p.y)+Vector3.UP*1.5
	camera.position = target-forward*16+Vector3.UP*7
	camera.position.y = maxf(camera.position.y,_height(field,camera.position.x,camera.position.z)+2.0)
	var aim = target+forward*30
	aim.y = _height(field,aim.x,aim.z)+1.5
	camera.look_at(aim)

func _height(field, x: float, z: float) -> float:
	return field.height_at(x,z) if field.has_method("height_at") else field.sample(x,z).height

func dense_patch(field, face_index: int) -> Dictionary:
	# Same deterministic selection rule for each generator. Record actual density
	# instead of assuming a planned stand center is an occupied forest patch.
	var cells: Dictionary = {}
	var packed = "tree_data" in field
	for id in (field.tree_data.size() if packed else field.obstacles.size()):
		var p: Vector3 = field.tree_data.positions[id] if packed else field.obstacles[id].position
		if Vector2(p.x,p.z).length()<1000: continue
		var face = posmod(roundi(wrapf(atan2(p.x,p.z)-field.face_phase,0,TAU)/(TAU/6)),6)
		if face!=face_index: continue
		var cell = Vector2i(floori(p.x/48),floori(p.z/48))
		cells[cell] = int(cells.get(cell,0))+1
	var ordered = cells.keys()
	ordered.sort_custom(func(a,b):
		if cells[a]!=cells[b]: return cells[a]>cells[b]
		return a.x<b.x if a.x!=b.x else a.y<b.y)
	for cell in ordered:
		var center = (Vector2(cell)+Vector2.ONE*.5)*48
		if field.contact_normal(center.x,center.y).y>=.7:
			return {"center":center,"trees_in_48m_cell":cells[cell]}
	return {"center":field.faces[face_index].to_world(field.faces[face_index].stands[24].position),"trees_in_48m_cell":0}
