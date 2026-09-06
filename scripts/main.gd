extends Node3D
const Terrain = preload("res://scripts/world/test_slope.gd")
const World = preload("res://scripts/world/alpine_world.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Router = preload("res://scripts/core/input_router.gd")
const Session = preload("res://scripts/core/run_session.gd")
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const ChaseCamera = preload("res://scripts/presentation/chase_camera.gd")
const Effects = preload("res://scripts/presentation/speed_effects.gd")
const Vectors = preload("res://scripts/presentation/debug_vectors.gd")
const HUD = preload("res://scripts/ui/hud.gd")
const Weather = preload("res://scripts/presentation/weather_controller.gd")
const WeatherEffects = preload("res://scripts/presentation/weather_effects.gd")
const Graphics = preload("res://scripts/presentation/graphics_quality.gd")
const Race = preload("res://scripts/racing/race_definition.gd")
const Workshop = preload("res://scripts/racing/race_workshop.gd")
const Ghost = preload("res://scripts/presentation/personal_best_ghost.gd")
const MountainDefinition = preload("res://scripts/world/mountain_definition.gd")
const MountainLibrary = preload("res://scripts/ui/mountain_library.gd")
var current_mountain = null
var mountain_library
var workshop
var ghost
var graphics = Graphics.preset(1)
const terrain_renderer = "legacy"
var mountain_seed: int = -1
var benchmark_no_captures: bool = false
var benchmark_resolution = Vector2i(1440,900)
var benchmark_actual_pixels = Vector2i.ZERO
var draw_samples: Array[float] = []
var peak_video_memory_bytes: int = 0
var weather
var weather_effects
var field
var world
var sim: SkiSimulation
var input_router
var session
var skier
var crash_collision
var camera
var effects
var vectors
var hud
var intent = RiderInput.new()
var active: bool = false
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
var jump_armed: bool = false
var workbench_return: String = "title"
var speed_periphery: ColorRect
var effect_time: float = 0.0
var quitting: bool = false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	input_router = Router.new()
	var values = preload("res://config/ski_default.tres").duplicate(true)
	sim = Simulation.new(values)
	field = Terrain.new()
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
	# A scene reload reconstructs both terrain and presentation from the race's
	# pinned mountain reference. Never silently run a race on the current seed.
	var pending_race = null
	var pending_mountain = null
	var load_warning = ""
	var reload_settings: Dictionary = get_tree().get_meta("world_reload_settings",{})
	get_tree().remove_meta("world_reload_settings")
	if not reload_settings.is_empty():
		graphics = Graphics.preset(reload_settings.graphics)
		sim.tuning = reload_settings.tuning
		physics_modified = reload_settings.modified
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
				field = MountainDefinition.generate(seed_result.seed,seed_result.version)
				current_mountain = MountainDefinition.from_field(field)
				mountain_seed = field.seed_value
			else: load_warning = seed_result.error
	if get_tree().has_meta("race_to_load"):
		var parsed = Race.decode(get_tree().get_meta("race_to_load"))
		get_tree().remove_meta("race_to_load")
		if parsed.has("race"):
			var rebuilt = Race.reconstruct_surface(parsed.race.mountain)
			if rebuilt.has("field"):
				pending_race = parsed.race
				field = rebuilt.field
				mountain_seed = pending_race.mountain.scenery_seed
				current_mountain = MountainDefinition.from_field(field) if field.GENERATOR_ID=="alpine-drainage" else null
			else: load_warning = rebuilt.error
		else: load_warning = parsed.error
	world = World.new()
	world.quality = graphics
	world.mountain_seed = mountain_seed
	add_child(world)
	world.build(field)
	crash_collision = preload("res://scripts/world/crash_collision.gd").new()
	crash_collision.world = world
	add_child(crash_collision)
	weather = Weather.new()
	add_child(weather)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--time-of-day="):
			weather.set_time_of_day(arg.get_slice("=",1))
		elif arg == "--cloud-shadows-off":
			world.cloud_lighting.shadow_strength = 0.0
		elif arg.begins_with("--weather="):
			weather.set_preset(arg.get_slice("=",1))
		elif arg.begins_with("--weather-quality="):
			var quality_id = ["off","low","high"].find(arg.get_slice("=",1))
			if quality_id >= 0:
				weather.set_quality(quality_id)
	weather.set_automatic("--weather-auto" in OS.get_cmdline_user_args())
	weather.set_time_cycle("--time-cycle" in OS.get_cmdline_user_args())
	if not reload_settings.is_empty():
		weather.set_preset(reload_settings.weather)
		weather.set_quality(reload_settings.weather_quality)
		weather.set_automatic(reload_settings.weather_auto)
		weather.daylight.hour = reload_settings.hour
		weather.set_time_cycle(reload_settings.time_cycle)
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
	camera.near = 0.15
	camera.far = 8500.0
	add_child(camera)
	camera.current = true
	effects = Effects.new()
	effects.lighting = world.cloud_lighting
	add_child(effects)
	weather_effects = WeatherEffects.new()
	add_child(weather_effects)
	vectors = Vectors.new()
	add_child(vectors)
	vectors.visible = false
	var motion_layer = CanvasLayer.new()
	motion_layer.layer = 0
	add_child(motion_layer)
	speed_periphery = ColorRect.new()
	speed_periphery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speed_periphery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var motion_material = ShaderMaterial.new()
	motion_material.shader = preload("res://assets/speed_periphery.gdshader")
	speed_periphery.material = motion_material
	motion_layer.add_child(speed_periphery)
	hud = HUD.new()
	add_child(hud)
	if not automated and not "--autoplay" in OS.get_cmdline_user_args(): skier.appearance.load_preferences()
	hud.build_skier_controls(skier.appearance,not automated and not "--autoplay" in OS.get_cmdline_user_args())
	hud.build_tuning(sim.tuning)
	hud.start_requested.connect(start_run)
	hud.restart_requested.connect(restart)
	hud.resume_requested.connect(resume)
	hud.lab_speed_requested.connect(start_speed_lab)
	hud.tuning_changed.connect(func(): physics_modified = true; session.eligible = false)
	hud.defaults_requested.connect(func(): physics_modified = false; restart())
	hud.workbench_closed.connect(close_workbench)
	hud.quit_requested.connect(quit_cleanly)
	hud.weather_preset_requested.connect(weather.set_preset)
	hud.weather_auto_requested.connect(weather.set_automatic)
	hud.weather_quality_requested.connect(weather.set_quality)
	hud.time_of_day_requested.connect(weather.set_time_of_day)
	hud.time_cycle_requested.connect(weather.set_time_cycle)
	hud.graphics_quality_requested.connect(set_graphics_quality)
	hud.graphics_quality.select(graphics.level)
	weather.settings_changed.connect(func(): hud.sync_weather(weather))
	hud.sync_weather(weather)
	mountain_library = MountainLibrary.new()
	add_child(mountain_library)
	mountain_library.build(self)
	hud.mountains_requested.connect(mountain_library.open)
	hud.set_mountain(current_mountain)
	workshop = Workshop.new()
	add_child(workshop)
	workshop.build(self)
	hud.races_requested.connect(workshop.open_library)
	hud.competition_requested.connect(open_competition)
	hud.ghost_visibility_requested.connect(set_ghost_visible)
	sim.reset(field.spawn_point(),field.spawn_heading())
	sim.prime_contacts(field)
	previous_position = sim.position
	if not reload_settings.is_empty():
		camera.close_view = reload_settings.close_view
		effects.muted = reload_settings.muted
	if pending_race:
		play_custom_race(pending_race)
	elif pending_mountain:
		start_run(false)
	elif get_tree().has_meta("standard_to_load"):
		var standard_timed: bool = get_tree().get_meta("standard_to_load")
		get_tree().remove_meta("standard_to_load")
		start_run(standard_timed)
	if not load_warning.is_empty(): hud.toast(load_warning)
	print("ALPINE APEX | terrain %.1f ms | %d triangles | %d obstacles | 120 Hz" % [world.generation_ms,world.terrain_triangles,field.obstacles.size()])
	if "--autoplay" in OS.get_cmdline_user_args():
		get_window().size = benchmark_resolution
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
	if sim == null or not active:
		return
	var tick_start = Time.get_ticks_usec()
	previous_position = sim.position
	intent = input_router.sample()
	if not Input.is_action_pressed("jump"):
		jump_armed = true
	intent.jump = intent.jump and jump_armed
	if automated:
		# Benchmark input is fixed even if someone types while its window is
		# focused. Physical keyboard/gamepad input must not alter comparisons.
		intent = RiderInput.new()
		intent.tuck = 1.0
		automated_ticks += 1
	if summit_ready:
		if absf(intent.steer)>.01:
			var heading = wrapf(sim.heading-intent.steer*dt*1.4,-PI,PI)
			sim.reset(field.spawn_point(),heading)
			sim.prime_contacts(field)
		if intent.tuck>.1: drop_from_summit()
		return
	sim.step(dt,intent,field)
	if timed and not sim.crashed:
		var completed: bool = session.step(dt,previous_position,sim.position,sim,intent)
		if completed:
			active = false
			hud.show_result(session,sim.peak_speed*3.6)
	elif not timed:
		session.elapsed += dt
		if current_mountain and field.reached_base(sim.position) and not sim.crashed:
			session.finished = true
			active = false
			hud.show_menu("finished","Mountain base reached.\nExplore another face or create a race.")
	if sim.crashed:
		skier.ragdoll.start(sim)
		skier.ragdoll.saved_close_view = camera.close_view
		camera.close_view = false
		active = false
		hud.show_menu("crashed",sim.crash_reason)
	cpu_tick_ms = lerpf(cpu_tick_ms,(Time.get_ticks_usec()-tick_start)/1000.0,0.05)
	if automated:
		if automated_ticks in screenshot_ticks:
			_capture("run_%04d" % automated_ticks)
		if sim.crashed or session.finished or automated_ticks > 9000:
			_finish_automation.call_deferred()

func _process(dt: float) -> void:
	if sim == null:
		return
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
	skier.pose(sim,fraction)
	var p: Vector3 = skier.global_position
	var ghost_time = lerpf(session.previous_elapsed,session.elapsed,fraction) if active else session.elapsed
	if skier.ragdoll.running: p = skier.ragdoll.focus()-Vector3.UP*.6
	crash_collision.prepare(p)
	ghost.update_ghost(session.reference_replay,ghost_time,p,timed and workshop.mode.is_empty() and hud.menu_mode!="title")
	skier.body_pivot.visible = skier.ragdoll.running or not camera.close_view
	var title: bool = (hud.menu.visible or hud.weather_panel.visible) and hud.menu_mode == "title"
	if workshop and not workshop.mode.is_empty():
		workshop.update_survey(dt)
	else:
		camera.update_camera(sim,field,p,dt,title,active)
		if summit_ready and not title:
			# A summit overview makes the chosen face visible before committing.
			var forward = Vector3(sin(sim.heading),0,cos(sim.heading))
			var look = p+forward*400
			look.y = field.sample(look.x,look.z).height
			camera.position = p-forward*30+Vector3.UP*45
			camera.look_at(look)
		if skier.ragdoll.running: camera.look_at(skier.ragdoll.focus())
	weather.update_weather(dt,active,title)
	world.update_weather(weather.state,dt,active or title)
	weather_effects.update_weather(weather.state,camera,p,field,dt,active,title,camera.motion_intensity if camera.effects_enabled else 0.0,weather.quality)
	speed_periphery.visible = active and camera.effects_enabled and camera.motion_intensity>0.005
	speed_periphery.material.set_shader_parameter("intensity",camera.motion_intensity)
	if active:
		effect_time += dt
	speed_periphery.material.set_shader_parameter("arcade_intensity",camera.motion_intensity if active and camera.effects_enabled and weather.state.enabled else 0.0)
	speed_periphery.material.set_shader_parameter("effect_time",effect_time)
	effects.update_effects(sim,field,p,dt,active,weather.state)
	vectors.update_vectors(sim)
	hud.update_hud(sim,session,intent,input_router.device_label(),frame_ms,cpu_tick_ms,dt,timed,weather.state.label+" · "+weather.state.time_label)
	if workshop and not workshop.mode.is_empty():
		hud.mode_label.text = "CREATE A RACE / WORLD SURVEY" if workshop.mode=="create" else "SAVED & SHARED RACES / WORLD SURVEY"
		hud.footer_controls.text = "WASD / ARROWS  PAN      SCROLL  ZOOM      CLICK SNOW  PLACE ENDPOINT      ESC  BACK"
	elif mountain_library and mountain_library.panel.visible:
		hud.mode_label.text = "MOUNTAIN LIBRARY"
		hud.footer_controls.text = "GENERATE A SEED   ·   EXPLORE THE TERRAIN   ·   SAVE AND SHARE   ·   ESC BACK"
	elif summit_ready:
		var bearing = posmod(roundi(180-rad_to_deg(sim.heading)),360)
		var compass = ["N","NE","E","SE","S","SW","W","NW"][posmod(roundi(bearing/45.0),8)]
		hud.mode_label.text = "SUMMIT  /  %03d° %s  /  CHOOSE YOUR DESCENT" % [bearing,compass]
		hud.footer_controls.text = "A / D  OR  LEFT STICK  CHOOSE DIRECTION     ·     W / ENTER / RIGHT TRIGGER  DROP IN     ·     ESC  PAUSE"
	else:
		hud.footer_controls.text = hud.SKI_CONTROLS

func _unhandled_input(event: InputEvent) -> void:
	if automated:
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
		weather_effects.reset()
		hud.toast("FIRST PERSON" if camera.close_view else "CHASE CAMERA")
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		camera.effects_enabled = not camera.effects_enabled
		hud.toast("MOTION EFFECTS ON" if camera.effects_enabled else "MOTION EFFECTS OFF")
	elif event.is_action_pressed("debug_overlay"):
		hud.debug_panel.visible = not hud.debug_panel.visible
		vectors.visible = hud.debug_panel.visible
	elif event.is_action_pressed("tuning"):
		if hud.tuning_panel.visible:
			close_workbench()
		else:
			workbench_return = "active" if active else hud.menu_mode
			hud.tuning_panel.visible = true
			active = false
			hud.hide_menu()
	elif event.is_action_pressed("toggle_audio"):
		effects.muted = not effects.muted
		hud.toast("AUDIO MUTED" if effects.muted else "AUDIO ON")
	elif event.is_action_pressed("toggle_hud"):
		hud.toggle_instruments()
	elif event.is_action_pressed("toggle_ghost"):
		set_ghost_visible(not ghost.enabled)
		hud.toast("PERSONAL-BEST GHOST ON" if ghost.enabled else "PERSONAL-BEST GHOST OFF")

func start_run(is_timed: bool = true) -> void:
	if current_mountain and not is_timed:
		session.configure_free(current_mountain.identity(),field.finish_z,field.finish_z if field.is_summit_mountain() else 0.0)
		workshop.show_race(null)
		timed = false
		restart()
		return
	if field.GENERATOR_ID!="laboratory" or field.seed_value != 849205174:
		active = false
		effects.stop_audio()
		get_tree().set_meta("standard_to_load",is_timed)
		_remember_world_settings()
		var reload_error = get_tree().reload_current_scene()
		if reload_error != OK:
			get_tree().remove_meta("standard_to_load")
			hud.show_menu("paused")
			hud.toast("Could not load the original test face. Please try again.")
		return
	session.configure()
	workshop.show_race(null)
	timed = is_timed
	restart()

func restart() -> void:
	summit_ready = not timed and session.race==null and field.is_summit_mountain()
	if skier.ragdoll.running: camera.close_view = skier.ragdoll.saved_close_view
	skier.ragdoll.stop()
	if session.race:
		sim.reset(session.race.start,session.race.heading)
	else:
		sim.reset(field.spawn_point(),field.spawn_heading())
	session.reset()
	session.eligible = not physics_modified and not automated and (session.race != null or (field.GENERATOR_ID=="laboratory" and field.seed_value == 849205174))
	sim.surface_normal = field.contact_normal(sim.position.x,sim.position.z)
	sim.prime_contacts(field)
	if timed: session.begin_capture(sim)
	previous_position = sim.position
	intent = RiderInput.new()
	jump_armed = false
	camera.reset()
	effects.reset()
	weather_effects.reset()
	effect_time = 0.0
	hud.hide_menu()
	hud.menu_mode = "racing"
	hud.tuning_panel.visible = false
	active = true

func open_competition() -> void:
	if active or hud.menu_mode=="racing":
		active = false
		hud.show_menu("paused")
	hud.tuning_panel.visible = false
	hud.open_competition(session)

func set_ghost_visible(enabled: bool) -> void:
	ghost.enabled = enabled
	hud.ghost_enabled = enabled
	hud.competition.ghost_toggle.set_pressed_no_signal(enabled)

func play_custom_race(race) -> void:
	var rebuilt = {"field":field} if workshop.matches_world(race) else Race.reconstruct_surface(race.mountain)
	if not rebuilt.has("field"):
		workshop.status.text = rebuilt.error
		hud.toast(rebuilt.error)
		return
	var target_field = rebuilt.field
	var error: String = race.validate_surface(target_field)
	if not error.is_empty():
		workshop.status.text = error
		hud.toast(error)
		return
	if not workshop.matches_world(race):
		active = false
		effects.stop_audio()
		get_tree().set_meta("race_to_load",race.share_text())
		_remember_world_settings()
		var reload_error = get_tree().reload_current_scene()
		if reload_error != OK:
			get_tree().remove_meta("race_to_load")
			workshop.status.text = "Could not load the race's mountain. Please try again."
		return
	session.configure(race)
	workshop.close()
	timed = true
	restart()

func resume() -> void:
	if sim.crashed or session.finished:
		hud.show_menu("crashed" if sim.crashed else "finished",sim.crash_reason if sim.crashed else Session.format_time(session.elapsed))
		return
	hud.hide_menu()
	sim.reset_pose_history()
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

func close_workbench() -> void:
	hud.tuning_panel.visible = false
	if workbench_return == "active":
		resume()
	else:
		hud.show_menu(workbench_return,sim.crash_reason if sim.crashed else Session.format_time(session.elapsed))

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and skier and skier.ragdoll.running:
		skier.ragdoll.set_frozen(true)
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN and skier and skier.ragdoll.running and skier.ragdoll.elapsed<15.0:
		skier.ragdoll.set_frozen(false)
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_cleanly()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and active and not automated:
		active = false
		if hud:
			hud.show_menu("paused")

func quit_cleanly() -> void:
	if quitting:
		return
	quitting = true
	active = false
	automated = false
	if effects:
		effects.stop_audio()
	# Let the native audio callback release its loop playbacks before the
	# engine's Resource/ObjectDB cleanup (headless has no playback thread).
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(0.10).timeout
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
	data.weather_quality = weather.quality
	data.weather_particle_budget = weather_effects.particle_budget()
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
	graphics = Graphics.preset(level)
	world.apply_graphics(graphics)
	if hud:
		hud.graphics_quality.select(graphics.level)

func load_mountain(definition, generated_field) -> void:
	if generated_field.GENERATOR_ID!="alpine-drainage" or MountainDefinition.from_field(generated_field).identity()!=definition.identity():
		mountain_library.status.text = "The preview does not match this mountain. Regenerate it first."
		return
	active = false
	effects.stop_audio()
	get_tree().set_meta("mountain_to_load",{"definition":definition,"field":generated_field})
	_remember_world_settings()
	var error = get_tree().reload_current_scene()
	if error!=OK:
		get_tree().remove_meta("mountain_to_load")
		get_tree().remove_meta("world_reload_settings")
		mountain_library.status.text = "Could not load the mountain. Your preview is still available."

func _remember_world_settings() -> void:
	get_tree().set_meta("world_reload_settings",{"graphics":graphics.level,"tuning":sim.tuning.duplicate(true),
		"modified":physics_modified,"weather":weather.selected_preset,"weather_quality":weather.quality,
		"weather_auto":weather.automatic,"hour":weather.daylight.hour,"time_cycle":weather.daylight.automatic,
		"close_view":camera.close_view,"muted":effects.muted})

func drop_from_summit() -> void:
	if not summit_ready or not active: return
	summit_ready = false
	sim.reset(field.launch_point(sim.heading),sim.heading)
	sim.prime_contacts(field)
	previous_position = sim.position
	camera.reset()
	effects.reset()
	weather_effects.reset()
