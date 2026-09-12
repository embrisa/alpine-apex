extends SceneTree
## Bounded native evidence only: production solver/presentation, explicit lab.
## No preferences, records, hardware output, audio or performance acceptance.
const DT = 1.0 / 120.0
const FPS = 30
var output = "res://artifacts/presentation_comfort/unused"
var game
var rows: Array = []
var failures: Array = []
var checks = 0
var sample_input = RiderInput.new()
var setup_ms = 0
var source_hashes: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value and message not in failures: failures.append(message)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = "res://" + arg.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or DirAccess.dir_exists_absolute(output):
		printerr("Native renderer and a new output directory are required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	for path in ["scripts/main.gd","scripts/core/ski_simulation.gd","scripts/presentation/skier_full_motion.gd",
		"scripts/presentation/skier_visual.gd","scripts/presentation/chase_camera.gd","scripts/presentation/camera_settings.gd",
		"scripts/ui/hud.gd","scripts/ui/settings_pages.gd","scripts/ui/interface_feedback.gd","tests/presentation_comfort_review.gd"]:
		source_hashes[path] = FileAccess.get_sha256("res://"+path)
	var start = Time.get_ticks_msec()
	set_meta("test_lab_fixture",true)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	game.benchmark_input = func(_tick): return sample_input
	root.add_child(game); current_scene = game
	while not game.initialized: await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.effects.haptic_hardware_enabled = false
	game.set_audio_muted(true); game.hud.feedback.muted = true
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "native"
	game.display_settings.render_scale = 1.0
	game.display_settings.fps_limit = FPS
	game.display_settings.apply_display(root,Vector2i(1280,720))
	game.display_settings.apply_viewport(root)
	game.set_graphics_quality(2)
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.weather.set_automatic(false); game.weather.set_time_cycle(false)
	game.reset_camera_settings()
	for frame in 15: await process_frame
	setup_ms = Time.get_ticks_msec()-start
	# Each independent sample starts at the same ordinary Speed Lab launch.
	# Six seconds answers entry/hold/turn/return/release without a full descent.
	for mode in ["chase","first_person","chase_effects_off"]:
		game.start_speed_lab(65)
		game.camera.close_view = mode == "first_person"; game.camera.reset()
		game.set_motion_effects(mode != "chase_effects_off")
		set_reduced(false)
		game.hud.toast_time = 0.0
		for frame in 180:
			var phase = "upright" if frame<15 else ("tuck" if frame<60 else ("turn" if frame<90 else ("tuck_return" if frame<150 else "release")))
			sample_input = RiderInput.new()
			sample_input.tuck = 1.0 if phase in ["tuck","tuck_return"] else 0.0
			sample_input.steer = 0.55 if phase == "turn" else 0.0
			await frame_capture(mode,phase,true)
		if mode == "chase":
			await menu_cycle(false)
			await menu_cycle(true)
			set_reduced(false)
			# Production view-switch handler, without synthetic physical-device claims.
			for close in [true,false]:
				game.automated = false
				var event = InputEventAction.new(); event.action = "camera_mode"; event.pressed = true
				game._unhandled_input(event); game.automated = true
				check(game.camera.close_view == close,"View switch routes through production handler")
				sample_input = RiderInput.new()
				for frame in 15: await frame_capture("view_switch","first_person" if close else "chase",true)
	for path in source_hashes:
		check(source_hashes[path]==FileAccess.get_sha256("res://"+path),"Source stable: "+path)
	var report = {"checks":checks,"failures":failures,"frames":rows,"setup_wall_ms":setup_ms,"source_hashes":source_hashes,
		"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),
		"driver":RenderingServer.get_current_rendering_driver_name(),"model":game.sim.MODEL_VERSION,
		"fixture":game.field.GENERATOR_ID,"seed":game.field.seed_value,"fps":FPS,"fixed_tick_hz":120,
		"pixels":[1280,720],"graphics_level":game.graphics.level,"camera_settings":game.camera_settings.snapshot(),
		"capture_overhead":true,"hardware_verified":false,"listening_verified":false,
		"stop_reason":"completed bounded frame schedule","preferences_enabled":game.preferences_enabled}
	FileAccess.open(output+"/review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("COMFORT_REVIEW ",JSON.stringify({"checks":checks,"failures":failures,"frames":rows.size(),"setup_wall_ms":setup_ms}))
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func menu_cycle(reduced: bool) -> void:
	var label = "menu_reduced" if reduced else "menu_normal"
	set_reduced(reduced)
	game.active = false; game.hud.show_menu("paused")
	var tick = game.sim.ticks
	var position = game.sim.position
	for frame in 15: await frame_capture(label,"pause",false)
	game.hud.open_settings()
	for i in game.hud.settings_tabs.get_tab_count():
		if game.hud.settings_tabs.get_tab_title(i)=="Interface & HUD": game.hud.settings_tabs.current_tab = i
	for frame in 15: await frame_capture(label,"settings",false)
	game.hud.close_weather()
	for frame in 15: await frame_capture(label,"back_to_pause",false)
	check(game.sim.ticks==tick and game.sim.position==position,"Pause/settings holds solver position and tick")
	game.resume(); sample_input = RiderInput.new()
	for frame in 15: await frame_capture(label,"resume",true)

func set_reduced(value: bool) -> void:
	for button in game.hud.settings_tabs.find_children("*","CheckButton",true,false):
		if button.text == "Reduce interface motion":
			button.button_pressed = value
			check(game.hud.feedback.reduced_motion==value,"Reduced-motion control matches applied state")
			return
	check(false,"Reduced-motion control found")

func frame_capture(clip: String, phase: String, riding: bool) -> void:
	if riding:
		for tick in 4: game._physics_process(DT)
	game._process(1.0/FPS)
	await process_frame
	await RenderingServer.frame_post_draw
	var index = rows.size()
	var path = "frame_%04d.jpg" % index
	var picture = root.get_texture().get_image()
	check(picture.save_jpg(output+"/"+path,.9)==OK,"Frame image saved")
	check(picture.get_size()==Vector2i(1280,720),"Requested native output size")
	check(not game.session.eligible and not game.preferences_enabled and not game.effects.haptic_hardware_enabled,"Fixture isolation")
	check(not game.sim.crashed,"No unexpected crash during bounded riding")
	if riding:
		check(not game.hud.footer.is_visible_in_tree(),"Riding controls footer hidden")
		check(game.hud.speed_dial.is_visible_in_tree() and game.hud.impact_bar.is_visible_in_tree(),"Riding speed and reserve instruments visible")
	var camera: Camera3D = root.get_camera_3d()
	var joints = game.skier.rendered_joints
	var rotations = game.skier.rendered_rotations
	var up: Vector3 = (rotations.LeftFoot.y+rotations.RightFoot.y).normalized()
	var forward: Vector3 = (rotations.LeftFoot.z+rotations.RightFoot.z).slide(up).normalized()
	var hip: float = (joints.Hips-(joints.LeftFoot+joints.RightFoot)*.5).dot(up)
	var pitch = rad_to_deg(atan2(rotations.Spine.y.dot(forward),rotations.Spine.y.dot(up)))
	rows.append({"frame":index,"path":path,"clip":clip,"phase":phase,"tick":game.sim.ticks,
		"riding":riding,"position":[game.sim.position.x,game.sim.position.y,game.sim.position.z],
		"speed_kmh":game.sim.speed_kmh(),"tuck":game.sim.effective_tuck,"grounded":game.sim.grounded,
		"hip_above_boots_m":hip,"chest_pitch_deg":pitch,"input_tuck":game.intent.tuck,"input_steer":game.intent.steer,
		"motion_diagnostics":game.skier.animation.full_motion.diagnostics.duplicate(),
		"footer":game.hud.footer.is_visible_in_tree(),"speed_visible":game.hud.speed_dial.is_visible_in_tree(),
		"reserve_visible":game.hud.impact_bar.is_visible_in_tree(),"menu_alpha":game.hud.menu.modulate.a,
		"reduced_motion":game.hud.feedback.reduced_motion,"effects_enabled":game.camera.effects_enabled,
		"camera":str(camera.global_transform),"fov":camera.fov})
