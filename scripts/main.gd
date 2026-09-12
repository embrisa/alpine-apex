extends Node3D
const Terrain = preload("res://scripts/world/test_slope.gd")
const World = preload("res://scripts/world/alpine_world.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Router = preload("res://scripts/core/input_router.gd")
const Session = preload("res://scripts/core/run_session.gd")
const CrashRecovery = preload("res://scripts/core/crash_recovery.gd")
var crash_recovery = CrashRecovery.new()
var recovery_placement: Dictionary = {}
const CrashGhostPose = preload("res://scripts/presentation/ghost_pose.gd")
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const ChaseCamera = preload("res://scripts/presentation/chase_camera.gd")
const CameraSettings = preload("res://scripts/presentation/camera_settings.gd")
var camera_settings = CameraSettings.new()
const Effects = preload("res://scripts/presentation/speed_effects.gd")
const Vectors = preload("res://scripts/presentation/debug_vectors.gd")
const HUD = preload("res://scripts/ui/hud.gd")
const Weather = preload("res://scripts/presentation/weather_controller.gd")
const WeatherEffects = preload("res://scripts/presentation/weather_effects.gd")
const Graphics = preload("res://scripts/presentation/graphics_quality.gd")
const PCGraphics = preload("res://scripts/presentation/pc_graphics_settings.gd")
var display_settings = PCGraphics.new()
var preferences_enabled: bool = false
var initialized: bool = false
var staged_loading: bool = false
var loading
var transitioning: bool = false
const Race = preload("res://scripts/racing/race_definition.gd")
const Workshop = preload("res://scripts/racing/race_workshop.gd")
const Ghost = preload("res://scripts/presentation/ghost_field.gd")
const GhostPose = preload("res://scripts/presentation/ghost_pose.gd")
const MountainDefinition = preload("res://scripts/world/mountain_definition.gd")
const GenerationJob = preload("res://scripts/world/generation_job.gd")
const GenerationEstimates = preload("res://scripts/world/generation_estimates.gd")
const GenerationSettings = preload("res://scripts/world/generation_settings.gd")
const Obstacles = preload("res://scripts/world/obstacle_access.gd")
var generation_job
var startup_race_code: String = ""
const MountainLibrary = preload("res://scripts/ui/mountain_library.gd")
const MountainZone = preload("res://scripts/world/mountain_zone.gd")
var mountain_zone = MountainZone.new()
var return_overlay
var returning_to_summit: bool = false
var summit_drop_armed: bool = true
var return_paused: bool = false
var return_message: String = ""
var summit_return_voice: String = ""
var last_ragdoll_position = Vector3.ZERO
var current_mountain = null
var mountain_library
var workshop
var ghost
var graphics = Graphics.preset(2)
const terrain_renderer = "legacy"
var mountain_seed: int = -1
var benchmark_no_captures: bool = false
# An explicit test input provider still executes the complete production tick.
var benchmark_input: Callable
var frame_costs = preload("res://scripts/diagnostics/frame_costs.gd").new()
var benchmark_resolution = Vector2i(1440,900)
var benchmark_actual_pixels = Vector2i.ZERO
var draw_samples: Array[float] = []
var peak_video_memory_bytes: int = 0
var weather
var weather_effects
var storm_effects
var weather_preferences = preload("res://scripts/presentation/weather_preferences.gd").new()
var free_weather_snapshot: Dictionary = {}
var weather_checkpoint = 0.0
var field
var world
var sim: SkiSimulation
var input_router
var session
var skier
var crash_collision
var camera
var camera_preview
var menu_camera
var presentation_camera: Camera3D
var effects
var voice
var audio_environment = preload("res://scripts/presentation/voice_environment.gd").new()
var vectors
var hud
var navigation
var controller_keyboard
var rider_axes_armed = false
var intent = RiderInput.new()
var impact_warning = preload("res://scripts/presentation/impact_warning.gd").new()
var active: bool = false:
	set(value):
		if active != value:
			# A menu, pause, finish or focus change cancels pending release input.
			rider_axes_armed = false
			air_controls_armed = false
			air_tilt_controls_armed = false
			if input_router != null: input_router.cancel_air_input()
			intent.air_pitch = 0.0; intent.air_yaw = 0.0; intent.air_tilt = 0.0; intent.grab = false
			if sim != null: sim.air_control.cancel_input()
			jump_armed = false
			jump_prepared = false
			intent.jump = false
			intent.jump_held = false
			if sim != null: sim.clear_input_buffer()
			if skier != null: skier.animation.hold()
		active = value
		if not value:
			_reset_screen_effects()
			_clear_storm_effects()
			_checkpoint_weather()
		if value and initialized: _restore_riding_camera()
		if not value and effects != null: effects.wind.silence()
		if not value and effects != null and (sim==null or not sim.crashed): effects.reset_haptics()
		if not value and effects != null and (sim==null or not sim.crashed): effects.sfx.silence()
		if voice != null: voice.set_gameplay_active(value)
		_sync_camera_controls()
var timed: bool = true
var physics_modified: bool = false
var summit_ready: bool = false
var previous_position: Vector3
var cpu_tick_ms: float = 0.0
var frame_ms: float = 0.0
var frame_samples: Array[float] = []
var gpu_samples: Array[float] = []
var render_cpu_samples: Array[float] = []
var automated: bool = false
var automated_ticks: int = 0
var screenshot_ticks: Array = [1,1200,2400,4200,6000]
var render_frames: int = 0
var last_frame_usec: int = 0
var air_controls_armed = false
var air_tilt_controls_armed = false
var jump_armed: bool = false
var jump_prepared: bool = false
var workbench_return: String = "title"
var speed_periphery: ColorRect
var effect_time: float = 0.0
var quitting: bool = false
var camera_controls_active: bool = false
var camera_stick_armed: bool = false
var discard_camera_mouse_motion: bool = false
var application_focused: bool = true

func _ready() -> void:
	get_tree().auto_accept_quit = false
	Input.joy_connection_changed.connect(_controller_connection_changed)
	input_router = Router.new()
	navigation = preload("res://scripts/ui/menu_navigation.gd").new()
	add_child(navigation) # Detect devices before the first loading tip is drawn.
	var values = preload("res://config/ski_default.tres").duplicate(true)
	sim = Simulation.new(values)
	sim.tuning.ground_assist_enabled = "--ground-assist" in OS.get_cmdline_user_args()
	sim.tuning.landing_assist_enabled = "--air-assist" in OS.get_cmdline_user_args()
	if sim.tuning.ground_assist_enabled or sim.tuning.landing_assist_enabled: physics_modified = true
	# The library and normal startup share one generator. Laboratory fixtures
	# must select their surface explicitly.
	field = null
	preferences_enabled = not automated and "--autoplay" not in OS.get_cmdline_user_args() and "--script" not in OS.get_cmdline_args() and "-s" not in OS.get_cmdline_args() and DisplayServer.get_name()!="headless"
	staged_loading = preferences_enabled or "--ui-staged-loading" in OS.get_cmdline_user_args()
	loading = preload("res://scripts/ui/loading_overlay.gd").new()
	add_child(loading)
	generation_job = GenerationJob.new()
	loading.attach_job(generation_job)
	var reload_feedback: Dictionary = get_tree().get_meta("world_reload_settings",{}).get("interface",{})
	if not reload_feedback.is_empty(): loading.apply_preferences(reload_feedback)
	if staged_loading:
		loading.begin("Preparing your descent", "Opening the mountain…")
		await loading.draw_frame()
	if preferences_enabled: display_settings.load_preferences()
	if preferences_enabled: camera_settings.load_preferences()
	display_settings.apply_arguments(OS.get_cmdline_user_args())
	graphics = display_settings.profile()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--graphics-quality="):
			var index = ["low","balanced","high"].find(arg.get_slice("=",1))
			if index >= 0: graphics = Graphics.preset(index)
		elif arg.begins_with("--mountain-seed=") and arg.get_slice("=",1).is_valid_int():
			mountain_seed = int(arg.get_slice("=",1))
		elif arg.begins_with("--benchmark-resolution="):
			var size_text = arg.get_slice("=",1).split("x")
			if size_text.size()==2 and size_text[0].is_valid_int() and size_text[1].is_valid_int():
				benchmark_resolution = Vector2i(clampi(int(size_text[0]),640,7680),clampi(int(size_text[1]),480,4320))
	benchmark_no_captures = "--benchmark-no-captures" in OS.get_cmdline_user_args()
	frame_costs.enabled = "--profile-frame-costs" in OS.get_cmdline_user_args()
	# A scene reload reconstructs both terrain and presentation from the race's
	# pinned mountain reference. Never silently run a race on the current seed.
	_initialize_weather()
	var pending_race = null
	var pending_mountain = null
	var load_warning = ""
	var reload_settings: Dictionary = get_tree().get_meta("world_reload_settings",{})
	get_tree().remove_meta("world_reload_settings")
	if not reload_settings.is_empty():
		display_settings.restore(reload_settings.get("display",display_settings.snapshot()))
		graphics = display_settings.profile()
		camera_settings.restore(reload_settings.get("camera",{}))
		sim.tuning = reload_settings.tuning
		physics_modified = reload_settings.modified
	if get_tree().has_meta("mountain_retry_recipe"):
		current_mountain = get_tree().get_meta("mountain_retry_recipe")
		get_tree().remove_meta("mountain_retry_recipe")
		GenerationEstimates.configure(generation_job,current_mountain.seed_value,current_mountain.generation_settings)
		var retry_result = await loading.run_data(current_mountain.reconstruct.bind(generation_job),generation_job)
		if generation_job.is_cancelled(): _cancel_startup(); return
		if retry_result.has("field"):
			field = retry_result.field; mountain_seed = field.seed_value
			pending_mountain = {"definition":current_mountain,"field":field}
		else:
			load_warning = retry_result.error; current_mountain = null
	if get_tree().has_meta("mountain_to_load"):
		pending_mountain = get_tree().get_meta("mountain_to_load")
		get_tree().remove_meta("mountain_to_load")
		current_mountain = pending_mountain.definition
		field = pending_mountain.field
		mountain_seed = field.seed_value
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--generated-seed=") and pending_mountain==null and not get_tree().has_meta("standard_to_load") and not get_tree().has_meta("race_to_load"):
			var seed_result = MountainDefinition.parse_seed(arg.get_slice("=",1))
			if seed_result.has("seed"):
				if staged_loading:
					loading.stage("Generating the physical mountain…")
					field = await _generate_mountain(seed_result.seed,seed_result.version)
				else: field = MountainDefinition.generate(seed_result.seed,seed_result.version,{},generation_job)
				if field==null: _cancel_startup(); return
				current_mountain = MountainDefinition.from_field(field)
				mountain_seed = field.seed_value
			else: load_warning = seed_result.error
	if get_tree().has_meta("race_to_load"):
		var requested_code: String = get_tree().get_meta("race_to_load")
		var parsed = Race.decode(requested_code)
		get_tree().remove_meta("race_to_load")
		if parsed.has("race"):
			startup_race_code = requested_code
			var rebuilt = get_tree().get_meta("prepared_race_surface",{})
			get_tree().remove_meta("prepared_race_surface")
			if rebuilt.is_empty():
				GenerationEstimates.configure(generation_job,parsed.race.mountain.seed,parsed.race.mountain.get("settings",{}))
				if staged_loading:
					loading.stage(GenerationEstimates.label(GenerationEstimates.estimate(parsed.race.mountain.seed,parsed.race.mountain.get("settings",{}))))
					await loading.draw_frame()
					rebuilt = await loading.run_data(Race.reconstruct_surface.bind(parsed.race.mountain,generation_job),generation_job)
				else: rebuilt = Race.reconstruct_surface(parsed.race.mountain)
			if rebuilt.has("field"):
				pending_race = parsed.race
				field = rebuilt.field
				mountain_seed = pending_race.mountain.scenery_seed
				current_mountain = MountainDefinition.from_field(field) if field.GENERATOR_ID=="alpine-drainage" else null
			else: load_warning = rebuilt.error
		else: load_warning = parsed.error
	if field==null:
		if get_tree().has_meta("standard_to_load") or get_tree().get_meta("test_lab_fixture",false) or "--test-lab" in OS.get_cmdline_user_args():
			field = Terrain.new()
		else:
			if staged_loading:
				loading.stage("Shaping six alpine faces, forests and powder…")
				field = await _generate_mountain(MountainDefinition.DEFAULT_SEED)
			else: field = MountainDefinition.generate(MountainDefinition.DEFAULT_SEED,MountainDefinition.CURRENT_VERSION,{},generation_job)
			if field==null: _cancel_startup(); return
			current_mountain = MountainDefinition.from_field(field,"Default Mountain")
			mountain_seed = field.seed_value
	if generation_job.is_cancelled(): _cancel_startup(); return
	if "job" in field:
		field.job = generation_job
		loading.attach_job(generation_job)
	graphics.terrain_gi = display_settings.terrain_gi
	display_settings.apply_viewport(get_viewport())
	if preferences_enabled: display_settings.apply_display(get_window())
	world = World.new()
	world.quality = graphics
	world.mountain_seed = mountain_seed
	add_child(world)
	if staged_loading:
		await world.build(field,_loading_checkpoint,loading.run_data)
		await _loading_checkpoint("Preparing the rider, camera and interface…",-1.0)
	else: world.build(field)
	if generation_job.is_cancelled(): _cancel_startup(); return
	generation_job.begin_stage("rider_and_interface",4)
	generation_job.mutex.lock(); generation_job.expected_stages.rider_and_interface = 6000.0; generation_job.mutex.unlock()
	crash_collision = preload("res://scripts/world/crash_collision.gd").new()
	crash_collision.world = world
	add_child(crash_collision)
	if "--cloud-shadows-off" in OS.get_cmdline_user_args(): world.cloud_lighting.shadow_strength = 0.0
	session = Session.new()
	if current_mountain:
		session.configure_free(current_mountain.identity(),field.finish_z,field.finish_z if field.is_summit_mountain() else 0.0)
		timed = false
	else:
		session.load_record()
	skier = Visual.new()
	skier.lighting = world.cloud_lighting
	skier.assets = world.assets
	add_child(skier)
	ghost = Ghost.new()
	add_child(ghost)
	camera = ChaseCamera.new()
	camera.settings = camera_settings
	camera.near = 0.15
	camera.far = 32000.0
	add_child(camera)
	camera_preview = ChaseCamera.new()
	camera_preview.settings = camera_settings
	camera_preview.near = camera.near
	camera_preview.far = camera.far
	add_child(camera_preview)
	menu_camera = preload("res://scripts/presentation/menu_camera.gd").new()
	add_child(menu_camera)
	menu_camera.setup(field,world.ski_surface)
	camera.current = true
	generation_job.advance()
	if staged_loading:
		await _loading_checkpoint("Preparing skiing effects and audio…",-1.0)
		if generation_job.is_cancelled(): _cancel_startup(); return
	effects = Effects.new()
	effects.frame_costs = frame_costs
	voice = preload("res://scripts/presentation/skier_voice.gd").new()
	voice.environment = audio_environment
	add_child(voice)
	voice.persist = preferences_enabled
	voice.load_preferences()
	if reload_settings.has("voice"): voice.restore(reload_settings.voice)
	effects.lighting = world.cloud_lighting
	add_child(effects)
	effects.sfx.bind_equipment_source(skier)
	effects.wind.persist = preferences_enabled
	effects.wind.load_preferences()
	if reload_settings.has("wind"): effects.wind.restore(reload_settings.wind)
	effects.sfx.persist = preferences_enabled
	effects.sfx.load_preferences()
	if reload_settings.has("riding_audio"): effects.sfx.restore(reload_settings.riding_audio)
	for arg in OS.get_cmdline_user_args():
		if arg == "--wind-mode=original": effects.wind.mode = 1
		elif arg == "--wind-mode=procedural": effects.wind.mode = 0
		elif arg == "--sfx-mode=original": effects.sfx.mode = 1
		elif arg == "--sfx-mode=procedural": effects.sfx.mode = 0
	effects.apply_quality(graphics)
	effects.snow_tracks.bind_surface(field)
	effects.bind_powder_surface(world,graphics)
	ghost.bind(world.assets,effects.snow_tracks,field,graphics,skier,effects.powder_surface)
	effects.powder_surface.track_history = ghost.track_stack
	storm_effects = preload("res://scripts/presentation/storm_effects.gd").new()
	add_child(storm_effects)
	storm_effects.layer_height = world.cloud_lighting.height_m
	weather_effects = WeatherEffects.new()
	weather_effects.lighting = world.cloud_lighting
	add_child(weather_effects)
	weather_effects.set_budget_scale(graphics.weather_budget)
	weather_effects.set_quality(graphics.weather_quality)
	vectors = Vectors.new()
	add_child(vectors)
	vectors.visible = false
	var motion_layer = CanvasLayer.new()
	motion_layer.layer = 0
	add_child(motion_layer)
	speed_periphery = ColorRect.new()
	speed_periphery.visible = false
	speed_periphery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speed_periphery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var motion_material = ShaderMaterial.new()
	motion_material.shader = preload("res://assets/speed_periphery.gdshader")
	speed_periphery.material = motion_material
	motion_layer.add_child(speed_periphery)
	generation_job.advance()
	if staged_loading:
		await _loading_checkpoint("Preparing the mountain interface…",-1.0)
		if generation_job.is_cancelled(): _cancel_startup(); return
	hud = HUD.new()
	hud.feedback.pending_preferences = reload_settings.get("interface",{}).duplicate()
	add_child(hud)
	loading.configure_feedback(hud.feedback)
	if not automated and not "--autoplay" in OS.get_cmdline_user_args(): skier.appearance.load_preferences()
	hud.build_skier_controls(skier.appearance,not automated and not "--autoplay" in OS.get_cmdline_user_args())
	hud.build_tuning(sim.tuning)
	hud.start_requested.connect(start_run)
	hud.restart_requested.connect(restart)
	hud.respawn_requested.connect(respawn_here)
	hud.crash_pause_requested.connect(toggle_crash_pause)
	hud.resume_requested.connect(resume)
	hud.lab_speed_requested.connect(start_speed_lab)
	hud.tuning_changed.connect(func(): physics_modified = true; session.eligible = false)
	hud.vibration_changed.connect(func(value):
		if value<=0.0: effects.reset_haptics()
	)
	hud.defaults_requested.connect(func(): physics_modified = false; restart())
	hud.workbench_closed.connect(close_workbench)
	hud.workbench_requested.connect(open_workbench)
	hud.audio_mute_requested.connect(set_audio_muted)
	hud.wind_mode_requested.connect(set_wind_mode)
	hud.wind_volume_requested.connect(set_wind_volume)
	hud.sync_wind(effects.wind)
	hud.riding_audio_settings.bind(effects.sfx)
	hud.voice_settings.changed.connect(func(values): voice.restore(values); voice.save_preferences())
	hud.voice_settings.preview_requested.connect(voice.preview)
	hud.voice_settings.stop_requested.connect(voice.silence)
	hud.voice_settings.sync(voice)
	hud.motion_effects_requested.connect(set_motion_effects)
	hud.camera_setting_requested.connect(set_camera_setting)
	hud.camera_defaults_requested.connect(reset_camera_settings)
	hud.camera_preset_requested.connect(set_camera_preset)
	hud.camera_preview_requested.connect(set_camera_preview)
	hud.settings_tabs.tab_changed.connect(func(_index):
		if hud.camera_options.preview_active and not hud.camera_options.camera_tab_visible(): set_camera_preview(false)
	)
	hud.sync_camera_settings(camera_settings)
	hud.quit_requested.connect(quit_cleanly)
	hud.weather_option_requested.connect(_set_weather_option)
	hud.weather_preset_requested.connect(weather.set_preset)
	hud.weather_auto_requested.connect(weather.set_automatic)
	hud.weather_quality_requested.connect(func(value): set_display_setting("weather_quality",value))
	hud.time_of_day_requested.connect(weather.set_time_of_day)
	hud.time_cycle_requested.connect(weather.set_time_cycle)
	hud.graphics_quality_requested.connect(set_graphics_preset)
	hud.graphics_quality.select(display_settings.quality-1)
	hud.display_setting_requested.connect(set_display_setting)
	hud.graphics_values_requested.connect(func(values):
		for key in values: display_settings.set_graphics_value(key,values[key])
		apply_graphics_configuration()
	)
	hud.graphics_group_reset_requested.connect(func(group): display_settings.reset_group(group); apply_graphics_configuration())
	hud.display_preview_requested.connect(preview_display)
	hud.display_keep_requested.connect(keep_display)
	hud.display_revert_requested.connect(revert_display)
	hud.sync_display(display_settings)
	weather.settings_changed.connect(_sync_weather_ui)
	_sync_weather_ui()
	mountain_library = MountainLibrary.new()
	add_child(mountain_library)
	mountain_library.build(self)
	hud.mountains_requested.connect(mountain_library.open)
	hud.set_mountain(current_mountain)
	workshop = Workshop.new()
	add_child(workshop)
	workshop.build(self)
	hud.races_requested.connect(workshop.open_library)
	hud.navigation_requested.connect(workshop.open_navigation)
	hud.competition_requested.connect(open_competition)
	hud.ghost_visibility_requested.connect(set_ghost_visible)
	hud.ghost_selection_requested.connect(_choose_ghosts)
	generation_job.advance()
	if staged_loading:
		await _loading_checkpoint("Preparing summit access…",-1.0)
		if generation_job.is_cancelled(): _cancel_startup(); return
	sim.reset(field.spawn_point(),field.spawn_heading())
	sim.prime_contacts(field)
	skier.reset_animation(sim)
	previous_position = sim.position
	if not reload_settings.is_empty():
		camera.close_view = reload_settings.close_view
		effects.muted = reload_settings.muted
		camera.effects_enabled = reload_settings.get("motion_effects",true)
	else: effects.muted = hud.feedback.muted
	voice.set_muted(effects.muted)
	hud.sync_interface(effects.muted,camera.effects_enabled)
	hud.feedback.enabled = true
	mountain_zone = MountainZone.new(field)
	return_overlay = preload("res://scripts/ui/summit_return_overlay.gd").new()
	add_child(return_overlay)
	generation_job.advance()
	generation_job.end_stage("rider_and_interface")
	navigation.setup(self)
	controller_keyboard = preload("res://scripts/ui/controller_keyboard.gd").new()
	add_child(controller_keyboard)
	controller_keyboard.setup(hud)
	navigation.virtual_keyboard = controller_keyboard
	navigation.device_changed.connect(func():
		hud.set_input_family(navigation.family,navigation.device_label())
		hud.footer_controls.text = navigation.prompts(workshop.mode=="create")
	)
	hud.set_input_family(navigation.family,navigation.device_label())
	if not reload_settings.is_empty():
		hud.widget_layout.restore(reload_settings.get("hud_layout",hud.widget_layout.snapshot()))
		hud.widget_layout.global_visible = reload_settings.get("hud_visible",true)
		hud.shell_layout.restore(reload_settings.get("interface_layout",{}))
		hud.shell_layout.resize()
	initialized = true
	if pending_race:
		play_custom_race(pending_race)
	elif pending_mountain:
		start_run(false)
	elif get_tree().has_meta("standard_to_load"):
		var standard_timed: bool = get_tree().get_meta("standard_to_load")
		get_tree().remove_meta("standard_to_load")
		start_run(standard_timed)
	if not pending_race and not free_weather_snapshot.is_empty(): _leave_race_weather()
	if not load_warning.is_empty(): hud.toast(load_warning)
	elif not effects.wind.available: hud.toast("Procedural wind unavailable · using Original")
	if staged_loading:
		await _loading_checkpoint("Ready. Finding your fall line…",100.0)
		if generation_job.is_cancelled(): _cancel_startup(); return
		_present_camera(0.0,sim.position)
		loading.finish()
		hud.feedback.play("ready")
	if "tree_data" in field:
		var scene_ms = 0.0
		for value in world.build_timings.values(): scene_ms += value
		GenerationEstimates.record(field,scene_ms)
	print("ALPINE APEX | terrain %.1f ms | %d triangles | %d obstacles | 120 Hz" % [world.generation_ms,world.terrain_triangles,Obstacles.count(field)])
	if "--autoplay" in OS.get_cmdline_user_args():
		display_settings.apply_display(get_window(),benchmark_resolution)
		get_window().unresizable = true
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
		automated = true
		# Verify actual render pixels once, before the run and 120-frame warmup.
		# WindowTexture.get_size() can report stretched logical dimensions instead.
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			benchmark_actual_pixels = get_viewport().get_texture().get_image().get_size()
		start_run(current_mountain==null)
		session.eligible = false
		camera.close_view = "--first-person" in OS.get_cmdline_user_args()
	if "--capture-menu" in OS.get_cmdline_user_args():
		_capture_menu.call_deferred()

func _physics_process(dt: float) -> void:
	if not initialized or transitioning or returning_to_summit or quitting or (loading and loading.busy) or sim == null:
		return
	if session.recovering:
		# Crash subpages and the ragdoll's settle limit never own the race clock.
		if application_focused or automated:
			_check_race_weather()
			session.step_crash(dt)
		hud.update_crash_recovery(session,recovery_placement.get("error",""),not application_focused and not automated)
		return
	if not active: return
	_check_race_weather() # Resolve eligibility before this tick can finish/save.
	var tick_start = Time.get_ticks_usec()
	previous_position = sim.position
	intent = input_router.sample(sim.grounded)
	if not rider_axes_armed:
		if absf(intent.steer)+intent.tuck+intent.brake<.01: rider_axes_armed = true
		intent.steer = 0.0; intent.tuck = 0.0; intent.brake = 0.0
	if not air_tilt_controls_armed:
		if absf(intent.air_tilt)<.000001: air_tilt_controls_armed = true
		intent.air_tilt = 0.0
	if not air_controls_armed:
		if absf(intent.air_pitch)+absf(intent.air_yaw)<.000001 and not intent.grab and not Input.is_action_pressed("trick_modifier"):
			air_controls_armed = true
		intent.air_pitch = 0.0; intent.air_yaw = 0.0; intent.grab = false
	# A valid hold must begin after neutral has been observed in active play.
	# Godot can expose a release edge on the following physics tick. Merely
	# seeing neutral must never authorize that delayed edge from a menu hold.
	if jump_armed and (intent.jump_held or Input.is_action_just_pressed("jump")):
		jump_prepared = true
	intent.jump = intent.jump and jump_prepared and not intent.jump_held
	if intent.jump: jump_prepared = false
	intent.jump_held = intent.jump_held and jump_prepared
	if not Input.is_action_pressed("jump"):
		jump_armed = true
	if automated:
		# Benchmark input is fixed even if someone types while its window is
		# focused. Physical keyboard/gamepad input must not alter comparisons.
		intent = RiderInput.new()
		intent.tuck = 1.0
		if benchmark_input.is_valid(): intent = benchmark_input.call(sim.ticks)
		automated_ticks += 1
	if summit_ready:
		if not summit_drop_armed and intent.tuck<=0.1 and not Input.is_action_pressed("begin_run") and not Input.is_action_pressed("jump"):
			summit_drop_armed = true
		if absf(intent.steer)>.01:
			var heading = wrapf(sim.heading-intent.steer*dt*1.4,-PI,PI)
			sim.reset(field.spawn_point(),heading)
			sim.prime_contacts(field)
			skier.reset_animation(sim)
		if intent.tuck>.1 and summit_drop_armed: drop_from_summit()
		return
	crash_recovery.observe_support(sim)
	var simulation_started = frame_costs.begin()
	sim.step(dt,intent,world.ski_surface)
	frame_costs.end(&"simulation",simulation_started)
	var animation_started = frame_costs.begin()
	skier.step_animation(dt,sim,intent,field)
	frame_costs.end(&"animation_tick",animation_started)
	if _resolve_zone_exit(dt,previous_position,sim.position):
		cpu_tick_ms = lerpf(cpu_tick_ms,(Time.get_ticks_usec()-tick_start)/1000.0,0.05)
		return
	var audio_started = frame_costs.begin()
	observe_audio_tick(dt)
	frame_costs.end(&"audio_observers",audio_started)
	# Independent observer: muting or changing sound must not affect impacts.
	effects.haptics.observe_tick(sim,dt)
	if timed:
		var completed: bool = session.step(dt,previous_position,sim.position,sim,intent)
		_capture_ghost_pose((session.elapsed-session.previous_elapsed)/dt if completed else 1.0)
		if completed:
			_invalidate_crash_recovery()
			active = false
			hud.show_result(session,sim.peak_speed*3.6)
			voice.finish_run(session)
	elif not timed:
		session.previous_elapsed = session.elapsed
		session.elapsed += dt
		if current_mountain and not mountain_zone.enabled and field.reached_base(sim.position) and not sim.crashed:
			session.finished = true
			active = false
			hud.show_menu("finished","Mountain base reached.\nExplore another face or create a race.")
	if sim.crashed:
		crash_recovery.capture(sim,session.attempt_id,field.get_instance_id())
		session.begin_crash(sim)
		_capture_crash_boundary_pose()
		recovery_placement = crash_recovery.resolve(field,world.ski_surface,session,mountain_zone,timed)
		skier.ragdoll.start(sim)
		last_ragdoll_position = skier.ragdoll.focus()
		skier.ragdoll.saved_close_view = camera.close_view
		camera.close_view = false
		active = false
		hud.show_menu("crashed",sim.crash_reason)
		hud.update_crash_recovery(session,recovery_placement.get("error",""))
		voice.begin_crash()
	cpu_tick_ms = lerpf(cpu_tick_ms,(Time.get_ticks_usec()-tick_start)/1000.0,0.05)
	if automated and not benchmark_input.is_valid():
		if automated_ticks in screenshot_ticks:
			_capture("run_%04d" % automated_ticks)
		if sim.crashed or session.finished or automated_ticks > 9000:
			_finish_automation.call_deferred()

func observe_audio_tick(dt: float) -> void:
	var candidates: Array[String] = audio_environment.sample(sim,field,dt)
	if not effects.muted: effects.sfx.observe_tick(sim,field,dt,audio_environment.near_passes)
	else: effects.sfx.silence()
	voice.observe_tick(sim,dt,field,session.progress_percent(sim.position)/100.0 if timed else -1.0,candidates)

func _process(dt: float) -> void:
	if initialized:
		_update_display_recovery()
		if navigation and hud.footer.visible: hud.footer_controls.text = workshop.navigation_panel.prompts() if workshop.mode=="navigation" else navigation.prompts(workshop.mode=="create")
	_sync_camera_preview()
	_sync_camera_controls()
	if not initialized or (loading and loading.busy) or sim == null:
		_reset_screen_effects()
		return
	if voice.audition_active and not hud.voice_settings.selection.is_visible_in_tree(): voice.silence()
	if voice.crash_pending:
		var crash_visible: bool = application_focused and not transitioning and not returning_to_summit and hud.menu_mode=="crashed" and hud.menu.visible and skier.ragdoll.running and not session.recovery_paused
		var hip_speed: float = skier.ragdoll.bodies.Hips.linear_velocity.length() if skier.ragdoll.running else INF
		voice.observe_crash(dt,hip_speed,crash_visible)
	if camera_controls_active:
		var stick: Vector2 = input_router.sample_camera_look(camera_settings.shared.stick_deadzone,camera_settings.shared.stick_exponent)
		if stick.is_zero_approx(): camera_stick_armed = true
		camera.set_stick_look(stick if camera_stick_armed else Vector2.ZERO)
	render_frames += 1
	var now = Time.get_ticks_usec()
	var measured_frame_ms = float(now-last_frame_usec)/1000.0 if last_frame_usec>0 else dt*1000.0
	last_frame_usec = now
	frame_ms = lerpf(frame_ms,dt*1000.0,0.07)
	if automated and render_frames > 120:
		frame_samples.append(measured_frame_ms)
		draw_samples.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		peak_video_memory_bytes = maxi(peak_video_memory_bytes,int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
		var viewport_rid = get_viewport().get_viewport_rid()
		var gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
		var render_cpu_ms = RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
		if gpu_ms>0.0:
			gpu_samples.append(gpu_ms)
		if render_cpu_ms>0.0:
			render_cpu_samples.append(render_cpu_ms)
	# Rendering interpolates between completed 120 Hz states: at most 8.33 ms
	# of interpolation latency, with input sampled at each physics tick.
	var fraction = Engine.get_physics_interpolation_fraction() if active else 1.0
	skier.snow_burial_enabled = effects.powder_surface!=null and effects.powder_surface.is_active()
	var pose_started = frame_costs.begin()
	skier.pose(sim,fraction)
	frame_costs.end(&"pose",pose_started)
	var p: Vector3 = skier.global_position
	if active and not timed and not summit_ready:
		var discovery: String=world.flavor.discover_near(p)
		if not discovery.is_empty(): hud.toast("Discovered · "+discovery)
	var ghost_time = lerpf(session.previous_elapsed,session.elapsed,fraction) if active else session.elapsed
	if skier.ragdoll.running:
		var ragdoll_position: Vector3 = skier.ragdoll.focus()
		if not returning_to_summit and not transitioning and mountain_zone.swept_exit_fraction(last_ragdoll_position,ragdoll_position)>=0.0:
			_begin_summit_return(false)
			return # The midpoint may already have reset this ragdoll and its camera.
		last_ragdoll_position = ragdoll_position
		p = ragdoll_position-Vector3.UP*.6
	var collision_started = frame_costs.begin()
	crash_collision.prepare(p)
	frame_costs.end(&"collision_preparation",collision_started)
	ghost.update_ghosts(session,ghost_time,p,timed and workshop.mode.is_empty() and hud.menu_mode!="title",not active and not (session.recovering and not session.recovery_paused and (application_focused or automated)))
	hud.ghost_colors = ghost.colors
	var camera_started = frame_costs.begin()
	_present_camera(dt,p)
	frame_costs.end(&"camera",camera_started)
	var menu_view: bool = presentation_camera == menu_camera
	var animate_menu: bool = menu_view and not hud.feedback.reduced_motion
	var first_person_presented: bool = (presentation_camera==camera and camera.close_view) or (presentation_camera==camera_preview and camera_preview.close_view)
	skier.body_pivot.visible = menu_view or skier.ragdoll.running or (summit_ready and presentation_camera!=camera_preview) or not first_person_presented
	var weather_started = frame_costs.begin()
	var weather_active = active and not summit_ready and not transitioning and not returning_to_summit
	if session.race: weather.sample_race(session.elapsed)
	else: weather.update_weather(dt,weather_active,animate_menu)
	storm_effects.update_storm(weather.state,weather_active,weather.lightning,hud.feedback.reduced_motion,effects.muted,effects.wind.volume)
	if weather.free_seconds-weather_checkpoint>=30.0: _checkpoint_weather()
	world.update_weather(weather.state,dt,active or animate_menu)
	frame_costs.end(&"weather_world",weather_started)
	get_tree().call_group("race_beam_vfx","update_effect",dt,active or not workshop.mode.is_empty(),hud.feedback.reduced_motion)
	var trees_started = frame_costs.begin()
	world.scenery.tree_motion.update(p,sim.velocity,dt,active)
	world.assets.update_foliage_sight(presentation_camera,p,dt,(active and presentation_camera==camera) or presentation_camera==camera_preview,camera_settings.shared.forest_visibility,camera_settings.shared.forest_visibility_strength)
	frame_costs.end(&"interactive_trees",trees_started)
	var weather_anchor: Vector3 = menu_camera.focus_point if menu_view else p
	weather_effects.update_weather(weather.state,presentation_camera,weather_anchor,field,dt,active,animate_menu,camera.motion_intensity * camera_settings.profile("first_person" if camera.close_view else "chase").streak_strength / 100.0 if active and camera.effects_enabled else 0.0,graphics.weather_quality,first_person_presented)
	_update_screen_effects(dt)
	var crash_audio_visible: bool = (application_focused or automated) and not transitioning and not returning_to_summit and hud.menu_mode=="crashed" and hud.menu.visible and not hud.weather_panel.visible and not hud.tuning_panel.visible and not session.recovery_paused
	var voice_speaking: bool = voice.enabled and not voice.muted and voice.volume>0.001 and voice.clock_seconds<voice.speaking_until
	var effects_started = frame_costs.begin()
	effects.update_effects(sim,field,p,dt,active and (application_focused or automated),weather.state,skier.ragdoll,presentation_camera,crash_audio_visible,voice_speaking,skier.skis)
	frame_costs.end(&"effects",effects_started)
	vectors.update_vectors(sim)
	var hud_started = frame_costs.begin()
	hud.widget_layout.menu_visible = hud.has_menu_background() or workshop.is_survey_open() or hud.camera_options.preview_active
	hud.footer.visible = hud.has_menu_background() or workshop.is_survey_open() or summit_ready
	hud.update_hud(sim,session,intent,navigation.device_label(),frame_ms,cpu_tick_ms,dt,timed,weather.state.label+" · "+weather.state.time_label)
	hud.update_summit_return(mountain_zone.distance_to_boundary(sim.position),active and not summit_ready and not returning_to_summit)
	if workshop and not workshop.mode.is_empty():
		hud.mode_label.text = "MAP / PERSONAL NAVIGATION" if workshop.mode=="navigation" else "CREATE A RACE / WORLD SURVEY" if workshop.mode=="create" else "SAVED & SHARED RACES"
	elif mountain_library and mountain_library.panel.visible:
		hud.mode_label.text = "MOUNTAIN LIBRARY"
	elif summit_ready and not hud.has_menu_background():
		var bearing = posmod(roundi(180-rad_to_deg(sim.heading)),360)
		var compass = ["N","NE","E","SE","S","SW","W","NW"][posmod(roundi(bearing/45.0),8)]
		hud.mode_label.text = "SUMMIT  /  %03d° %s  /  CHOOSE YOUR DESCENT" % [bearing,compass]

	if navigation and hud.footer.visible:
		hud.footer_controls.text = hud.Prompts.summit(navigation.family) if summit_ready and navigation.scope()==null else (workshop.navigation_panel.prompts() if workshop.mode=="navigation" else navigation.prompts(workshop.mode=="create"))
	frame_costs.end(&"hud",hud_started)

func _menu_context() -> String:
	if sim.crashed: return "crashed"
	if session.finished: return "finished"
	if workshop and workshop.mode=="library": return workshop.return_mode
	if mountain_library and mountain_library.panel.visible: return mountain_library.return_mode
	if hud.tuning_panel.visible: return "paused" if workbench_return=="active" else workbench_return
	return "paused" if hud.menu_mode=="racing" else hud.menu_mode

func _present_camera(dt: float, rider_position: Vector3) -> void:
	# Loading owns visibility; this can also prepare its first ready frame.
	if returning_to_summit or transitioning:
		menu_camera.cancel_fade()
		hud.set_background_fade(0.0)
		presentation_camera = get_viewport().get_camera_3d()
		return
	if hud.camera_options.preview_active:
		var preview_close: bool = hud.camera_options.view=="first_person"
		if camera_preview.close_view!=preview_close: camera_preview.reset()
		camera_preview.close_view = preview_close
		camera_preview.effects_enabled = camera.effects_enabled
		camera_preview.update_camera(sim,field,rider_position,dt,false,false,false,hud.camera_options.preview_speed.value)
		presentation_camera = camera_preview
		camera_preview.make_current()
		menu_camera.cancel_fade()
		hud.set_background_fade(0.0)
	elif workshop and workshop.is_survey_open():
		presentation_camera = workshop.survey
		workshop.survey.make_current()
		menu_camera.cancel_fade()
		hud.set_background_fade(0.0)
		workshop.update_survey(dt)
	elif not active and hud.has_menu_background():
		menu_camera.select_context(_menu_context())
		var before_cut: int = menu_camera.cut_serial
		menu_camera.update_view(rider_position,dt,hud.feedback.reduced_motion,skier.ragdoll.running and not skier.ragdoll.frozen)
		presentation_camera = menu_camera
		menu_camera.make_current()
		if before_cut!=menu_camera.cut_serial:
			weather_effects.reset()
			_clear_storm_effects()
		hud.set_background_fade(menu_camera.fade_alpha)
	else:
		if not menu_camera.context.is_empty(): _restore_riding_camera()
		presentation_camera = camera
		camera.make_current()
		camera.update_camera(sim,field,rider_position,dt,false,active,summit_ready)
		if skier.ragdoll.running: camera.look_at(skier.ragdoll.focus())

func _restore_riding_camera() -> void:
	if not is_instance_valid(menu_camera) or not is_instance_valid(hud): return
	if menu_camera.context.is_empty() and get_viewport().get_camera_3d()==camera: return
	menu_camera.leave()
	hud.set_background_fade(0.0)
	camera.make_current()
	presentation_camera = camera
	camera.reset()
	camera_stick_armed = false
	camera.update_camera(sim,field,sim.position,0.0,false,active,summit_ready)
	weather_effects.reset()
	_clear_storm_effects()

func _camera_control_allowed() -> bool:
	return initialized and active and application_focused and not automated and not quitting and not transitioning and not returning_to_summit and not (loading and loading.busy) and camera != null and hud != null and not hud.menu.visible and not hud.weather_panel.visible and not hud.tuning_panel.visible and not hud.competition.panel.visible and not (mountain_library and mountain_library.panel.visible) and not (workshop and not workshop.mode.is_empty()) and not sim.crashed

func _sync_camera_controls() -> void:
	var allowed = _camera_control_allowed()
	if allowed == camera_controls_active: return
	camera_controls_active = allowed
	camera_stick_armed = false
	discard_camera_mouse_motion = allowed
	if camera != null: camera.clear_look_input()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if allowed else Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	if not navigation or automated: return
	if not initialized: navigation._device_used(event)
	elif navigation.route(event): get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if initialized and navigation and navigation.scope()!=null and not automated:
		if event.has_meta("menu_owned"): return
		if workshop.mode=="navigation":
			if event.is_action_pressed("pause_run") or event.is_action_pressed("ui_cancel"): navigation.back()
			return # The navigation drawer owns shortcuts as well as terrain input.
		if event.is_action_pressed("pause_run") or event.is_action_pressed("ui_cancel"): navigation.back()
		elif not navigation.top_popup():
			if event.is_action_pressed("tuning"):
				if hud.tuning_panel.visible: close_workbench()
				else: open_workbench()
			elif event.is_action_pressed("race_library"): workshop.open_library()
			elif event.is_action_pressed("run_records"): open_competition()
			elif workshop.mode=="create" and event is InputEventMouse: workshop.handle_input(event)
		return
	if hud and hud.camera_options.preview_active:
		if event.is_action_pressed("pause_run"):
			set_camera_preview(false)
			return
		if event.is_action_pressed("restart"): set_camera_preview(false)
		else: return
	_sync_camera_controls()
	if camera_controls_active:
		if event is InputEventMouseMotion:
			# Ignore the capture/warp edge; subsequent motion uses output pixels.
			if discard_camera_mouse_motion: discard_camera_mouse_motion = false
			else: camera.add_mouse_look(event.screen_relative)
			return
		if event.is_action_pressed("camera_recenter"):
			camera.recenter_look()
			camera_stick_armed = false
			return
	if returning_to_summit:
		if event.is_action_pressed("pause_run"): return_paused = true
		return
	if not initialized or transitioning or (loading and loading.busy) or automated:
		return
	if mountain_library and mountain_library.panel.visible:
		if event.is_action_pressed("pause_run") and not mountain_library.export_dialog.visible and not mountain_library.import_dialog.visible:
			mountain_library.close()
		return
	if workshop and not workshop.mode.is_empty():
		workshop.handle_input(event)
		return
	if event.is_action_pressed("race_library"):
		workshop.open_library()
		return
	if event.is_action_pressed("run_records"):
		if hud.competition.panel.visible: hud.close_competition()
		else: open_competition()
		return
	if event.is_action_pressed("restart"):
		restart()
	elif event.is_action_pressed("pause_run"):
		if hud.competition.panel.visible:
			hud.close_competition()
		elif hud.weather_panel.visible:
			hud.close_weather()
		elif hud.tuning_panel.visible:
			close_workbench()
		elif active:
			active = false
			hud.show_menu("paused")
		elif hud.menu_mode == "paused":
			resume()
	elif event.is_action_pressed("begin_run") and summit_ready and active:
		drop_from_summit()
	elif event.is_action_pressed("begin_run") and hud.menu.visible:
		hud._primary_pressed()
	elif event.is_action_pressed("camera_mode"):
		camera.close_view = not camera.close_view
		camera.reset()
		camera_stick_armed = false
		weather_effects.reset()
		_clear_storm_effects()
		hud.toast("FIRST PERSON" if camera.close_view else "CHASE CAMERA")
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		set_motion_effects(not camera.effects_enabled)
		hud.toast("MOTION EFFECTS ON" if camera.effects_enabled else "MOTION EFFECTS OFF")
	elif event.is_action_pressed("debug_overlay"):
		hud.widget_layout.values.debug.visible = not hud.widget_layout.values.debug.visible
		hud.layout_widgets()
		vectors.visible = hud.widget_layout.values.debug.visible
	elif event.is_action_pressed("tuning"):
		if hud.tuning_panel.visible:
			close_workbench()
		else:
			open_workbench()
	elif event.is_action_pressed("toggle_audio"):
		set_audio_muted(not effects.muted)
		hud.toast("AUDIO MUTED" if effects.muted else "AUDIO ON")
	elif event.is_action_pressed("compare_wind"):
		set_wind_mode(1-effects.wind.mode)
		hud.toast("WIND · "+effects.wind.label())
	elif event.is_action_pressed("toggle_hud"):
		hud.toggle_instruments()
	elif event.is_action_pressed("toggle_ghost"):
		set_ghost_visible(not ghost.enabled)
		hud.toast("GHOSTS ON" if ghost.enabled else "GHOSTS OFF")

func start_run(is_timed: bool = false) -> void:
	_invalidate_crash_recovery()
	_leave_race_weather()
	_cancel_summit_return()
	if world and world.scenery: world.scenery.tree_motion.reset()
	if transitioning: return
	if current_mountain and (not is_timed or (not get_tree().get_meta("test_lab_fixture",false) and "--test-lab" not in OS.get_cmdline_user_args())):
		session.configure_free(current_mountain.identity(),field.finish_z,field.finish_z if field.is_summit_mountain() else 0.0)
		workshop.show_race(null)
		timed = false
		restart()
		return
	if field.GENERATOR_ID!="laboratory" or field.seed_value != 849205174:
		active = false
		effects.stop_audio()
		transitioning = true
		loading.configure_feedback(hud.feedback)
		loading.begin("Returning to the test face", "Opening the original mountain…")
		await loading.draw_frame()
		get_tree().set_meta("standard_to_load",is_timed)
		_remember_world_settings()
		var reload_error = get_tree().reload_current_scene()
		if reload_error != OK:
			get_tree().remove_meta("standard_to_load")
			get_tree().remove_meta("world_reload_settings")
			transitioning = false
			loading.finish()
			hud.show_menu("paused")
			hud.toast("Could not load the original test face. Please try again.")
		return
	session.configure()
	workshop.show_race(null)
	timed = is_timed
	restart()

func _reset_screen_effects() -> void:
	if impact_warning != null: impact_warning.reset()
	if is_instance_valid(speed_periphery):
		speed_periphery.hide()
		speed_periphery.material.set_shader_parameter("warning_strength",0.0)

func _update_screen_effects(dt: float) -> void:
	var riding: bool = initialized and active and application_focused and not transitioning and not returning_to_summit and not quitting and sim!=null and not sim.crashed and not (loading and loading.busy)
	if not riding:
		_reset_screen_effects()
		return
	impact_warning.update(sim.impacts.reserve,dt,camera.effects_enabled and not hud.feedback.reduced_motion)
	var speed: float = camera.motion_intensity if camera.effects_enabled else 0.0
	var profile: Dictionary = camera_settings.profile("first_person" if camera.close_view else "chase")
	effect_time += dt
	speed_periphery.visible = speed * maxf(profile.blur_strength,profile.streak_strength) / 100.0>0.005 or impact_warning.strength>0.0001
	speed_periphery.material.set_shader_parameter("intensity",speed * profile.blur_strength / 100.0)
	speed_periphery.material.set_shader_parameter("arcade_intensity",speed * profile.streak_strength / 100.0 if weather.state.enabled else 0.0)
	speed_periphery.material.set_shader_parameter("effect_time",effect_time)
	speed_periphery.material.set_shader_parameter("warning_strength",impact_warning.strength)
	speed_periphery.material.set_shader_parameter("warning_pulse",impact_warning.pulse)

func restart(preserve_return: bool = false) -> void:
	_invalidate_crash_recovery()
	set_camera_preview(false)
	_reset_screen_effects()
	voice.reset()
	if not preserve_return: _cancel_summit_return()
	summit_drop_armed = true
	if world and world.scenery: world.scenery.tree_motion.reset()
	summit_ready = not timed and session.race==null and field.is_summit_mountain()
	if skier.ragdoll.running: camera.close_view = skier.ragdoll.saved_close_view
	skier.ragdoll.stop()
	if session.race:
		sim.reset(session.race.start,session.race.heading)
	else:
		sim.reset(field.spawn_point(),field.spawn_heading())
	session.reset()
	if session.race: weather.begin_race(session.race.weather_preset,session.race.time_band,session.race.identity())
	session.eligible = not physics_modified and not automated and "--test-lab" not in OS.get_cmdline_user_args() and (session.race != null or (field.GENERATOR_ID=="laboratory" and field.seed_value == 849205174))
	sim.surface_normal = field.contact_normal(sim.position.x,sim.position.z)
	sim.prime_contacts(field)
	skier.reset_animation(sim)
	_check_race_weather()
	if timed:
		session.begin_capture(sim)
		_capture_ghost_pose(1.0)
	ghost.sync_attempt(session)
	previous_position = sim.position
	intent = RiderInput.new()
	air_controls_armed = false
	air_tilt_controls_armed = false
	input_router.cancel_air_input()
	jump_armed = false
	jump_prepared = false
	camera.reset()
	camera_stick_armed = false
	effects.reset()
	weather_effects.reset()
	_clear_storm_effects()
	effect_time = 0.0
	hud.hide_menu()
	hud.menu_mode = "racing"
	hud.tuning_panel.visible = false
	active = true
	if timed and not preserve_return: voice.start_run()

func _capture_crash_boundary_pose() -> void:
	if session.recording==null or session.recording.overflow: return
	skier.pose(sim,1.0)
	session.recording.capture_presentation(session.elapsed,CrashGhostPose.capture(skier,sim,field))

func _invalidate_crash_recovery() -> void:
	crash_recovery.invalidate()
	recovery_placement.clear()
	if session: session.cancel_recovery()

func toggle_crash_pause() -> void:
	if not session.recovering or transitioning or returning_to_summit: return
	session.recovery_paused = not session.recovery_paused
	if skier.ragdoll.running:
		skier.ragdoll.set_frozen(session.recovery_paused or not application_focused or skier.ragdoll.elapsed>=15.0)
	if session.recovery_paused:
		effects.wind.silence()
		effects.sfx.silence()
		effects.reset_haptics()
		voice.silence()
	hud.update_crash_recovery(session,recovery_placement.get("error",""))

func respawn_here() -> void:
	if not initialized or active or transitioning or returning_to_summit or quitting or (loading and loading.busy): return
	if not sim.crashed or not session.recovering or session.recovery_paused or session.finished: return
	if not application_focused and not automated: return
	if not hud.menu.visible or hud.menu_mode!="crashed": return
	if not crash_recovery.matches(session.attempt_id,field.get_instance_id()): return
	# Recheck active props at activation; a previously displayed choice is not a
	# license to use stale placement after another menu changes the course.
	recovery_placement = crash_recovery.resolve(field,world.ski_surface,session,mountain_zone,timed)
	if not recovery_placement.get("error","").is_empty():
		hud.update_crash_recovery(session,recovery_placement.error)
		return
	set_camera_preview(false)
	if skier.ragdoll.running: camera.close_view = skier.ragdoll.saved_close_view
	skier.ragdoll.stop()
	CrashRecovery.restore_at_rest(sim,recovery_placement,world.ski_surface)
	skier.reset_animation(sim)
	session.recover(sim)
	_capture_crash_boundary_pose()
	previous_position = sim.position
	crash_recovery.invalidate()
	crash_recovery.observe_support(sim)
	recovery_placement.clear()
	intent = RiderInput.new()
	rider_axes_armed = false
	air_controls_armed = false
	air_tilt_controls_armed = false
	jump_armed = false
	jump_prepared = false
	input_router.cancel_air_input()
	sim.clear_input_buffer()
	camera.reset()
	camera_stick_armed = false
	effects.reset()
	audio_environment.reset()
	voice.reset()
	weather_effects.reset()
	_reset_screen_effects()
	_clear_storm_effects()
	effect_time = 0.0
	hud.hide_menu()
	hud.tuning_panel.hide()
	hud.menu_mode = "racing"
	summit_ready = false
	active = true

func open_competition() -> void:
	if active or hud.menu_mode=="racing":
		active = false
		hud.show_menu("paused")
	hud.tuning_panel.visible = false
	hud.open_competition(session)

func _capture_ghost_pose(fraction: float = 1.0) -> void:
	if not session.recording or not session.recording.wants_presentation_sample(): return
	# Completed 30 Hz samples plus exact endpoints, independent of render cadence.
	# Read only the production writer after the fixed animation step. No extra
	# simulation or animation step; render restores its ordinary interpolation.
	var started = frame_costs.begin()
	skier.pose(sim,fraction)
	session.capture_presentation(GhostPose.capture(skier,sim,field))
	frame_costs.end(&"ghost_capture",started)

func _choose_ghosts(mode: String, ids: Array) -> void:
	session.choose_ghosts(mode,ids)
	ghost.refresh_colors(session.ghost_runs)
	hud.ghost_colors = ghost.colors
	hud.competition.refresh(session,ghost.enabled)

func set_ghost_visible(enabled: bool) -> void:
	ghost.set_enabled(enabled)
	hud.ghost_enabled = enabled
	hud.competition.ghost_toggle.set_pressed_no_signal(enabled)

func play_custom_race(race) -> void:
	_invalidate_crash_recovery()
	if transitioning: return
	_suspend_free_weather()
	_cancel_summit_return()
	var same_world: bool = workshop.matches_world(race)
	var rebuilt = {"field":field}
	if not same_world:
		transitioning = true
		active = false
		loading.configure_feedback(hud.feedback)
		loading.begin("Loading race mountain", "Reconstructing the race's terrain…")
		await loading.draw_frame()
		generation_job = GenerationJob.new()
		GenerationEstimates.configure(generation_job,race.mountain.seed,race.mountain.get("settings",{}))
		loading.attach_job(generation_job)
		loading.stage(GenerationEstimates.label(GenerationEstimates.estimate(race.mountain.seed,race.mountain.get("settings",{}))))
		await loading.draw_frame()
		rebuilt = await loading.run_data(Race.reconstruct_surface.bind(race.mountain,generation_job),generation_job)
	if not rebuilt.has("field"):
		transitioning = false
		loading.finish()
		_leave_race_weather()
		workshop.status.text = rebuilt.error
		hud.toast(rebuilt.error)
		return
	var target_field = rebuilt.field
	var error: String = race.validate_surface(target_field)
	if not error.is_empty():
		transitioning = false
		loading.finish()
		_leave_race_weather()
		workshop.status.text = error
		hud.toast(error)
		return
	if not workshop.matches_world(race):
		active = false
		effects.stop_audio()
		get_tree().set_meta("race_to_load",race.share_text())
		get_tree().set_meta("prepared_race_surface",rebuilt)
		_remember_world_settings()
		var reload_error = get_tree().reload_current_scene()
		if reload_error != OK:
			get_tree().remove_meta("race_to_load")
			get_tree().remove_meta("prepared_race_surface")
			get_tree().remove_meta("world_reload_settings")
			transitioning = false
			loading.finish()
			_leave_race_weather()
			workshop.status.text = "Could not load the race's mountain. Please try again."
		return
	session.configure(race)
	workshop.close()
	timed = true
	restart()

func resume() -> void:
	set_camera_preview(false)
	if sim.crashed or session.finished:
		hud.show_menu("crashed" if sim.crashed else "finished",sim.crash_reason if sim.crashed else Session.format_time(session.elapsed))
		return
	hud.hide_menu()
	sim.reset_pose_history()
	skier.animation.hold()
	previous_position = sim.position
	session.previous_elapsed = session.elapsed
	hud.menu_mode = "racing"
	active = true

func start_speed_lab(kmh: float) -> void:
	restart()
	if summit_ready: drop_from_summit()
	session.eligible = false
	var normal: Vector3 = field.sample(sim.position.x,sim.position.z).normal
	sim.velocity = Vector3.DOWN.slide(normal).normalized() * kmh / 3.6
	hud.toast("SPEED LAB  /  %d km/h  /  UNRANKED" % kmh)

func open_workbench() -> void:
	workbench_return = "active" if active else hud.menu_mode
	active = false
	hud.hide_menu()
	hud.tuning_panel.show()
	hud.tuning_tabs.focus_page()

func set_audio_muted(value: bool) -> void:
	effects.muted = value
	voice.set_muted(value)
	if value: effects.wind.silence()
	if value: effects.sfx.silence()
	hud.sync_interface(value,camera.effects_enabled)
	hud.feedback.save()

func set_wind_mode(value: int) -> void:
	effects.wind.mode = clampi(value,0,1)
	effects.wind.save_preferences()
	hud.sync_wind(effects.wind)

func set_wind_volume(value: float) -> void:
	effects.wind.volume = clampf(value,0.0,1.0) if is_finite(value) else 1.0
	effects.wind.save_preferences()
	hud.sync_wind(effects.wind)

func set_motion_effects(value: bool) -> void:
	camera.effects_enabled = value
	hud.sync_interface(effects.muted,value)

func _loading_checkpoint(message: String, percent: float) -> void:
	loading.stage(message,percent)
	await loading.draw_frame()

func close_workbench() -> void:
	hud.tuning_panel.visible = false
	if workbench_return == "active":
		resume()
	else:
		hud.show_menu(workbench_return,sim.crash_reason if sim.crashed else Session.format_time(session.elapsed))

func _controller_connection_changed(_device: int, _connected: bool) -> void:
	jump_armed = false
	jump_prepared = false
	intent.jump = false
	intent.jump_held = false
	air_controls_armed = false
	air_tilt_controls_armed = false
	intent.air_pitch = 0.0; intent.air_yaw = 0.0; intent.air_tilt = 0.0; intent.grab = false
	if input_router != null: input_router.cancel_air_input()
	if sim: sim.air_control.cancel_input()
	if sim: sim.clear_input_buffer()
	if effects: effects.reset_haptics()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_camera_preview(false)
		_reset_screen_effects()
		application_focused = false
		if effects: effects.reset_haptics()
		if voice: voice.silence()
		_sync_camera_controls()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		application_focused = true
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and returning_to_summit and not automated:
		return_paused = true
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and skier and skier.ragdoll.running:
		skier.ragdoll.set_frozen(true)
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN and not returning_to_summit and skier and skier.ragdoll.running and skier.ragdoll.elapsed<15.0 and not session.recovery_paused:
		skier.ragdoll.set_frozen(false)
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_cleanly()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and active and not automated:
		active = false
		if hud:
			hud.show_menu("paused")

func quit_cleanly() -> void:
	set_camera_preview(false)
	if quitting:
		return
	_checkpoint_weather()
	quitting = true
	if effects: effects.reset_haptics()
	_cancel_summit_return()
	active = false
	automated = false
	if effects:
		effects.stop_audio()
	# Let the native audio callback release its loop playbacks before the
	# engine's Resource/ObjectDB cleanup (headless has no playback thread).
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(0.18).timeout
	get_tree().quit()

func _capture(label: String) -> void:
	if benchmark_no_captures:
		return
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() != "headless":
		print("CAPTURE ",label," rider=",sim.position," camera=",camera.position," distance=",camera.position.distance_to(sim.position))
		var img = get_viewport().get_texture().get_image()
		img.save_png("res://artifacts/%s.png" % label)

func _capture_menu() -> void:
	await get_tree().create_timer(2.0).timeout
	await _capture("menu")
	await quit_cleanly()

func _finish_automation() -> void:
	automated = false
	active = false
	await _capture("run_end")
	frame_samples.sort()
	var mean = 0.0
	for ms in frame_samples:
		mean += ms
	mean /= maxf(1.0,frame_samples.size())
	var data = {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"resolution":str(get_window().size),"logical_ui_resolution":str(get_viewport().get_visible_rect().size),"window_size":str(get_window().size),"frames":frame_samples.size(),"mean_frame_ms":mean,"p95_frame_ms":frame_samples[int(frame_samples.size()*0.95)] if not frame_samples.is_empty() else 0.0,"p99_frame_ms":frame_samples[int(frame_samples.size()*0.99)] if not frame_samples.is_empty() else 0.0,"last_smoothed_tick_ms":cpu_tick_ms,"peak_kmh":sim.peak_speed*3.6,"airtime_s":sim.total_airtime,"run_time_s":session.elapsed,"crashed":sim.crashed,"reason":sim.crash_reason,"finished":session.finished,"world_build_ms":world.generation_ms}
	data.graphics_quality = graphics.label()
	data.lighting = {"sdfgi":world.environment.sdfgi_enabled,"sdfgi_cascades":world.environment.sdfgi_cascades,"sdfgi_cell_m":world.environment.sdfgi_min_cell_size,"ssao":world.environment.ssao_enabled,"ssil":world.environment.ssil_enabled,"ssil_radius_m":world.environment.ssil_radius,"ssil_intensity":world.environment.ssil_intensity}
	data.actual_render_pixels = [benchmark_actual_pixels.x,benchmark_actual_pixels.y]
	data.display = display_settings.report(get_viewport(),benchmark_actual_pixels)
	data.warmup_frames_excluded = 120
	data.platform = OS.get_name()
	data.graphics_driver = RenderingServer.get_current_rendering_driver_name()
	data.terrain_renderer = terrain_renderer
	data.mountain = world.mountain.descriptor()
	data.capture_overhead_included = not benchmark_no_captures
	data.draw_calls = _timing_summary(draw_samples)
	data.peak_video_memory_bytes = peak_video_memory_bytes
	data.course_id = session.course_id
	var slow_count = maxi(1,ceili(frame_samples.size()*0.01))
	var slow_total = 0.0
	for i in range(maxi(0,frame_samples.size()-slow_count),frame_samples.size()):
		slow_total += frame_samples[i]
	data.one_percent_low_fps = 1000.0/(slow_total/slow_count) if slow_total>0.0 else 0.0
	data.weather = weather.selected_preset
	data.weather_quality = graphics.weather_quality
	data.weather_particle_budget = weather_effects.particle_budget()
	data.snow_budget = effects.snow_budget()
	data.time_hour = weather.daylight.hour
	data.cloud_shadow_strength = world.cloud_lighting.shadow_strength
	data.render_gpu_ms = _timing_summary(gpu_samples)
	data.render_cpu_ms = _timing_summary(render_cpu_samples)
	var output = "res://artifacts/render_benchmark.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--benchmark-label="):
			output = "res://artifacts/weather_benchmark_%s.json" % arg.get_slice("=",1).validate_filename()
	var file = FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t"))
	print("RENDER_BENCHMARK ",JSON.stringify(data))
	await quit_cleanly()

func _timing_summary(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {"available":false}
	samples.sort()
	var total = 0.0
	for sample in samples:
		total += sample
	return {"available":true,"samples":samples.size(),"mean":total/samples.size(),"p95":samples[int(samples.size()*0.95)],"p99":samples[int(samples.size()*0.99)]}

func set_graphics_quality(level: int) -> void:
	# Named resource-tier API used by retained rendering fixtures.
	set_graphics_preset([1,4,7][clampi(level,0,2)])

func set_graphics_preset(id: int) -> void:
	display_settings.select_preset(id)
	apply_graphics_configuration()

func apply_graphics_configuration() -> void:
	graphics = display_settings.profile()
	display_settings.apply_viewport(get_viewport())
	world.apply_graphics(graphics)
	if weather_effects:
		weather_effects.set_budget_scale(graphics.weather_budget)
		weather_effects.set_quality(graphics.weather_quality)
	if workshop:
		for marker in workshop.markers.get_children():
			if marker.has_method("apply_quality"): marker.apply_quality(graphics.level)
	if effects: effects.apply_quality(graphics)
	if ghost: ghost.apply_quality(graphics)
	if hud:
		hud.graphics_quality.select(display_settings.quality-1)
		hud.sync_display(display_settings)
	_check_race_weather()
	weather_preferences.set_value("quality",graphics.weather_quality)
	_save_presentation_settings()

func _save_presentation_settings() -> void:
	if preferences_enabled and display_settings.save_preferences()!=OK and hud:
		hud.toast("Could not save settings. Check available disk space.")

func set_camera_setting(view: String, key: String, value: Variant) -> void:
	if automated or not camera_settings.set_value(view,key,value): return
	hud.sync_camera_settings(camera_settings)
	if preferences_enabled: camera_settings.save_preferences()

func reset_camera_settings(view: String = "all") -> void:
	if automated: return
	if view=="all": camera_settings.reset()
	else: camera_settings.reset_view(view)
	hud.sync_camera_settings(camera_settings)
	if preferences_enabled: camera_settings.save_preferences()

func set_camera_preset(action: String, view: String, name: String, new_name: String) -> void:
	if automated: return
	var changed = false
	match action:
		"apply": changed = camera_settings.apply_preset(view,name)
		"save": changed = camera_settings.save_preset(view,name)
		"replace": changed = camera_settings.save_preset(view,name,true)
		"rename": changed = camera_settings.rename_preset(view,name,new_name)
		"delete": changed = camera_settings.delete_preset(view,name)
	if not changed:
		hud.toast("Choose a saved preset, or enter an unused name (1–40 characters).")
		return
	hud.sync_camera_settings(camera_settings)
	if preferences_enabled: camera_settings.save_preferences()

func _sync_camera_preview() -> void:
	if not hud or not camera_preview: return
	var available: bool = initialized and sim!=null and not sim.crashed and not transitioning and not returning_to_summit and not quitting and not (loading and loading.busy) and (workshop==null or workshop.mode.is_empty())
	hud.camera_options.set_preview_available(available,hud.menu_mode=="paused" and not session.finished)
	if hud.camera_options.preview_active and (not available or not hud.camera_options.camera_tab_visible() or (not application_focused and not automated)):
		set_camera_preview(false)

func set_camera_preview(enabled: bool) -> void:
	if not hud or not camera_preview or not hud.camera_options.preview_toolbar: return
	if enabled:
		_sync_camera_preview()
		if not hud.camera_options.preview_supported or not hud.weather_panel.visible or not hud.camera_options.camera_tab_visible(): return
		active = false
		camera.clear_look_input()
		camera_preview.reset()
		hud.camera_options.set_preview(true,sim.speed_kmh())
	else:
		if not hud.camera_options.preview_active: return
		hud.camera_options.set_preview(false)
		camera_preview.reset()
		_restore_riding_camera()
	_sync_camera_controls()
	_reset_screen_effects()
	weather_effects.reset()
	_clear_storm_effects()

func set_display_setting(key: String, value: Variant) -> void:
	if key in PCGraphics.Output.KEYS:
		display_settings.display.restore({key:value})
		if key=="fps_limit": Engine.max_fps = display_settings.fps_limit
		else: display_settings.apply_display(get_window())
		display_settings.apply_viewport(get_viewport())
		if hud: hud.sync_display(display_settings)
		_save_presentation_settings()
		return
	display_settings.set_graphics_value(key,value)
	apply_graphics_configuration()
	if key=="frame_generation" and display_settings.display_mode=="fullscreen": display_settings.apply_display(get_window())

func load_mountain(definition, generated_field) -> void:
	_invalidate_crash_recovery()
	_leave_race_weather()
	_cancel_summit_return()
	if transitioning: return
	if generated_field.GENERATOR_ID!="alpine-drainage" or MountainDefinition.from_field(generated_field).identity()!=definition.identity():
		mountain_library.status.text = "The preview does not match this mountain. Regenerate it first."
		return
	active = false
	effects.stop_audio()
	transitioning = true
	loading.configure_feedback(hud.feedback)
	loading.begin("Loading your mountain", "Preparing the terrain and scenery…")
	await loading.draw_frame()
	get_tree().set_meta("mountain_to_load",{"definition":definition,"field":generated_field})
	_remember_world_settings()
	var error = get_tree().reload_current_scene()
	if error!=OK:
		get_tree().remove_meta("mountain_to_load")
		get_tree().remove_meta("world_reload_settings")
		transitioning = false
		loading.finish()
		mountain_library.status.text = "Could not load the mountain. Your preview is still available."

func _remember_world_settings() -> void:
	_remember_application_weather()
	get_tree().set_meta("world_reload_settings",{"graphics":graphics.level,"display":display_settings.snapshot(),"tuning":sim.tuning.duplicate(true),
		"camera":camera_settings.snapshot(),
		"modified":physics_modified,
		"close_view":camera.close_view,"muted":effects.muted,"motion_effects":camera.effects_enabled,
		"interface":hud.feedback.snapshot(),"hud_layout":hud.widget_layout.snapshot(),"hud_visible":hud.widget_layout.global_visible,"interface_layout":hud.shell_layout.snapshot(),"wind":effects.wind.snapshot(),"voice":voice.snapshot(),"riding_audio":effects.sfx.snapshot()})

func drop_from_summit() -> void:
	if not summit_ready or not active or returning_to_summit or not summit_drop_armed: return
	voice.reset()
	summit_ready = false
	sim.reset(field.launch_point(sim.heading),sim.heading)
	sim.prime_contacts(field)
	skier.reset_animation(sim)
	previous_position = sim.position
	camera.reset()
	camera_stick_armed = false
	effects.reset()
	weather_effects.reset()
	_clear_storm_effects()

func _resolve_zone_exit(dt: float, before: Vector3, after: Vector3) -> bool:
	var exit_fraction: float = mountain_zone.swept_exit_fraction(before,after)
	if exit_fraction<0.0: return false
	if benchmark_input.is_valid():
		session.elapsed += dt*exit_fraction
		session.finished = true
		active = false
		return true
	if "--autoplay" in OS.get_cmdline_user_args():
		session.elapsed += dt*exit_fraction
		session.finished = true
		active = false
		_finish_automation.call_deferred()
		return true
	# Resolve event order before RunSession can persist a time or a replay.
	# An extreme tick can also reach the old rectangular safety boundary. That
	# later safety failure must not erase a finish before the circular return line.
	var can_finish = not sim.crashed or sim.crash_reason==field.boundary_message
	var finish: float = session.finish_fraction(before,after) if timed and can_finish else -1.0
	var valid_finish = finish>=0.0 and finish<exit_fraction
	if valid_finish:
		session.step(dt,before,after,sim,intent)
		_capture_ghost_pose((session.elapsed-session.previous_elapsed)/dt)
	_begin_summit_return(valid_finish)
	return true

func _begin_summit_return(valid_finish: bool) -> void:
	if returning_to_summit or transitioning or quitting or not mountain_zone.enabled: return
	summit_return_voice = voice.Events.finish_event(session) if valid_finish else ""
	return_message = "Finished %s · Back at the summit" % Session.format_time(session.elapsed) if valid_finish else ("Race ended at the boundary · Back at the summit" if timed else "Back at the summit · Choose your descent")
	if not valid_finish:
		session.eligible = false
		session.recording = null
		session.finished = false
	_invalidate_crash_recovery()
	returning_to_summit = true
	return_paused = false
	active = false
	if skier.ragdoll.running: skier.ragdoll.set_frozen(true)
	hud.hide_menu()
	hud.update_summit_return(INF,false)
	return_overlay.begin(_return_to_summit_midpoint,_return_to_summit_complete,hud.feedback.reduced_motion)

func _return_to_summit_midpoint() -> void:
	if not returning_to_summit or transitioning or quitting: return
	_leave_race_weather()
	# A race's restart spawns at its authored start. Explicitly leave it first.
	session.configure_free(current_mountain.identity(),field.finish_z,field.finish_z)
	workshop.show_race(null)
	timed = false
	restart(true)
	summit_drop_armed = false
	active = false

func _return_to_summit_complete() -> void:
	if not returning_to_summit or transitioning or quitting: return
	returning_to_summit = false
	active = not return_paused
	if return_paused: hud.show_menu("paused")
	elif not summit_return_voice.is_empty(): voice.request(summit_return_voice)
	summit_return_voice = ""
	hud.toast(return_message)

func _cancel_summit_return() -> void:
	summit_return_voice = ""
	if is_instance_valid(return_overlay): return_overlay.cancel()
	returning_to_summit = false
	return_paused = false

func _exit_tree() -> void:
	_checkpoint_weather()
	if camera_controls_active and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cancel_summit_return()

func _generate_mountain(seed_number: int, version: int = MountainDefinition.CURRENT_VERSION):
	GenerationEstimates.configure(generation_job,seed_number,GenerationSettings.preset())
	loading.stage(GenerationEstimates.label(GenerationEstimates.estimate(seed_number,GenerationSettings.preset())))
	await loading.draw_frame()
	return await loading.run_data(MountainDefinition.generate.bind(seed_number,version,{},generation_job),generation_job)

func _cancel_startup() -> void:
	_remember_application_weather()
	# Retain only a compact retry recipe, never a partially constructed mountain.
	if not startup_race_code.is_empty(): get_tree().set_meta("race_to_load",startup_race_code)
	elif current_mountain: get_tree().set_meta("mountain_retry_recipe",current_mountain)
	initialized = false; active = false
	if effects: effects.stop_audio()
	for child in get_children():
		if child!=loading and not child.is_queued_for_deletion(): child.queue_free()
	for member in ["world","crash_collision","weather","skier","ghost","camera","menu_camera","effects","voice","weather_effects","storm_effects","vectors","hud","mountain_library","workshop","return_overlay","speed_periphery"]:
		set(member,null)
	field = null; current_mountain = null; mountain_zone = null; session = null
	loading.cancelled_startup()

func preview_display(values: Dictionary) -> void:
	display_settings.display.begin_preview(values,Time.get_ticks_msec(),get_window())
	display_settings.apply_display(get_window())
	hud.settings_pages.recovery.popup_centered(Vector2i(560,180))
	hud.settings_pages.recovery.get_cancel_button().grab_focus()
	_update_display_recovery()

func keep_display() -> void:
	hud.settings_pages.output_dirty = false
	display_settings.display.keep()
	hud.settings_pages.recovery.hide()
	hud.sync_display(display_settings)
	_save_presentation_settings()

func revert_display() -> void:
	if display_settings.display.pending.is_empty(): return
	hud.settings_pages.output_dirty = false
	display_settings.display.revert()
	display_settings.apply_display(get_window())
	hud.settings_pages.recovery.hide()
	hud.sync_display(display_settings)

func _update_display_recovery() -> void:
	var output = display_settings.display
	if output.pending.is_empty(): return
	if output.expired(Time.get_ticks_msec()): revert_display(); return
	hud.settings_pages.recovery.dialog_text = "Keep this display mode?\nReverting in %d seconds." % ceili((output.deadline_ms-Time.get_ticks_msec())/1000.0)

func _initialize_weather() -> void:
	weather = Weather.new(); add_child(weather)
	var remembered: Dictionary = get_tree().get_meta("weather_application",{})
	if not remembered.is_empty():
		weather_preferences.restore(remembered.preferences)
		free_weather_snapshot = remembered.free.duplicate(true)
		weather.restore(remembered.live)
	else:
		if preferences_enabled: weather_preferences.load_preferences()
		var launch_rng = RandomNumberGenerator.new()
		if preferences_enabled: launch_rng.randomize()
		else: launch_rng.seed = 849205174
		var startup: Dictionary = weather_preferences.launch(launch_rng,OS.get_cmdline_user_args(),preferences_enabled)
		weather.seed_stream(launch_rng.randi() if preferences_enabled else 849205174)
		display_settings.set_graphics_value("weather_quality",startup.quality)
		graphics = display_settings.profile()
		startup.quality = 2 # FX budget and the shared sky remain separate, as in graphics settings.
		weather.configure_launch(startup,weather_preferences if preferences_enabled else null)
	weather.choice_changed.connect(_weather_choice)
	weather.transients_cleared.connect(_clear_storm_effects)
	weather_preferences.changed.connect(_save_weather_preferences)
	_remember_application_weather()

func _suspend_free_weather() -> void:
	if free_weather_snapshot.is_empty(): free_weather_snapshot = weather.snapshot()
	_clear_storm_effects()
	_checkpoint_weather()

func _leave_race_weather() -> void:
	if free_weather_snapshot.is_empty(): return
	weather.restore(free_weather_snapshot)
	free_weather_snapshot.clear()
	weather.lightning = weather_preferences.values.lightning
	weather.rare_storms = weather_preferences.values.rare_storms
	# A failed race load returns to free skiing, including from a previous race.
	if session and session.race:
		if current_mountain: session.configure_free(current_mountain.identity(),field.finish_z,field.finish_z if field.is_summit_mountain() else 0.0)
		else: session.configure()
		timed = false
	_remember_application_weather()
	_sync_weather_ui()

func _weather_choice(key: String, value: Variant) -> void:
	if session and session.race:
		_check_race_weather()
		if key=="quality": weather_preferences.set_value(key,value)
	else: weather_preferences.set_value(key,value)
	_sync_weather_ui()

func _set_weather_option(key: String, value: Variant) -> void:
	weather_preferences.set_value(key,value)
	if key=="lightning":
		weather.lightning = weather_preferences.values.lightning
		_clear_storm_effects()
	if key=="rare_storms":
		weather.rare_storms = weather_preferences.values.rare_storms
		if not weather.rare_storms: weather.pending_storm = ""
	_sync_weather_ui()

func _check_race_weather() -> void:
	if not session or not session.race or not weather: return
	var reason = ""
	if graphics.weather_quality==0 or weather.quality==0: reason = "Weather FX is Off"
	elif weather.automatic or weather.daylight.automatic: reason = "Automatic weather or daylight enabled"
	elif weather.selected_preset!=session.race.weather_preset or not is_equal_approx(weather.daylight.hour,Weather.Rules.TIMES[session.race.time_band]): reason = "Authored weather or time changed"
	if not reason.is_empty():
		var changed: bool = session.practice_reason.is_empty()
		session.mark_practice(reason)
		if changed:
			if hud: hud.toast("Practice · "+reason+". Retry to restore race conditions.")
			_sync_weather_ui()

func _sync_weather_ui() -> void:
	if not hud or not weather: return
	hud.sync_weather(weather)
	for key in hud.weather_options:
		var control = hud.weather_options[key]
		if control is CheckButton: control.set_pressed_no_signal(weather_preferences.values[key])
		else: control.select(weather_preferences.values[key])
	if hud.weather_practice:
		hud.weather_practice.text = "Practice · "+session.practice_reason+". Retry to restore authored conditions." if session and not session.practice_reason.is_empty() else "Race conditions are fixed. Changing weather/time or using FX Off makes this attempt practice." if session and session.race else ""

func _clear_storm_effects() -> void:
	if weather: weather.state.lightning_flash = 0.0
	if is_instance_valid(storm_effects): storm_effects.clear_transients(weather.active_seconds if weather else 0.0)
	if world and world.weather_material: world.render_state.shader(world.weather_material,"lightning_flash",0.0)

func _checkpoint_weather() -> void:
	if not weather: return
	var saved: Dictionary = free_weather_snapshot if not free_weather_snapshot.is_empty() else weather.snapshot()
	weather_preferences.free_seconds = saved.free_seconds
	weather_preferences.cooldown = saved.cooldown
	weather_preferences.storm_at_exit = saved.automatic_storm or saved.selected_preset in ["snowstorm","thunderstorm"]
	weather_checkpoint = weather.free_seconds
	_save_weather_preferences()

func _save_weather_preferences() -> void:
	if preferences_enabled and weather_preferences.save_preferences()!=OK and hud: hud.toast("Could not save weather preferences.")

func _remember_application_weather() -> void:
	if not weather: return
	_checkpoint_weather()
	get_tree().set_meta("weather_application",{"live":weather.snapshot(),"free":free_weather_snapshot.duplicate(true),"preferences":weather_preferences.snapshot()})
