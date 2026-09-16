extends "res://tests/camera_playtest.gd"
## Unranked real-solver v15 motion, with isolated default and close-low settings.
## ./godotw.ps1 --script tests/camera_pitch_playtest.gd '--' --views --version=15 --benchmark-label=camera_pitch --ui-staged-loading
var pitch_clips: Array = []

func inspect_massif() -> void:
	game.set_process(false)
	install_camera_baseline()
	game.hud.hide_menu()
	game.summit_ready = false
	game.active = true
	if version != 15: camera_failures.append("Camera motion review requires generator v15")
	if game.preferences_enabled: camera_failures.append("Scripted review can write personal preferences")
	for custom in [false,true]:
		game.camera_settings.reset()
		if custom:
			game.camera_settings.update_profile("chase",{"rest_distance":1.0,"fast_distance":3.0,"rest_height":2.0,"fast_height":4.0,"vertical_smoothing":40.0})
		for close in [false,true]:
			for jump in [false,true]:
				await pitch_clip(custom,close,jump)
	write_camera_report()
	preload("res://tests/test_report.gd").write(OUTPUT+"/pitch_motion.json",JSON.stringify({
		"generator":version,"seed":mountain_seed,"model":game.sim.MODEL_VERSION,
		"engine":Engine.get_version_info().string,"physics_hz":120,"presentation_hz":60,
		"actual_pixels":[actual_pixels.x,actual_pixels.y],"display":game.display_settings.report(root,actual_pixels),
		"camera_sha256":FileAccess.get_sha256("res://scripts/presentation/chase_camera.gd"),
		"unranked":not game.session.eligible,"preferences_written":false,"capture_overhead":true,
		"clips":pitch_clips,"failures":camera_failures},"\t"))
	print("CAMERA_PITCH_MOTION ",JSON.stringify({"clips":pitch_clips.size(),"failures":camera_failures}))

func pitch_clip(custom: bool, close: bool, jump: bool) -> void:
	fixture(820.0 if jump else 1600.0,90.0 if jump else 150.0,close)
	game.session.eligible = false
	# Prime the selected view before advancing the solver. Effects remain enabled.
	await present(0.5)
	var label = "%s_%s_%s" % ["custom" if custom else "default","pov" if close else "chase","jump" if jump else "steep"]
	var rows: Array = []
	var ground_transitions = 0
	var was_grounded: bool = game.sim.grounded
	for frame in 240:
		for tick in 2:
			var intent = RiderInput.new()
			intent.jump = jump and frame==30 and tick==0
			intent.tuck = 0.0 if jump else 1.0
			game.intent = intent
			game.sim.step(1.0/120.0,intent,field)
			game.skier.step_animation(1.0/120.0,game.sim,intent,field)
			if game.sim.grounded != was_grounded: ground_transitions += 1
			was_grounded = game.sim.grounded
		game._process(1.0/60.0)
		await process_frame
		await save_motion_frame(label,frame)
		var cam = game.camera
		var skier_point: Vector3 = game.skier.global_position + Vector3.UP*0.8
		var forward: Vector3 = Vector3(game.sim.velocity.x,0,game.sim.velocity.z).normalized()
		var ahead: Vector3 = game.sim.position + forward*12.0
		ahead.y = field.sample(ahead.x,ahead.z).height+0.1
		var viewport_rect = root.get_visible_rect()
		var skier_screen: Vector2 = cam.unproject_position(skier_point)/viewport_rect.size
		var ahead_screen: Vector2 = cam.unproject_position(ahead)/viewport_rect.size
		rows.append({"frame":frame,"grounded":game.sim.grounded,"crashed":game.sim.crashed,
			"speed_kmh":game.sim.speed_kmh(),"pitch_degrees":rad_to_deg(asin(clampf(-cam.global_basis.z.y,-1.0,1.0))),
			"slope_degrees":game.sim.slope_angle,"landing_force":game.sim.landing_force,
			"skier_on_screen":not cam.is_position_behind(skier_point) and viewport_rect.has_point(cam.unproject_position(skier_point)),
			"ahead_on_screen":not cam.is_position_behind(ahead) and viewport_rect.has_point(cam.unproject_position(ahead)),
			"skier_screen":[skier_screen.x,skier_screen.y],"ahead_screen":[ahead_screen.x,ahead_screen.y]})
		if frame in [0,29,44,64,104,139,179,239]:
			await camera_capture(label+"_%03d" % frame,"120 Hz solver / 60 Hz presentation, unranked v15 motion")
		if game.sim.crashed: break
	pitch_clips.append({"label":label,"settings":game.camera_settings.snapshot(),"first_person":close,
		"jump_requested":jump,"contact_transitions":ground_transitions,"crash":game.sim.crash_reason,
		"airtime_s":game.sim.total_airtime,"frames":rows})
	print("PITCH_CLIP ",JSON.stringify({"label":label,"frames":rows.size(),"transitions":ground_transitions,"crash":game.sim.crash_reason}))
