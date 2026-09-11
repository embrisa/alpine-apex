extends SceneTree
## Isolated loading movies / actual v11 startup timings. Never starts a ranked run.
const OUTPUT = "res://artifacts/loading_atmosphere"
var samples: Array[float] = []
var cpu: Array[float] = []
var gpu: Array[float] = []
var stage_samples: Dictionary = {}
var peak_video_bytes: int = 0
var peak_static_bytes: int = 0

func _initialize() -> void: call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.content_scale_size = Vector2i(1440,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	Engine.max_fps = 120
	if "--loading-world-sample" in OS.get_cmdline_user_args():
		await sample_world()
	else:
		await movie()
	quit()

func movie() -> void:
	# Movie Maker fixes capture pixels from the project's 1440x900 viewport at
	# startup. A later window resize would crop the capture despite a valid UI.
	root.size = Vector2i(1440,900)
	var loading = load("res://scripts/ui/loading_overlay.gd").new()
	root.add_child(loading)
	loading.audio_enabled = "--loading-audio-preview" in OS.get_cmdline_user_args()
	# Three full 24-second cycles show wide, framed and monochrome compositions.
	for index in [0,5,6]:
		set_meta("alpine_loading_photo",index-1)
		loading.begin("Preparing your descent","Preparing mountain scenery…")
		loading.set_process(false)
		await process_frame
		assert(root.get_visible_rect().encloses(loading.title.get_global_rect()),"Movie title must fit the capture canvas")
		if index == 0:
			await RenderingServer.frame_post_draw
			var first_frame = root.get_texture().get_image()
			assert(first_frame.get_size()==Vector2i(1440,900),"Movie capture must match the fixed writer dimensions")
			first_frame.save_png(OUTPUT+"/movie_first_frame.png")
		for frame in 720:
			loading.phase = float(frame)/30.0
			loading.artwork.set_visual_time(loading.phase)
			loading.snow.update_motion(loading.phase,true)
			loading.pulse.position.x = maxf(0.0,loading.bar.size.x-loading.pulse.size.x)*(sin(loading.phase*2.8)*0.5+0.5)
			loading._update_wait_feedback(loading.phase,1.0/30.0)
			await process_frame
		loading.finish()
	loading.queue_free()
	await process_frame

func sample_world() -> void:
	root.size = Vector2i(3840,2160)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var disabled = "--loading-atmosphere-off" in OS.get_cmdline_user_args()
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	var start = Time.get_ticks_usec()
	root.add_child(game)
	current_scene = game
	game.loading.atmosphere_enabled = not disabled
	var previous = start
	while not game.initialized or game.loading.busy:
		var stage: String = game.loading.detail.text
		await process_frame
		var now = Time.get_ticks_usec()
		var ms = (now-previous)/1000.0
		previous = now
		samples.append(ms)
		if not stage_samples.has(stage): stage_samples[stage] = []
		stage_samples[stage].append(ms)
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		peak_video_bytes = maxi(peak_video_bytes,int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
		peak_static_bytes = maxi(peak_static_bytes,OS.get_static_memory_usage())
	game.active = false
	game.set_physics_process(false)
	game.session.eligible = false
	var duration = (Time.get_ticks_usec()-start)/1000.0
	var stages: Dictionary = {}
	for stage in stage_samples: stages[stage] = timings(stage_samples[stage])
	var pixels = Vector2i.ZERO
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot = root.get_texture().get_image()
		pixels = screenshot.get_size()
		screenshot.save_png(OUTPUT+"/world_ready_%s.png" % ("off" if disabled else "on"))
	var data = {"atmosphere":not disabled,"total_loading_ms":duration,"actual_pixels":[pixels.x,pixels.y],
		"device":RenderingServer.get_video_adapter_name(),"generator_version":game.current_mountain.generator_version,
		"seed":game.current_mountain.seed_value,"frame_ms":timings(samples),"cpu_render_ms":timings(cpu),"gpu_ms":timings(gpu),
		"peak_video_bytes":peak_video_bytes,"peak_static_bytes":peak_static_bytes,"stages":stages,
		"scope":"Actual v11 startup including worker generation, cache reads, uploads and blocking stages; screenshot excluded"}
	FileAccess.open(OUTPUT+"/world_%s.json" % ("off" if disabled else "on"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("LOADING_WORLD_RESULTS ",JSON.stringify(data))
	game.effects.stop_audio()
	game.queue_free()
	await process_frame

func timings(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted = values.duplicate()
	sorted.sort()
	var total = 0.0
	var over_50 = 0
	for value in sorted:
		total += value
		if value > 50.0: over_50 += 1
	return {"mean":total/sorted.size(),"p95":sorted[int(sorted.size()*0.95)],"p99":sorted[int(sorted.size()*0.99)],"max":sorted.back(),"frames":sorted.size(),"frames_over_50_ms":over_50}
