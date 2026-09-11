extends SceneTree
var checks: int = 0
var failures: Array = []
var game

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool,label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ",label)
	else:
		print("PASS: ",label)

func key(code: Key) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_input(event)

func run() -> void:
	set_meta("test_lab_fixture",true) # Explicit laboratory regression fixture.
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(not game.active and game.hud.menu.visible,"Project opens at the start screen")
	var dial_rect: Rect2 = game.hud.speed_dial.get_global_rect()
	check(dial_rect.position.x>=0 and dial_rect.position.y>=0 and root.get_visible_rect().encloses(dial_rect),"Speed dial stays fully inside the viewport")
	check(game.session.course_id=="laboratory-v3-physics-v28-default","Grounded snow uses its new benchmark identity")
	key(KEY_F2)
	check(not game.active and game.hud.tuning_panel.visible,"Workbench pauses from the title screen")
	var workbench_rect: Rect2 = game.hud.tuning_panel.get_global_rect()
	check(workbench_rect.position.x>=0 and workbench_rect.position.y>=0,"Workbench opens inside the viewport")
	game.close_workbench()
	check(not game.active and game.hud.menu_mode=="title","Closing the title workbench does not silently start a run")
	game.start_run(true)
	await physics_frame
	check(game.active and not game.hud.menu.visible,"Drop in enters the playable descent")
	key(KEY_ESCAPE)
	var t: float = game.session.elapsed
	await physics_frame
	check(not game.active and game.session.elapsed==t,"Pause freezes the simulation and race timer")
	key(KEY_ESCAPE)
	check(game.active,"Resume restores active skiing")
	key(KEY_F2)
	check(not game.active,"Workbench pauses a running descent")
	game.close_workbench()
	check(game.active,"Workbench returns to the prior active state")
	game.hud.tuning_sliders["edge_grip"].value = 2.0
	check(not game.session.eligible and game.physics_modified,"Changing physics invalidates the current benchmark")
	game.restart()
	check(not game.session.eligible,"Restart preserves modified-physics ineligibility")
	game.hud.restore_defaults()
	check(game.session.eligible and absf(game.sim.tuning.ski_friction-0.022)<0.000001 and absf(game.sim.tuning.edge_grip-1.6)<0.000001,"Restore defaults uses exact tuning values before re-enabling benchmark records")
	game.start_speed_lab(150)
	check(absf(game.sim.speed_kmh()-150.0)<0.01 and not game.session.eligible,"Speed lab initializes the chosen speed and remains unranked")
	game.start_speed_lab(200)
	check(absf(game.sim.speed_kmh()-200.0)<0.01 and not game.session.eligible,"Exceptional entry speed remains available in the unranked lab")
	game.sim.crash("TREE IMPACT")
	game.active = false
	game.restart()
	check(not game.sim.crashed and game.sim.velocity.length()==0 and game.session.elapsed==0,"Instant restart clears crash, momentum, and clock")
	key(KEY_F3)
	check(game.vectors.visible and game.hud.debug_panel.visible,"Telemetry toggle enables instruments and world arrows")
	key(KEY_M)
	check(game.effects.muted,"Audio can be muted independently")
	check(not game.effects.wind.audible,"Mute also disables procedural wind")
	var original_wind_mode: int = game.effects.wind.mode
	key(KEY_F7)
	check(game.effects.wind.mode!=original_wind_mode and game.hud.wind_mode.selected==game.effects.wind.mode,"F7 compares wind and synchronizes settings")
	key(KEY_F7)
	check(game.effects.wind.mode==original_wind_mode,"F7 restores the previous wind mode")
	key(KEY_C)
	check(game.camera.close_view,"Camera toggle changes view mode")
	key(KEY_V)
	check(not game.camera.effects_enabled,"Motion comfort toggle disables dynamic camera effects")
	key(KEY_V)
	check(game.camera.effects_enabled,"Motion effects can be re-enabled")
	game.automated = true
	game.restart()
	check(not game.session.eligible,"Restarting an automated playtest cannot enable personal bests")
	game.automated_ticks = 100
	game.jump_armed = true
	Input.action_press("jump")
	Input.action_press("steer_right",0.8)
	Input.action_press("brake",0.7)
	game._physics_process(1.0/120.0)
	check(not game.intent.jump and game.intent.steer==0.0 and game.intent.brake==0.0 and game.intent.tuck==1.0,"Autoplay ignores live jump, steering and braking input")
	var auto_view: bool = game.camera.close_view
	key(KEY_ESCAPE)
	key(KEY_C)
	check(game.active and game.camera.close_view==auto_view,"Autoplay ignores pause and camera hotkeys during measurement")
	for action in ["jump","steer_right","brake"]:
		Input.action_release(action)
	game.automated = false
	_weather_checks()
	_lighting_checks()
	_speed_band_checks()
	_input_checks()
	_camera_input_checks()
	_camera_settings_checks()
	_screen_direction_checks()
	# Test release semantics so holding the start/jump button cannot make the
	# first simulation step hop unintentionally.
	Input.action_press("jump")
	game.restart()
	await physics_frame
	await physics_frame
	check(game.sim.grounded,"Holding jump while restarting does not trigger an unwanted hop")
	Input.action_release("jump")
	await physics_frame
	await physics_frame
	check(game.sim.grounded,"Releasing a button held through restart is also suppressed")
	await _jump_release_checks()
	await _controller_runtime_checks()
	_haptic_lifecycle_checks()
	_feedback_checks()
	_impact_warning_checks()
	await _impact_warning_reload_checks()
	game.active = false
	game.queue_free()
	await process_frame
	var output = {"checks":checks,"failures":failures}
	var file = FileAccess.open("res://artifacts/runtime_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t"))
	print("RUNTIME_RESULTS ",JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)

func _jump_release_checks() -> void:
	game.set_physics_process(false)
	game.start_speed_lab(0)
	await process_frame
	await process_frame
	game._physics_process(1.0/120.0) # Observe neutral before arming.
	Input.action_press("jump")
	game._physics_process(1.0/120.0)
	check(game.intent.jump_held and not game.intent.jump and game.sim.grounded,"Pressing jump shows readiness without hopping")
	await process_frame
	await process_frame
	game._physics_process(1.0/120.0)
	check(game.sim.grounded and game.sim.total_airtime==0.0,"Holding jump does not auto-repeat")
	Input.action_release("jump")
	game._physics_process(1.0/120.0)
	check(game.intent.jump and not game.intent.jump_held and not game.sim.grounded,"Releasing jump launches the prepared hop")
	await process_frame
	await process_frame
	game._physics_process(1.0/120.0)
	check(not game.intent.jump and game.sim.jump_buffer_remaining==0.0,"Release event lasts one sampled tick")
	for action in ["pause","workbench","focus"]:
		game.start_speed_lab(0)
		await process_frame
		await process_frame
		game._physics_process(1.0/120.0)
		Input.action_press("jump")
		game._physics_process(1.0/120.0)
		if action=="pause": key(KEY_ESCAPE)
		elif action=="workbench": key(KEY_F2)
		else: game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(not game.active and not game.jump_armed,"Leaving play disarms prepared jump: "+action)
		if action=="workbench": game.close_workbench()
		else: game.resume()
		Input.action_release("jump")
		game._physics_process(1.0/120.0)
		check(game.sim.grounded and not game.intent.jump,"Release held through inactive screen is ignored: "+action)
	game.start_speed_lab(0)
	await process_frame
	await process_frame
	game._physics_process(1.0/120.0)
	game.sim.position.y += 1.0
	game.sim.grounded = false
	Input.action_press("jump")
	game._physics_process(1.0/120.0)
	Input.action_release("jump")
	game._physics_process(1.0/120.0)
	check(game.sim.jump_buffer_remaining>0.0,"Early air release reaches the simulation buffer")
	key(KEY_ESCAPE)
	check(game.sim.jump_buffer_remaining==0.0,"Pause cancels pending air release before it can survive into a landing")
	game.resume()
	check(game.sim.jump_buffer_remaining==0.0,"Resume does not restore a cancelled jump request")

class ControllerSummit extends "res://scripts/world/test_slope.gd":
	func launch_point(_heading: float) -> Vector3: return spawn_point()

func _controller_runtime_checks() -> void:
	var pad = preload("res://tests/controller_input_suite.gd")
	game.set_physics_process(false); game.set_process(false)
	game.application_focused = true
	game.start_speed_lab(0)
	await process_frame; await process_frame
	game._physics_process(1.0/120.0)
	pad.axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	game._physics_process(1.0/120.0)
	check(game.intent.jump_held and game.sim.grounded,"Physical R2 mapping prepares without jumping")
	await process_frame; await process_frame
	pad.axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	game._physics_process(1.0/120.0)
	check(game.intent.jump and game.sim.jump_executed,"Physical R2 release executes one hop")
	for transition in ["restart","disconnect"]:
		game.start_speed_lab(0)
		await process_frame; await process_frame
		game._physics_process(1.0/120.0)
		pad.axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
		game._physics_process(1.0/120.0)
		if transition=="restart": game.restart()
		else: game._controller_connection_changed(0,false)
		pad.axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
		game._physics_process(1.0/120.0)
		check(not game.intent.jump and game.sim.grounded,"R2 held through "+transition+" cannot jump on release")
	# A small summit fixture exercises production input/drop lifecycle without a bake.
	var saved_field = game.field
	game.field = ControllerSummit.new()
	for control in ["forward","confirm"]:
		game.start_speed_lab(0)
		game.summit_ready = true; game.summit_drop_armed = true
		await process_frame; await process_frame
		game._physics_process(1.0/120.0)
		pad.axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
		game._physics_process(1.0/120.0)
		check(game.summit_ready,"R2 alone does not drop from the summit: "+control)
		pad.axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
		game._physics_process(1.0/120.0)
		if control=="forward":
			pad.axis(JOY_AXIS_LEFT_Y,-1.0)
			game._physics_process(1.0/120.0)
			pad.axis(JOY_AXIS_LEFT_Y,0.0)
		else:
			root.gui_release_focus()
			pad.button(JOY_BUTTON_A,true)
			pad.button(JOY_BUTTON_A,false)
		check(not game.summit_ready and not game.sim.jump_executed,"Summit "+control+" drops without an unintended hop")
	game.field = saved_field
	game.summit_ready = false
	game.restart()

func _haptic_lifecycle_checks() -> void:
	game.effects.haptic_hardware_enabled = false
	game.start_speed_lab(0)
	game.effects.muted = true
	game._physics_process(1.0/120.0)
	check(game.effects.haptics.last_tick==game.sim.ticks,"Muted audio still samples haptics on completed simulation ticks")
	for transition in ["pause","focus","restart","disconnect","zero"]:
		game.start_speed_lab(0)
		game.effects.haptics.pending_impact = 10.0
		game.effects.update_haptics(0.0,true,false,.5)
		check(game.effects.haptic_output.y>0.0,"Arm a real output envelope before "+transition)
		if transition=="pause": game.active = false
		elif transition=="focus": game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		elif transition=="restart": game.restart()
		elif transition=="disconnect": game._controller_connection_changed(0,false)
		else: game.hud.tuning_sliders.vibration_intensity.value = 0.0
		check(game.effects.haptic_output==Vector3.ZERO and game.effects.haptics.pending_impact==0.0,"Lifecycle immediately stops haptics: "+transition)
	game.hud.tuning_sliders.vibration_intensity.value = .5
	game.application_focused = true
	game.restart()

func _feedback_checks() -> void:
	game.active = false
	game.sim.reset(Vector3.ZERO)
	game.intent = RiderInput.new()
	game.sim.impacts.hit(10.5,10.5,"HARD LANDING",game.sim.tuning)
	game.hud.update_hud(game.sim,game.session,game.intent,"Test",8.3,.1,.1,true)
	check(game.hud.state_label.text.begins_with("HARD LANDING") and absf(game.hud.impact_bar.value-70.0)<.001,"Rough landing reduces the visible impact reserve by severity")
	var paused_reserve: float = game.sim.impacts.reserve
	game._physics_process(30.0)
	game.hud.update_hud(game.sim,game.session,game.intent,"Test",8.3,.1,30.0,true)
	check(game.sim.impacts.reserve==paused_reserve and game.sim.impacts.since_hit==0.0,"Pause and HUD rendering cannot refill the impact reserve")
	game.sim.impacts.since_hit = 2.0
	game.hud.update_hud(game.sim,game.session,game.intent,"Test",8.3,.1,.1,true)
	check(game.hud.state_label.text.begins_with("RECOVERING"),"Smooth skiing after the delay gives a recovery cue")
	game.sim.impacts.reserve = .20
	game.hud.update_hud(game.sim,game.session,game.intent,"Test",8.3,.1,.1,true)
	check(game.hud.state_label.text.begins_with("LOW IMPACT RESERVE"),"Low impact reserve gives a clear impact warning")
	game.sim.impacts.reset()
	game.sim.balance = 0.0
	game.sim.balance_pressure = 2.0
	game.intent.jump_held = true
	game.hud.update_hud(game.sim,game.session,game.intent,"Test",8.3,.1,.1,true)
	check(game.hud.state_label.text.begins_with("JUMP READY") and game.hud.impact_bar.value==100.0,"Retired balance values cannot affect the new bar or jump readiness")
	game.sim.crash("IMPACT LIMIT / HARD LANDING")
	game.hud.update_hud(game.sim,game.session,game.intent,"Test",8.3,.1,.1,true)
	check(game.hud.state_label.text=="IMPACT LIMIT / HARD LANDING","Crash reason takes priority over jump readiness")
	game.restart()
	check(game.sim.impacts.reserve==1.0 and not game.sim.crashed,"Restart restores the full impact bar after a fall")

func _impact_warning_checks() -> void:
	game.set_process(false)
	game.set_physics_process(false)
	for condition in ["stationary","airborne","rock"]:
		game.start_speed_lab(0)
		game.application_focused = true
		game.camera.effects_enabled = false
		game.sim.impacts.reserve = 0.1
		game.sim.grounded = condition!="airborne"
		game.sim.rock_contact = 1.0 if condition=="rock" else 0.0
		var position: Vector3 = game.sim.position
		var velocity: Vector3 = game.sim.velocity
		var eligible: bool = game.session.eligible
		var elapsed: float = game.session.elapsed
		game._update_screen_effects(1.0)
		check(game.speed_periphery.visible and game.impact_warning.strength>0.5,"Warning builds visibly within a second without speed effects: "+condition)
		check(game.impact_warning.pulse==0.65 and game.speed_periphery.material.get_shader_parameter("intensity")==0.0,"V off keeps steady warning and disables speed sampling")
		check(game.sim.position==position and game.sim.velocity==velocity and game.sim.impacts.reserve==0.1 and game.session.eligible==eligible and game.session.elapsed==elapsed,"Warning observation leaves skiing, reserve and race state unchanged")
	game.camera.effects_enabled = true
	game.hud.feedback.reduced_motion = true
	game._update_screen_effects(0.1)
	check(game.speed_periphery.visible and game.impact_warning.pulse==0.65,"Reduced interface motion suppresses warning pulsing")
	game.hud.feedback.reduced_motion = false
	game._update_screen_effects(0.1)
	check(game.impact_warning.phase>0.0,"Normal motion permits the warning pulse")
	for transition in ["pause","crash","results","loading","focus","reload","summit_return","restart"]:
		game.restart()
		game.application_focused = true
		game.sim.impacts.reserve = 0.1
		game._update_screen_effects(1.0)
		if transition=="pause": game.active = false
		elif transition=="crash": game.sim.crash("IMPACT LIMIT / HARD LANDING")
		elif transition=="results": game.active = false; game.hud.show_menu("finished")
		elif transition=="loading": game.loading.busy = true
		elif transition=="focus": game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		elif transition=="reload": game.transitioning = true
		elif transition=="summit_return": game.returning_to_summit = true
		else: game.restart()
		if transition!="restart": game._update_screen_effects(0.1)
		check(not game.speed_periphery.visible and game.impact_warning.strength==0.0 and game.impact_warning.phase==0.0,"Screen warning clears for "+transition)
		game.loading.busy = false
		game.transitioning = false
		game.returning_to_summit = false
	game.restart()
	game.application_focused = true
	game.camera.effects_enabled = false
	game.sim.impacts.reserve = 0.1
	game._update_screen_effects(1.0)
	game.active = false
	game.resume()
	game._update_screen_effects(1.0/120.0)
	check(game.impact_warning.strength>0.0 and game.impact_warning.strength<0.05,"Resume fades from current reserve instead of restoring a stale pulse")
	game.restart()
	game._update_screen_effects(0.1)
	check(not game.speed_periphery.visible,"A healthy restart needs no screen pass with speed effects off")

func _impact_warning_reload_checks() -> void:
	# Exercise the real scene reload using the inexpensive laboratory fixture.
	current_scene = game
	game.sim.impacts.reserve = 0.1
	game.application_focused = true
	game.hud.feedback.reduced_motion = true
	game._update_screen_effects(1.0)
	var old_warning = game.impact_warning
	check(old_warning.strength>0.5,"Arm warning before actual scene reload")
	game._remember_world_settings()
	var error = reload_current_scene()
	check(error==OK,"World scene reload dispatch succeeds")
	if error!=OK: return
	await scene_changed
	game = current_scene
	while not game.initialized or game.loading.busy: await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	check(game.impact_warning!=old_warning and game.impact_warning.strength==0.0 and not game.speed_periphery.visible,"Scene reload creates a clean warning controller and hidden screen pass")
	check(game.hud.feedback.reduced_motion and not game.camera.effects_enabled,"Scene reload retains steady-warning comfort preferences")

func _speed_band_checks() -> void:
	game.active = false
	var correct = true
	for band in [[0,"MANEUVERING"],[30,"ORDINARY SKIING"],[60,"FAST"],[90,"RACING"],[120,"ELITE DOWNHILL"],[150,"EXTREME RACING"],[165,"EXTREME TERRAIN"],[200,"EXCEPTIONAL SPEED"]]:
		game.sim.velocity = Vector3.BACK*(float(band[0])+0.01)/3.6
		game.hud.update_hud(game.sim,game.session,game.intent,"Test input",8.3,0.1,0.1,true)
		correct = correct and game.hud.band_label.text==band[1]
	check(correct,"All eight speed bands follow the requested thresholds, including 165 and 200")

func _screen_direction_checks() -> void:
	for first_person in [false,true]:
		for direction in [-1.0,1.0]:
			game.start_speed_lab(60)
			game.active = false
			# Start aligned with the skis. The speed lab otherwise points velocity
			# down the local fall line, adding pre-existing cross-slope slip to
			# this input/camera direction check.
			game.sim.velocity = game.sim.support_basis().z*60.0/3.6
			game.camera.close_view = first_person
			game.camera.update_camera(game.sim,game.field,game.sim.position,0.016,false,true)
			var screen_right: Vector3 = game.camera.global_basis.x
			var start: Vector3 = game.sim.position
			var action = "steer_left" if direction<0 else "steer_right"
			Input.action_press(action,0.75)
			var frame = game.input_router.sample()
			for i in range(60):
				game.sim.step(1.0/120.0,frame,game.field)
			Input.action_release(action)
			check((game.sim.position-start).dot(screen_right)*direction>0.05,"%s moves to the matching screen side in %s view" % [action,"first-person" if first_person else "chase"])

func _input_checks() -> void:
	var router = game.input_router
	Input.action_press("steer_right",0.42)
	Input.action_press("tuck",0.65)
	Input.action_press("brake",0.20)
	var frame = router.sample()
	check(absf(frame.steer-0.42)<0.001 and absf(frame.tuck-0.65)<0.001 and absf(frame.brake-0.20)<0.001,"Analog steering and trigger strengths survive the input abstraction")
	for action in ["steer_right","tuck","brake"]:
		Input.action_release(action)
	var correct = true
	for item in [["steer_left",JOY_AXIS_LEFT_X,-1.0],["steer_right",JOY_AXIS_LEFT_X,1.0],["tuck",JOY_AXIS_LEFT_Y,-1.0],["brake",JOY_AXIS_TRIGGER_LEFT,1.0],["jump",JOY_AXIS_TRIGGER_RIGHT,1.0]]:
		var found = false
		for event in InputMap.action_get_events(item[0]):
			if event is InputEventJoypadMotion and event.axis==item[1] and event.axis_value==item[2]:
				found = true
		correct = correct and found
	check(correct,"Standard left-stick and trigger bindings exist without hardcoded controller identities")
	var a = InputEventKey.new()
	a.physical_keycode = KEY_A
	a.pressed = true
	check(a.is_action_pressed("steer_left"),"Keyboard physical A maps to left steering")

func _camera_settings_checks() -> void:
	game.automated = false
	game.restart()
	game.active = false
	game.hud.show_menu("paused")
	game.hud.open_settings()
	game._sync_camera_controls()
	var before = [game.sim.position,game.sim.velocity,game.sim.heading,game.session.elapsed,game.session.eligible,game.physics_modified]
	game.hud.camera_setting_controls.rest_distance.value = 4.5
	game.hud.camera_setting_controls.fast_distance.value = 9.5
	game.hud.camera_setting_controls.rest_height.value = 5.5
	game.hud.camera_setting_controls.fast_height.value = 11.5
	game.hud.camera_setting_controls.vertical_smoothing.value = 70.0
	game.hud.camera_setting_controls.forest_visibility.value = 35.0
	check(game.camera_settings.forest_visibility==35.0 and game.hud.camera_setting_readouts.forest_visibility.text=="35%","Forest visibility slider reaches local presentation settings")
	var lens_tilt = {"rest_fov":85.0,"fast_fov":65.0,"chase_pitch_offset":12.0,"first_person_pitch_offset":-8.0}
	for key in lens_tilt: game.hud.camera_setting_controls[key].value = lens_tilt[key]
	for key in lens_tilt: check(game.camera_settings.get(key)==lens_tilt[key],"Lens/tilt slider reaches the live camera: " + key)
	check(game.hud.camera_setting_readouts.rest_fov.text=="85°" and game.hud.camera_setting_readouts.fast_fov.text=="65°" and game.hud.camera_setting_readouts.chase_pitch_offset.text=="+12°" and game.hud.camera_setting_readouts.first_person_pitch_offset.text=="-8°","FoV and tilt display degrees and tilt direction")
	check(game.camera.settings == game.camera_settings and game.camera_settings.rest_distance == 4.5 and game.camera_settings.fast_distance == 9.5, "Settings sliders update the live camera preferences")
	check(game.camera_settings.rest_height == 5.5 and game.camera_settings.fast_height == 11.5 and game.camera_settings.vertical_smoothing == 70.0,"Height and stabilization controls reach the live camera")
	check(game.hud.camera_setting_readouts.rest_height.text == "5.50 m" and game.hud.camera_setting_readouts.vertical_smoothing.text == "70%","Camera controls display metres and percentages correctly")
	check(game.hud.camera_setting_readouts.rest_distance.text == "4.50 m" and not game.camera_controls_active, "Distance readouts update while settings retain cursor control")
	check(before == [game.sim.position,game.sim.velocity,game.sim.heading,game.session.elapsed,game.session.eligible,game.physics_modified], "Camera menu changes preserve solver, replay eligibility and physics tuning")
	game._remember_world_settings()
	check(get_meta("world_reload_settings").camera == game.camera_settings.snapshot(), "Mountain reload carries all camera preferences")
	remove_meta("world_reload_settings")
	game.restart()
	check(game.camera_settings.rest_distance == 4.5 and game.camera_settings.fast_distance == 9.5, "Restart retains configured camera distances")
	check(game.camera_settings.rest_height == 5.5 and game.camera_settings.fast_height == 11.5 and game.camera_settings.vertical_smoothing == 70.0,"Restart retains configured heights and smoothing")
	check(game.camera_settings.forest_visibility==35.0,"Restart retains forest visibility preference")
	for key in lens_tilt: check(game.camera_settings.get(key)==lens_tilt[key],"Restart retains lens/tilt: " + key)
	game.hud.camera_reset_button.pressed.emit()
	check(game.camera_settings.snapshot() == game.CameraSettings.DEFAULTS and game.hud.camera_setting_controls.rest_height.value == 6.0 and game.hud.camera_setting_controls.vertical_smoothing.value == 50.0, "Camera reset button restores all defaults and synchronizes sliders")
	for key in game.CameraSettings.DEFAULTS:
		check(game.hud.camera_setting_controls[key].value == game.CameraSettings.DEFAULTS[key],"Reset synchronizes camera slider: " + key)
	game.automated = true
	game.hud.camera_setting_requested.emit("rest_distance",12.0)
	game.hud.camera_setting_requested.emit("rest_height",12.0)
	game.hud.camera_setting_requested.emit("vertical_smoothing",0.0)
	for key in lens_tilt: game.hud.camera_setting_requested.emit(key,lens_tilt[key])
	check(not game.preferences_enabled and game.camera_settings.snapshot() == game.CameraSettings.DEFAULTS, "Automated runs ignore preference loading and all live camera changes")
	game.automated = false
	game.hud.close_weather()
	game.restart()

func _camera_input_checks() -> void:
	game.set_physics_process(false)
	game.set_process(false)
	game.restart()
	game._sync_camera_controls()
	check(game.camera_controls_active, "Active skiing enables camera controls")
	game._process(0.016) # Observe a neutral stick after restart.
	var snapshot = [game.sim.position,game.sim.velocity,game.sim.heading,game.session.elapsed,game.session.eligible]
	var motion = InputEventMouseMotion.new()
	motion.screen_relative = Vector2(400, 100)
	game.discard_camera_mouse_motion = false
	game._unhandled_input(motion)
	game._process(0.016)
	check(game.camera.look_yaw < -0.6 and game.camera.look_pitch < 0.0, "Mouse motion reaches independent camera look")
	check(snapshot == [game.sim.position,game.sim.velocity,game.sim.heading,game.session.elapsed,game.session.eligible], "Mouse look preserves skier state, timing and record eligibility")
	Input.action_press("look_right",1.0)
	game._process(0.016)
	check(game.camera.look_yaw < -0.7 and game.input_router.sample().steer == 0.0, "Right stick looks independently of steering")
	key(KEY_ESCAPE)
	check(not game.camera_controls_active and game.camera.pending_mouse.is_zero_approx() and game.camera.pending_stick.is_zero_approx(), "Pause releases camera controls and pending motion")
	game._unhandled_input(motion)
	check(game.camera.pending_mouse.is_zero_approx(), "Menu mouse motion cannot leak into look")
	key(KEY_ESCAPE)
	var yaw: float = game.camera.look_yaw
	game._process(0.016)
	check(game.camera.look_yaw == yaw and not game.camera_stick_armed, "Stick held through pause must return to neutral")
	Input.action_release("look_right")
	game._process(0.016)
	check(game.camera_stick_armed, "Neutral rearms camera stick after pause")
	for panel in [game.hud.tuning_panel,game.hud.weather_panel,game.hud.competition.panel,game.mountain_library.panel]:
		panel.visible = true
		game._sync_camera_controls()
		check(not game.camera_controls_active, "Visible UI panel releases look controls: " + panel.name)
		panel.visible = false
		game._sync_camera_controls()
	game.workshop.mode = "create"
	game._sync_camera_controls()
	check(not game.camera_controls_active, "Race authoring retains cursor control")
	game.workshop.mode = ""
	game._sync_camera_controls()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.camera_controls_active and not game.active, "Focus loss releases camera and pauses")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not game.camera_controls_active, "Focus return does not silently recapture the mouse")
	game.resume()
	game.camera.add_mouse_look(Vector2(100, 0))
	game.automated = true
	game._sync_camera_controls()
	game._unhandled_input(motion)
	Input.action_press("look_right", 1.0)
	yaw = game.camera.look_yaw
	game._process(0.016)
	check(not game.camera_controls_active and game.camera.pending_mouse.is_zero_approx() and game.camera.look_yaw == yaw, "Autoplay ignores live mouse and right-stick input")
	Input.action_release("look_right")
	game.automated = false
	game._sync_camera_controls()
	key(KEY_C)
	check(game.camera.look_yaw == 0.0 and not game.camera_stick_armed, "Camera switch resets look and requires neutral stick")
	game.camera.look_yaw = 1.0
	game.camera.carve_blend = 1.0
	game.restart()
	check(game.camera.look_yaw == 0.0 and game.camera.carve_blend == 0.0, "Restart clears free look and carving")
	game.summit_ready = true
	game.camera.add_mouse_look(Vector2(900, 0))
	snapshot = [game.sim.position,game.sim.heading]
	game._process(0.016)
	check(game.camera.look_yaw < -1.5 and snapshot == [game.sim.position,game.sim.heading], "Summit view accepts look without choosing another descent heading")
	game.summit_ready = false
	game.sim.crash("CAMERA TEST")
	game._sync_camera_controls()
	check(not game.camera_controls_active, "Crash releases camera controls")
	game.restart()
	game.set_process(true)
	game.set_physics_process(true)

func _weather_checks() -> void:
	var controller = game.weather
	controller.set_preset("clear")
	controller.set_quality(2)
	check(not controller.automatic and controller.state.label=="Clear","Weather defaults to clear, high quality, automatic off")
	game.active = false
	game.hud.show_menu("title")
	game.hud.weather_button.pressed.emit()
	check(game.hud.weather_panel.visible and not game.hud.menu.visible,"Weather controls open from the title without starting a run")
	game.hud.weather_preset.item_selected.emit(2)
	game.hud.weather_auto.toggled.emit(true)
	game.hud.weather_quality.item_selected.emit(1)
	check(controller.selected_preset=="snowfall" and controller.automatic and controller.quality==1,"Weather controls dispatch preset, auto and quality changes")
	key(KEY_ESCAPE)
	check(game.hud.menu_mode=="title" and game.hud.menu.visible and not game.active,"Escape from weather controls returns to title")
	game.start_run(true)
	var snapshot = [game.sim.position,game.sim.velocity,game.sim.heading,game.sim.balance,game.session.elapsed,game.session.eligible,game.session.course_id]
	var independent = true
	for id in ["clear","cloudy","snowfall","rain"]:
		controller.set_preset(id)
		game._process(0.016)
		independent = independent and snapshot==[game.sim.position,game.sim.velocity,game.sim.heading,game.sim.balance,game.session.elapsed,game.session.eligible,game.session.course_id]
	check(independent,"All weather presentation updates leave simulation state, clock and benchmark eligibility untouched")
	controller.set_preset("rain")
	game._process(0.2)
	check("RAIN" in game.hud.altitude_label.text and "°C" not in game.hud.altitude_label.text,"HUD shows actual weather without a fabricated temperature")
	controller.set_preset("clear")
	controller.set_automatic(true)
	controller.update_weather(180.0,true)
	check(controller.state.label=="Clear" and is_equal_approx(controller.state.cloud_coverage,0.2),"Auto weather holds the preset for three minutes")
	controller.update_weather(10.0,true)
	check(controller.state.cloud_coverage>0.2 and controller.state.cloud_coverage<0.78 and "→" in controller.state.label,"Auto weather blends lighting and clouds gradually")
	var frozen = [controller.phase_seconds,controller.visual_time,controller.state.cloud_coverage]
	controller.update_weather(60.0,false)
	check(frozen==[controller.phase_seconds,controller.visual_time,controller.state.cloud_coverage],"Pause freezes the transition and weather animation clock")
	controller.update_weather(10.0,true)
	check(controller.selected_preset=="cloudy" and is_zero_approx(controller.phase_seconds),"Twenty-second transition arrives at the next preset")
	var sequence: Array = []
	for i in range(5):
		controller.update_weather(200.0,true)
		sequence.append(controller.selected_preset)
	check(sequence==["snowfall","cloudy","rain","cloudy","clear"],"Auto cycle includes cloudy interludes and returns to clear")
	controller.update_weather(190.0,true)
	controller.set_automatic(false)
	var held: float = controller.state.cloud_coverage
	controller.update_weather(30.0,true)
	check(is_equal_approx(held,controller.state.cloud_coverage),"Disabling auto preserves an in-progress blend without a lighting jump")
	controller.set_preset("snowfall")
	check(is_zero_approx(controller.phase_seconds) and controller.state.snow>0.8,"Selecting a preset cancels the blend and starts a fresh hold")
	controller.set_automatic(true)
	controller.update_weather(27.0,true)
	game.restart()
	check(is_equal_approx(controller.phase_seconds,27.0) and controller.selected_preset=="snowfall" and game.weather_effects.stretch==0.0,"Restart retains weather progression and clears speed accents")
	game._process(0.016)
	var high: int = 0
	for quality in [2,1,0]:
		controller.set_quality(quality)
		game._process(0.016)
		var ceiling: int = [0,1000,2000][quality]
		var allocated: int = game.weather_effects.particle_budget()
		var valid: bool = allocated<=ceiling and (allocated>0 if quality>0 else allocated==0)
		if quality==1:
			valid = valid and allocated<high
		check(valid,"Weather particle allocation stays within %d at quality %d" % [ceiling,quality])
		if quality==2:
			high = game.weather_effects.particle_budget()
	check(game.world.environment.sky==game.world.original_sky and not game.weather_effects.volumes[0].visible,"Off disables precipitation and restores the original sky")
	controller.set_quality(2)
	game.sim.velocity = Vector3.BACK*55.0
	game._process(0.5)
	key(KEY_V)
	game._process(0.016)
	check(game.weather_effects.stretch==0.0 and game.speed_periphery.material.get_shader_parameter("arcade_intensity")==0.0,"V removes weather stretching and arcade streaks immediately")
	key(KEY_V)
	var resets: int = game.weather_effects.reset_count
	key(KEY_C)
	game._process(0.016)
	check(game.weather_effects.reset_count>resets and game.weather_effects.camera_velocity.is_zero_approx(),"Camera switch resets precipitation without a false airflow impulse")
	resets = game.weather_effects.reset_count
	# Teleport the complete simulation, including contact/body pose snapshots.
	var destination: Vector3 = game.sim.position+Vector3(0,0,100)
	destination.y = game.field.sample(destination.x,destination.z).height
	game.sim.reset(destination,game.sim.heading)
	game.sim.prime_contacts(game.field)
	game.previous_position = game.sim.position
	game._process(0.016)
	check(game.weather_effects.reset_count>resets and game.weather_effects.camera_velocity.is_zero_approx(),"Teleport resets precipitation and camera-relative flow")
	controller.set_preset("rain")
	game.effects.muted = false
	game._process(1.0)
	key(KEY_M)
	game._process(2.0)
	check(game.effects.audio_rain.volume_db < -64.0 and game.effects.audio_wind.volume_db < -64.0,"M fades both rain and wind to silence")
	key(KEY_ESCAPE)
	game.hud.weather_button.pressed.emit()
	game.hud.close_weather()
	check(not game.active and game.hud.menu_mode=="paused","Weather controls return to pause without resuming")
	controller.set_automatic(false)
	controller.set_preset("clear")
	game.effects.muted = false
	game.camera.effects_enabled = true
	game.camera.close_view = false
	game.restart()

func _lighting_checks() -> void:
	var weather = game.weather
	weather.set_preset("clear")
	weather.set_time_of_day("day")
	weather.set_time_cycle(false)
	var noon_energy: float = weather.state.sun_energy
	var noon_direction: Vector3 = weather.state.sun_direction
	weather.set_time_of_day("dawn")
	check(weather.state.sun_energy>0.0 and weather.state.sun_energy<noon_energy and weather.state.sun_color.r>weather.state.sun_color.b,"Dawn has lower, warmer sunlight than noon")
	weather.set_time_of_day("dusk")
	check(weather.state.sun_energy>0.0 and weather.state.sun_direction.dot(noon_direction)<0.5,"Dusk changes the sun direction as well as its color")
	weather.set_time_of_day("night")
	game._process(0.1)
	check(not game.world.sun.visible and game.world.moon.visible and weather.state.moon_energy>0.0,"Night extinguishes the sun and enables cool moonlight")
	weather.set_preset("rain")
	var wet_moon: float = weather.state.moon_energy
	weather.set_preset("clear")
	check(weather.state.moon_energy>wet_moon,"Overcast weather softens night lighting as well as daylight")
	weather.set_time_of_day("day")
	weather.set_preset("rain")
	check(weather.state.sun_energy<noon_energy,"Weather reduces the strength of daylight")
	weather.set_preset("cloudy")
	game._process(0.1)
	var sky_params = game.world.weather_material.get_shader_parameter("cloud_params")
	var snow_params = game.world.snow_material.get_shader_parameter("cloud_params")
	var rider_params = game.skier.material_probe().get_shader_parameter("cloud_params")
	check(sky_params==snow_params and snow_params==rider_params and snow_params.w>0.0,"Sky, snow and skier share the same moving cloud field")
	var offset: Vector2 = game.world.cloud_offset
	game.world.update_weather(weather.state,10.0,false)
	check(offset==game.world.cloud_offset,"Paused clouds do not move their ground shadows")
	game.world.update_weather(weather.state,1.0,true)
	check(game.world.cloud_offset.distance_to(offset)>1.0,"Wind moves the shared cloud field in world metres")
	weather.set_quality(0)
	weather.set_time_of_day("night")
	game._process(0.1)
	check(game.world.snow_material.get_shader_parameter("cloud_params").w==0.0 and game.world.moon.visible,"Effects Off removes cloud shadows while retaining selected time of day")
	weather.set_quality(2)
	weather.set_time_of_day("day")
	weather.set_time_cycle(true)
	var hour: float = weather.daylight.hour
	weather.update_weather(50.0,false,true)
	check(weather.daylight.hour==hour,"Title and pause do not advance the optional time cycle")
	weather.update_weather(300.0,true)
	check(is_equal_approx(weather.daylight.hour,18.0),"Automatic time advances a quarter day in five minutes")
	game.restart()
	check(is_equal_approx(weather.daylight.hour,18.0) and weather.daylight.automatic,"Restart retains time of day and its cycle setting")
	weather.update_weather(1200.0,true)
	check(is_equal_approx(weather.daylight.hour,18.0),"Twenty-minute time cycle wraps continuously")
	var single_shadow_light = true
	for step in range(480):
		weather.daylight.hour = step*0.05
		weather.update_weather(0.0,false)
		if weather.state.sun_energy>0.001 and weather.state.moon_energy>0.001:
			single_shadow_light = false
	check(single_shadow_light,"The complete time cycle keeps at most one shadow-casting light active")
	game.hud.time_of_day.item_selected.emit(0)
	game.hud.time_cycle.toggled.emit(false)
	check(weather.state.time_label=="Dawn" and not weather.daylight.automatic,"Time controls select a preset and stop the automatic cycle")
	weather.set_time_of_day("day")
	weather.set_preset("clear")
