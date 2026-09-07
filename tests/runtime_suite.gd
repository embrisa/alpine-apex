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
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(not game.active and game.hud.menu.visible,"Project opens at the start screen")
	var dial_rect: Rect2 = game.hud.speed_dial.get_global_rect()
	check(dial_rect.position.x>=0 and dial_rect.position.y>=0 and root.get_visible_rect().encloses(dial_rect),"Speed dial stays fully inside the viewport")
	check(game.session.course_id=="laboratory-v3-physics-v12-default","Changed terrain and handling use a new benchmark identity")
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
	_feedback_checks()
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

func _feedback_checks() -> void:
	game.active = false
	game.sim.reset(Vector3.ZERO)
	game.intent = RiderInput.new()
	game.sim.impacts.hit(10.5,10.5,"HARD LANDING",game.sim.tuning)
	game.hud.update_hud(game.sim,game.session,game.intent,"Test",8.3,.1,.1,true)
	check(game.hud.state_label.text.begins_with("HARD LANDING") and absf(game.hud.impact_bar.value-65.0)<.001,"Rough landing reduces the visible impact reserve by severity")
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
	for item in [["steer_left",JOY_AXIS_LEFT_X,-1.0],["steer_right",JOY_AXIS_LEFT_X,1.0],["tuck",JOY_AXIS_TRIGGER_RIGHT,1.0],["brake",JOY_AXIS_TRIGGER_LEFT,1.0]]:
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
