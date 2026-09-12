extends "res://tests/performance_descent.gd"
## Matched 15-second ordinary-input clips, using a current validated trace.
## Captures are diagnostic evidence and excluded from performance acceptance.
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	output = "res://artifacts/orchestration_20260912/forest/world_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var path = ""
	var start_seconds = 90
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input-trace="): path = arg.trim_prefix("--input-trace=")
		if arg.begins_with("--trial-start-seconds="): start_seconds = maxi(0,int(arg.get_slice("=",1)))
	if path.is_empty() or not FileAccess.file_exists(path):
		printerr("Forest review requires --input-trace= with a current validated ordinary-input trace"); quit(2); return
	var decoded = JSON.parse_string(FileAccess.get_file_as_string(path))
	var preflight = Trace.preflight_error(decoded,Definition.CURRENT_VERSION)
	if not preflight.is_empty(): printerr(preflight); quit(2); return
	trace = decoded
	var end_tick = (start_seconds+15)*120
	if end_tick>trace.result.ticks: printerr("Forest review exceeds trace coverage"); quit(2); return
	field = preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: quit(2); return
	if not Trace.matches(field,trace.identity): printerr("SIGHT_TRACE_IDENTITY_CHANGED"); quit(2); return
	var reference = Trace.Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
	reference.reset(field.launch_point(trace.heading),trace.heading); reference.prime_contacts(field)
	for tick in end_tick: reference.step(1.0/120,input_at_tick(tick),field)
	if reference.crashed: printerr("Forest review reference crashed"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Forest strength review"),"field":field})
	game = load("res://main.tscn").instantiate(); game.automated = true; root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_physics_process(false); game.set_process(false)
	game.benchmark_input = input_at_tick; game.benchmark_no_captures = true
	game.camera_settings.reset(); game.camera.settings = game.camera_settings
	game.display_settings.frame_generation = false; game.display_settings.fps_limit = 60
	game.display_settings.apply_display(root,Vector2i(3840,2160)); game.display_settings.apply_viewport(root)
	if game.preferences_enabled: failures.append("Personal preferences enabled")
	var cases = []
	for close in [true,false]:
		for strength in [0.0,25.0,50.0,75.0,100.0]:
			var id = "%s_strength_%03d" % ["first_person" if close else "chase",strength]
			game.start_run(false); game.summit_ready = false; game.physics_modified = true; game.session.eligible = false
			game.sim.reset(field.launch_point(trace.heading),trace.heading); game.sim.prime_contacts(field)
			for tick in start_seconds*120: game.sim.step(1.0/120,input_at_tick(tick),game.world.ski_surface)
			game.previous_position = game.sim.position; game.skier.reset_animation(game.sim)
			game.camera_settings.shared.forest_visibility = 60; game.camera_settings.shared.forest_visibility_strength = strength
			game.camera.close_view = close; game.camera.reset(); game.hud.hide_menu()
			game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
			game.weather.visual_time = 0; game.world.assets.wind_time = 0
			game.effects.reset(); game.weather_effects.reset(); game.active = true
			for frame in 180: game._process(1.0/60); await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"/"+id+".png")
			var nearby_start = field.tree_data.nearby(game.sim.position,18).size()
			for frame in 900:
				game._physics_process(1.0/120); game._physics_process(1.0/120); game._process(1.0/60)
				await process_frame
				# First three seconds are chronological at 10 captures/second;
				# the remaining twelve seconds retain one frame/second context.
				if (frame<180 and frame%6==0) or frame%60==0:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_jpg(output+"/%s_%03d.jpg" % [id,frame],.94)
				if game.sim.crashed or not game.active: break
			var exact = game.sim.position==reference.position and game.sim.ticks==end_tick
			if not exact: failures.append("Ordinary-input endpoint diverged: "+id)
			cases.append({"id":id,"exact_reference":exact,"end":str(game.sim.position),"ticks":game.sim.ticks,"nearby_start":nearby_start,"crash":game.sim.crash_reason,"sight":game.world.assets.foliage_sight.parameters,"forest":game.world.scenery.density_forest.report()})
			print("SIGHT_WORLD_CASE ",JSON.stringify(cases[-1]))
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"trial_start_seconds":start_seconds,"riding_seconds_per_case":15,"warmup_frames":180,"trace_sha256":FileAccess.get_sha256(path),"display":game.display_settings.report(root,Vector2i(3840,2160)),"camera":game.camera_settings.snapshot(),"capture_overhead_included":true,"unranked":not game.session.eligible,"failures":failures,"output":output},"\t"))
	print("SIGHT_WORLD_REVIEW ",output)
	game.effects.stop_audio(); game.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
