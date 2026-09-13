extends SceneTree
## Native production scene and ordinary 120 Hz input on an authored local map.
const Maps=preload("res://scripts/diagnostics/test_map.gd")
const Costs=preload("res://scripts/diagnostics/frame_costs.gd")
const Evidence=preload("res://scripts/diagnostics/scenario_evidence.gd")
var game
var output=""
var map_id=""
var seconds=6
var capture=false
var recording=false
var previous_frame=0
var samples={"frame_ms":[],"render_cpu_ms":[],"gpu_ms":[],"draw_calls":[],"primitives":[]}
var failures: Array[String]=[]
var unfocused_frames=0
var report: Dictionary={}

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label); printerr("TARGETED_PERFORMANCE_FAIL ",label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): map_id=arg.get_slice("=",1)
		elif arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		elif arg.begins_with("--seconds="): seconds=int(arg.get_slice("=",1))
		elif arg=="--capture-map": capture=true
	check(map_id in ["perf-slopes","perf-rocks","perf-vegetation","perf-mixed"],"Select a known performance map")
	check(seconds>=4 and seconds<=10,"Select 4-10 seconds")
	check(DisplayServer.get_name()!="headless","Native rendering required")
	check(capture or OS.get_environment("ALPINE_VALIDATION_MODE")=="FpsCritical","FPS measurement requires the owning FpsCritical guard")
	check(not output.is_empty() and not DirAccess.dir_exists_absolute(output),"Choose a fresh output directory")
	if not failures.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var source=collect_sources()
	var started=Time.get_ticks_usec()
	set_meta("test_map_fixture",map_id)
	game=load("res://main.tscn").instantiate()
	game.automated=true; game.benchmark_input=input_at_tick
	root.add_child(game); current_scene=game
	while not game.initialized:
		if Time.get_ticks_usec()-started>180000000:
			check(false,"Scene startup exceeded 180 seconds"); await finish(); return
		await process_frame
	game.set_physics_process(false); game.active=false
	game.benchmark_no_captures=true; game.effects.haptic_hardware_enabled=false
	game.set_audio_muted(true)
	game.display_settings.apply_display(root,game.benchmark_resolution)
	game.display_settings.apply_viewport(root)
	game.weather.set_automatic(false); game.weather.set_time_cycle(false)
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.frame_costs.enabled=true
	if game.world.scenery.density_forest: game.world.scenery.density_forest.frame_costs=game.frame_costs
	if game.world.minerals: game.world.minerals.frame_costs=game.frame_costs
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	root.grab_focus()
	report={"schema":1,"scope":"targeted_local_rendering","map":game.field.fixture_descriptor(),
		"setup_seconds":(Time.get_ticks_usec()-started)/1000000.0,"world_build_ms":game.world.build_timings,
		"source_hashes":source,"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"backend":RenderingServer.get_current_rendering_driver_name(),"device":RenderingServer.get_video_adapter_name(),
		"requested_seconds":seconds,"simulation_hz":120,"personal_records":false,"full_mountain":false,
		"capture":capture,"capture_overhead_included":false,"human_acceptance":false,"input":"start z=64, 60 km/h; tuck=.35 brake=.08 steer=0; ordinary production solver"}
	check(game.world.backdrop==null and game.world.wilderness==null and game.world.preparation==null,"No mountain, wilderness or preparation cache construction")
	check(game.world.scenery.scrub_candidates.is_empty(),"No procedural scattering")
	check(not game.session.eligible and game.session.benchmark_path.contains("targeted_tests"),"Isolated unranked session")
	check((game.world.scenery.density_forest!=null)==(report.map.trees>0),"Production forest selected exactly when requested")
	check((game.world.minerals!=null)==(report.map.rocks>0),"Production mineral renderer selected exactly when requested")
	prepare_start()
	# Prepare temporal rendering and resident batches before any timing sample.
	var warm_started=Time.get_ticks_usec()
	await create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	var pixels=root.get_texture().get_image().get_size()
	check(pixels==game.benchmark_resolution,"Requested output resolution is actually rendered")
	report.actual_pixels=[pixels.x,pixels.y]
	report.display=game.display_settings.report(root,pixels)
	report.graphics=game.graphics.snapshot()
	report.warmup_seconds=(Time.get_ticks_usec()-warm_started)/1000000.0
	if capture:
		await captures()
		report.performance_evidence=false
	else:
		# Exact end-state reference runs outside the measured window.
		var reference=preload("res://scripts/core/ski_simulation.gd").new()
		reference.tuning=game.sim.tuning.duplicate(true)
		reset_sim(reference)
		for tick in seconds*120: reference.step(1.0/120.0,input_at_tick(tick),game.field)
		check(not reference.crashed,"Requested duration fits the safe lane")
		if failures.is_empty(): await measure(reference)
		report.performance_evidence=failures.is_empty()
	report.stable_sources=source==collect_sources()
	check(report.stable_sources,"Source files remained stable")
	report.total_seconds=(Time.get_ticks_usec()-started)/1000000.0
	await finish()

func reset_sim(sim) -> void:
	var p=Vector3(0,game.field.sample(0,64).height,64)
	sim.reset(p,0); sim.prime_contacts(game.field)
	sim.velocity=Vector3.DOWN.slide(game.field.sample(p.x,p.z).normal).normalized()*60.0/3.6

func prepare_start() -> void:
	game.start_run(false); game.set_physics_process(false)
	reset_sim(game.sim); game.previous_position=game.sim.position
	game.skier.reset_animation(game.sim)
	game.camera.close_view=false; game.camera.reset(); game.menu_camera.leave()
	game.camera.update_camera(game.sim,game.field,game.sim.position,1.0/60.0)
	game.camera.make_current(); game.hud.hide_menu(); game.active=true
	game.weather.visual_time=0.0; game.weather_effects.reset()

func input_at_tick(_tick: int) -> RiderInput:
	var intent=RiderInput.new(); intent.tuck=.35; intent.brake=.08
	return intent

func measure(reference) -> void:
	process_frame.connect(sample_frame)
	game.frame_costs.reset()
	var started=Time.get_ticks_usec()
	var fsr_before: Dictionary=game.display_settings.fsr_status()
	recording=true; game.set_physics_process(true)
	while game.sim.ticks<seconds*120 and not game.sim.crashed and not game.session.finished:
		await physics_frame
		if Time.get_ticks_usec()-started>30000000: check(false,"Measurement exceeded 30-second safety ceiling"); break
	game.set_physics_process(false); recording=false
	process_frame.disconnect(sample_frame)
	report.execution_seconds=(Time.get_ticks_usec()-started)/1000000.0
	report.ticks=game.sim.ticks; report.end_position=str(game.sim.position)
	report.stop_reason="duration" if game.sim.ticks==seconds*120 and not game.sim.crashed else "incomplete"
	check(report.stop_reason=="duration" and not game.session.finished,"Complete duration without crash, finish or early boundary")
	check(game.sim.position==reference.position and game.sim.velocity==reference.velocity,"Every ordinary input reaches the exact reference end state")
	check(unfocused_frames==0 and root.has_focus() and root.mode!=Window.MODE_MINIMIZED,"Focused non-minimized measurement")
	check(samples.frame_ms.size()>=30,"At least 30 rendered frame intervals")
	for kind in ["frame_ms","render_cpu_ms","gpu_ms"]:
		check(not samples[kind].is_empty() and samples[kind].all(func(v): return is_finite(v) and v>0),"Positive finite "+kind)
	var fsr_after: Dictionary=game.display_settings.fsr_status()
	check(not fsr_after.get("frame_generation_active",false) and fsr_after.get("generated_frames",0)==fsr_before.get("generated_frames",0),"Rendered frames only")
	if fsr_after.get("present_counter_available",false):
		var presents=int(fsr_after.get("rendered_present_calls",0))-int(fsr_before.get("rendered_present_calls",0))
		check(presents>0 and absi(presents-samples.frame_ms.size())<=maxi(5,ceili(samples.frame_ms.size()*.03)),"Native rendered presents match sampled frames")
	if game.display_settings.upscaler!="native":
		check(int(fsr_after.get("upscale_dispatches",0))>int(fsr_before.get("upscale_dispatches",0)) and str(fsr_after.get("error","")).is_empty(),"Fresh native upscaler dispatches without errors")
	report.fsr_before=fsr_before; report.fsr_after=fsr_after
	report.unfocused_frames=unfocused_frames
	for kind in samples: report[kind]=Costs.stats(samples[kind])
	if not samples.frame_ms.is_empty(): report.average_fps=1000.0/report.frame_ms.mean
	report.cpu_scopes_us=game.frame_costs.report()
	report.forest={} if game.world.scenery.density_forest==null else game.world.scenery.density_forest.report()
	Evidence.write(output.path_join("samples.json"),samples)

func sample_frame() -> void:
	if not recording: return
	var now=Time.get_ticks_usec()
	if previous_frame>0:
		samples.frame_ms.append((now-previous_frame)/1000.0)
		var rid=root.get_viewport_rid()
		samples.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		samples.gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		samples.primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		if not root.has_focus() or not game.application_focused or root.mode==Window.MODE_MINIMIZED: unfocused_frames+=1
	previous_frame=now

func captures() -> void:
	# Freeze the main camera selector only for visual inspection, outside timing.
	game.set_process(false); game.hud.hide()
	var camera=Camera3D.new(); game.add_child(camera)
	camera.position=Vector3(10,game.field.sample(10,42).height+8,42)
	camera.look_at(Vector3(0,game.field.sample(0,135).height+4,135)); camera.fov=62
	camera.make_current()
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join("detail.png"))==OK,"Detail capture saved")
	camera.position=Vector3(330,330,-190); camera.look_at(Vector3(0,-45,180)); camera.fov=55
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join("overview.png"))==OK,"Overview capture saved")
	report.stop_reason="capture_complete"

func collect_sources() -> Dictionary:
	var result={}
	for folder in ["res://scripts","res://assets/graphics","res://config"]: hash_folder(folder,result)
	for path in ["res://main.tscn","res://project.godot","res://tests/fixtures/test_maps.json","res://tests/fixtures/performance_maps.json","res://tests/targeted_performance.gd"]:
		result[path]=FileAccess.get_sha256(path)
	return result

func hash_folder(folder: String,result: Dictionary) -> void:
	for name in DirAccess.get_files_at(folder):
		if name.get_extension() in ["gd","gdshader","gdshaderinc","tres"]:
			var path=folder.path_join(name); result[path]=FileAccess.get_sha256(path)
	for directory in DirAccess.get_directories_at(folder): hash_folder(folder.path_join(directory),result)

func finish() -> void:
	report.failures=failures
	if not failures.is_empty(): report.performance_evidence=false
	if not output.is_empty(): Evidence.write(output.path_join("results.json"),report)
	print("TARGETED_PERFORMANCE_RESULT ",JSON.stringify({"map":map_id,"failures":failures,"output":output,"setup_seconds":report.get("setup_seconds",0),"fps":report.get("average_fps",0)}))
	if game:
		game.active=false; game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
