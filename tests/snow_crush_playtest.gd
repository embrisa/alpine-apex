extends "res://tests/planted_snow_playtest.gd"
## Current presentation, same cached v14 fixtures, crush disabled/enabled.
## Visual and timing passes are separate. These runs cannot write records.
func run() -> void:
	benchmark = "--timing" in OS.get_cmdline_user_args()
	output = "res://artifacts/snow_crush_v26/"+("timing" if benchmark else "visual")
	DirAccess.make_dir_recursive_absolute(output)
	version = 14
	sources = source_hashes()
	field = Definition.generate(849205174,Definition.CURRENT_VERSION)
	var selection: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/snow_crush_v26/mountain.json"))
	if selection.height_sha256!=field.height_checksum or selection.obstacle_sha256!=field.obstacle_checksum:
		printerr("Crush fixture terrain identity changed"); quit(1); return
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Snow crushing verification"),"field":field})
	game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.start_run(false); game.summit_ready = false; game.active = true; game.physics_modified = true; game.session.eligible = false
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.set_graphics_quality(2); game.world.environment.sdfgi_enabled = false
	game.effects.muted = true; game.hud.hide(); game.hud.hide_menu(); game.speed_periphery.hide()
	game.display_settings.display_mode = "windowed"
	game.display_settings.frame_generation = false
	game.display_settings.terrain_gi = false
	requested = Vector2i(3840,2160) if benchmark else Vector2i(1920,1080)
	game.display_settings.upscaler = "auto" if benchmark else "native"
	game.display_settings.render_scale = .75 if benchmark else 1.0
	game.display_settings.fps_limit = 120 if benchmark else 30
	game.display_settings.apply_display(root,requested); game.display_settings.apply_viewport(root)
	root.content_scale_size = requested
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	game.camera.close_view = false
	game.camera.make_current()
	var overlay = CanvasLayer.new(); root.add_child(overlay)
	label = Label.new(); overlay.add_child(label); label.position = Vector2(20,20); label.add_theme_font_size_override("font_size",24)
	label.add_theme_color_override("font_shadow_color",Color.BLACK); label.add_theme_constant_override("shadow_offset_x",2); label.add_theme_constant_override("shadow_offset_y",2)
	label.visible = not benchmark
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	var actual = root.get_texture().get_image().get_size()
	if actual!=requested: failures.append("Output pixel mismatch")
	if benchmark: process_frame.connect(measure_frame)
	for enabled in [false,true]:
		game.sim.tuning.snow_crush_max_m = .30 if enabled else 0.0
		for chosen in selection.cases:
			await capture_crossing(chosen.fixture,enabled)
	if sources!=source_hashes(): failures.append("Source changed during render verification")
	var report = {"model":game.sim.MODEL_VERSION,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"sources":sources,"actual_pixels":[actual.x,actual.y],"device":RenderingServer.get_video_adapter_name(),"display":game.display_settings.report(root,actual),"quality":game.graphics.label(),"camera":"production chase","camera_settings":game.camera_settings.snapshot(),"sdfgi":game.world.environment.sdfgi_enabled,"unranked":not game.session.eligible,"cases":rows,"failures":failures,"capture_overhead_included":not benchmark,"peak_video_bytes":peak_video,"peak_engine_static_bytes":peak_static}
	preload("res://tests/test_report.gd").write(output+"/results.json",JSON.stringify(report,"\t"))
	print("SNOW_CRUSH_RENDER ",output," failures=",failures)
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func capture_crossing(fixture: Dictionary, enabled: bool) -> void:
	reset_fixture(fixture)
	var intent = RiderInput.new(); intent.tuck = 1.0
	game.intent = intent; game._process(DT)
	for frame in 60: await process_frame
	var id: String = fixture.name+("_crush" if enabled else "_rigid")
	label.text = id+" / 160 km/h entry / UNRANKED"
	var samples: Array = []; var peak_gap = 0.0; var peak_crush = 0.0
	var first_frame = frames.size(); var first_solver = solver_us.size(); var first_cpu = render_cpu.size(); var first_gpu = gpu.size()
	measuring = benchmark; last_frame = 0
	var ticks_per_frame = 1 if benchmark else 4
	for frame in roundi(fixture.seconds/(DT*ticks_per_frame)):
		for tick in ticks_per_frame:
			game.previous_position = game.sim.position
			var started = Time.get_ticks_usec()
			game.sim.step(DT,intent,game.world.ski_surface)
			if benchmark: solver_us.append(Time.get_ticks_usec()-started)
			game.skier.step_animation(DT,game.sim,intent,field)
		game.intent = intent; game.session.elapsed += DT*ticks_per_frame
		game._process(DT*ticks_per_frame); game.speed_periphery.hide()
		if benchmark: await physics_frame
		else:
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(output+"/%s_%03d.jpg"%[id,frame],.90)
		game.skier.skeleton.force_update_all_bone_transforms()
		for i in 2:
			var bone = "RightFoot" if i==0 else "LeftFoot"
			var foot: Transform3D = game.skier.skeleton.global_transform*game.skier.skeleton.get_bone_global_pose(game.skier.bone_ids[bone])
			var ankle: Vector3 = game.skier.skis[i].get_child(1).global_transform*Vector3(0,game.skier._origin(bone).y,0)
			peak_gap = maxf(peak_gap,foot.origin.distance_to(ankle))
			peak_crush = maxf(peak_crush,game.sim.skis[i].crush_m)
		samples.append({"frame":frame,"kmh":game.sim.speed_kmh(),"grounded":game.sim.grounded,"crush_m":game.sim.skis[0].crush_m,"crush_rate_m_s":game.sim.skis[0].crush_rate_m_s,"powder":game.effects.responses[0].powder,"position":[game.sim.position.x,game.sim.position.y,game.sim.position.z],"camera_transform":str(game.camera.global_transform)})
		if game.sim.crashed: failures.append(id+": "+game.sim.crash_reason); break
	measuring = false
	if peak_gap>.001: failures.append(id+": rigid boot/foot gap above 1 mm")
	if enabled and peak_crush<.03: failures.append(id+": no visible crushing event")
	var row = {"name":id,"fixture":fixture,"crushing":enabled,"airtime_s":game.sim.total_airtime,"exit_kmh":game.sim.speed_kmh(),"peak_crush_m":peak_crush,"boot_gap_m":peak_gap,"samples":samples,"snow_budget":game.effects.snow_budget()}
	if benchmark:
		row.frame_ms = stats(frames.slice(first_frame)); row.solver_us = stats(solver_us.slice(first_solver)); row.render_cpu_ms = stats(render_cpu.slice(first_cpu)); row.gpu_ms = stats(gpu.slice(first_gpu))
	rows.append(row)
	if not benchmark:
		game.camera.make_current()
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(output+"/"+id+"_chase.jpg",.94)

func source_hashes() -> Dictionary:
	var hashes = super.source_hashes()
	for path in ["scripts/core/snow_crush_contact.gd","tests/snow_crush_playtest.gd","scripts/presentation/downhill_posture.gd","scripts/presentation/skier_pose_writer.gd","scripts/presentation/skier_equipment.gd","scripts/presentation/chase_camera.gd","scripts/presentation/camera_settings.gd","scripts/presentation/pc_graphics_settings.gd"]:
		hashes[path] = FileAccess.get_sha256("res://"+path)
	return hashes
