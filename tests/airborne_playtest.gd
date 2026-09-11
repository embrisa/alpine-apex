extends "res://tests/skier_animation_playtest.gd"
## Version-pinned real-terrain jump clips and a separate screenshot-free timing run.
const Definition = preload("res://scripts/world/mountain_definition.gd")
var field
var timing_only = false
var evidence: Array = []
var tick_us: Array[float] = []
var failures: Array = []
func run():
	if DisplayServer.get_name()=="headless": quit(2); return
	output = "res://artifacts/jump_v13/native"
	timing_only = "--timing" in OS.get_cmdline_user_args()
	requested = Vector2i(3840,2160) if timing_only else Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output)
	field = Definition.generate(849205174,10)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Jump v13 validation"),"field":field})
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.start_run(false)
	game.summit_ready = false
	game.session.eligible = false
	game.effects.muted = true
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	game.hud.hide()
	game.camera.effects_enabled = false
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "fsr2" if timing_only else "native"
	game.display_settings.render_scale = .75 if timing_only else 1.0
	game.display_settings.fps_limit = 120
	game.display_settings.apply_display(root,requested)
	game.display_settings.apply_viewport(root)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for i in 120: await process_frame
	await RenderingServer.frame_post_draw
	var actual = root.get_texture().get_image().get_size()
	if actual!=requested: printerr("Wrong output size ",actual); quit(2); return
	if timing_only: process_frame.connect(measure_frame)
	for scenario in ["forward_release","backward_release","active_reversals","natural_drop"]:
		var face = field.faces[0]
		var p: Vector2 = face.to_world(Vector2(face.gully_x(820,-1),820))
		var height = 9.0
		if scenario=="natural_drop":
			p = field.jumps[0].position-field.jumps[0].direction*75.0
			height = 0.0
		var origin = Vector3(p.x,field.sample(p.x,p.y).height+height,p.y)
		game.sim.reset(origin,face.heading)
		game.sim.prime_contacts(field)
		game.sim.velocity = game.sim.support_basis().z*(26.0 if scenario=="natural_drop" else 20.0)
		if height>0:
			game.sim.grounded = false
			game.sim.heading += .6
			game.sim.body.roll_velocity = 1.6
			game.sim.body.pitch_velocity = .6
		game.sim.facing_backward = scenario=="backward_release"
		game.sim.reset_pose_history()
		game.skier.reset_animation(game.sim)
		game.camera.reset()
		var control = RiderInput.new()
		var landings = 0
		var previous_air = not game.sim.grounded
		var frames_count = 960 if timing_only else 180
		var substeps = 1 if timing_only else 4
		var samples: Array = []
		measuring = timing_only
		for frame_index in frames_count:
			var seconds = frame_index*substeps*DT
			control.tuck = .35
			control.steer = (.8 if fmod(seconds,1.2)<.6 else -.8) if scenario=="active_reversals" else 0.0
			for tick in substeps:
				var start = Time.get_ticks_usec()
				game.sim.step(DT,control,game.world.ski_surface)
				game.skier.step_animation(DT,game.sim,control,field)
				if timing_only: tick_us.append(Time.get_ticks_usec()-start)
				if previous_air and game.sim.grounded: landings += 1
				previous_air = not game.sim.grounded
			game.intent = control
			game.previous_position = game.sim.position
			game._process(DT*substeps)
			game.skier.pose(game.sim,1.0)
			if timing_only:
				await physics_frame
			else:
				for view in ["chase","side"]:
					var center: Vector3 = game.sim.position+Vector3.UP*.85
					var frame: Basis = game.sim.support_basis()
					game.camera.position = center+frame*(Vector3(0,1.1,-5.5) if view=="chase" else Vector3(3.8,.7,0))
					game.camera.look_at(center)
					await process_frame
					await RenderingServer.frame_post_draw
					var picture = root.get_texture().get_image()
					var folder = output+"/"+scenario+"_"+view
					DirAccess.make_dir_recursive_absolute(folder)
					picture.save_jpg(folder+"/%04d.jpg"%frame_index,.9)
					if frame_index in [0,15,30,60,90,179]: picture.save_png(folder+"/%04d.png"%frame_index)
			if frame_index%15==0:
				samples.append({"frame":frame_index,"seconds":seconds,"air":not game.sim.grounded,"assist":game.sim.landing_assist_strength,"facing_backward":game.sim.facing_backward,"reserve":game.sim.impacts.reserve,"position":str(game.sim.position)})
			if game.sim.crashed: break
		measuring = false
		if game.sim.crashed: failures.append(scenario+": "+game.sim.crash_reason)
		evidence.append({"scenario":scenario,"landings":landings,"airtime_s":game.sim.total_airtime,"crash":game.sim.crash_reason,"samples":samples})
		print("AIR_NATIVE_CASE ",JSON.stringify(evidence[-1]))
	var report = {"version":10,"seed":849205174,"physics":game.sim.MODEL_VERSION,"unranked":not game.session.eligible,"failures":failures,"cases":evidence,"actual_pixels":[actual.x,actual.y],"display":game.display_settings.report(root,actual),"device":RenderingServer.get_video_adapter_name(),"capture_overhead_included":not timing_only,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum}
	if timing_only:
		report.frame_ms = stats(frames)
		report.render_cpu_ms = stats(render_cpu)
		report.render_gpu_ms = stats(gpu)
		report.fixed_tick_us = stats(tick_us)
		report.peak_video_bytes = peak_video
		report.peak_engine_static_bytes = peak_static
	FileAccess.open(output+("/timing.json" if timing_only else "/clips.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("AIR_NATIVE_COMPLETE ",JSON.stringify(report))
	if not timing_only:
		game.hud.show()
		game.hud.open_settings()
		_select_tab(game.hud.settings_tabs,"Controls")
		var help_page = game.hud.settings_tabs.get_current_tab_control() as ScrollContainer
		var air_help = _expand_group(help_page,"Air control")
		for frame in 3: await process_frame
		help_page.ensure_control_visible(air_help)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/controls.png")
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _select_tab(tabs: TabContainer, caption: String) -> void:
	for index in tabs.get_tab_count():
		if tabs.get_tab_title(index)==caption:
			tabs.current_tab = index
			return
	assert(false,"Missing tab: "+caption)

func _expand_group(page: Control, caption: String) -> Control:
	for button in page.find_children("*","Button",true,false):
		if button.has_meta("group_body") and button.text.ends_with(caption):
			button.button_pressed = true
			return button.get_meta("group_body")
	assert(false,"Missing settings group: "+caption)
	return null
