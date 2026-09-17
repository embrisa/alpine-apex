extends "res://tests/session_navigation_playtest.gd"
## One stationary near/far comparison for finish and personal navigation beams.
## Capture first, inspect, then pass its report to --views for capture-free timing.
const OldFinish = preload("res://tests/fixtures/finish_beam_800m/race_beams.gd")
const Finish = preload("res://scripts/presentation/race_beams.gd")
const PIXELS = Vector2i(3840,2160)
var visual_only = false
var saved_views = ""
var views: Array = []
var finish_beam
var actual_pixels = Vector2i.ZERO
var sample_seconds = 15.0

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg=="--capture": visual_only = true
		if arg.begins_with("--output="): OUTPUT = arg.trim_prefix("--output=")
		if arg.begins_with("--views="): saved_views = arg.trim_prefix("--views=")
	if not OUTPUT.begins_with("res://"): OUTPUT = "res://"+OUTPUT
	var resolved = ProjectSettings.globalize_path(OUTPUT).simplify_path().replace("\\","/")
	var artifacts = ProjectSettings.globalize_path("res://artifacts/").replace("\\","/")
	if not resolved.begins_with(artifacts) or DirAccess.dir_exists_absolute(OUTPUT):
		printerr("Choose a fresh artifact output"); quit(2); return
	if not visual_only and saved_views.is_empty():
		printerr("Timing requires --views from a reviewed capture run"); quit(2); return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for path in ["tests/beacon_cost_playtest.gd","tests/session_navigation_playtest.gd",
			"scripts/presentation/race_beams.gd","scripts/presentation/session_navigation_beams.gd",
			"assets/graphics/race_beam.gdshader","assets/graphics/race_beam_base.gdshader",
			"tests/fixtures/finish_beam_800m/race_beams.gd","tests/fixtures/finish_beam_800m/race_beam.gdshader"]:
		sources[path] = metadata(path)
	var field = Fixture.load_standard()
	if field==null: quit(2); return
	set_meta("mountain_to_load",{"definition":Mountain.from_field(field),"field":field})
	root.size = PIXELS
	game = load("res://main.tscn").instantiate()
	game.automated = true
	game.benchmark_no_captures = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.workshop.set_process(false)
	game.active = false
	game.session.record_directory = OUTPUT+"/records"
	game.session.benchmark_path = OUTPUT+"/benchmark.json"
	game.session.mark_practice("Isolated stationary beacon cost")
	game.workshop.store.directory = OUTPUT+"/library"
	game.effects.haptic_hardware_enabled = false
	game.effects.muted = true; game.voice.set_muted(true)
	game.preferences_enabled = false; game.hud.feedback.persist = false
	game.workshop._clear_markers()
	game.hud.root.hide(); game.speed_periphery.hide(); game.vectors.hide()
	game.camera_settings.reset()
	game.set_graphics_quality(2)
	game.display_settings.frame_generation = false
	game.display_settings.fps_limit = 60 if visual_only else 0
	game.display_settings.vsync = 0
	game.display_settings.display_mode = "windowed"
	game.display_settings.apply_display(root,PIXELS)
	game.display_settings.apply_viewport(root)
	set_weather("clear","day")
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	await process_frame; await RenderingServer.frame_post_draw
	actual_pixels = root.get_texture().get_image().get_size() # Outside every timing interval.
	audit.check(actual_pixels==PIXELS,"Actual 4K output")
	audit.check(field.cache_hit and not game.preferences_enabled and not game.session.eligible,"Warm current Standard fixture and isolated practice stores")
	if visual_only:
		var summit: Vector3 = game.sim.position
		var summit_heading: float = game.sim.heading
		# A lower supported anchor allows a distant observer on the open upper slope.
		# Keep the existing landmark location; never remove scenery to clear the view.
		var lower = Checks.Navigation.anchor(game.field,Vector3(1337.539063,0,-673.972656))
		audit.check(lower.error.is_empty(),"Lower landmark supports a cost fixture")
		if not lower.error.is_empty(): finish(); return
		for distance in [30.0,2000.0]:
			game.sim.reset(summit if distance<100.0 else lower.position,summit_heading if distance<100.0 else 0.0)
			markers = Checks.supported_points(game,32)
			audit.check(markers.size()==32,"32 supported anchors")
			if markers.size()!=32: finish(); return
			var found = find_view(markers[2],distance,false)
			audit.check(not found.is_empty(),"Exposed ordinary chase at %.0f m" % distance)
			if not found.is_empty():
				var anchors: Array = []
				for point in markers: anchors.append(vector(point))
				views.append({"label":"near" if distance<100.0 else "far","rider":vector(found.position),"distance_m":distance,"markers":anchors})
	else:
		var saved = JSON.parse_string(FileAccess.get_file_as_string(saved_views))
		if not saved is Dictionary or not saved.get("failures",["missing"]).is_empty() or not saved.get("visual_only",false):
			audit.check(false,"Successful capture receipt required"); finish(); return
		views = saved.views
		audit.check(views.size()==2,"Reuse reviewed near/far cameras")
	if not audit.failures.is_empty(): finish(); return
	for plan in views:
		markers.clear()
		for item in plan.markers: markers.append(vec(item))
		audit.check(markers.size()==32,"Retain all 32 reviewed anchors")
		for point in markers: audit.check(Checks.Navigation.anchor(game.field,point).error.is_empty(),"Retained supported anchor")
		present_rider(vec(plan.rider),markers[2])
		audit.check(view_issues(shaft_probe(game.camera,markers[2]),false).is_empty(),"Exposed current shaft "+plan.label)
		for selection in ["finish800","finish2000","navigation0","navigation5","navigation32"]:
			configure(selection)
			await settle(1.0 if visual_only else 2.0)
			if visual_only:
				await RenderingServer.frame_post_draw
				var picture = root.get_texture().get_image()
				var label = plan.label+"_"+selection
				audit.check(picture.save_png(OUTPUT+"/"+label+".png")==OK,"Saved "+label)
				captures.append({"label":label,"camera":camera_snapshot(game.camera),"pixels":[picture.get_width(),picture.get_height()]})
			else:
				var sample = await timed_sample()
				sample.merge({"view":plan.label,"selection":selection,"camera":camera_snapshot(game.camera)},true)
				samples.append(sample)
				print("BEACON_SAMPLE ",JSON.stringify(sample))
	finish()

func view_issues(probe: Dictionary, require_ridge: bool) -> Array[String]:
	var issues = super.view_issues(probe,require_ridge)
	# Conservative fixture choice only. It avoids camera-near opaque crowns that
	# a heightfield-only ray misses; actual visibility still needs pixel inspection.
	if not game.field.tree_data.nearby(game.camera.global_position,45.0).is_empty():
		issues.append("cost_camera_near_trees")
	return issues

func configure(selection: String) -> void:
	if is_instance_valid(finish_beam): finish_beam.free()
	game.workshop.navigation_state.clear_points()
	if selection.begins_with("finish"):
		finish_beam = OldFinish.new() if selection=="finish800" else Finish.new()
		game.add_child(finish_beam)
		finish_beam.build(markers[2],true,game.field)
	else:
		populate(selection.trim_prefix("navigation").to_int())
	game.display_settings.reset_history()

func draw_frame(dt: float) -> void:
	game.world.assets.update_foliage_sight(game.presentation_camera,game.skier.global_position,dt,true,
		game.camera_settings.shared.forest_visibility,game.camera_settings.shared.forest_visibility_strength)
	await super.draw_frame(dt)

func settle(seconds: float) -> void:
	var started = Time.get_ticks_usec()
	while Time.get_ticks_usec()-started<int(seconds*1000000): await draw_frame(1.0/120.0)

func timed_sample() -> Dictionary:
	var frames: Array[float] = []
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var unfocused = 0
	var rid = root.get_viewport_rid()
	var started = Time.get_ticks_usec()
	var previous = started
	while Time.get_ticks_usec()-started<int(sample_seconds*1000000):
		await draw_frame(1.0/120.0)
		var now = Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0); previous = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		if not game.application_focused: unfocused += 1
	audit.check(unfocused==0 and gpu.min()>0,"Focused timing with valid GPU queries")
	return {"frames":frames.size(),"seconds":float(previous-started)/1000000.0,"unfocused_frames":unfocused,
		"frame_ms":distribution(frames),"gpu_ms":distribution(gpu),"render_cpu_ms":distribution(cpu),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"captures_during_timing":0}

static func vec(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])
static func metadata(path: String) -> Dictionary:
	var file = FileAccess.open("res://"+path,FileAccess.READ)
	return {"bytes":file.get_length(),"modified":FileAccess.get_modified_time("res://"+path)}

func finish() -> void:
	for path in sources: audit.check(metadata(path)==sources[path],"Source metadata retained "+path)
	var anchors: Array = []
	for point in markers: anchors.append(vector(point))
	preload("res://tests/test_report.gd").write(OUTPUT+"/report.json",JSON.stringify({
		"checks":audit.checks,"failures":audit.failures,"visual_only":visual_only,"views":views,"markers":anchors,
		"captures":captures,"samples":samples,"source_metadata":sources,"engine":Engine.get_version_info(),
		"runtime":OS.get_executable_path(),"device":RenderingServer.get_video_adapter_name(),
		"display":game.display_settings.report(root,actual_pixels),"world_version":game.field.GENERATOR_VERSION,
		"seed":game.field.seed_value,"scope":"Stationary Standard beacon cost; not descent FPS or human acceptance"},"\t"))
	game.effects.stop_audio(); game.free()
	quit(0 if audit.failures.is_empty() else 1)
