extends "res://tests/camera_playtest.gd"
## Native default-v15 grade review. Frozen fixtures and real solver clips differ.
func inspect_massif() -> void:
	game.set_process(false)
	game.hud.hide_menu()
	game.active = true
	for preset in game.CameraSettings.BUILT_INS:
		for view in game.CameraSettings.VIEWS: game.camera_settings.apply_preset(view,preset)
		for close in [false,true]:
			for direction in ["flat","downhill","uphill"]:
				for kmh in [0,120]:
					place_grade(direction,close,kmh)
					await present(.4)
					await camera_capture("%s_%s_%s_%d" % [preset.to_lower(),"pov" if close else "chase",direction,kmh],"stationary native grade fixture")
	game.camera_settings.reset()
	for close in [false,true]:
		place_grade("uphill",close,60)
		var view = "first_person" if close else "chase"
		game.camera_settings.update_profile(view,{"slope_follow":0})
		game.camera.reset(); await present(.4)
		await camera_capture("uphill_fixed_"+view,"same hill, fixed world tilt")
		game.camera_settings.reset()
		place_grade("uphill",close,60)
		await present(.4)
		await camera_capture("uphill_follow_"+view,"same hill, broad slope following")
		record_motion = "--camera-motion-capture" in OS.get_cmdline_user_args()
		for frame in 240:
			for tick in 2:
				var intent = RiderInput.new()
				game.intent = intent
				game.sim.step(1.0/120,intent,field)
				game.skier.step_animation(1.0/120,game.sim,intent,field)
			game._process(1.0/60)
			await process_frame
			if record_motion and frame%2==0: await save_motion_frame("uphill_stop_"+view,frame/2)
			if frame in [29,89,179,239]: await camera_capture("uphill_stop_%s_%03d" % [view,frame],"real 120 Hz solver, uphill deceleration / 60 Hz presentation")
			if game.sim.crashed: camera_failures.append("Uphill clip crashed: "+game.sim.crash_reason); break
	# The actual preview must evaluate grade too, while retaining paused state.
	place_grade("uphill",false,60)
	game.active = false; game.automated = false; game.application_focused = true
	game.hud.show_menu("paused"); game.hud.open_settings()
	_select_tab(game.hud.settings_tabs,"Camera")
	game.hud.camera_options.groups["Preview speed"].button.button_pressed = true
	game.set_camera_preview(true)
	if not game.hud.camera_options.preview_active: camera_failures.append("Uphill preview did not acquire camera ownership")
	game.hud.camera_options.preview_speed.value = 120
	await present(.5)
	await camera_capture("uphill_preview","stationary preview uses actual terrain grade")
	game.set_camera_preview(false)
	game.automated = true
	write_camera_report()

func place_grade(direction: String, close: bool, kmh: float) -> void:
	var position: Vector3
	var heading: float
	if direction=="flat":
		position = field.spawn_point()
		var normal: Vector3 = field.sample(position.x,position.z).normal
		var contour = Vector3(normal.z,0,-normal.x).normalized()
		heading = atan2(contour.x,contour.z)
	else:
		place_on_face(face_index,1600,close)
		position = game.sim.position
		heading = game.sim.heading + (PI if direction=="uphill" else 0.0)
	game.sim.reset(position,heading)
	game.sim.prime_contacts(field)
	game.sim.velocity = game.sim.support_basis().z*kmh/3.6
	game.sim.reset_pose_history()
	game.previous_position = game.sim.position
	game.skier.reset_animation(game.sim)
	game.camera.close_view = close
	game.camera.effects_enabled = true
	game.camera.reset()
	game.effects.reset()
	game.active = true; game.summit_ready = false
	game.session.eligible = false

func camera_capture(label: String, evidence: String) -> void:
	await super.camera_capture(label,evidence)
	var cam = game.camera_preview if game.hud.camera_options.preview_active else game.camera
	camera_frames.back()["filtered_slope_degrees"] = rad_to_deg(cam.slope_pitch)
	var ahead = game.sim.position + Vector3(sin(game.sim.heading),0,cos(game.sim.heading))*20
	ahead.y = field.sample(ahead.x,ahead.z).height+.1
	var visible = not cam.is_position_behind(ahead) and root.get_visible_rect().has_point(cam.unproject_position(ahead))
	camera_frames.back()["ahead_20m_on_screen"] = visible
	# Frozen forward-facing fixtures should show the route; motion can reverse
	# travel relative to body heading and is reviewed as a separate sequence.
	if "stationary native grade" in evidence and not visible: camera_failures.append(label+": forward route outside view")
