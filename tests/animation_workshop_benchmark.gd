extends SceneTree
const Project = preload("res://scripts/workshop/motion_project.gd")
var game
var rows: Array = []
var last_usec = 0
var source_hashes: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	if not FileAccess.file_exists("res://artifacts/workshop_baseline_visual.gd"): printerr("Missing frozen pre-workshop visual"); quit(2); return
	Engine.max_fps = 120
	for path in ["scripts/main.gd","scripts/presentation/skier_visual.gd","scripts/presentation/skier_pose_writer.gd","scripts/core/ski_simulation.gd","scripts/workshop/motion_project.gd","scripts/workshop/motion_stage.gd","artifacts/workshop_baseline_visual.gd"]:
		source_hashes[path] = FileAccess.get_sha256("res://"+path)
	set_meta("test_lab_fixture",true)
	game = load("res://main.tscn").instantiate(); game.automated = true; root.add_child(game)
	while not game.initialized: await process_frame
	game.set_process(false); game.set_physics_process(false); game.start_run(false); game.session.eligible = false
	game.display_settings.display_mode = "windowed"; game.display_settings.upscaler = "fsr2"; game.display_settings.render_scale = .75; game.display_settings.fps_limit = 120
	game.display_settings.apply_display(root,Vector2i(3840,2160)); game.display_settings.apply_viewport(root)
	game.effects.stop_audio(); game.voice.silence(); game.hud.hide()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var current = game.skier
	var baseline = load("res://artifacts/workshop_baseline_visual.gd").new(); baseline.assets = current.assets; game.add_child(baseline)
	for which in ["before","after"]:
		game.skier = baseline if which=="before" else current
		baseline.visible = which=="before"; current.visible = which=="after"
		game.restart(); game.active = true; game.session.eligible = false; game.hud.hide()
		var intent = preload("res://scripts/core/rider_input.gd").new(); intent.tuck = .4
		var frames: Array = []; var cpu: Array = []; var gpu: Array = []; var pose_times: Array = []
		var peak_memory = 0; var peak_video = 0; last_usec = 0
		for frame in 420:
			intent.steer = sin(frame/120.0)*.35
			for tick in 2:
				game.sim.step(1.0/120,intent,game.field); game.skier.step_animation(1.0/120,game.sim,intent,game.field)
			game._process(1.0/120)
			await process_frame
			var now = Time.get_ticks_usec()
			if frame>=120:
				frames.append((now-last_usec)/1000.0)
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				pose_times.append(game.skier.pose_microseconds/1000.0)
				peak_memory = maxi(peak_memory,Performance.get_monitor(Performance.MEMORY_STATIC))
				peak_video = maxi(peak_video,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
			last_usec = now
		rows.append({"mode":which,"frame_ms":stats(frames),"render_cpu_ms":stats(cpu),"render_gpu_ms":stats(gpu),"pose_ms":stats(pose_times),"peak_static_bytes":peak_memory,"peak_video_bytes":peak_video})
	game.skier = current; baseline.queue_free(); game.effects.stop_audio(); game.queue_free(); await process_frame
	var editor = preload("res://scripts/workshop/motion_workshop.gd").new(); editor.persistence_enabled = false; root.add_child(editor)
	for i in 60: await process_frame
	for mode in ["playback","scrub"]:
		var frames: Array = []; var costs: Array = []; last_usec = 0
		for frame in 300:
			var at: float = fposmod(frame/60.0,editor.project.variant(editor.variant_id).duration) if mode=="playback" else float((frame*37)%400)/60
			editor.seek(at); await process_frame
			var now = Time.get_ticks_usec()
			if frame>=60: frames.append((now-last_usec)/1000.0); costs.append(editor.stage.frame_cost_us/1000.0)
			last_usec = now
		rows.append({"mode":mode,"frame_ms":stats(frames),"pose_ms":stats(costs)})
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image().get_size()
	var stable = true
	for path in source_hashes: stable = stable and source_hashes[path]==FileAccess.get_sha256("res://"+path)
	var report = {"scope":"Short laboratory gameplay pair and studio preview; not full-mountain performance","pixels":[pixels.x,pixels.y],"render_scale":.75,"frame_cap":120,"device":RenderingServer.get_video_adapter_name(),"rows":rows,"source_hashes":source_hashes,"sources_stable":stable}
	Project.atomic_json("res://artifacts/animation_workshop/benchmark.json",report)
	print("WORKSHOP_BENCHMARK ",JSON.stringify(report))
	editor.queue_free(); await process_frame; quit()
func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	values.sort(); var sum = 0.0
	for value in values: sum += value
	return {"mean":sum/values.size(),"p95":values[int((values.size()-1)*.95)],"p99":values[int((values.size()-1)*.99)],"max":values[-1]}
