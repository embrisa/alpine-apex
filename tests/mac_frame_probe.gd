extends SceneTree
## Focused-window frame probe for macOS attribution. Launch through
## scripts/mac_frame_probe.sh (LaunchServices focus, full-mountain policy flags).
## Fixed full-tuck input on the Standard mountain from the launch point, 240
## warm-up frames, then `--probe-seconds` of measured frames. Writes
## artifacts/mac_probe/<label>.json with frame statistics, submissions, effective
## graphics values and frame_costs CPU scopes. Metal exposes no viewport GPU
## timer, so GPU attribution comes from comparing labelled configurations.
## Options after `--`: --probe-label=NAME --probe-seconds=N --probe-capture
## --probe-menu pauses into the menu after warm-up and measures that state.
## --probe-stall=MS busy-waits the main thread for MS every --probe-stall-every=S
## seconds (default 4) and records the frame times and solver ticks of the 16
## frames after each stall; --probe-steps=N sets Engine.max_physics_steps_per_frame.
## --probe-set=graphics_key=value (repeatable; PCGraphicsSettings keys or preset
## CONTROLS) plus any ordinary game arguments such as --graphics-quality=low,
## --upscaler=fsr2, --render-scale=0.5 or --cloud-shadows-off.
## Repeatable rendered captures: --probe-hold=KMH locks the rider to that speed
## and --probe-immortal removes impact damage and crashes, both through the
## existing test-case diagnostic policy; --probe-at-tick=N warms up by solver
## tick instead of frame count and captures exactly there, so an A/B pair
## compares the same ground whatever the frame rate. These three are for visual
## comparison, not timing: the diagnostic simulation and locked speed are not
## the ordinary solver workload. `--first-person` selects the close view here too.
var game
var frames = PackedFloat64Array(); var rcpu = PackedFloat64Array(); var draws = PackedFloat64Array(); var prims = PackedFloat64Array()
var overrides: Dictionary = {}
var last_usec = 0; var seconds = 25; var warm = 240; var warm_left = 0; var measuring = false; var end_usec = 0; var label = "probe"; var capture = false; var menu = false
var stall_ms = 0; var stall_every = 4.0; var next_stall_usec = 0; var steps = 0
var episodes: Array = []; var episode: Array = []; var last_ticks = 0
var hold_kmh = 0.0; var immortal = false; var at_tick = 0; var diagnostic = false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-seconds="): seconds = int(arg.get_slice("=",1))
		if arg.begins_with("--probe-label="): label = arg.get_slice("=",1).validate_filename()
		if arg=="--probe-capture": capture = true
		if arg=="--probe-menu": menu = true
		if arg.begins_with("--probe-stall="): stall_ms = int(arg.get_slice("=",1))
		if arg.begins_with("--probe-stall-every="): stall_every = float(arg.get_slice("=",1))
		if arg.begins_with("--probe-steps="): steps = int(arg.get_slice("=",1))
		if arg.begins_with("--probe-hold="): hold_kmh = float(arg.get_slice("=",1))
		if arg=="--probe-immortal": immortal = true
		if arg.begins_with("--probe-at-tick="): at_tick = int(arg.get_slice("=",1))
		if arg.begins_with("--probe-set="):
			var raw: String = arg.get_slice("=",2)
			overrides[arg.get_slice("=",1)] = (raw=="true") if raw in ["true","false"] else (int(raw) if raw.is_valid_int() else float(raw))
	game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.benchmark_no_captures = true
	game.frame_costs.enabled = true
	game.effects.frame_costs = game.frame_costs
	if game.world.scenery and game.world.scenery.density_forest: game.world.scenery.density_forest.frame_costs = game.frame_costs
	if game.world.minerals: game.world.minerals.frame_costs = game.frame_costs
	if game.world.grass: game.world.grass.frame_costs = game.frame_costs
	game.crash_collision.frame_costs = game.frame_costs
	game.skier.animation.full_motion.frame_costs = game.frame_costs
	game.display_settings.apply_display(root)
	for i in 6: await process_frame
	if not overrides.is_empty():
		for key in overrides: game.display_settings.set_graphics_value(key,overrides[key])
		game.apply_graphics_configuration()
		for i in 6: await process_frame
	game.display_settings.apply_viewport(root)
	if steps>0: Engine.max_physics_steps_per_frame = steps
	if hold_kmh>0.0 or immortal:
		# The test-case owner already owns locked speed and impact immunity.
		# start_recording() installs its diagnostic simulation and filtered
		# surface and calls start_run(); no .apexcase recorder is started, so
		# this drives the policy itself once per solver tick.
		var policy = game.test_cases.policy
		policy.values = {"hold_speed":hold_kmh>0.0,"speed_kmh":clampf(hold_kmh,1.0,300.0) if hold_kmh>0.0 else 120.0,
			"immortal":immortal,"trees":true,"rocks":true}
		game.test_cases.start_recording()
		game.test_cases.ui.toolbar.hide()
		game.hud.mode_label.visible = false # observe_frame rewrites its text every frame.
		diagnostic = true
		physics_frame.connect(diagnostic_tick)
	else:
		game.start_run(false)
	# start_run() restores the saved view, so honour the ordinary --first-person
	# game argument afterwards; main.gd only applies it on its benchmark path.
	game.camera.close_view = "--first-person" in OS.get_cmdline_user_args()
	game.session.eligible = false
	warm_left = warm
	process_frame.connect(measure)
func diagnostic_tick() -> void:
	# SceneTree.physics_frame precedes node physics, so the locked speed is in
	# place before the solver steps. Immunity needs no per-tick work.
	if diagnostic and game.test_cases.policy.values.hold_speed and not game.sim.crashed:
		game.test_cases.policy.before_tick(game.sim,game.world.ski_surface,game.sim.ticks)
func measure() -> void:
	var now = Time.get_ticks_usec()
	if at_tick>0:
		# Deterministic rendered capture. The 120 Hz solver reaches a given tick
		# at the same world position whatever the frame rate, so matched stills
		# compare the same ground. Frame samples here are incidental.
		if last_usec>0: frames.append((now-last_usec)/1000.0)
		last_usec = now
		if game.sim.ticks>=at_tick or game.sim.crashed: finish()
		return
	if warm_left>0:
		warm_left -= 1
		if warm_left==0:
			if menu:
				game.active = false
				game.hud.show_menu("paused")
			game.frame_costs.reset(); measuring = true; end_usec = now+seconds*1000000; last_usec = now
			next_stall_usec = now+int(stall_every*1000000.0); last_ticks = game.sim.ticks
		return
	if not measuring: return
	frames.append((now-last_usec)/1000.0); last_usec = now
	var ticks_now: int = game.sim.ticks
	if episode.size()<16 and not episodes.is_empty(): episode.append([snappedf(frames[-1],.01),ticks_now-last_ticks])
	last_ticks = ticks_now
	if stall_ms>0 and now>=next_stall_usec and end_usec-now>1500000:
		next_stall_usec = now+int(stall_every*1000000.0)
		episode = []; episodes.append(episode)
		OS.delay_msec(stall_ms) # One deliberate main-thread stall; the next frame catches up.
	var c = RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()); if c>0.0: rcpu.append(c)
	draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if now>=end_usec or game.sim.crashed or (not game.active and not menu): finish()
func finish() -> void:
	measuring = false
	process_frame.disconnect(measure)
	if diagnostic and physics_frame.is_connected(diagnostic_tick): physics_frame.disconnect(diagnostic_tick)
	DirAccess.make_dir_recursive_absolute("res://artifacts/mac_probe")
	if capture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/mac_probe/%s.png" % label)
	var Costs = preload("res://scripts/diagnostics/frame_costs.gd")
	var win = root.get_window()
	var graphics = game.graphics
	var effective = {}
	for key in ["shadow_distance_m","shadow_quality","volumetric_shafts","highlight_glow","snow_local_deformation","tree_far_m","tree_mid_m","tree_near_m","scrub_density","weather_quality","snow_crystal_density","snow_sparkle","snow_sheen","normal_strength","texture_tier","backdrop_tier","offmap_tree_distance_m","fog_strength","mesh_lod_bias"]:
		if key in graphics: effective[key] = graphics.get(key)
	var data = {"label":label,"overrides":overrides,"platform":OS.get_name(),"driver":RenderingServer.get_current_rendering_driver_name(),"device":RenderingServer.get_video_adapter_name(),
		"engine":Engine.get_version_info().string,"window_size":str(win.size),"window_mode":win.mode,"screen_size":str(DisplayServer.screen_get_size(win.current_screen)),
		"scaling_3d_mode":root.scaling_3d_mode,"scaling_3d_scale":root.scaling_3d_scale,"msaa_3d":root.msaa_3d,"quality":graphics.label(),"upscaler":game.display_settings.upscaler,
		"effective_upscaler":game.display_settings.effective_upscaler(),"render_scale":game.display_settings.render_scale,"effective":effective,
		"crashed":game.sim.crashed,"crash_reason":game.sim.crash_reason,"ticks":game.sim.ticks,"peak_kmh":game.sim.peak_speed*3.6,
		"frame_ms":Costs.stats(frames),"fps_mean":1000.0/Costs.stats(frames).mean if frames.size()>0 else 0.0,"render_cpu_ms":Costs.stats(rcpu),"draw_calls":Costs.stats(draws),"primitives":Costs.stats(prims),
		"lighting":{"sdfgi":game.world.environment.sdfgi_enabled,"ssao":game.world.environment.ssao_enabled,"ssil":game.world.environment.ssil_enabled,"glow":game.world.environment.glow_enabled,"volumetric_fog":game.world.environment.volumetric_fog_enabled},
		"cpu_scopes_us":game.frame_costs.report(),
		"cloud_receivers":{"world":game.world.cloud_lighting.materials.size(),"effects":game.effects.lighting.materials.size(),"weather":game.weather_effects.lighting.materials.size(),"skier":game.skier.lighting.materials.size(),"wind":game.world.assets.wind_receivers.size()},
		"diagnostic":{"hold_kmh":hold_kmh,"immortal":immortal,"at_tick":at_tick},
		"stall":{"ms":stall_ms,"max_physics_steps_per_frame":Engine.max_physics_steps_per_frame,"episodes_frame_ms_and_ticks":episodes}}
	var f = preload("res://tests/test_report.gd").open_write("res://artifacts/mac_probe/%s.json" % label); f.store_string(JSON.stringify(data,"\t")); f.close()
	print("MAC_FRAME_PROBE_DONE ",label)
	quit(0)
