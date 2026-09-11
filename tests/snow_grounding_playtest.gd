extends "res://tests/skier_animation_playtest.gd"
## Matched v15 production-chase motion; visual, timing and controller modes.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Probe = preload("res://tests/planted_snow_probe.gd")
const Receipt = preload("res://tests/snow_grounding_mountain.gd")
var field
var solver_us: Array[float] = []
var failures: Array = []
var selected: Array = []
var fixture_index = 0
var reference = false
var interactive = false

class Keys extends Node:
	var host
	func _unhandled_key_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_F6,KEY_F7,KEY_F8]:
			host.choose(event.physical_keycode)
			get_viewport().set_input_as_handled()

func run() -> void:
	if DisplayServer.get_name()=="headless": printerr("Rendered snow playtest requires a display"); quit(1); return
	var args = OS.get_cmdline_user_args()
	benchmark = "--timing" in args; interactive = "--interactive" in args
	output = "res://artifacts/snow_grounding_v28/"+("interactive" if interactive else ("timing" if benchmark else "visual"))
	DirAccess.make_dir_recursive_absolute(output)
	var sources = render_sources()
	var selection: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/snow_grounding_v28/mountain.json"))
	field = Definition.generate(849205174,15)
	if selection.height_sha256!=field.height_checksum or selection.obstacle_sha256!=field.obstacle_checksum:
		printerr("Snow playtest terrain differs from measured fixtures"); quit(1); return
	selected = selection.render_cases
	if selected.size()<2: printerr("Missing measured snow fixtures"); quit(1); return
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Grounded snow playtest"),"field":field})
	game = load("res://main.tscn").instantiate()
	# A test-only dynamic owner allows the frozen reference to use the same
	# current presentation. The product's typed simulation remains unchanged.
	var source = FileAccess.get_file_as_string("res://scripts/main.gd").replace("var sim: SkiSimulation","var sim")
	FileAccess.open(output+"/comparison_main.gd",FileAccess.WRITE).store_string(source)
	game.set_script(load(output+"/comparison_main.gd"))
	game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.start_run(false); game.summit_ready = false; game.active = true; game.physics_modified = true; game.session.eligible = false
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.set_graphics_quality(2); game.world.environment.sdfgi_enabled = false
	game.effects.muted = not interactive
	game.hud.hide(); game.hud.hide_menu()
	game.display_settings.display_mode = "windowed"
	game.display_settings.frame_generation = false; game.display_settings.terrain_gi = false
	requested = Vector2i(3840,2160) if benchmark or interactive else Vector2i(1920,1080)
	game.display_settings.upscaler = "auto" if benchmark or interactive else "native"
	game.display_settings.render_scale = .75 if benchmark or interactive else 1.0
	game.display_settings.fps_limit = 120 if benchmark or interactive else 30
	game.display_settings.apply_display(root,requested); game.display_settings.apply_viewport(root)
	root.content_scale_size = requested
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	game.camera.close_view = false; game.camera.make_current()
	var overlay = CanvasLayer.new(); root.add_child(overlay)
	label = Label.new(); overlay.add_child(label); label.position = Vector2(20,20)
	label.add_theme_font_size_override("font_size",24); label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2); label.add_theme_constant_override("shadow_offset_y",2)
	label.visible = not benchmark
	for i in 90: await process_frame
	await RenderingServer.frame_post_draw
	var actual = Vector2i(root.get_texture().get_size()) if benchmark else root.get_texture().get_image().get_size()
	if actual!=requested or root.content_scale_size!=requested: failures.append("Output pixel/canvas mismatch")
	if interactive:
		# Keep startup/preferences isolated, then give live input to the normal
		# game loop. Its automated flag otherwise replaces all controller input.
		game.automated = false
		var keys = Keys.new(); keys.host = self; root.add_child(keys)
		# Start on the moving snow-only crossing; retain the other measured
		# terrain interactions for explicit comparison with F8.
		fixture_index = mini(1,selected.size()-1)
		choose(KEY_F7)
		game.set_process(true); game.set_physics_process(true)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/ready.png")
		var devices: Array = []
		for device in Input.get_connected_joypads(): devices.append({"id":device,"name":Input.get_joy_name(device)})
		FileAccess.open(output+"/ready.json",FileAccess.WRITE).store_string(JSON.stringify({"model":game.sim.MODEL_VERSION,"generator":15,"seed":849205174,"unranked":not game.session.eligible,"live_input":not game.automated,"paused":not game.active,"fixture":selected[fixture_index].fixture,"controllers":devices,"display":game.display_settings.report(root,actual),"sources":sources,"failures":failures},"\t"))
		print("SNOW_CONTROLLER_READY model=",game.sim.MODEL_VERSION," generator=15 unranked=true live_input=true F6=compare F7=retry F8=next controllers=",devices," failures=",failures)
		return
	if benchmark: process_frame.connect(measure_frame)
	for enabled in ([false,true,true,false] if benchmark else [false,true]):
		reference = not enabled
		game.sim = load("res://artifacts/snow_grounding_v28/baseline/core/ski_simulation.gd").new() if reference else load("res://scripts/core/ski_simulation.gd").new()
		for chosen in selected: await ride(chosen.fixture)
	if sources!=render_sources(): failures.append("Sources changed during rendered comparison")
	var report = {"model":28,"baseline_model":27,"generator":15,"seed":849205174,"sources":sources,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"actual_pixels":[actual.x,actual.y],"device":RenderingServer.get_video_adapter_name(),"display":game.display_settings.report(root,actual),"quality":game.graphics.label(),"camera":"production chase","camera_settings":game.camera_settings.snapshot(),"unranked":not game.session.eligible,"cases":rows,"failures":failures,"capture_overhead_included":not benchmark,"peak_video_bytes":peak_video,"peak_engine_static_bytes":peak_static}
	FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SNOW_RENDER_COMPLETE ",output," failures=",failures)
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func reset_fixture(fixture: Dictionary) -> void:
	var p: Array = fixture.origin
	var origin = Vector3(p[0],field.sample(p[0],p[2]).height,p[2])
	game.sim.reset(origin,fixture.heading); game.sim.prime_contacts(game.world.ski_surface)
	game.sim.velocity = game.sim.support_basis().z*fixture.kmh/3.6; game.sim.effective_tuck = 1.0
	game.previous_position = origin; game.skier.reset_animation(game.sim); game.camera.reset(); game.effects.reset()
	game.physics_modified = true; game.session.eligible = false; game.summit_ready = false

func choose(key: int) -> void:
	game.active = false
	if key==KEY_F6: reference = not reference
	if key==KEY_F8: fixture_index = (fixture_index+1)%selected.size()
	game.sim = load("res://artifacts/snow_grounding_v28/baseline/core/ski_simulation.gd").new() if reference else load("res://scripts/core/ski_simulation.gd").new()
	game.start_run(false); game.active = false
	reset_fixture(selected[fixture_index].fixture)
	game.hud.show(); game.hud.show_menu("paused")
	label.text = ("MODEL 27 BASELINE" if reference else "SOFTER SNOW / MODEL 28")+" / UNRANKED\nF6 compare · F7 retry · F8 next slope · Resume to ski"

func ride(fixture: Dictionary) -> void:
	reset_fixture(fixture)
	var intent = RiderInput.new(); intent.tuck = 1.0
	game.intent = intent; game._process(DT)
	for i in 90: await process_frame
	var id: String = fixture.name+("_before" if reference else "_after")
	label.text = id+" / 160 km/h entry / UNRANKED"
	var samples: Array = []; var gap = 0.0; var assisted_ticks = 0
	var first_frame = frames.size(); var first_solver = solver_us.size(); var first_cpu = render_cpu.size(); var first_gpu = gpu.size()
	measuring = benchmark; last_frame = 0
	var tick_count = 1 if benchmark else 4
	for frame in roundi(fixture.seconds/(DT*tick_count)):
		for tick in tick_count:
			intent.steer = Probe.steering(fixture,(frame*tick_count+tick)*DT)
			game.previous_position = game.sim.position
			var start = Time.get_ticks_usec()
			game.sim.step(DT,intent,game.world.ski_surface)
			if benchmark: solver_us.append(Time.get_ticks_usec()-start)
			if not reference and game.sim.snow_contact_assist.correction_m_s>0: assisted_ticks += 1
			game.skier.step_animation(DT,game.sim,intent,field)
		game.intent = intent; game.session.elapsed += DT*tick_count
		game._process(DT*tick_count)
		if benchmark: await physics_frame
		else:
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(output+"/%s_%03d.jpg"%[id,frame],.90)
		# Rigid foot/binding closure is a mechanical check, not an animation grade.
		if not benchmark:
			game.skier.skeleton.force_update_all_bone_transforms()
			for i in 2:
				var bone = "RightFoot" if i==0 else "LeftFoot"
				var foot: Transform3D = game.skier.skeleton.global_transform*game.skier.skeleton.get_bone_global_pose(game.skier.bone_ids[bone])
				var ankle: Vector3 = game.skier.skis[i].get_child(1).global_transform*Vector3(0,game.skier._origin(bone).y,0)
				gap = maxf(gap,foot.origin.distance_to(ankle))
		if not benchmark or frame%12==0:
			samples.append({"frame":frame,"kmh":game.sim.speed_kmh(),"grounded":game.sim.grounded,"position":[game.sim.position.x,game.sim.position.y,game.sim.position.z],"crush_m":game.sim.skis[0].crush_m,"assist_m_s":0.0 if reference else game.sim.snow_contact_assist.correction_m_s})
		if game.sim.crashed: failures.append(id+": "+game.sim.crash_reason); break
	measuring = false
	if not benchmark and gap>.001: failures.append(id+": foot/binding gap exceeds 1 mm")
	var row = {"sequence":rows.size(),"name":id,"model":game.sim.MODEL_VERSION,"fixture":fixture,"airtime_s":game.sim.total_airtime,"exit_kmh":game.sim.speed_kmh(),"boot_gap_m":gap,"assisted_ticks":assisted_ticks,"samples":samples,"snow_budget":game.effects.snow_budget()}
	if benchmark:
		row.frame_ms = stats(frames.slice(first_frame)); row.solver_us = stats(solver_us.slice(first_solver)); row.render_cpu_ms = stats(render_cpu.slice(first_cpu)); row.gpu_ms = stats(gpu.slice(first_gpu))
	rows.append(row)

func render_sources() -> Dictionary:
	var result = Receipt.source_hashes()
	for folder in ["scripts/core/","scripts/presentation/"]:
		for name in DirAccess.get_files_at("res://"+folder):
			if name.ends_with(".gd"): result[folder+name] = FileAccess.get_sha256("res://"+folder+name)
	for name in DirAccess.get_files_at("res://assets/graphics"):
		if name.ends_with(".gdshader") or name.ends_with(".gdshaderinc") or name.ends_with(".gd"):
			result["assets/graphics/"+name] = FileAccess.get_sha256("res://assets/graphics/"+name)
	for path in ["scripts/main.gd","tests/snow_grounding_playtest.gd","scripts/presentation/skier_visual.gd","scripts/presentation/skier_animation.gd","scripts/presentation/skier_pose_writer.gd","scripts/presentation/skier_equipment.gd","scripts/presentation/chase_camera.gd","scripts/presentation/downhill_posture.gd","scripts/presentation/action_posture.gd","scripts/presentation/pc_graphics_settings.gd"]:
		result[path] = FileAccess.get_sha256("res://"+path)
	return result
