extends "res://tests/targeted_performance.gd"
## Production rider/forest on the local mixed fixture, ordinary forward input.
## One excluded traversal then one whole-feature Off/On pair; source/engine metadata only.
var destination = ""
var capture_feature_off = false
var arms: Array = []
var powered_frames = 0
var clearance_checked_frames = 0
var clearance_frames = 0
var contact_cost: Array = []
var pose_cost: Array = []

class TimedPole:
	extends "res://scripts/core/pole_propulsion.gd"
	var cost_us = PackedFloat64Array()
	func advance(dt: float, sim, intent, incoming_tangent_speed: float) -> Vector3:
		var started=Time.get_ticks_usec()
		var result=super.advance(dt,sim,intent,incoming_tangent_speed)
		cost_us.append(float(Time.get_ticks_usec()-started))
		return result

func run() -> void:
	seconds=6; map_id="perf-mixed"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): destination=arg.trim_prefix("--output=")
		if arg=="--capture-map": capture=true
		if arg=="--feature-off": capture_feature_off=true
	check(not destination.is_empty() and not DirAccess.dir_exists_absolute(destination),"Fresh output required")
	check(DisplayServer.get_name()!="headless","Native rendering required")
	check(capture or OS.get_environment("ALPINE_VALIDATION_MODE")=="FpsCritical","Timing needs FpsCritical admission")
	if not failures.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(destination)
	var source=collect_sources(); var started=Time.get_ticks_usec()
	set_meta("test_map_fixture",map_id)
	game=load("res://main.tscn").instantiate()
	game.automated=true; game.benchmark_input=input_at_tick
	root.add_child(game); current_scene=game
	while not game.initialized or game.loading.busy: await process_frame
	game.set_physics_process(false); game.active=false; game.preferences_enabled=false
	game.benchmark_no_captures=true; game.effects.haptic_hardware_enabled=false; game.set_audio_muted(true)
	game.display_settings.apply_display(root,Vector2i(3840,2160)); game.display_settings.apply_viewport(root)
	game.weather.set_automatic(false); game.weather.set_time_cycle(false)
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.frame_costs.enabled=true
	game.skier.animation.full_motion.frame_costs=game.frame_costs
	game.sim.pole_push=TimedPole.new()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	root.grab_focus()
	var setup_seconds=(Time.get_ticks_usec()-started)/1000000.0
	check(game.world.wilderness==null and game.world.preparation==null and not game.session.eligible,"Local isolated fixture")
	if capture:
		game.display_settings.fps_limit=60; game.display_settings.apply_viewport(root)
		game.sim.tuning=game.sim.tuning.duplicate(true)
		game.sim.tuning.pole_push_enabled=not capture_feature_off
		game.set_process(false); prepare_start()
		for frame in 360:
			for sub in 2: game._physics_process(1.0/120.0)
			game._process(1.0/60.0)
			count_participation()
			await process_frame; await RenderingServer.frame_post_draw
			if frame in [20,50,100,150,200,300]:
				root.get_texture().get_image().save_jpg(destination.path_join("riding-%03d.jpg"%frame),.94)
		check(powered_frames==0 if capture_feature_off else powered_frames>20,"Visual preflight exercises the selected feature state")
		report={"capture":true,"performance_evidence":false,"setup_seconds":setup_seconds,"map":game.field.fixture_descriptor(),"graphics":game.graphics.snapshot(),"pixels":root.size,
			"feature_enabled":not capture_feature_off,"powered_frames":powered_frames,"clearance_checked_frames":clearance_checked_frames,"clearance_changed_frames":clearance_frames}
	else:
		for arm in 3:
			game.sim.tuning=game.sim.tuning.duplicate(true)
			game.sim.tuning.pole_push_enabled=arm!=1
			prepare_start(); game.active=true
			for i in 30: await process_frame
			root.grab_focus()
			if arm==0:
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().get_size()==Vector2i(3840,2160),"Actual output is4K")
			output=destination.path_join(["warmup","off","on"][arm]); DirAccess.make_dir_recursive_absolute(output)
			report={"arm":["warmup","off","on"][arm],"excluded":arm==0,"feature_enabled":arm!=1}
			samples={"frame_ms":[],"render_cpu_ms":[],"gpu_ms":[],"draw_calls":[],"primitives":[]}
			unfocused_frames=0; previous_frame=0; powered_frames=0; clearance_checked_frames=0; clearance_frames=0; contact_cost=[]; pose_cost=[]
			var reference=preload("res://scripts/core/ski_simulation.gd").new()
			reference.tuning=game.sim.tuning.duplicate(true); reset_sim(reference)
			for tick in seconds*120: reference.step(1.0/120.0,input_at_tick(tick),game.field)
			game.sim.pole_push.cost_us.clear()
			await measure(reference)
			report.powered_render_frames=powered_frames; report.clearance_checked_render_frames=clearance_checked_frames; report.clearance_render_frames=clearance_frames
			report.pole_contact_us=Costs.stats(contact_cost); report.pose_us=Costs.stats(pose_cost)
			report.pole_solver_us=Costs.stats(game.sim.pole_push.cost_us)
			check(report.pole_solver_us.get("count",0)==report.ticks,"Every fixed tick includes direct pole-actuator timing")
			report.memory={"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"video_allocated_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
			check(powered_frames==0 if arm==1 else powered_frames>20,"Real pole thrust matches the selected feature state")
			check(arm!=1 or clearance_checked_frames==0,"Disabled propulsion has no active-push clearance search")
			arms.append(report.duplicate(true)); Evidence.write(output.path_join("results.json"),report)
			if not failures.is_empty(): break
		report={"capture":false,"performance_evidence":failures.is_empty(),"setup_seconds":setup_seconds,"arms":arms,
			"map":game.field.fixture_descriptor(),"graphics":game.graphics.snapshot(),"display":game.display_settings.report(root,root.size),"pixels":root.size,
			"scope":"Local production mixed fixture:6s ordinary forward input, start from rest; excluded warmup then whole-feature Off/On. Same fixture and inputs; propulsion intentionally changes travel, pose and view. Per-arm reference equality is required. Scene FPS difference is not isolated feature cost or whole-mountain FPS."}
	output=destination
	report.engine=Engine.get_version_info(); report.engine_path=OS.get_executable_path()
	report.source_verification="metadata"; report.sources=source; report.stable_sources=source==collect_sources()
	check(report.stable_sources,"Scoped inputs remained stable")
	await finish()

func reset_sim(sim) -> void:
	var p=Vector3(0,game.field.sample(0,64).height,64)
	sim.reset(p,0); sim.prime_contacts(game.field); sim.reset_pose_history()

func input_at_tick(_tick: int) -> RiderInput:
	var value=RiderInput.new(); value.tuck=1.0
	return value

func sample_frame() -> void:
	super.sample_frame()
	if not recording: return
	count_participation()
	var diag: Dictionary=game.skier.animation.full_motion.diagnostics
	contact_cost.append(float(diag.get("pole_contact_cpu_us",0.0)))
	pose_cost.append(float(game.skier.pose_microseconds))

func count_participation() -> void:
	if game.sim.pole_push_acceleration>0.0: powered_frames+=1
	var diag: Dictionary=game.skier.animation.full_motion.diagnostics
	if diag.get("carry_clearance_rad",[]).size()==2: clearance_checked_frames+=1
	if diag.get("carry_clearance_rad",[]).any(func(v): return v>.00001): clearance_frames+=1

func collect_sources() -> Dictionary:
	var result={}
	for file in ["res://scripts/presentation/pole_push_pose.gd","res://scripts/presentation/skier_visual.gd","res://scripts/presentation/skier_full_motion.gd",
		"res://scripts/core/pole_propulsion.gd","res://scripts/core/ski_simulation.gd","res://config/ski_default.tres","res://tests/pole_push_cost.gd",
		"res://tests/targeted_performance.gd","res://tests/fixtures/performance_maps.json",OS.get_executable_path()]:
		result[file]={"size":FileAccess.open(file,FileAccess.READ).get_length(),"mtime":FileAccess.get_modified_time(file)}
	return result
