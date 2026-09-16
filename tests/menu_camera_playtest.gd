extends SceneTree
## Real-world lifecycle, rendered acceptance and screenshot-free tour timings.
var game
var rendered = false
var checks = 0
var failures: Array[String] = []
var captures: Array = []
var timings: Dictionary = {}
var source_hashes: Dictionary = {}
var output = "res://artifacts/live_menu"

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",caption)
	if not ok: failures.append(caption)

func state() -> Array:
	return [game.sim.position,game.sim.velocity,game.sim.heading,game.session.elapsed,game.session.eligible,game.sim.impacts.reserve,game.session.recording,game.weather.daylight.hour,game.weather.phase_seconds]

func tick(seconds: float, hz: int = 60) -> void:
	for i in roundi(seconds*hz): game._process(1.0/hz)

func run() -> void:
	rendered = DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute(output)
	for path in ["scripts/main.gd","scripts/presentation/menu_camera.gd","scripts/ui/hud.gd","scripts/presentation/weather_effects.gd","scripts/racing/race_workshop.gd","config/ski_default.tres"]:
		source_hashes[path] = FileAccess.get_sha256("res://"+path)
	if "--live-menu-lab" in OS.get_cmdline_user_args(): set_meta("test_lab_fixture",true)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	current_scene = game
	while not game.initialized or game.loading.busy: await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.session.eligible = false
	game.effects.muted = true
	game.hud.feedback.muted = true
	game.hud.feedback.persist = false
	game.hud.feedback.reduced_motion = false
	game.weather.set_automatic(true)
	game.weather.set_time_cycle(true)
	game._process(0.0)
	check(root.get_camera_3d()==game.menu_camera,"Ready main menu owns the live camera")
	check(game.loading.artwork.texture==null and game.hud.root.find_child("TitlePhotography",true,false)==null,"Finished loading releases photos and ordinary menus never instantiate them")
	var before = state()
	var visual_clock: float = game.weather.visual_time
	tick(8.0)
	check(state()==before,"Main menu motion preserves physics, session, records and daylight/weather progression")
	check(game.weather.visual_time>visual_clock,"Cloud and weather presentation continue behind menus")
	var phase: float = game.menu_camera.shot_time
	game.hud.open_settings(); game._process(0.0)
	check(game.menu_camera.context=="title" and game.menu_camera.shot_time==phase,"Settings retains main menu camera context and shot phase")
	game.hud.close_weather()
	game.open_workbench(); game._process(0.0)
	check(game.menu_camera.context=="title" and game.menu_camera.shot_time==phase,"Workbench retains the originating title tour")
	game.close_workbench()
	game.workshop.open_library(); game._process(0.0)
	var survey_before: Transform3D = game.workshop.survey.transform
	tick(1.0)
	check(root.get_camera_3d()==game.menu_camera and game.workshop.survey.transform==survey_before,"Race browsing uses the live menu camera without moving the survey")
	game.workshop.begin_creation(); game._process(0.0)
	check(root.get_camera_3d()==game.workshop.survey and not game.hud.menu_fade.visible,"Endpoint placement exclusively owns the survey camera")
	game.workshop.back_pressed(); game._process(0.0)
	check(root.get_camera_3d()==game.menu_camera,"Returning to the race library restores the live menu camera")
	check(not game.workshop.cursor.visible and (game.workshop.zone_outline==null or not game.workshop.zone_outline.visible),"Race-library browsing hides the placement cursor and boundary outline")
	game.workshop.back_pressed()
	if game.current_mountain:
		game.mountain_library.open(); game._process(0.0)
		check(game.menu_camera.context=="title","Mountain browser inherits the title context")
		game.mountain_library.close()
	game.camera.close_view = true
	game.menu_camera.fade_time = 0.2; game.menu_camera.fade_alpha = 0.7
	game.hud.set_background_fade(0.7)
	game.start_run(false)
	check(root.get_camera_3d()==game.camera and not game.hud.menu_fade.visible and game.camera.close_view,"Drop In interrupts a fade and immediately restores the selected riding mode")
	game.session.eligible = false
	for i in 3:
		game.active = false
		game.hud.show_menu("paused")
		game._process(0.0)
		before = state()
		tick(2.0)
		check(state()==before and game.menu_camera.context=="paused" and game.skier.body_pivot.visible,"Pause %d keeps the first-person skier visible without advancing the run" % i)
		game.menu_camera.fade_time = 0.1; game.menu_camera.fade_alpha = 0.5
		game.hud.set_background_fade(0.5)
		game.resume()
		check(root.get_camera_3d()==game.camera and game.menu_camera.context.is_empty() and game.camera.close_view and not game.hud.menu_fade.visible,"Resume %d restores riding before another physics tick" % i)
	game.active = false
	game.hud.show_menu("paused"); game._process(0.0)
	game.hud.open_settings(); game._process(0.0)
	check(game.menu_camera.context=="paused","Settings opened from pause never starts a mountain tour")
	game.hud.close_weather()
	game.hud.feedback.reduced_motion = true
	game._process(0.0)
	var held: Transform3D = game.menu_camera.transform
	tick(5.0)
	check(game.menu_camera.transform==held and not game.hud.menu_fade.visible,"Reduced motion holds the real camera and disables fades")
	game.hud.feedback.reduced_motion = false
	game.loading.begin("Loading check","Preparing a menu frame")
	var loading_before: Transform3D = game.menu_camera.transform
	tick(1.0)
	check(game.menu_camera.transform==loading_before and game.loading.artwork.texture!=null,"Only an active loader owns photographs and holds menu updates")
	game.loading.finish()
	game._process(0.0)
	check(game.loading.artwork.texture==null and root.get_camera_3d()==game.menu_camera,"Loading completion returns to the live menu")
	if rendered: await review_views()
	if rendered and "--menu-benchmark" in OS.get_cmdline_user_args():
		game.hud.show_menu("title")
		game.menu_camera.leave()
		game._process(0.0)
		await measure("complete_tour",true,0.0)
		game.hud.show_menu("paused")
		await measure("pause_orbit",false,12.0)
	await review_crash()
	if rendered and "--menu-benchmark" in OS.get_cmdline_user_args(): await measure("resting_crash",false,12.0)
	var saved_view: bool = game.skier.ragdoll.saved_close_view
	game.menu_camera.fade_time = 0.2; game.menu_camera.fade_alpha = 0.7
	game.hud.set_background_fade(0.7)
	game.restart()
	check(not game.skier.ragdoll.running and root.get_camera_3d()==game.camera and game.camera.close_view==saved_view and not game.hud.menu_fade.visible,"Retry exits the crash and cancels fades while restoring the saved riding mode")
	var end_hashes: Dictionary = {}
	for path in source_hashes: end_hashes[path] = FileAccess.get_sha256("res://"+path)
	var report = {"checks":checks,"failures":failures,"captures":captures,"timings":timings,"rendered":rendered,"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"source_before":source_hashes,"source_after":end_hashes,"sources_unchanged":source_hashes==end_hashes,"scenic_views":game.menu_camera.shots.size()}
	preload("res://tests/test_report.gd").write(output+"/review_%s.json" % ("native" if rendered else "headless"),JSON.stringify(report,"\t"))
	print("LIVE_MENU_RESULTS ",checks," checks, ",failures.size()," failures")
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	game._process(0.0)
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	image.save_png(output+"/"+label+".png")
	var camera: Camera3D = root.get_camera_3d()
	captures.append({"label":label,"pixels":[image.get_width(),image.get_height()],"camera":str(camera.global_position),"clearance_m":camera.global_position.y-game.field.sample(camera.global_position.x,camera.global_position.z).height,"shot":game.menu_camera.shot_index})

func review_views() -> void:
	game.hud.show_menu("title")
	game.menu_camera.leave()
	game._process(0.0)
	for size_value in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(3840,2160)]:
		root.mode = Window.MODE_WINDOWED
		root.borderless = true
		root.size = size_value
		_select_tab(game.hud.menu_tabs,"Ride")
		await capture("title_%dx%d" % [size_value.x,size_value.y])
		game.hud.open_settings()
		_select_tab(game.hud.settings_tabs,"Display")
		await capture("settings_%dx%d" % [size_value.x,size_value.y])
		game.hud.close_weather()
	game.display_settings.apply_display(root,Vector2i(3840,2160))
	for index in game.menu_camera.shots.size():
		game.menu_camera.shot_index = index
		game.menu_camera.shot_time = 0.0
		await capture("scenic_%02d" % index)
		var old: Vector3 = game.menu_camera.position
		tick(8.0)
		check(game.menu_camera.position.distance_to(old)>0.5,"Scenic shot %d moves in the rendered world" % index)
		await capture("scenic_%02d_drift" % index)
	game.hud.show_menu("paused")
	await capture("pause_clear")
	game.weather.set_preset("snowfall")
	tick(1.0)
	check(game.weather_effects.previous_camera==game.menu_camera.global_position and not game.weather_effects.previous_close,"Snowfall follows the actual menu camera with third-person presentation")
	await capture("pause_snowfall")
	game.hud.feedback.reduced_motion = true
	await capture("pause_reduced_motion")
	game.hud.feedback.reduced_motion = false
	game.weather.set_preset("clear")
	if not game.menu_camera.shots.is_empty():
		var saved: Vector3 = game.sim.position
		var point: Vector3 = game.menu_camera.shots[0].site-Vector3.UP*2.0
		game.sim.reset(point,game.sim.heading)
		game.sim.prime_contacts(game.field); game.skier.reset_animation(game.sim)
		game.menu_camera.leave()
		await capture("pause_on_slope")
		game.sim.reset(saved,game.field.spawn_heading())
		game.sim.prime_contacts(game.field); game.skier.reset_animation(game.sim)
	game.hud.show_menu("title")
	game.menu_camera.leave()
	game._process(0.0)
	tick(24.18)
	await capture("fade_old_shot")
	tick(0.18)
	await capture("fade_scenic_shot")
	tick(0.4)
	await capture("fade_complete")

func review_crash() -> void:
	game.restart()
	game.session.eligible = false
	game.sim.crashed = true
	game.sim.crash_reason = "Menu camera crash fixture"
	game.skier.ragdoll.start(game.sim)
	game.last_ragdoll_position = game.skier.ragdoll.focus()
	game.skier.ragdoll.saved_close_view = game.camera.close_view
	game.camera.close_view = false
	game.active = false
	game.hud.show_menu("crashed",game.sim.crash_reason)
	game._process(0.0)
	check(game.menu_camera.context=="crashed" and root.get_camera_3d()==game.menu_camera,"Crash menu uses the live ragdoll camera")
	if rendered: await capture("crash_start")
	var until = Time.get_ticks_msec()+16000
	while not game.skier.ragdoll.frozen and Time.get_ticks_msec()<until:
		await process_frame
		game._process(1.0/120.0)
	check(game.skier.ragdoll.frozen and game.skier.ragdoll.elapsed>=15.0,"Existing 15-second ragdoll lifecycle still freezes the crash")
	var angle: float = game.menu_camera.orbit_angle
	tick(1.0)
	check(game.menu_camera.orbit_angle>angle,"Resting crash camera begins a slow orbit")
	if rendered: await capture("crash_resting")

func measure(label: String, tour: bool, seconds: float) -> void:
	print("LIVE_MENU_MEASURE_BEGIN ",label)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for i in 120:
		game._process(1.0/120.0)
		await process_frame
	game.menu_camera.leave(); game._process(0.0)
	var frames: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var video_peak = 0
	var static_peak = 0
	var start = Time.get_ticks_usec()
	var previous = start
	var initial_cut: int = game.menu_camera.cut_serial
	var target_cuts: int = maxi(2,game.menu_camera.shots.size()*2)
	var reported_cut = initial_cut
	while (game.menu_camera.cut_serial-initial_cut<target_cuts if tour else (Time.get_ticks_usec()-start)/1000000.0<seconds):
		await process_frame
		var now = Time.get_ticks_usec()
		var dt = (now-previous)/1000000.0
		previous = now
		game._process(dt)
		frames.append(dt*1000.0)
		var rid = root.get_viewport_rid()
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		video_peak = maxi(video_peak,int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
		static_peak = maxi(static_peak,int(OS.get_static_memory_usage()))
		if game.menu_camera.cut_serial!=reported_cut:
			reported_cut = game.menu_camera.cut_serial
			print("LIVE_MENU_TOUR_CUT ",reported_cut-initial_cut,"/",target_cuts)
		if (now-start)>420000000:
			check(false,"Complete tour finishes within seven minutes")
			break
	await RenderingServer.frame_post_draw
	var actual = root.get_texture().get_image().get_size()
	timings[label] = {"seconds":(Time.get_ticks_usec()-start)/1000000.0,"frames":frames.size(),"frame_ms":game._timing_summary(frames),"cpu_ms":game._timing_summary(cpu),"gpu_ms":game._timing_summary(gpu),"video_peak_bytes":video_peak,"static_peak_bytes":static_peak,"display":game.display_settings.report(root,actual),"actual_pixels":[actual.x,actual.y],"cuts":game.menu_camera.cut_serial-initial_cut,"capture_overhead_included":false}
	print("LIVE_MENU_MEASURE_END ",label," ",JSON.stringify(timings[label]))

func _select_tab(tabs: TabContainer, caption: String) -> void:
	for index in tabs.get_tab_count():
		if tabs.get_tab_title(index)==caption:
			tabs.current_tab = index
			return
	assert(false,"Missing tab: "+caption)
