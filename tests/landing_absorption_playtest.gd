extends "res://tests/skier_animation_playtest.gd"
## Unranked laboratory landings with real 4 m terrain, full solver and HUD.
var failures: Array = []
var tick_us: Array[float] = []
var view_camera: Camera3D

func run():
	if DisplayServer.get_name()=="headless": quit(2); return
	benchmark = "--timing" in OS.get_cmdline_user_args()
	output = "res://artifacts/landing_v18/"+("timing" if benchmark else "visual")
	DirAccess.make_dir_recursive_absolute(output)
	requested = Vector2i(3840,2160) if benchmark else Vector2i(1440,900)
	set_meta("test_lab_fixture",true)
	game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.start_run(false); game.active = false; game.session.eligible = false
	game.effects.muted = true; game.voice.set_muted(true)
	game.hud.hide_menu(); game.hud.toast_time = 0
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.camera.effects_enabled = false
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "fsr2" if benchmark else "native"
	game.display_settings.render_scale = .75 if benchmark else 1.0
	game.display_settings.fps_limit = 120
	game.display_settings.apply_display(root,requested); game.display_settings.apply_viewport(root)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	view_camera = Camera3D.new(); game.add_child(view_camera)
	view_camera.fov = 58; view_camera.near = .05; view_camera.far = 15000
	var overlay = CanvasLayer.new(); root.add_child(overlay)
	label = Label.new(); overlay.add_child(label); label.position = Vector2(24,105)
	label.add_theme_font_size_override("font_size",22)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2); label.add_theme_constant_override("shadow_offset_y",2)
	label.visible = not benchmark
	for tick in 120: await process_frame
	await RenderingServer.frame_post_draw
	var actual = root.get_texture().get_image().get_size()
	if actual!=requested: printerr("Wrong output size: ",actual); quit(2); return
	if benchmark: process_frame.connect(measure_frame)
	for request in [
		{"name":"small_clean","height":.6,"normal":3.0,"min_loss":0.0,"max_loss":.000001},
		{"name":"large_clean","height":5.0,"normal":14.0,"min_loss":.01,"max_loss":.10},
		{"name":"awkward","height":2.0,"normal":14.0,"roll":1.05,"min_loss":.35,"max_loss":.650001},
		{"name":"extreme_clean","height":12.0,"normal":35.0,"min_loss":.10,"max_loss":.30}]:
		await ride_landing(request)
	var report = {"physics":game.sim.MODEL_VERSION,"unranked":not game.session.eligible,"cases":rows,"failures":failures,"captures":captures,
		"actual_pixels":[actual.x,actual.y],"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),
		"display":game.display_settings.report(root,actual),"capture_overhead_included":not benchmark,"human_playtest":false,"scope":"Four scripted laboratory landing and recovery scenarios"}
	if benchmark:
		report.frame_ms = stats(frames); report.render_cpu_ms = stats(render_cpu); report.render_gpu_ms = stats(gpu)
		report.fixed_tick_us = stats(tick_us); report.peak_video_bytes = peak_video; report.peak_engine_static_bytes = peak_static
	FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("LANDING_NATIVE_RESULTS ",JSON.stringify(report))
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func ride_landing(request: Dictionary):
	var z = 150.0
	var origin = Vector3(0,game.field.sample(0,z).height,z)
	game.sim.reset(origin); game.sim.prime_contacts(game.field)
	var frame: Basis = game.sim.support_basis()
	game.sim.position.y += request.height
	game.sim.velocity = frame.z*20.0-frame.y*request.normal
	game.sim._begin_flight(frame*Basis(Vector3.BACK,request.get("roll",0.0)))
	game.sim.reset_pose_history(); game.skier.reset_animation(game.sim)
	game.previous_position = game.sim.position; game.camera.reset(); game.effects.reset()
	var intent = RiderInput.new()
	var minimum_reserve = 1.0
	var impact = 0.0
	var touched = false
	var contact_frame = -1
	var trace: Array = []
	var folder = output+"/"+request.name
	if not benchmark: DirAccess.make_dir_recursive_absolute(folder)
	measuring = benchmark; last_frame = 0
	for frame_index in (720 if benchmark else 180):
		for tick in (1 if benchmark else 4):
			game.previous_position = game.sim.position
			var start = Time.get_ticks_usec()
			game.sim.step(DT,intent,game.field)
			game.skier.step_animation(DT,game.sim,intent,game.field)
			if benchmark: tick_us.append(Time.get_ticks_usec()-start)
			if not touched and game.sim.time_since_landing==0:
				touched = true; contact_frame = frame_index
			impact = maxf(impact,game.sim.landing_force)
			minimum_reserve = minf(minimum_reserve,game.sim.impacts.reserve)
		game.intent = intent; game.session.elapsed += DT*(1 if benchmark else 4)
		game._process(DT*(1 if benchmark else 4)); game.speed_periphery.hide()
		var center: Vector3 = game.sim.position+Vector3.UP*.8
		view_camera.position = center+frame*Vector3(4.5,1.2,-1.0)
		view_camera.look_at(center); view_camera.make_current()
		label.text = "%s\nInto slope: %.1f m/s   Minimum reserve: %.1f%%"%[request.name.replace("_"," ").to_upper(),impact,minimum_reserve*100]
		if benchmark:
			await physics_frame
		else:
			await process_frame; await RenderingServer.frame_post_draw
			var picture = root.get_texture().get_image()
			if frame_index<90: picture.save_jpg(folder+"/%04d.jpg"%frame_index,.88)
			if frame_index in [0,30,90,179] or (touched and frame_index-contact_frame in [0,3,8,15]):
				var name = folder+"/%04d.png"%frame_index
				picture.save_png(name); captures.append(name)
		if frame_index%15==0:
			trace.append({"frame":frame_index,"reserve":game.sim.impacts.reserve,"grounded":game.sim.grounded,"phase":game.skier.animation.phase,"hud":game.hud.state_label.text})
		if game.sim.crashed: failures.append(request.name+": "+game.sim.crash_reason); break
	measuring = false
	var loss: float = 1.0-minimum_reserve
	if not touched: failures.append(request.name+": no touchdown")
	if loss<request.min_loss or loss>request.max_loss: failures.append(request.name+": unexpected reserve loss "+str(loss))
	if game.session.eligible: failures.append(request.name+": must remain unranked")
	rows.append({"scenario":request.name,"normal_speed_mps":impact,"minimum_reserve":minimum_reserve,"final_reserve":game.sim.impacts.reserve,"contact_frame":contact_frame,"trace":trace})
	print("LANDING_NATIVE_CASE ",request.name," impact=",impact," reserve=",minimum_reserve)
