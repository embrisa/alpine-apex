extends SceneTree
## Native chronological evidence; captures are explicitly excluded from benchmarks.
var game
var output = "res://artifacts/weather_upgrade/motion-after"
var clips = []
var matrix_only = false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = "res://"+arg.get_slice("=",1)
		if arg=="--matrix": matrix_only = true
	if DisplayServer.get_name()=="headless": printerr("Native renderer required"); quit(2); return
	set_meta("test_lab_fixture",true)
	root.size = Vector2i(1280,720); Engine.max_fps = 60
	game = load("res://main.tscn").instantiate(); game.automated = true
	game.benchmark_no_captures = true
	game.screenshot_ticks = []
	root.add_child(game)
	while not game.initialized: await process_frame
	game.benchmark_no_captures = true
	game.set_process(false); game.set_physics_process(false)
	game.set_graphics_quality(2)
	game.display_settings.upscaler = "native"; game.display_settings.render_scale = 1.0; game.display_settings.apply_viewport(root)
	DirAccess.make_dir_recursive_absolute(output)
	if matrix_only:
		for graphics in 3:
			game.set_graphics_quality(graphics)
			for fx in 3:
				game.set_display_setting("weather_quality",fx)
				for lightning in 3:
					for reduced in [false,true]:
						game.weather.lightning = lightning; game.hud.feedback.reduced_motion = reduced
						await capture_clip("thunderstorm","dusk",false,"_g%d_fx%d_l%d_r%d" % [graphics,fx,lightning,int(reduced)])
		await capture_interfaces()
	else:
		for preset in game.weather.PRESETS:
			for band in ["dawn","day","dusk","night"]:
				for close in [false,true]: await capture_clip(preset,band,close)
	FileAccess.open(output+"/motion.json",FileAccess.WRITE).store_string(JSON.stringify({"clips":clips,"native_pixels":[1280,720],"fps":30,"capture_overhead":true,"unranked":not game.session.eligible},"\t"))
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit()

func capture_clip(preset: String, band: String, close: bool, suffix: String = "") -> void:
	var label = "%s_%s_%s" % [preset,band,"pov" if close else "chase"]+suffix
	var folder = output+"/"+label; DirAccess.make_dir_recursive_absolute(folder)
	game.start_speed_lab(80)
	game.automated_ticks = 0
	game.sim.reset(Vector3(0,game.field.sample(0,500).height,500),0)
	game.sim.prime_contacts(game.field)
	game.sim.velocity = Vector3.BACK.slide(game.sim.surface_normal).normalized()*22.2
	game.previous_position = game.sim.position; game.skier.reset_animation(game.sim)
	game.weather.set_preset(preset); game.weather.set_time_of_day(band)
	game.weather.set_automatic(false); game.weather.set_time_cycle(false)
	game.camera.close_view = close; game.camera.reset(); game.hud.root.hide()
	game.weather_effects.reset()
	if "active_seconds" in game.weather and preset=="thunderstorm":
		var strike = load("res://scripts/presentation/storm_effects.gd").event(game.weather.variation_seed,0)
		game.weather.active_seconds = strike.at-.4
	for frame in 45:
		for tick in 4: game._physics_process(1.0/120.0)
		game._process(1.0/30.0)
		for particle in game.weather_effects.volumes+game.weather_effects.drifts+game.effects.sprays:
			particle.speed_scale = 0.0
			if particle.visible: particle.request_particles_process(1.0/30.0)
		await process_frame; await RenderingServer.frame_post_draw
		if frame>=15:
			var picture = root.get_texture().get_image()
			picture.save_jpg(folder+"/%03d.jpg" % (frame-15),.88)
	clips.append({"clip":label,"seconds":1.0,"frames":30,"crash":game.sim.crash_reason,"particles":game.weather_effects.particle_budget(),"graphics":game.graphics.level,"fx":game.graphics.weather_quality,"lightning":game.weather.lightning,"reduced_motion":game.hud.feedback.reduced_motion})
	print("WEATHER_MOTION ",label)

func capture_interfaces() -> void:
	game.active = false; game.hud.root.show(); game.hud.feedback.reduced_motion = false
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = size
		game.hud.open_settings()
		for i in game.hud.settings_tabs.get_tab_count():
			if game.hud.settings_tabs.get_tab_title(i)=="Weather": game.hud.settings_tabs.current_tab = i
		for frame in 5: game._process(.016); await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/settings_%d.png" % size.x)
		game.hud.close_weather(); game.workshop.open_library(); game.workshop.begin_creation()
		game.workshop.weather_selector.select(5); game.workshop.time_selector.select(2)
		game.workshop.name_input.text = "Storm challenge"; game.workshop._refresh_draft()
		for frame in 5: game._process(.016); await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/creator_%d.png" % size.x)
		game.workshop.back_pressed(); game.workshop.close()
