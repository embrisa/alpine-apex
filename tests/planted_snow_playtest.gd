extends "res://tests/skier_animation_playtest.gd"
## Fixed v13 input fixtures, optional v14 scene, and an unranked manual handoff.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Probe = preload("res://tests/planted_snow_probe.gd")
var field
var observer: Camera3D
var solver_us: Array[float] = []
var failures: Array = []
var reference = false
var version = 13
var interactive = false
var sources: Dictionary = {}
var comparison_fixtures: Array = []
var comparison_index = 0

class ComparisonKeys extends Node:
	var host
	func _unhandled_key_input(event: InputEvent) -> void:
		if not event is InputEventKey or not event.pressed or event.echo: return
		if event.physical_keycode in [KEY_F6,KEY_F7,KEY_F8]:
			host.change_comparison(event.physical_keycode)
			get_viewport().set_input_as_handled()

func run() -> void:
	var args = OS.get_cmdline_user_args()
	reference = "--reference" in args; benchmark = "--timing" in args; interactive = "--interactive" in args or "--interactive-check" in args
	for arg in args:
		if arg.begins_with("--version="): version = int(arg.trim_prefix("--version="))
	output = "res://artifacts/planted_snow/"+("reference" if reference else "current")+"_v%d_"%version+("timing" if benchmark else "visual")
	DirAccess.make_dir_recursive_absolute(output)
	sources = source_hashes()
	field = comparison_field()
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Soft snow comparison"),"field":field})
	game = load("res://main.tscn").instantiate()
	if reference or interactive:
		# The product main has a typed v23 owner. Relax only this test copy so
		# the immutable v22 object can use identical current presentation code.
		var source = FileAccess.get_file_as_string("res://scripts/main.gd").replace("var sim: SkiSimulation","var sim")
		var comparison_main = output+"/comparison_main.gd"
		FileAccess.open(comparison_main,FileAccess.WRITE).store_string(source)
		game.set_script(load(comparison_main))
	game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.start_run(false); game.summit_ready = false; game.session.eligible = false; game.active = true
	if reference: game.sim = load("res://artifacts/planted_snow/baseline/core/ski_simulation.gd").new()
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.set_graphics_quality(2)
	game.world.environment.sdfgi_enabled = false
	game.display_settings.display_mode = "windowed"
	var high_output = benchmark or interactive
	requested = Vector2i(3840,2160) if high_output else Vector2i(1920,1080)
	game.display_settings.upscaler = "fsr2" if high_output else "native"
	game.display_settings.render_scale = .75 if high_output else 1.0
	# Visual captures advance four 120 Hz ticks per rendered frame. Keep their
	# wall clock at 30 FPS so GPU snow particles share the same elapsed time.
	game.display_settings.fps_limit = 120 if high_output else 30
	game.display_settings.apply_display(root,requested); game.display_settings.apply_viewport(root)
	root.content_scale_size = requested
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/planted_snow/baseline/mountain.json"))
	var selected: Array = []
	for name in ["face_5_band_0","face_1_band_2","face_4_band_2"]:
		for fixture in baseline.fixtures:
			if fixture.name==name: selected.append(fixture)
	if interactive:
		comparison_fixtures = selected
		var overlay = CanvasLayer.new(); overlay.layer = 120; root.add_child(overlay)
		label = Label.new(); overlay.add_child(label); label.position = Vector2(20,16)
		label.add_theme_font_size_override("font_size",22)
		label.add_theme_color_override("font_shadow_color",Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x",2); label.add_theme_constant_override("shadow_offset_y",2)
		var keys = ComparisonKeys.new(); keys.host = self; root.add_child(keys)
		game.automated = false
		change_comparison(KEY_F7)
		game.set_process(true); game.set_physics_process(true)
		print("UNRANKED_SNOW_COMPARISON_READY v",version)
		if "--interactive-check" in args:
			var compared: Array = []
			for key in [KEY_F6,KEY_F7,KEY_F6,KEY_F8]:
				change_comparison(key)
				compared.append(game.sim.MODEL_VERSION)
				if game.active or game.session.eligible or not game.physics_modified: failures.append("Comparison must pause and remain unranked")
				if game.sim.MODEL_VERSION!=(22 if reference else SkiSimulation.MODEL_VERSION): failures.append("Comparison selected wrong model")
				for i in 12: await process_frame
			FileAccess.open("res://artifacts/planted_snow/interactive.json",FileAccess.WRITE).store_string(JSON.stringify({"models":compared,"failures":failures,"unranked":not game.session.eligible}))
			game.effects.stop_audio(); quit(0 if failures.is_empty() else 1)
		return
	game.effects.muted = true; game.hud.hide(); game.hud.hide_menu(); game.speed_periphery.hide()
	observer = Camera3D.new(); game.add_child(observer)
	observer.fov = 60; observer.near = .05; observer.far = 15000
	var layer = CanvasLayer.new(); root.add_child(layer)
	label = Label.new(); layer.add_child(label); label.position = Vector2(20,18)
	label.add_theme_font_size_override("font_size",22); label.visible = not benchmark
	for i in 120: await process_frame
	# Texture.get_size() can describe the stretched canvas. Verify actual
	# readback pixels once outside the timing interval instead.
	await RenderingServer.frame_post_draw
	var actual = root.get_texture().get_image().get_size()
	if actual!=requested: failures.append("Output pixels mismatch")
	if game.graphics.level!=2 or game.world.environment.sdfgi_enabled: failures.append("High/SDFGI configuration mismatch")
	if benchmark: process_frame.connect(measure_frame)
	for fixture in selected: await ride(fixture)
	measuring = false
	if sources!=source_hashes(): failures.append("Sources changed during capture")
	var report = {"model":game.sim.MODEL_VERSION,"version":version,"reference":reference,"unranked":not game.session.eligible,"actual_pixels":[actual.x,actual.y],"quality":game.graphics.label(),"sdfgi":game.world.environment.sdfgi_enabled,"display":game.display_settings.report(root,actual),"device":RenderingServer.get_video_adapter_name(),"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"sources":sources,"cases":rows,"failures":failures,"capture_overhead_included":not benchmark}
	if benchmark:
		report.frame_ms = stats(frames); report.render_cpu_ms = stats(render_cpu); report.gpu_ms = stats(gpu); report.solver_us = stats(solver_us)
		report.animation_us = stats(animation_us); report.presentation_us = stats(pose_us)
		report.peak_video_bytes = peak_video; report.peak_engine_static_bytes = peak_static
	FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PLANTED_NATIVE ",output," failures=",failures)
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func comparison_field():
	return Definition.generate(849205174,version)

func change_comparison(key: int) -> void:
	game.active = false
	if key==KEY_F6:
		reference = not reference
		game.sim = load("res://artifacts/planted_snow/baseline/core/ski_simulation.gd").new() if reference else load("res://scripts/core/ski_simulation.gd").new()
	if key==KEY_F8: comparison_index = (comparison_index+1)%comparison_fixtures.size()
	game.start_run(false); game.active = false; game.summit_ready = false
	reset_fixture(comparison_fixtures[comparison_index])
	game.physics_modified = true; game.session.eligible = false
	game.hud.show_menu("paused")
	label.text = ("ORIGINAL CONTACT" if reference else "SOFT SNOW")+" · UNRANKED\nF6 compare contact · F7 restart comparison · F8 next slope"

func reset_fixture(fixture: Dictionary) -> void:
	var p: Array = fixture.origin
	var origin = Vector3(p[0],field.sample(p[0],p[2]).height,p[2])
	game.sim.reset(origin,fixture.heading); game.sim.prime_contacts(game.world.ski_surface)
	game.sim.velocity = game.sim.support_basis().z*fixture.kmh/3.6; game.sim.effective_tuck = 1.0
	game.previous_position = origin; game.skier.reset_animation(game.sim); game.camera.reset(); game.effects.reset()

func ride(fixture: Dictionary) -> void:
	reset_fixture(fixture)
	var intent = RiderInput.new(); intent.tuck = 1.0
	game.intent = intent; game._process(DT); place_observer()
	for i in 120: await process_frame
	var samples: Array = []
	var first_frame = frames.size(); var first_solver = solver_us.size(); var first_cpu = render_cpu.size(); var first_gpu = gpu.size()
	var advanced_ticks = 0
	measuring = benchmark; last_frame = 0
	for frame in (720 if benchmark else 180):
		var seconds = frame/float(120 if benchmark else 30)
		intent.steer = Probe.steering(fixture,seconds)
		for tick in (1 if benchmark else 4):
			game.previous_position = game.sim.position
			var started = Time.get_ticks_usec()
			game.sim.step(DT,intent,game.world.ski_surface)
			advanced_ticks += 1
			if benchmark: solver_us.append(Time.get_ticks_usec()-started)
			started = Time.get_ticks_usec()
			game.skier.step_animation(DT,game.sim,intent,field)
			if benchmark: animation_us.append(Time.get_ticks_usec()-started)
		game.intent = intent; game.session.elapsed += DT*(1 if benchmark else 4)
		var presented = Time.get_ticks_usec()
		game._process(DT*(1 if benchmark else 4)); game.speed_periphery.hide(); place_observer()
		if benchmark: pose_us.append(Time.get_ticks_usec()-presented)
		label.text = ("ORIGINAL CONTACT" if reference else "SOFT SNOW")+" / "+fixture.name
		if benchmark: await physics_frame
		else:
			await process_frame; await RenderingServer.frame_post_draw
			if frame%15==0: root.get_texture().get_image().save_jpg(output+"/%s_%03d.jpg"%[fixture.name,frame],.94)
		if frame%12==0: samples.append({"s":seconds,"kmh":game.sim.speed_kmh(),"grounded":game.sim.grounded,"load":game.sim.normal_load,"reach_m":game.sim.support_offset_m,"snow_depth_m":game.sim.skis[0].snow_depth,"penetration_m":game.sim.skis[0].penetration,"groove_depth_m":game.effects.responses[0].depth_m,"powder":game.effects.responses[0].powder,"track_count":game.effects.snow_tracks.written,"compression_m":game.sim.skis[0].compression_m if "compression_m" in game.sim.skis[0] else 0.0})
		if game.sim.crashed: failures.append(fixture.name+": "+game.sim.crash_reason); break
	measuring = false
	var row = {"fixture":fixture.name,"duration_s":advanced_ticks*DT,"airtime_s":game.sim.total_airtime,"crash":game.sim.crash_reason,"samples":samples,"snow_budget":game.effects.snow_budget()}
	if benchmark:
		row.frame_ms = stats(frames.slice(first_frame)); row.solver_us = stats(solver_us.slice(first_solver))
		row.render_cpu_ms = stats(render_cpu.slice(first_cpu)); row.gpu_ms = stats(gpu.slice(first_gpu))
	rows.append(row)

func place_observer() -> void:
	var center: Vector3 = game.sim.position+Vector3.UP*.8
	var p = center
	# Inspection-only camera: retain a clear sight line through dense woodland.
	# This does not change the production camera or any simulated position.
	for offset in [Vector3(2.5,1.5,-6.8),Vector3(-2.5,1.5,-6.8),Vector3(0,3,-3.5),Vector3(2,1,-2),Vector3(-2,1,-2),Vector3(0,1,-1.5)]:
		p = center+Basis(Vector3.UP,game.sim.heading)*offset
		p.y = maxf(p.y,field.sample(p.x,p.z).height+1.0)
		if field.sweep_obstacle_contact(center,p).is_empty(): break
	observer.position = p; observer.look_at(center); observer.make_current()

func source_hashes() -> Dictionary:
	var values = {}
	for path in ["scripts/world/mountain_definition.gd","scripts/world/heightfield_surface.gd","scripts/world/mountain_geology_v13.gd","scripts/world/generators/alpine_face_v13.gd","scripts/world/alpine_world.gd","scripts/world/alpine_scenery.gd","scripts/presentation/density_forest.gd","scripts/presentation/snow_tracks.gd"]:
		values[path] = FileAccess.get_sha256("res://"+path)
	for path in ["scripts/presentation/powder_surface.gd","assets/graphics/powder_surface.gdshaderinc","scripts/world/generators/alpine_massif_v14.gd","scripts/world/generators/alpine_face_v14.gd","scripts/world/generators/tree_snow_v14.gd","scripts/world/mountain_cache_v14.gd"]:
		values[path] = FileAccess.get_sha256("res://"+path)
	for path in ["scripts/core/ski_simulation.gd","scripts/core/ski_contact.gd","scripts/core/snow_contact_response.gd","scripts/core/ski_tuning.gd","scripts/core/rider_body.gd","config/ski_default.tres","scripts/main.gd","scripts/presentation/snow_response.gd","scripts/presentation/skier_visual.gd","scripts/presentation/skier_animation.gd","scripts/presentation/graphics_quality.gd","assets/graphics/models/skier_v7.glb","assets/graphics/powder_compute.gd","assets/graphics/ski_track.gdshader","assets/graphics/powder_surface.gdshader","tests/planted_snow_playtest.gd"]:
		values[path] = FileAccess.get_sha256("res://"+path)
	return values
