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
var unfocused_frames = 0
var forest_coverage: Dictionary = {}
var rows = []
var failures = []
var scenario_replay = false
var trial_seconds = 0
var trial_start_seconds = 0
var trial_end_tick = 0
var trial_expected = Vector3.ZERO
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var version = Definition.CURRENT_VERSION
	var path = "res://artifacts/fps_optimization/descent_input.json"
	var weather = "clear"
	var time_of_day = "day"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--version="): version = int(arg.get_slice("=",1))
		if arg.begins_with("--input-trace="): path = arg.get_slice("=",1)
		if arg.begins_with("--benchmark-label="): output = "res://artifacts/pc_environment/"+arg.get_slice("=",1).validate_filename()
		if arg.begins_with("--repetitions="): repetitions = clampi(int(arg.get_slice("=",1)),1,10)
		if arg.begins_with("--weather="): weather = arg.get_slice("=",1)
		if arg.begins_with("--time-of-day="): time_of_day = arg.get_slice("=",1)
		if arg.begins_with("--trial-seconds="): trial_seconds = clampi(int(arg.get_slice("=",1)),1,60)
		if arg.begins_with("--trial-start-seconds="): trial_start_seconds = maxi(0,int(arg.get_slice("=",1)))
		if arg=="--scenario-replay": scenario_replay = true
	if not FileAccess.file_exists(path): printerr("Generate a current successful trace using tests/performance_trace.gd"); quit(2); return
	var decoded = JSON.parse_string(FileAccess.get_file_as_string(path))
	# Reject stale inputs before loading a mountain or constructing a scene.
	var preflight: String = Trace.preflight_error(decoded,version,not scenario_replay)
	if not preflight.is_empty(): printerr(preflight); quit(2); return
	trace = decoded
	var physical_started = Time.get_ticks_usec()
	field = preload("res://tests/validation_mountain.gd").load_standard() if version == 15 else Definition.generate(849205174,version)
	if field == null: quit(2); return
	var physical_seconds = (Time.get_ticks_usec()-physical_started)/1000000.0
	if not Trace.matches(field,trace.identity):
		printerr("Benchmark rejects stale or unsuccessful input traces"); quit(2); return
	if trial_seconds>0:
		trial_end_tick = (trial_start_seconds+trial_seconds)*120
		if trial_end_tick>trace.result.ticks: printerr("Requested short trial exceeds trace coverage"); quit(2); return
		var reference = Trace.Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
		reference.reset(field.launch_point(trace.heading),trace.heading); reference.prime_contacts(field)
		for tick in trial_end_tick: reference.step(1.0/120.0,input_at_tick(tick),field)
		if reference.crashed: printerr("Short trial reference crashed"); quit(2); return
		trial_expected = reference.position
	DirAccess.make_dir_recursive_absolute(output)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Performance verification"),"field":field})
	var scene_started = Time.get_ticks_usec()
	game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_physics_process(false)
	var loading_report = {"scope":"one startup shared by all repetitions; excludes process launch, trace generation and trial warmups",
		"physical_load_or_generation_seconds":physical_seconds,"physical_cache_hit":field.cache_hit if "cache_hit" in field else false,
		"physical_stages_ms":field.generation_stages.duplicate(true) if "generation_stages" in field else {},
		"scene_ready_seconds":(Time.get_ticks_usec()-scene_started)/1000000.0,
		"scenery_cache_hit":game.world.preparation.cache_hit if game.world.preparation else false,
		"scene_build_ms":game.world.build_timings.duplicate(),"job_stages_ms":game.generation_job.snapshot().timings_ms}
	print("PERFORMANCE_LOADING ",JSON.stringify(loading_report))
	await configure_comparison()
	game.benchmark_input = input_at_tick
	game.benchmark_no_captures = true
	game.effects.frame_costs = game.frame_costs
	game.world.scenery.density_forest.frame_costs = game.frame_costs
	game.world.minerals.frame_costs = game.frame_costs
	game.camera_settings.load_preferences() # Read only; current user camera geometry.
	if trace.has("presentation"):
		game.camera_settings.restore(trace.presentation.camera)
		game.camera.effects_enabled = trace.presentation.camera_effects_enabled
	if trace.has("camera_samples"):
		var effects_enabled: bool = game.camera.effects_enabled
		game.camera.set_script(preload("res://tests/performance_recorded_camera.gd"))
		game.camera.recorded_look = trace.camera_samples
		game.camera.effects_enabled = effects_enabled
	game.camera.settings = game.camera_settings
	game.weather.set_preset(weather); game.weather.set_time_of_day(time_of_day)
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
		if trace.has("initial_state") and not Trace.Inputs.matches_state(game.sim,trace.initial_state):
			printerr("Recording launch state does not match current simulation"); quit(2); return
		if trial_seconds>0:
			for tick in trial_start_seconds*120: game.sim.step(1.0/120.0,input_at_tick(tick),game.world.ski_surface)
			game.weather.visual_time = 0.0
			if "active_seconds" in game.weather: game.weather.active_seconds = 0.0
		game.previous_position = game.sim.position
		game.skier.reset_animation(game.sim); game.camera.close_view = false; game.camera.reset()
		game.hud.hide_menu(); game.effects.reset()
		for i in 240: await process_frame
		frames.clear(); gpu.clear(); cpu.clear(); draws.clear(); sections.clear()
		game.frame_samples.clear(); game.draw_samples.clear(); game.gpu_samples.clear(); game.render_cpu_samples.clear()
		game.frame_costs.reset(); previous_frame = 0; peak_video = 0; peak_static = 0
		unfocused_frames = 0; forest_coverage.clear()
		var start_status = game.display_settings.fsr_status()
		var started_unix = Time.get_unix_time_from_system()
		var started = Time.get_ticks_usec()
		game.active = true; game.set_physics_process(true); recording = true
		var last_progress = -1
		var checkpoint = 0
		var checkpoints: Array = trace.get("checkpoints",[])
		while not game.session.finished and not game.sim.crashed and game.sim.ticks<(trial_end_tick if trial_seconds>0 else int(trace.result.ticks)):
			await physics_frame
			while checkpoint<checkpoints.size() and checkpoints[checkpoint][0]<game.sim.ticks: checkpoint += 1
			if checkpoint<checkpoints.size() and game.sim.ticks==int(checkpoints[checkpoint][0]):
				if not Trace.Inputs.matches_state(game.sim,checkpoints[checkpoint]):
					failures.append("Recorded trajectory diverged at tick %d" % game.sim.ticks); break
				checkpoint += 1
			var progress = game.sim.ticks/2400
			if progress!=last_progress:
				last_progress = progress
				print("PERFORMANCE_PROGRESS run=",repetition+1," tick=",game.sim.ticks," kmh=",snappedf(game.sim.speed_kmh(),.1))
		recording = false; game.set_physics_process(false)
		var elapsed = (Time.get_ticks_usec()-started)/1000000.0
		var ended_unix = Time.get_unix_time_from_system()
		var expected = Vector3(trace.result.position[0],trace.result.position[1],trace.result.position[2])
		var exact = game.sim.position==expected and game.sim.ticks==trace.result.ticks
		if trial_seconds>0: exact = game.sim.position==trial_expected and game.sim.ticks==trial_end_tick and not game.sim.crashed
		if (trial_seconds==0 and (game.session.finished!=trace.result.finished or game.sim.crash_reason!=trace.result.crash)) or not exact: failures.append("Run %d did not reproduce the recorded outcome" % (repetition+1))
		var end_status = game.display_settings.fsr_status()
		var section_report = {}
		for section in sections: section_report[section] = frame_stats(sections[section])
		# Write only after measurement ends. Retain the actual distribution so
		# median FPS, tails and later analyses never have to infer raw frames.
		FileAccess.open(output+"/frame_samples_%d.json" % (repetition+1),FileAccess.WRITE).store_string(JSON.stringify({"frame_ms":frames,"gpu_ms":gpu,"render_cpu_ms":cpu,"draw_calls":draws,"sections":sections}))
		var row = {"run":repetition+1,"finished":game.session.finished,"crash":game.sim.crash_reason,"exact_trace":exact,"ticks":game.sim.ticks,"wall_seconds":elapsed,"frame_ms":frame_stats(frames),"gpu_ms":Costs.stats(gpu),"render_cpu_ms":Costs.stats(cpu),"draw_calls":Costs.stats(draws),"cpu_scopes_us":game.frame_costs.report(),"sections":section_report,"peak_video_bytes":peak_video,"peak_engine_static_bytes":peak_static,"snow":game.effects.snow_budget(),"forest":game.world.scenery.density_forest.report(),"fsr_begin":start_status,"fsr_end":end_status}
		row.merge({"started_unix_seconds":started_unix,"ended_unix_seconds":ended_unix,"unfocused_frames":unfocused_frames,"forest_coverage":forest_coverage.duplicate(true)})
		row.merge(comparison_metadata())
		rows.append(row)
		var report = {"scope":"complete_production_descent","trace_sha256":FileAccess.get_sha256(path),"identity":Trace.identity(field),"actual_pixels":[pixels.x,pixels.y],"display":game.display_settings.report(root,pixels),"sdfgi":game.world.environment.sdfgi_enabled,"camera":game.camera_settings.snapshot(),"weather":weather,"device":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info(),"capture_overhead_included":false,"warmup_frames":240,"unranked":not game.session.eligible,"rows":rows,"failures":failures}
		if trial_seconds>0:
			report.scope = "short_production_trial"; report.trial_seconds = trial_seconds; report.trial_start_seconds = trial_start_seconds
		if scenario_replay: report.scope = "recorded_scenario"
		report.merge({"loading":loading_report,"graphics_profile":game.graphics.snapshot(),"graphics_preset":game.graphics.preset_id,"renderer":RenderingServer.get_current_rendering_method(),"rendering_driver":RenderingServer.get_current_rendering_driver_name()})
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
	var index = tick/int(trace.command_ticks)
	if index>=trace.commands.size(): return RiderInput.new()
	return Trace.Inputs.decode(trace.commands[index])
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
		if not game.application_focused: unfocused_frames += 1
		var forest = game.world.scenery.density_forest
		if not forest_coverage.has(section): forest_coverage[section] = {"frames_with_resident_regions":0,"max_resident_regions":0,"max_pending_regions":0}
		var coverage: Dictionary = forest_coverage[section]
		if not forest.resident.is_empty(): coverage.frames_with_resident_regions += 1
		coverage.max_resident_regions = maxi(coverage.max_resident_regions,forest.resident.size())
		coverage.max_pending_regions = maxi(coverage.max_pending_regions,forest.pending.size())
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
