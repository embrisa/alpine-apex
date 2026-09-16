extends "res://tests/performance_descent.gd"
## Separate inspection camera over real production snow after ordinary skiing.
var fixture_tick = 6000
func run() -> void:
	output = "res://artifacts/fps_optimization/tracks_visual"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--benchmark-label="): output = "res://artifacts/fps_optimization/"+arg.get_slice("=",1).validate_filename()
	DirAccess.make_dir_recursive_absolute(output)
	trace = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/fps_optimization/descent_input.json"))
	var preflight = Trace.preflight_error(trace,Definition.CURRENT_VERSION)
	if not preflight.is_empty(): printerr(preflight); quit(2); return
	field = preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: quit(2); return
	field.build_material_map()
	if not Trace.matches(field,trace.identity): printerr("Close-track trace identity changed"); quit(2); return
	var sim = load("res://scripts/core/ski_simulation.gd").new(preload("res://config/ski_default.tres").duplicate(true))
	sim.reset(field.launch_point(trace.heading),trace.heading); sim.prime_contacts(field)
	for tick in fixture_tick: sim.step(1.0/120,super.input_at_tick(tick),field)
	var site = {"position":sim.position,"heading":sim.heading,"velocity":sim.velocity}
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Track inspection"),"field":field})
	game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_physics_process(false); game.set_process(false)
	game.benchmark_input = input_at_tick; game.benchmark_no_captures = true
	game.camera_settings.load_preferences(); game.camera.settings = game.camera_settings
	game.display_settings.frame_generation = false; game.display_settings.fps_limit = 60
	game.display_settings.apply_display(root,Vector2i(3840,2160)); game.display_settings.apply_viewport(root)
	game.start_run(false); game.summit_ready = false; game.physics_modified = true; game.session.eligible = false
	game.sim.reset(site.position,site.heading); game.sim.prime_contacts(field); game.sim.velocity = site.velocity
	game.previous_position = game.sim.position; game.skier.reset_animation(game.sim); game.camera.reset()
	game.hud.hide_menu(); game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.weather.visual_time = 0; game.world.assets.wind_time = 0; game.world.cloud_offset = Vector2.ZERO
	game.effects.reset(); game.weather_effects.reset(); game.active = true; game._process(0)
	for frame in 240: await process_frame
	for frame in 240:
		game._physics_process(1.0/120); game._physics_process(1.0/120); game._process(1.0/60)
		await process_frame
		if game.sim.crashed: printerr("Track fixture crashed"); quit(2); return
	game.active = false; game._process(0); game.hud.root.hide()
	var direction: Vector3 = game.sim.skis[0].forward
	var focus: Vector3 = game.sim.position-direction*3.0
	focus.y = field.sample(focus.x,focus.z).height+.04
	var observer = Camera3D.new(); observer.fov = 60; observer.far = 15000
	game.add_child(observer); observer.make_current()
	var angle = atan2(direction.x,direction.z)
	place_observer(observer,focus,angle)
	game.world.update_weather(game.weather.state,0,false)
	for frame in 240: await process_frame
	await RenderingServer.frame_post_draw
	var actual = root.get_texture().get_image().get_size()
	root.get_texture().get_image().save_png(output+"/tracks_close_still.png")
	for frame in 120:
		place_observer(observer,focus,angle+(frame/119.0-.5)*.5)
		game.world.update_weather(game.weather.state,0,false)
		await process_frame; await RenderingServer.frame_post_draw
		if frame%4==0: root.get_texture().get_image().save_jpg(output+"/tracks_close_%03d.jpg" % frame,.94)
	var cases = [{"id":"tracks_close","start":str(site.position),"end":str(game.sim.position),"crash":game.sim.crash_reason,"sdfgi":game.world.environment.sdfgi_enabled,"snow":game.effects.snow_budget()}]
	preload("res://tests/test_report.gd").write(output+"/visuals.json",JSON.stringify({"cases":cases,"actual_pixels":[actual.x,actual.y],"display":game.display_settings.report(root,actual),"camera":game.camera_settings.snapshot(),"unranked":not game.session.eligible,"inspection_camera":true,"capture_overhead_included":true,"fixed_fps":60},"\t"))
	print("PERFORMANCE_TRACKS_VISUAL ",JSON.stringify(cases[0]))
	game.effects.stop_audio(); game.queue_free(); await process_frame; quit(0)
func place_observer(observer: Camera3D, focus: Vector3, angle: float) -> void:
	var eye = focus+Vector3(sin(angle),0,cos(angle))*2.7
	eye.y = field.sample(eye.x,eye.z).height+1.4
	observer.global_position = eye; observer.look_at(focus)
func input_at_tick(tick: int) -> RiderInput: return super.input_at_tick(fixture_tick+tick)
