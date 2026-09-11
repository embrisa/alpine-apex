extends "res://tests/massif_playtest.gd"
## Native camera review. Scripted telemetry fixtures and real-solver clips
## are labeled separately; neither verifies physical mouse/gamepad hardware.
## ./godotw.ps1 --script tests/camera_playtest.gd '--' --views --benchmark-label=camera_upgrade_views --benchmark-resolution=3840x2160
var camera_frames: Array = []
var camera_failures: Array[String] = []
var baseline_script_path = ""
var record_motion = false

func run() -> void:
	await super.run()
	if not camera_failures.is_empty(): quit(1)

func inspect_massif() -> void:
	game.set_process(false)
	install_camera_baseline()
	record_motion = "--camera-motion-capture" in OS.get_cmdline_user_args()
	game.hud.hide_menu()
	game.summit_ready = false
	game.active = true
	for close in [false, true]:
		for kmh in [0, 30, 90, 150, 200, 240]:
			fixture(820, kmh, close)
			await present(1.2)
			await camera_capture("%s_%03d" % ["pov" if close else "chase", kmh], "frozen speed fixture")
	if "--camera-framing-only" in OS.get_cmdline_user_args():
		write_camera_report()
		return
	fixture(820, 150)
	game.sim.edge_angle = deg_to_rad(35)
	game.sim.lateral_acceleration = 1.3 * 9.81
	await present(0.6)
	await camera_capture("carve_loaded", "frozen force fixture")
	game.sim.edge_angle = 0.0
	game.sim.lateral_acceleration = 0.0
	game.sim.velocity *= 200.0 / 150.0
	await present(0.3)
	await camera_capture("carve_release_early", "frozen force fixture")
	await present(1.5)
	await camera_capture("carve_release_straight", "frozen force fixture")
	for pose in [{"label":"look_side", "delta":Vector2(900,0)}, {"label":"look_back", "delta":Vector2(1750,0)}, {"label":"look_down", "delta":Vector2(0,600)}, {"label":"look_up", "delta":Vector2(0,-500)}]:
		fixture(950, 0)
		game.camera.add_mouse_look(pose.delta)
		await present(0.8)
		await camera_capture(pose.label, "stationary orbit fixture")
	fixture(820, 150, true)
	game.camera.add_mouse_look(Vector2(900,200))
	await present(0.6)
	await camera_capture("pov_look_side", "frozen first-person fixture")
	game.camera.add_mouse_look(Vector2(4000,0))
	await present(0.2)
	await camera_capture("pov_yaw_limit", "large mouse delta fixture")
	if absf(rad_to_deg(game.camera.look_yaw)+120.0)>0.01: camera_failures.append("First-person yaw wrapped across its stop")
	fixture(820, 200)
	game.camera.effects_enabled = false
	await present(1.5)
	await camera_capture("comfort", "frozen speed fixture")
	game.sim.reset(field.spawn_point(), field.spawn_heading())
	game.sim.prime_contacts(field)
	game.skier.reset_animation(game.sim)
	game.summit_ready = true
	game.camera.reset()
	await present(0.5)
	await camera_capture("summit_forward", "summit orbit fixture")
	game.camera.add_mouse_look(Vector2(1000,0))
	await present(0.8)
	await camera_capture("summit_look", "summit orbit fixture")
	game.summit_ready = false
	await skiing_clip("turn_brake", 820, 120)
	await skiing_clip("jump_land", 820, 90)
	await skiing_clip("steep", 1600, 150)
	await skiing_clip("jump_land",820,90,true)
	if record_motion:
		await bump_clip(false)
		await bump_clip(true)
	await cursor_checks()
	game.active = false
	game.hud.show_menu("paused")
	_select_tab(game.hud.menu_tabs,"Tools")
	game.hud.weather_button.pressed.emit()
	_select_tab(game.hud.settings_tabs,"Controls")
	var help_page = game.hud.settings_tabs.get_current_tab_control() as ScrollContainer
	var camera_help = _expand_group(help_page,"Camera")
	await present(.1)
	help_page.ensure_control_visible(camera_help)
	await present(0.1)
	await camera_capture("controls_help", "UI fixture")
	write_camera_report()

func write_camera_report() -> void:
	var report = {"captures":camera_frames, "failures":camera_failures, "actual_pixels":[actual_pixels.x,actual_pixels.y], "display":game.display_settings.report(root,actual_pixels), "hardware_input_verified":false, "unranked":not game.session.eligible,"baseline_script":baseline_script_path,"motion_sequences":record_motion}
	FileAccess.open(OUTPUT+"/camera_review.json", FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CAMERA_REVIEW ", JSON.stringify({"captures":camera_frames.size(),"failures":camera_failures}))

func install_camera_baseline() -> void:
	# Optional archived presentation script permits matched before/after views
	# on the same current mountain and solver, without reverting shared files.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera-baseline-script="):
			baseline_script_path = arg.get_slice("=",1)
	if baseline_script_path.is_empty(): return
	var replacement = load(baseline_script_path).new()
	replacement.settings = game.camera_settings
	replacement.near = game.camera.near
	replacement.far = game.camera.far
	game.camera.queue_free()
	game.camera = replacement
	game.add_child(replacement)
	replacement.make_current()

func fixture(z: float, kmh: float, close: bool = false) -> void:
	place_on_face(face_index,z,close)
	game.sim.velocity = game.sim.support_basis().z * kmh / 3.6
	game.sim.reset_pose_history()
	game.camera.effects_enabled = true
	game.camera.reset()
	game.active = true
	game.summit_ready = false

func present(seconds: float) -> void:
	for frame in roundi(seconds * 60):
		game._process(1.0/60.0)
		await process_frame

func camera_capture(label: String, evidence: String) -> void:
	await capture(label,0)
	var cam = game.camera_preview if game.hud.camera_options.preview_active else game.camera
	var ground: float = field.sample(cam.position.x,cam.position.z).height
	var ahead = game.sim.position + Vector3(sin(game.sim.heading),0,cos(game.sim.heading))*4.0
	ahead.y = field.sample(ahead.x,ahead.z).height+0.1
	var skier_screen: Vector2 = cam.unproject_position(game.sim.position)/Vector2(root.get_visible_rect().size)
	camera_frames.append({"label":label,"evidence":evidence,"speed_kmh":game.sim.speed_kmh(),"fov":cam.fov,"boom_distance_m":cam.boom_distance,"boom_height_m":cam.boom_height,"carve":cam.carve_blend,"camera_clearance_m":cam.position.y-ground,"downward_pitch_degrees":rad_to_deg(asin(clampf(cam.global_basis.z.y,-1.0,1.0))),"skier_screen":str(skier_screen),"ahead_on_screen":not cam.is_position_behind(ahead) and root.get_visible_rect().has_point(cam.unproject_position(ahead)),"grounded":game.sim.grounded,"crash":game.sim.crash_reason,"eligible":game.session.eligible})
	if game.session.eligible: camera_failures.append(label+": ranked test")
	if cam.position.y < ground+0.5: camera_failures.append(label+": camera below terrain clearance")
	if not cam.close_view and not game.summit_ready and not cam.has_manual_look() and game.active:
		if cam.position.y < ground+0.99: camera_failures.append(label+": automatic chase below collision clearance")

func skiing_clip(label: String, z: float, kmh: float, close: bool = false) -> void:
	fixture(z,kmh,close)
	var clip_name = label + ("_pov" if close else "")
	for frame in 180:
		for tick in 2:
			var intent = RiderInput.new()
			if label == "turn_brake":
				intent.steer = 0.65 if frame<65 else (-0.65 if frame<105 else 0.0)
				intent.brake = 1.0 if frame>=140 else 0.0
				intent.tuck = 1.0 if frame>=105 and frame<140 else 0.0
			elif label == "jump_land":
				intent.jump = frame==30 and tick==0
			else: intent.tuck = 1.0
			game.intent = intent
			game.sim.step(1.0/120.0,intent,field)
			game.skier.step_animation(1.0/120.0,game.sim,intent,field)
		game._process(1.0/60.0)
		await process_frame
		if record_motion: await save_motion_frame(clip_name,frame)
		if frame in [29,44,64,104,139,179]:
			await camera_capture("%s_%03d" % [clip_name,frame],"120 Hz solver / 60 Hz presentation clip")
		if game.sim.crashed: break

func save_motion_frame(label: String, frame: int) -> void:
	var directory = OUTPUT + "/motion/" + label
	if frame == 0: DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(directory+"/%04d.jpg" % frame,0.90)

func bump_clip(close: bool) -> void:
	fixture(820,90,close)
	game.camera.effects_enabled = false
	var origin: Vector3 = game.sim.position
	var label = "synthetic_bumps_" + ("pov" if close else "chase")
	# Explicitly synthetic rider-height perturbation, separate from solver clips.
	for frame in 180:
		game.sim.position.y = origin.y + 0.12*sin(TAU*8.0*float(frame)/60.0)
		game.sim.reset_pose_history()
		game._process(1.0/60.0)
		await process_frame
		await save_motion_frame(label,frame)
		if frame in [29,89,179]: await camera_capture("%s_%03d" % [label,frame],"synthetic 8 Hz / 0.12 m vertical perturbation; not solver motion")

func cursor_checks() -> void:
	fixture(820,0)
	game.automated = false
	game.application_focused = true
	game._sync_camera_controls()
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: camera_failures.append("Active native cursor not captured")
	game.active = false
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE: camera_failures.append("Paused native cursor not released")
	game.automated = true
	game._sync_camera_controls()

func _select_tab(tabs: TabContainer, caption: String) -> void:
	for index in tabs.get_tab_count():
		if tabs.get_tab_title(index)==caption:
			tabs.current_tab = index
			return
	assert(false,"Missing tab: "+caption)

func _expand_group(page: Control, caption: String) -> Control:
	for button in page.find_children("*","Button",true,false):
		if button.has_meta("group_body") and button.text.ends_with(caption):
			button.button_pressed = true
			return button.get_meta("group_body")
	assert(false,"Missing settings group: "+caption)
	return null
