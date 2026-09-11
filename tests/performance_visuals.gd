extends "res://tests/performance_descent.gd"
## Run with --fixed-fps 60. Captures are separate from performance measurements.
var fixture_tick = 0
func run() -> void:
	output = "res://artifacts/fps_optimization/visuals"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--benchmark-label="): output = "res://artifacts/fps_optimization/"+arg.get_slice("=",1).validate_filename()
	DirAccess.make_dir_recursive_absolute(output)
	trace = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/fps_optimization/descent_input.json"))
	var preflight = Trace.preflight_error(trace,Definition.CURRENT_VERSION)
	if not preflight.is_empty(): printerr(preflight); quit(2); return
	field = preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: quit(2); return
	field.build_material_map()
	if not Trace.matches(field,trace.identity): printerr("Visual trace identity changed"); quit(2); return
	var sim = load("res://scripts/core/ski_simulation.gd").new(preload("res://config/ski_default.tres").duplicate(true))
	sim.reset(field.launch_point(trace.heading),trace.heading); sim.prime_contacts(field)
	var sites = []
	for tick in 34001:
		if tick in [6000,14000,22000,34000]:
			sites.append({"tick":tick,"position":sim.position,"velocity":sim.velocity,"heading":sim.heading})
		sim.step(1.0/120,super.input_at_tick(tick),field)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Rendering comparison"),"field":field})
	game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_physics_process(false); game.set_process(false)
	game.benchmark_input = input_at_tick; game.benchmark_no_captures = true
	game.camera_settings.load_preferences(); game.camera.settings = game.camera_settings
	game.display_settings.frame_generation = false; game.display_settings.fps_limit = 60
	game.display_settings.apply_display(root,Vector2i(3840,2160)); game.display_settings.apply_viewport(root)
	var cases = []
	for weather in ["clear","snowfall"]:
		for index in sites.size():
			for close in [false,true]:
				var site: Dictionary = sites[index]; fixture_tick = site.tick
				var id = "%s_%d_%s" % [weather,index,"first_person" if close else "chase"]
				game.start_run(false); game.summit_ready = false; game.physics_modified = true; game.session.eligible = false
				game.sim.reset(site.position,site.heading); game.sim.prime_contacts(field); game.sim.velocity = site.velocity
				game.previous_position = game.sim.position
				game.skier.reset_animation(game.sim); game.camera.close_view = close; game.camera.reset()
				game.hud.hide_menu(); game.weather.set_preset(weather); game.weather.set_time_of_day("day")
				game.weather.visual_time = 0; game.world.assets.wind_time = 0; game.world.cloud_offset = Vector2.ZERO
				game.effects.reset(); game.weather_effects.reset()
				var particles = game.find_children("*","GPUParticles3D",true,false)
				for particle_index in particles.size():
					particles[particle_index].use_fixed_seed = true
					particles[particle_index].seed = 7100+particle_index
					particles[particle_index].restart()
				game.active = true; game._process(0)
				# Keep the same state during GI/texture residency warmup.
				for frame in 240: await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output+"/"+id+"_still.png")
				for frame in 120:
					game._physics_process(1.0/120); game._physics_process(1.0/120)
					game._process(1.0/60)
					await process_frame; await RenderingServer.frame_post_draw
					if frame%4==0: root.get_texture().get_image().save_jpg(output+"/%s_%03d.jpg" % [id,frame],.94)
					if game.sim.crashed: break
				cases.append({"id":id,"start":str(site.position),"end":str(game.sim.position),"crash":game.sim.crash_reason,"sdfgi":game.world.environment.sdfgi_enabled,"snow":game.effects.snow_budget()})
				print("PERFORMANCE_VISUAL ",id," crash=",game.sim.crash_reason)
	await RenderingServer.frame_post_draw
	var actual = root.get_texture().get_image().get_size()
	FileAccess.open(output+"/visuals.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"actual_pixels":[actual.x,actual.y],"display":game.display_settings.report(root,actual),"camera":game.camera_settings.snapshot(),"unranked":not game.session.eligible,"capture_overhead_included":true,"fixed_fps":60},"\t"))
	game.effects.stop_audio(); game.queue_free(); await process_frame; quit(0)
func input_at_tick(tick: int) -> RiderInput: return super.input_at_tick(fixture_tick+tick)
