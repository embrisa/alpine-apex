extends "res://tests/massif_playtest.gd"
## Frozen current-production material comparison. Paused poses, no timing verdict.
var snow_modes = preload("res://tests/scenery_snow_modes.gd").new()
var snow_views: Array = []
var frozen_path = "res://artifacts/scenery_snow/baseline"
var baseline_only = false
var quick_review = false
var review_trace: Dictionary = {}

func run() -> void:
	# This material review only restores the current warm fixture. It does not
	# inherit the legacy massif producer's cold generation or source hash scans.
	if DisplayServer.get_name()=="headless": quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input-trace="):
			review_trace = JSON.parse_string(FileAccess.get_file_as_string(arg.get_slice("=",1)))
			var error = preload("res://tests/performance_trace.gd").preflight_error(review_trace,Definition.CURRENT_VERSION,false)
			if not error.is_empty(): printerr(error); quit(2); return
	field = preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: quit(2); return
	if not review_trace.is_empty() and not preload("res://tests/performance_trace.gd").matches(field,review_trace.identity):
		printerr("Review route does not match the current physical fixture"); quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--benchmark-resolution="):
			var dimensions = arg.get_slice("=",1).split("x")
			requested_pixels = Vector2i(int(dimensions[0]),int(dimensions[1]))
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Scenery material review"),"field":field})
	game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy):
		Engine.max_fps = 30
		await process_frame
	game.set_physics_process(false); game.effects.muted = true
	game.start_run(false); game.session.eligible = false
	game.display_settings.apply_display(root,requested_pixels)
	Engine.max_fps = 30
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	actual_pixels = root.get_texture().get_image().get_size()
	assert(actual_pixels==requested_pixels)
	await inspect_massif()
	snow_modes.restore()
	game.queue_free(); await process_frame; quit()

func inspect_massif() -> void:
	OUTPUT = "res://artifacts/scenery_snow/review"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): OUTPUT = "res://"+arg.get_slice("=",1)
		if arg.begins_with("--snow-baseline="): frozen_path = "res://"+arg.get_slice("=",1)
	baseline_only = "--baseline-only" in OS.get_cmdline_user_args()
	quick_review = "--quick-review" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	snow_modes.setup(game,frozen_path)
	game.camera_settings.reset()
	game.active=false; game.summit_ready=false; game.set_process(false)
	game.hud.hide_menu(); game.hud.root.hide()
	game.weather.set_time_cycle(false); game.weather.set_automatic(false)
	var observer = Camera3D.new(); game.add_child(observer)
	observer.far=32000; observer.fov=75; observer.make_current()
	var conditions = [["clear","day"]] if quick_review else [["clear","day"],["clear","dusk"],["cloudy","day"],["snowfall","day"],["clear","night"]]
	if "--route-only" in OS.get_cmdline_user_args():
		assert(not review_trace.is_empty(),"Route-only review needs a compatible input trace")
		conditions = []
	for condition in conditions:
		game.weather.set_preset(condition[0]); game.weather.set_time_of_day(condition[1])
		for face in ([0,3] if quick_review else range(6)):
			var heading: float = field.faces[face].heading
			observer.make_current(); observer.position=field.spawn_point()+Vector3.UP*65
			observer.look_at(observer.position+Vector3(sin(heading)*10000,-1900,cos(heading)*10000))
			await snow_pair("summit_%s_%s_%d" % [condition[0],condition[1],face])
		for face in [0,3]:
			game.camera.make_current(); place_on_face(face,2750,false)
			await snow_pair("ride_%s_%s_%d" % [condition[0],condition[1],face])
		for bearing in ([Vector2.RIGHT] if quick_review else [Vector2.RIGHT,Vector2.DOWN,Vector2.ONE.normalized()]):
			var p=bearing*2835.0
			observer.make_current(); observer.position=Vector3(p.x,field.sample(p.x,p.y).height+1.8,p.y)
			observer.look_at(observer.position+Vector3(bearing.x*1000,-80,bearing.y*1000))
			await snow_pair("apron_%s_%s_%s" % [condition[0],condition[1],str(bearing)])
	# Optional actual benchmark framing: no riding or timing is inferred here.
	if not review_trace.is_empty():
		var recorded = review_trace
		game.camera_settings.restore(recorded.presentation.camera)
		game.camera.effects_enabled = recorded.presentation.camera_effects_enabled
		game.camera.settings = game.camera_settings
		var origin = Vector2(recorded.scenario_origin[0],recorded.scenario_origin[1])
		game.sim.reset(Vector3(origin.x,field.height_at(origin.x,origin.y),origin.y),recorded.heading)
		game.sim.prime_contacts(field); game.previous_position = game.sim.position
		game.skier.reset_animation(game.sim); game.camera.close_view = false; game.camera.reset()
		game.camera.make_current()
		await snow_pair("route_start")
	if not quick_review and "--route-only" not in OS.get_cmdline_user_args():
		game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
		observer.make_current(); observer.position=field.spawn_point()+Vector3.UP*65
		observer.look_at(observer.position+Vector3(0,-1900,10000))
		for tier in [0,1,2]:
			var profile = preload("res://scripts/presentation/graphics_quality.gd").numbered(7,{"backdrop_tier":tier})
			await game.world.wilderness.apply_quality(profile)
			await snow_pair("baked_tier_%d" % tier)
	if "--clips" in OS.get_cmdline_user_args():
		motion=true
		for condition in conditions:
			game.weather.set_preset(condition[0]); game.weather.set_time_of_day(condition[1])
			for mode in modes():
				select_snow(mode); observer.make_current()
				for frame in 24:
					var heading: float = field.faces[0].heading+lerpf(-.15,.15,float(frame)/23)
					observer.position=field.spawn_point()+Vector3.UP*65
					observer.look_at(observer.position+Vector3(sin(heading)*10000,-1900,cos(heading)*10000))
					game.world.update_weather(game.weather.state,0.0,false)
					await capture("pan_%s_%s_%s_%03d" % [condition[0],condition[1],mode,frame],2)
		game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
		for mode in modes():
			select_snow(mode); game.camera.make_current()
			for frame in 32:
				place_on_face(0,2650+frame*4,false); game._process(0.0)
				await capture("ride_motion_%s_%03d" % [mode,frame],2)
		motion=false
	select_snow("cheap")
	var report = {"views":snow_views,"frozen":snow_modes.manifest,"world_version":Definition.CURRENT_VERSION,
		"pixels":[actual_pixels.x,actual_pixels.y],"display":game.display_settings.report(root,actual_pixels),
		"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,
		"unranked":not game.session.eligible,"capture_overhead":true,"performance_acceptance":false,
		"motion":"Chronological camera/paused riding poses, not simulated descent or controller acceptance."}
	preload("res://tests/test_report.gd").write(OUTPUT+"/scenery_snow.json",JSON.stringify(report,"\t"))
	observer.queue_free()

func modes() -> Array:
	return ["baseline"] if baseline_only else ["baseline","cheap","enhanced"]

func select_snow(mode: String) -> void:
	snow_modes.select(mode)
	game.display_settings.reset_history()

func snow_pair(label: String) -> void:
	var selected = root.get_camera_3d()
	game._process(0.0); selected.make_current()
	game.world.update_weather(game.weather.state,0.0,false)
	var pose = selected.global_transform
	for mode in modes():
		select_snow(mode)
		await capture(label+"_"+mode,12)
		assert(selected.global_transform==pose and root.get_camera_3d()==selected,"Matched camera drift")
	snow_views.append({"label":label,"camera":str(pose),"weather":game.weather.snapshot(),"modes":modes()})
	print("SCENERY_SNOW_VIEW ",label)
