extends SceneTree
## Native evidence runner. Parent MUST hold the serial validation guard.
## No personal preferences, ranked records, captures or readbacks in samples.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")
const Sources = preload("res://scripts/world/generation_sources.gd")
const Trace = preload("res://tests/performance_trace.gd")
const Survey = preload("res://tests/alpine_v13_route_survey.gd")
const Obstacles = preload("res://scripts/world/obstacle_access.gd")
const Costs = preload("res://scripts/diagnostics/frame_costs.gd")
const Output = preload("res://scripts/presentation/display_settings.gd")
const PIXELS = Vector2i(3840,2160)
const SEED = 849205174
const SETTLE_SECONDS = 5.0
const SAMPLE_SECONDS = 10.0
const ROUTE_SECONDS = 30.0
const ROUTE_MAX_SECONDS = 60.0
const POST_LOAD_SECONDS = 900.0
var game
var field
var output = "res://artifacts/interface_overhaul/performance"
var failures: Array[String] = []
var rows: Array = []
var captures: Array = []
var manifest: Dictionary = {}
var source_hashes: Dictionary = {}
var deadline_usec = 0
var original_window: Dictionary = {}
var original_cap = 0
var sites: Dictionary = {}
var take_captures = true
var include_display = false
var include_matched = false
var phase = "all"
var case_name = "startup"
var route_site = "summit"
var route_checkpoints: Array = []
var segment_serial = 0
var route_reference: Dictionary = {}
var fixed_reference: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures.append(case_name+": "+label)
		printerr("INTERFACE_PERFORMANCE_FAIL ",failures[-1])
	return ok

func alive() -> bool:
	if not failures.is_empty(): return false
	if deadline_usec>0 and Time.get_ticks_usec()>deadline_usec:
		check(false,"900-second post-load ceiling exceeded")
		return false
	return true

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--interface-performance-output="):
			output = arg.trim_prefix("--interface-performance-output=")
			if not output.is_absolute_path(): output = "res://"+output
		if arg=="--interface-no-captures": take_captures = false
		if arg=="--interface-display-checks": include_display = true
		if arg=="--interface-matched-ui": include_matched = true
		if arg.begins_with("--interface-phase="): phase = arg.get_slice("=",1)
	DirAccess.make_dir_recursive_absolute(output)
	if not check(phase in ["all","fixed","moving","ui","matched","powder","timeline","display"],"known evidence phase"): quit(2); return
	if not check(DisplayServer.get_name()!="headless","native window required"):
		write_report(); quit(2); return
	if not check(Engine.has_singleton("AlpineFidelityFX") and RenderingServer.get_current_rendering_driver_name()=="d3d12","validated custom DX12 engine required"):
		write_report(); quit(2); return
	# Reject arguments which could select another fixture or activate main's own runner.
	for arg in OS.get_cmdline_user_args():
		if arg in ["--test-lab","--autoplay","--capture-menu","--ground-assist","--air-assist"] or arg.begins_with("--generated-seed="):
			check(false,"incompatible argument "+arg)
	if not alive(): write_report(); quit(2); return
	original_window = Output.capture_window(root)
	original_cap = Engine.max_fps
	source_hashes = collect_sources()
	print("INTERFACE_PERFORMANCE_LOAD seed=849205174 version=15 settings=Standard")
	var load_start = Time.get_ticks_usec()
	# The same validated Standard cache path as normal gameplay, never a lab.
	field = Definition.generate(849205174,15)
	if not check(field!=null,"v15 Standard generation/load succeeded"):
		await finish(); return
	var physical_ms = (Time.get_ticks_usec()-load_start)/1000.0
	deadline_usec = Time.get_ticks_usec()+int(POST_LOAD_SECONDS*1000000)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Default Mountain"),"field":field})
	game = load("res://main.tscn").instantiate()
	game.automated = true
	game.benchmark_input = input_at_tick
	game.benchmark_no_captures = true
	root.add_child(game)
	current_scene = game
	var scene_deadline = Time.get_ticks_msec()+600000
	while not game.initialized or (game.loading and game.loading.busy):
		if not alive(): await finish(); return
		if Time.get_ticks_msec()>scene_deadline:
			check(false,"scene initialization exceeded 600 seconds"); await finish(); return
		await process_frame
	game.preferences_enabled = false
	game.benchmark_no_captures = true
	game.active = false
	game.set_physics_process(false)
	game.session.eligible = false
	game.hud.feedback.persist = false
	game.hud.feedback.enabled = true
	game.effects.haptic_hardware_enabled = false
	game.frame_costs.enabled = true
	game.effects.frame_costs = game.frame_costs
	game.world.scenery.density_forest.frame_costs = game.frame_costs
	game.world.minerals.frame_costs = game.frame_costs
	game.display_settings.display_mode = "fullscreen"
	game.display_settings.fps_limit = 120
	game.display_settings.vsync = 0
	game.display_settings.frame_generation = false
	game.set_graphics_preset(7)
	game.display_settings.apply_display(root,PIXELS)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	manifest = {"schema":1,"phase":phase,"seed":SEED,"generator":15,"generation_settings":game.current_mountain.generation_settings,
		"recipe_key":Cache.recipe_key(SEED),"cache_key":Cache.cache_key(SEED),"physical_cache_path":Cache.path_for(SEED),
		"physical_cache_hit":field.cache_hit,"physical_stages":field.generation_stages,"physical_load_ms":physical_ms,
		"scene_ready_ms":(Time.get_ticks_usec()-load_start)/1000.0-physical_ms,"scene_build_timings":game.world.build_timings,
		"scenery_cache_hit":game.world.preparation.cache_hit,"identity":Trace.identity(field),"engine":Engine.get_version_info(),
		"executable":OS.get_executable_path(),"engine_sha256":Sources.engine_identity(),"backend":RenderingServer.get_current_rendering_driver_name(),
		"device":RenderingServer.get_video_adapter_name(),"source_hashes":source_hashes,"post_load_limit_seconds":POST_LOAD_SECONDS,
		"deadline_begins":"after physical cache load, including scene construction","start_unix_seconds":Time.get_unix_time_from_system(),
		"internal_pixel_evidence":"Actual viewport scale times output readback; native SDK status does not expose internal texture dimensions.",
		"memory_evidence":"Engine static/renderer allocation counters; OS working set/private and GPU process allocations belong to guard.json.",
		"route_input":"120 Hz; tuck=.35 brake=.08 steer=.10*sin(tick/240); reset identical start on crash/base or after 3600 ticks"}
	var baseline_path = "res://artifacts/interface_overhaul/baseline/interface_native.json"
	if FileAccess.file_exists(baseline_path):
		manifest.baseline_sha256 = FileAccess.get_sha256(baseline_path)
		var baseline = JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
		if baseline is Dictionary: manifest.historical_interface_performance = baseline.get("interface_performance",{})
	check(field.cache_hit,"warm physical cache required; cold result cannot be used as this comparison")
	check(game.current_mountain.generation_settings==Definition.Settings.preset(),"Standard recipe")
	await wait_seconds(.25)
	await verify_pixels()
	if alive():
		sites.summit = field.launch_point(field.faces[2].heading)
		var forest = forest_site(2)
		sites.forest = Vector3(forest.x,field.sample(forest.x,forest.y).height,forest.y)
		manifest.sites = sites.duplicate()
		if phase in ["all","fixed"]: await fixed_views()
	if alive() and phase in ["all","moving"]: await moving_routes()
	if alive() and phase in ["all","ui"]: await interface_cases()
	if alive() and (phase=="matched" or phase=="all" and include_matched): await load("res://tests/interface_matched_ui.gd").run(self)
	if alive() and phase in ["all","powder"]:
		var powder = load("res://tests/interface_powder_native_checks.gd").new()
		await powder.run(self)
	if alive() and take_captures and phase in ["all","timeline"]: await capture_timeline()
	if alive() and (phase=="display" or phase=="all" and include_display):
		await load("res://tests/interface_display_native_checks.gd").run(self)
	if alive(): check(source_hashes==collect_sources(),"source files changed during evidence collection")
	await finish()

func fixed_views() -> void:
	for preset in range(1,11):
		for view in ["summit","forest"]:
			if not alive(): return
			case_name = "fixed_%02d_%s" % [preset,view]
			print("INTERFACE_PERFORMANCE_BEGIN ",case_name," settle=5 measure=10")
			var apply_start = Time.get_ticks_usec()
			game.set_graphics_preset(preset)
			var apply_ms = (Time.get_ticks_usec()-apply_start)/1000.0
			prepare_site(view,false)
			# Hold simulation/camera position, keep production weather/effects alive.
			game.active = true
			await wait_seconds(SETTLE_SECONDS)
			var camera_before: Transform3D = game.camera.global_transform
			var row = await sample(SAMPLE_SECONDS,0,false)
			row.application_ms = apply_ms
			row.settle_seconds = SETTLE_SECONDS
			row.view = view
			row.camera_start = str(camera_before)
			row.camera_end = str(game.camera.global_transform)
			check(camera_before.origin.distance_to(game.camera.global_position)<.02,"fixed camera position stable within 2 cm")
			check(camera_before.basis.is_equal_approx(game.camera.global_transform.basis),"fixed camera orientation stable")
			if fixed_reference.has(view):
				var reference: Transform3D = fixed_reference[view]
				check(reference.origin.distance_to(camera_before.origin)<.02 and reference.basis.is_equal_approx(camera_before.basis),"same fixed camera across presets")
			else: fixed_reference[view] = camera_before
			game.active = false
			await complete_case(row)

func prepare_site(view: String, moving: bool) -> void:
	game.hud.close_weather()
	game.start_run(false)
	game.summit_ready = false
	game.session.eligible = false
	game.sim.reset(sites[view],field.faces[2].heading)
	game.sim.prime_contacts(field)
	game.previous_position = game.sim.position
	game.skier.reset_animation(game.sim)
	game.camera.close_view = false
	game.camera.reset()
	game.menu_camera.leave()
	game.camera.effects_enabled = true
	game.weather.set_automatic(false)
	game.weather.set_time_cycle(false)
	game.weather.set_preset("snowfall" if view=="forest" else "clear")
	game.weather.set_time_of_day("day")
	game.weather.visual_time = 0.0
	game.weather_effects.reset()
	game.hud.feedback.reduced_motion = false
	game.hud.hide_menu()
	game.active = moving
	game.set_physics_process(moving)
	game.display_settings.reset_history()

func moving_routes() -> void:
	# Counterbalance preset order; each view has a matched independent route.
	for pass_id in 2:
		route_site = "summit" if pass_id==0 else "forest"
		for preset in ([1,7,10] if pass_id==0 else [10,7,1]):
			if not alive(): return
			case_name = "moving_%02d_%s" % [preset,route_site]
			print("INTERFACE_PERFORMANCE_BEGIN ",case_name," settle=5 moving_ticks>=3600 wall>=30")
			game.set_graphics_preset(preset)
			prepare_site(route_site,false)
			await wait_seconds(SETTLE_SECONDS)
			route_checkpoints.clear()
			segment_serial = 0
			game.active = true
			game.set_physics_process(true)
			var row = await sample(ROUTE_SECONDS,0,true)
			row.route = route_site
			row.settle_seconds = SETTLE_SECONDS
			row.checkpoints = route_checkpoints.duplicate(true)
			check_route_checkpoints(row.checkpoints)
			game.active = false
			game.set_physics_process(false)
			await complete_case(row)

func input_at_tick(tick: int) -> RiderInput:
	# Called by main immediately before the production solver; render rate never
	# chooses input. Compare pre-step state at the same ticks across presets.
	if tick%600==0:
		route_checkpoints.append({"segment":segment_serial,"tick":tick,"position":[game.sim.position.x,game.sim.position.y,game.sim.position.z],"velocity":[game.sim.velocity.x,game.sim.velocity.y,game.sim.velocity.z],"heading":game.sim.heading})
	var intent = RiderInput.new()
	intent.tuck = .35
	intent.brake = .08
	intent.steer = .10*sin(float(tick)/240.0)
	return intent

func check_route_checkpoints(checkpoints: Array) -> void:
	for point in checkpoints:
		var key = "%s:%d:%d" % [route_site,point.segment,point.tick]
		if route_reference.has(key): check(route_reference[key]==point,"same-tick route state "+key)
		else: route_reference[key] = point.duplicate(true)

func interface_cases() -> void:
	game.set_graphics_preset(7)
	for reduced in [false,true]:
		for workload in ["menu","settings","settings_scroll","settings_transition","riding_hud"]:
			if not alive(): return
			case_name = "ui_%s_motion_%s" % [workload,"reduced" if reduced else "full"]
			print("INTERFACE_PERFORMANCE_BEGIN ",case_name," warmup_frames=120 sample_frames=240")
			prepare_site("summit",false)
			# The captured baseline muted riding/UI audio, disabled camera motion,
			# and set reduced motion. Record those same controls for the reduced row.
			game.effects.muted = true
			game.hud.feedback.muted = true
			game.hud.feedback.reduced_motion = reduced
			game.camera.effects_enabled = not reduced
			game.hud.show_menu("paused")
			if workload.begins_with("settings"):
				game.hud.open_settings()
				game.hud.settings_tabs.current_tab = 0 if workload=="settings" else 1
			# Start each page from a defined expansion state; make the scroll test
			# actually overflow at 4K using the existing group-toggle signals.
			for button in game.hud.weather_panel.find_children("*","Button",true,false):
				if button.has_meta("group_body"): button.button_pressed = workload=="settings_scroll"
			if workload=="riding_hud":
				game.hud.hide_menu()
				game.active = true
				game.set_physics_process(true)
				route_site = "summit"
			var scrolls: Array = game.hud.settings_tabs.get_current_tab_control().find_children("*","ScrollContainer",true,false)
			if game.hud.settings_tabs.get_current_tab_control() is ScrollContainer: scrolls.push_front(game.hud.settings_tabs.get_current_tab_control())
			for i in 120:
				if not alive(): return
				await process_frame
				if workload=="riding_hud" and (game.sim.crashed or not game.active):
					prepare_site("summit",true)
					game.hud.feedback.reduced_motion = reduced
					game.camera.effects_enabled = not reduced
			var action: Callable = func(index: int):
				if workload=="settings_transition" and index%20==0:
					game.hud.settings_tabs.current_tab = posmod(index/20,game.hud.settings_tabs.get_tab_count())
				if workload=="settings_scroll":
					for scroll in scrolls:
						var bar: VScrollBar = scroll.get_v_scroll_bar()
						scroll.scroll_vertical = roundi(maxf(0,bar.max_value-bar.page)*(.5-.5*cos(index*TAU/120.0)))
			var row = await sample(0,240,workload=="riding_hud",action)
			game.active = false
			game.set_physics_process(false)
			row.workload = workload
			row.warmup_frames = 120
			row.sample_frames = 240
			row.baseline_comparable_protocol = workload=="settings" and reduced
			row.baseline_identity_matched = false
			row.baseline_note = "Same 4K/High/Auto75/cap120/FGoff and 120/240 timing; historical baseline lacks exact recipe/camera/source identity. No causal before-after claim."
			row.scroll_ranges = scrolls.map(func(scroll): return scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page)
			if workload=="settings_scroll": check(row.scroll_ranges.any(func(value): return value>0),"settings workload has real scrollable content")
			await complete_case(row)
	game.effects.muted = false
	game.hud.feedback.muted = false

func sample(seconds: float, count: int, moving: bool, action: Callable = Callable()) -> Dictionary:
	var frame_ms = PackedFloat64Array()
	var cpu_ms = PackedFloat64Array()
	var gpu_ms = PackedFloat64Array()
	var app_ms = PackedFloat64Array()
	var physics_ms = PackedFloat64Array()
	var draws = PackedFloat64Array()
	var video = PackedFloat64Array()
	var memory = PackedFloat64Array()
	var restarts: Array = []
	var moved_ticks = 0
	var distance_m = 0.0
	var previous_tick: int = game.sim.ticks
	var previous_position: Vector3 = game.sim.position
	var reduced_motion: bool = game.hud.feedback.reduced_motion
	var camera_effects: bool = game.camera.effects_enabled
	var last_progress = 0
	game.frame_costs.reset()
	# Bound the production runner's incidental telemetry, too.
	game.frame_samples.clear(); game.gpu_samples.clear(); game.render_cpu_samples.clear(); game.draw_samples.clear()
	var fsr_begin: Dictionary = game.display_settings.fsr_status()
	var started = Time.get_ticks_usec()
	var previous = started
	var local_deadline = started+int((ROUTE_MAX_SECONDS if moving else maxf(30.0,seconds+20.0))*1000000)
	while alive():
		if action.is_valid(): action.call(frame_ms.size())
		await process_frame
		var now = Time.get_ticks_usec()
		frame_ms.append((now-previous)/1000.0)
		previous = now
		var rid = root.get_viewport_rid()
		cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		app_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		video.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		memory.append(Performance.get_monitor(Performance.MEMORY_STATIC))
		if moving:
			moved_ticks += maxi(0,game.sim.ticks-previous_tick)
			distance_m += previous_position.distance_to(game.sim.position)
			if game.sim.crashed or game.session.finished or game.sim.ticks>=3600 or not game.active:
				restarts.append({"segment":segment_serial,"tick":game.sim.ticks,"crash":game.sim.crash_reason,"position":str(game.sim.position)})
				segment_serial += 1
				prepare_site(route_site,true)
				game.hud.feedback.reduced_motion = reduced_motion
				game.camera.effects_enabled = camera_effects
			previous_tick = game.sim.ticks
			previous_position = game.sim.position
		var elapsed = (now-started)/1000000.0
		if int(elapsed)/10>last_progress:
			last_progress = int(elapsed)/10
			print("INTERFACE_PERFORMANCE_PROGRESS ",case_name," seconds=",int(elapsed)," frames=",frame_ms.size()," moving_ticks=",moved_ticks)
		if (count>0 and frame_ms.size()>=count) or (count==0 and elapsed>=seconds and (not moving or moved_ticks>=3600)): break
		if now>local_deadline:
			check(false,"case wall-clock ceiling exceeded"); break
	var fsr_end: Dictionary = game.display_settings.fsr_status()
	var rendered_presents = int(fsr_end.get("rendered_present_calls",0))-int(fsr_begin.get("rendered_present_calls",0))
	check(frame_ms.size()>0,"rendered samples collected")
	check(positive_finite(frame_ms) and positive_finite(cpu_ms) and positive_finite(gpu_ms),"positive finite frame/CPU/GPU timing")
	check(not fsr_end.get("frame_generation_active",true) and int(fsr_end.get("generated_frames",0))==int(fsr_begin.get("generated_frames",0)),"steady samples contain no generated frames")
	check(int(fsr_end.get("upscale_dispatches",0))>int(fsr_begin.get("upscale_dispatches",0)) and str(fsr_end.get("error","")).is_empty(),"native upscaler dispatch advances without reported error")
	check(rendered_presents>0 and absi(rendered_presents-frame_ms.size())<=maxi(4,ceili(frame_ms.size()*.02)),"rendered native presents agree with process-frame samples")
	if moving:
		check(moved_ticks>0 and distance_m>0,"real solver-driven travel")
		if count==0: check(moved_ticks>=3600 and distance_m>10,"at least 30 simulation seconds and 10 m travel")
		check(not game.session.eligible and not game.timed,"moving case stays unranked free skiing")
	var result = {"case":case_name,"preset":game.display_settings.quality,"profile":game.graphics.snapshot(),"asset_tier":game.graphics.level,
		"wall_seconds":(Time.get_ticks_usec()-started)/1000000.0,"frame_ms":frame_stats(frame_ms),"render_cpu_ms":Costs.stats(cpu_ms),
		"gpu_ms":Costs.stats(gpu_ms),"application_process_ms":Costs.stats(app_ms),"physics_process_ms":Costs.stats(physics_ms),
		"cpu_scopes_us":game.frame_costs.report(),"draw_calls":Costs.stats(draws),"video_bytes":Costs.stats(video),"engine_static_bytes":Costs.stats(memory),
		"video_first_bytes":video[0] if not video.is_empty() else 0,"video_last_bytes":video[-1] if not video.is_empty() else 0,
		"moving_ticks":moved_ticks,"distance_m":distance_m,"restarts":restarts,"fsr_begin":fsr_begin,"fsr_end":fsr_end,
		"native_rendered_presents":rendered_presents,"native_rendered_fps":rendered_presents/maxf(.001,(previous-started)/1000000.0),
		"feedback":game.hud.feedback.snapshot(),"camera_effects_enabled":game.camera.effects_enabled,"weather":game.weather.selected_preset,
		"weather_visual_time":game.weather.visual_time,"audio_muted":game.effects.muted,"capture_overhead_included":false,"unranked":not game.session.eligible,
		"application_focused":game.application_focused,"sampling_end_unix_seconds":Time.get_unix_time_from_system(),
		"snow":game.effects.snow_budget(),"forest":game.world.scenery.density_forest.report(),"camera_settings":game.camera_settings.snapshot()}
	write_json(case_name+"_samples.json",{"frame_ms":frame_ms,"render_cpu_ms":cpu_ms,"gpu_ms":gpu_ms,"application_process_ms":app_ms,"physics_process_ms":physics_ms,"draw_calls":draws,"video_bytes":video,"engine_static_bytes":memory})
	return result

func complete_case(row: Dictionary) -> void:
	row.display = game.display_settings.report(root,await verify_pixels())
	row.live = live_consumers()
	rows.append(row)
	write_report()
	print("INTERFACE_PERFORMANCE_RESULT ",case_name," ",JSON.stringify(row.frame_ms))
	if take_captures and alive(): await capture(case_name)

func live_consumers() -> Dictionary:
	var particles: Array = []
	for index in game.effects.sprays.size():
		var node = game.effects.sprays[index]
		particles.append({"amount":node.amount,"visible":node.visible,"emitting":node.emitting})
		check(node.amount==maxi(1,game.graphics.snow_particles[index/2]),"live ski particle allocation matches profile")
	check(game.effects.snow_tracks.capacity==game.graphics.snow_track_capacity,"live track allocation matches profile")
	check(is_equal_approx(game.world.sun.directional_shadow_max_distance,game.graphics.shadow_distance_m),"live directional shadow range matches profile")
	check(game.weather_effects.quality==game.graphics.weather_quality and is_equal_approx(game.weather_effects.budget_scale,game.graphics.weather_budget),"live weather allocation matches profile")
	var materials: Array = []
	for material in game.world.assets.surface_materials:
		if material is ShaderMaterial:
			var textures: Dictionary = {}
			for uniform in material.shader.get_shader_uniform_list():
				var value = material.get_shader_parameter(uniform.name)
				if value is Resource and not value.resource_path.is_empty(): textures[uniform.name] = value.resource_path
			materials.append({"shader":material.shader.resource_path,"textures":textures})
	return {"particles":particles,"materials":materials,"sdfgi":game.world.environment.sdfgi_enabled,
		"shadow_distance_m":game.world.sun.directional_shadow_max_distance,"weather_quality":game.weather_effects.quality,"weather_budget_scale":game.weather_effects.budget_scale,
		"ssao":game.world.environment.ssao_enabled,"ssil":game.world.environment.ssil_enabled,
		"ui_viewport_is_output":game.hud.root.get_viewport()==root,"ui_rect":str(game.hud.root.get_global_rect()),
		"ui_scale":str(game.hud.root.scale),"window_content_scale_mode":root.content_scale_mode,"window_content_scale_size":root.content_scale_size,
		"camera_transform":str(game.camera.global_transform)}

func verify_pixels() -> Vector2i:
	await RenderingServer.frame_post_draw
	var pixels: Vector2i = root.get_texture().get_image().get_size()
	check(pixels==PIXELS and root.size==PIXELS,"actual 3840x2160 output")
	check(game.hud.root.get_viewport()==root,"UI uses output viewport")
	check(root.content_scale_mode==Window.CONTENT_SCALE_MODE_CANVAS_ITEMS,"UI drawn at output resolution, never viewport-stretched")
	check(is_equal_approx(root.scaling_3d_scale,.75) and root.scaling_3d_mode==Viewport.SCALING_3D_MODE_FSR2,"Auto temporal path at actual .75 viewport scale")
	check(Engine.max_fps==120,"120 rendered FPS cap")
	return pixels

func capture_timeline() -> void:
	case_name = "descent_timeline"
	game.set_graphics_preset(7)
	for reduced in [false,true]:
		prepare_site("summit",true)
		game.hud.feedback.reduced_motion = reduced
		var start = Time.get_ticks_msec()
		for i in 5:
			if not alive(): return
			await wait_seconds(1.0)
			await capture("timeline_%s_%02d" % ["reduced" if reduced else "full",i])
			captures[-1].timeline_ms = Time.get_ticks_msec()-start
			if game.sim.crashed:
				prepare_site("summit",true)
				game.hud.feedback.reduced_motion = reduced
	game.active = false
	game.set_physics_process(false)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	check(img.save_png(output+"/"+label+".png")==OK,"capture saved "+label)
	captures.append({"file":label+".png","ticks":game.sim.ticks,"position":str(game.sim.position),"crash":game.sim.crash_reason,
		"feedback":game.hud.feedback.snapshot(),"camera_effects_enabled":game.camera.effects_enabled,"unranked":not game.session.eligible,"outside_measurement":true})

func wait_seconds(seconds: float) -> void:
	var end = Time.get_ticks_usec()+int(seconds*1000000)
	while alive() and Time.get_ticks_usec()<end: await process_frame

func safe_site(target: Vector2) -> Vector2:
	for ring in range(0,9):
		for i in 12:
			var p = target+Vector2.from_angle(i*TAU/12)*ring*12.0
			if field.rock_fraction_at(p.x,p.y)<.25 and field.contact_normal(p.x,p.y).y>.7 and Survey.clear_at(field,p,8): return p
	return target

func forest_site(index: int) -> Vector2:
	var face = field.faces[index]
	var chosen: Vector2 = face.to_world(Vector2(450,2200))
	var best = -1
	for passage in face.forest_passages:
		var q: Vector2 = passage.start.lerp(passage.finish,.5)+(passage.finish-passage.start).orthogonal().normalized()*passage.bend
		var p = safe_site(face.to_world(q))
		var trunks = 0
		for id in field.nearby_obstacle_indices(Vector3(p.x,0,p.y),70):
			var tree: Vector3 = Obstacles.position(field,id)
			if Vector2(tree.x,tree.z).distance_squared_to(p)<4900: trunks += 1
		if trunks>best and field.rock_fraction_at(p.x,p.y)<.35 and field.contact_normal(p.x,p.y).y>.72:
			best = trunks
			chosen = p
	return safe_site(chosen)

static func positive_finite(values) -> bool:
	if values.is_empty(): return false
	for value in values:
		if not is_finite(value) or value<=0: return false
	return true

static func frame_stats(values) -> Dictionary:
	var result = Costs.stats(values)
	if not positive_finite(values): return result
	var fps = PackedFloat64Array()
	for ms in values: fps.append(1000.0/ms)
	result.rendered_fps = Costs.stats(fps)
	result.average_fps = 1000.0/result.mean
	result.fps_at_p95_frame_ms = 1000.0/result.p95
	result.fps_at_p99_frame_ms = 1000.0/result.p99
	return result

func collect_sources() -> Dictionary:
	var result: Dictionary = {}
	for folder in ["res://scripts","res://assets/graphics","res://config","res://native/fidelityfx/godot_module"]: hash_folder(folder,result)
	for path in ["res://main.tscn","res://project.godot","res://tests/interface_performance_suite.gd","res://tests/interface_powder_native_checks.gd","res://tests/interface_display_native_checks.gd","res://tests/interface_matched_ui.gd"]:
		result[path] = FileAccess.get_sha256(path)
	return result

func hash_folder(folder: String, result: Dictionary) -> void:
	for name in DirAccess.get_files_at(folder):
		if name.get_extension() in ["gd","gdshader","gdshaderinc","tres","cpp","h"]:
			var path = folder.path_join(name)
			result[path] = FileAccess.get_sha256(path)
	for directory in DirAccess.get_directories_at(folder): hash_folder(folder.path_join(directory),result)

func write_json(name: String, data: Dictionary) -> void:
	var file = preload("res://tests/test_report.gd").open_write(output.path_join(name))
	if file: file.store_string(JSON.stringify(data,"\t"))
	else: check(false,"cannot write "+name)

func write_report() -> void:
	write_json("results.json",{"manifest":manifest,"rows":rows,"captures":captures,"failures":failures,
		"completed":case_name=="complete","current_case":case_name,"native_execution_required":true,
		"human_controller_acceptance":false,"full_descent_acceptance":false})

func finish() -> void:
	if is_instance_valid(game):
		game.active = false
		game.set_physics_process(false)
		game.display_settings.frame_generation = false
		game.display_settings.apply_viewport(root)
		if not game.display_settings.display.pending.is_empty(): game.revert_display()
		if game.effects: game.effects.stop_audio()
		game.queue_free()
		await process_frame
	if not original_window.is_empty(): Output._apply_window_state(root,original_window)
	Engine.max_fps = original_cap
	if failures.is_empty(): case_name = "complete"
	write_report()
	print("INTERFACE_PERFORMANCE_DONE rows=",rows.size()," failures=",failures.size()," output=",output)
	quit(0 if failures.is_empty() else 1)
