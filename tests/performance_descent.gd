extends SceneTree
## Real 120 Hz gameplay and render loop, driven solely by a validated input trace.
const Trace = preload("res://tests/performance_trace.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Costs = preload("res://scripts/diagnostics/frame_costs.gd")
var game
var field
var trace: Dictionary
var output = "res://artifacts/pc_environment/v15_high_clear"
var repetitions = 1
var recording = false
var previous_frame = 0
var frames = PackedFloat64Array()
var gpu = PackedFloat64Array()
var cpu = PackedFloat64Array()
var draws = PackedFloat64Array()
var sections: Dictionary = {}
var peak_video = 0
var peak_static = 0
var rows = []
var failures = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var version = Definition.CURRENT_VERSION
	var path = "res://artifacts/fps_optimization/descent_input.json"
	var weather = "clear"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--version="): version = int(arg.get_slice("=",1))
		if arg.begins_with("--input-trace="): path = arg.get_slice("=",1)
		if arg.begins_with("--benchmark-label="): output = "res://artifacts/pc_environment/"+arg.get_slice("=",1).validate_filename()
		if arg.begins_with("--repetitions="): repetitions = clampi(int(arg.get_slice("=",1)),1,10)
		if arg.begins_with("--weather="): weather = arg.get_slice("=",1)
	if not FileAccess.file_exists(path): printerr("Generate a current successful trace using tests/performance_trace.gd"); quit(2); return
	trace = JSON.parse_string(FileAccess.get_file_as_string(path))
	field = Definition.generate(849205174,version)
	if not Trace.matches(field,trace.identity) or not trace.result.finished or not trace.result.crash.is_empty():
		printerr("Benchmark rejects stale or unsuccessful input traces"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Performance verification"),"field":field})
	game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_physics_process(false)
	await configure_comparison()
	game.benchmark_input = input_at_tick
	game.benchmark_no_captures = true
	game.effects.frame_costs = game.frame_costs
	game.world.scenery.density_forest.frame_costs = game.frame_costs
	game.world.minerals.frame_costs = game.frame_costs
	game.camera_settings.load_preferences() # Read only; current user camera geometry.
	game.camera.settings = game.camera_settings
	game.weather.set_preset(weather); game.weather.set_time_of_day("day")
	game.display_settings.apply_display(root,game.benchmark_resolution)
	game.display_settings.apply_viewport(root)
	game.effects.muted = false
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image().get_size()
	if pixels!=game.benchmark_resolution: printerr("Wrong output dimensions"); quit(2); return
	process_frame.connect(measure)
	for repetition in repetitions:
		await prepare_comparison_trial(repetition)
		game.start_run(false); game.summit_ready = false; game.active = false
		game.physics_modified = true; game.session.eligible = false
		game.sim.reset(field.launch_point(trace.heading),trace.heading); game.sim.prime_contacts(field)
		game.previous_position = game.sim.position
		game.skier.reset_animation(game.sim); game.camera.close_view = false; game.camera.reset()
		game.hud.hide_menu(); game.effects.reset()
		for i in 240: await process_frame
		frames.clear(); gpu.clear(); cpu.clear(); draws.clear(); sections.clear()
		game.frame_samples.clear(); game.draw_samples.clear(); game.gpu_samples.clear(); game.render_cpu_samples.clear()
		game.frame_costs.reset(); previous_frame = 0; peak_video = 0; peak_static = 0
		var start_status = game.display_settings.fsr_status()
		var started = Time.get_ticks_usec()
		game.active = true; game.set_physics_process(true); recording = true
		var last_progress = -1
		while not game.session.finished and not game.sim.crashed and game.sim.ticks<=trace.result.ticks+2:
			await physics_frame
			var progress = game.sim.ticks/2400
			if progress!=last_progress:
				last_progress = progress
				print("PERFORMANCE_PROGRESS run=",repetition+1," tick=",game.sim.ticks," kmh=",snappedf(game.sim.speed_kmh(),.1))
		recording = false; game.set_physics_process(false)
		var elapsed = (Time.get_ticks_usec()-started)/1000000.0
		var expected = Vector3(trace.result.position[0],trace.result.position[1],trace.result.position[2])
		var exact = game.sim.position==expected and game.sim.ticks==trace.result.ticks
		if not game.session.finished or game.sim.crashed or not exact: failures.append("Run %d did not reproduce the successful trace" % (repetition+1))
		var end_status = game.display_settings.fsr_status()
		var section_report = {}
		for section in sections: section_report[section] = frame_stats(sections[section])
		# Write only after measurement ends. Retain the actual distribution so
		# median FPS, tails and later analyses never have to infer raw frames.
		FileAccess.open(output+"/frame_samples_%d.json" % (repetition+1),FileAccess.WRITE).store_string(JSON.stringify({"frame_ms":frames,"gpu_ms":gpu,"render_cpu_ms":cpu,"draw_calls":draws,"sections":sections}))
		var row = {"run":repetition+1,"finished":game.session.finished,"crash":game.sim.crash_reason,"exact_trace":exact,"ticks":game.sim.ticks,"wall_seconds":elapsed,"frame_ms":frame_stats(frames),"gpu_ms":Costs.stats(gpu),"render_cpu_ms":Costs.stats(cpu),"draw_calls":Costs.stats(draws),"cpu_scopes_us":game.frame_costs.report(),"sections":section_report,"peak_video_bytes":peak_video,"peak_engine_static_bytes":peak_static,"snow":game.effects.snow_budget(),"forest":game.world.scenery.density_forest.report(),"fsr_begin":start_status,"fsr_end":end_status}
		row.merge(comparison_metadata())
		rows.append(row)
		var report = {"scope":"complete_production_descent","trace_sha256":FileAccess.get_sha256(path),"identity":Trace.identity(field),"actual_pixels":[pixels.x,pixels.y],"display":game.display_settings.report(root,pixels),"sdfgi":game.world.environment.sdfgi_enabled,"camera":game.camera_settings.snapshot(),"weather":weather,"device":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info(),"capture_overhead_included":false,"warmup_frames":240,"unranked":not game.session.eligible,"rows":rows,"failures":failures}
		FileAccess.open(output+"/production.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		print("PERFORMANCE_RESULT run=",repetition+1," ",JSON.stringify(row.frame_ms)," exact=",exact)
		if not failures.is_empty(): break
	dispose_comparison()
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func configure_comparison() -> void: pass
func prepare_comparison_trial(_index: int) -> void: pass
func comparison_metadata() -> Dictionary: return {}
func dispose_comparison() -> void: pass

func input_at_tick(tick: int) -> RiderInput:
	var result = RiderInput.new()
	var index = tick/int(trace.command_ticks)
	if index>=trace.commands.size(): return result
	var command = trace.commands[index]
	result.steer=command[0]; result.tuck=command[1]; result.brake=command[2]; result.jump=command[3]
	result.jump_held=command[4]; result.air_pitch=command[5]; result.air_yaw=command[6]; result.grab=command[7]
	return result
func measure() -> void:
	if not recording: previous_frame = 0; return
	var now = Time.get_ticks_usec()
	if previous_frame>0:
		var ms = (now-previous_frame)/1000.0
		frames.append(ms)
		var radius = Vector2(game.sim.position.x,game.sim.position.z).length()
		var section = "open" if radius<700 else ("powder" if radius<1300 else ("minerals" if radius<1900 else "forest"))
		if not sections.has(section): sections[section] = PackedFloat64Array()
		sections[section].append(ms)
		var rid = root.get_viewport_rid()
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		peak_video = maxi(peak_video,int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
		peak_static = maxi(peak_static,int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	previous_frame = now
static func frame_stats(values) -> Dictionary:
	var result = Costs.stats(values)
	if values.is_empty(): return result
	result.average_fps = 1000.0/result.mean
	var ordered = values.duplicate(); ordered.sort()
	result.p50=(ordered[(ordered.size()-1)/2]+ordered[ordered.size()/2])*.5
	result.median_fps=1000.0/result.p50
	var slow = ordered.slice(maxi(0,ordered.size()-maxi(1,ceili(ordered.size()*.01))))
	result.slowest_one_percent_fps = 1000.0/Costs.stats(slow).mean
	return result
