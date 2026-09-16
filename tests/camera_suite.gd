extends SceneTree
const Camera = preload("res://scripts/presentation/chase_camera.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Router = preload("res://scripts/core/input_router.gd")
const Preferences = preload("res://scripts/presentation/camera_settings.gd")
var checks = 0
var failures: Array[String] = []
var camera
var sim = Simulation.new()
var field = Surface.new()
var smoothing_metrics: Array = []
var pitch_metrics: Array = []

class Surface extends RefCounted:
	var slope = 0.0
	var ridge = false
	var height_offset = 0.0
	var ahead_offset = 0.0
	func sample(x: float, z: float) -> Dictionary:
		var height = -z * slope + height_offset
		if z > 1.0: height += ahead_offset
		if ridge: height += 4.0 * exp(-pow((z + 4.0) / 1.5, 2.0)) * exp(-x*x / 100.0)
		return {"height":height}

class RockSurface extends Surface:
	var blocked = true
	func ray_geology(_from: Vector3, _to: Vector3, _radius: float) -> Dictionary:
		return {"fraction":0.5,"normal":Vector3.BACK} if blocked else {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func update(seconds: float, hz: int = 120, summit: bool = false, active: bool = true) -> void:
	for i in roundi(seconds * hz):
		camera.update_camera(sim, field, sim.position, 1.0 / hz, false, active, summit)

func reset(kmh: float = 0.0) -> void:
	sim.reset(Vector3.ZERO, 0.0)
	sim.velocity = Vector3.BACK * kmh / 3.6
	camera.close_view = false
	camera.effects_enabled = true
	field.slope = 0.0
	field.ridge = false
	field.height_offset = 0.0
	field.ahead_offset = 0.0
	camera.settings.reset()
	camera.reset()

func run() -> void:
	camera = Camera.new()
	# A frozen presentation script allows the same assertions to reproduce the
	# old defect without reverting shared source or touching player preferences.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera-baseline-script="):
			camera.free()
			camera = load(arg.get_slice("=",1)).new()
	root.add_child(camera)
	_framing_checks()
	_carve_checks()
	_look_checks()
	_input_checks()
	_clearance_checks()
	_rate_checks()
	_stabilization_checks()
	_pitch_checks()
	camera.queue_free()
	await process_frame
	var report = {"checks":checks, "failures":failures,"smoothing_metrics":smoothing_metrics,"pitch_metrics":pitch_metrics}
	DirAccess.make_dir_recursive_absolute("res://artifacts/camera_upgrade")
	preload("res://tests/test_report.gd").write("res://artifacts/camera_upgrade/camera_results.json",JSON.stringify(report, "\t"))
	print("CAMERA_RESULTS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _carve_checks() -> void:
	reset(150)
	configure({"carve_strength":100.0})
	sim.edge_angle = deg_to_rad(35.0)
	sim.lateral_acceleration = 1.3 * 9.81
	update(0.12)
	var attack: float = camera.carve_blend
	check(attack > 0.60 and attack < 0.65, "Carve enters with 0.12 s time constant")
	update(1.0)
	var straight_distance = camera.settings.framing("chase",150).y
	var straight_height = camera.settings.framing("chase",150).z
	check(absf(camera.boom_distance - (straight_distance - 0.6)) < 0.01 and absf(camera.boom_height - (straight_height - 0.25)) < 0.01, "Hard carve is bounded to 0.6 m inward / 0.25 m downward")
	var left: float = Camera.carve_factor(sim)
	sim.lateral_acceleration *= -1.0
	sim.edge_angle *= -1.0
	check(is_equal_approx(left, Camera.carve_factor(sim)), "Left and right carve response is symmetric")
	for i in 20:
		sim.lateral_acceleration *= -1.0
		sim.edge_angle *= -1.0
		update(0.1)
	check(camera.carve_blend <= 1.0 and camera.boom_distance >= 2.4 and camera.boom_height >= 2.75, "Repeated S turns cannot accumulate compression")
	sim.lateral_acceleration = 0.0
	update(0.12)
	check(camera.carve_blend > 0.80 and camera.carve_blend < 0.83, "Release is slower than attack")
	update(2.0)
	check(camera.carve_blend < 0.04, "Straight line releases carving compression")
	sim.lateral_acceleration = 1.3 * 9.81
	sim.slip_angle = deg_to_rad(30)
	check(absf(Camera.carve_factor(sim) - 0.5) < 0.001, "Heavy slip fades carving")
	sim.slip_angle = deg_to_rad(40)
	check(Camera.carve_factor(sim) == 0.0, "Full skid has no carve target")
	sim.slip_angle = 0.0
	sim.grounded = false
	check(Camera.carve_factor(sim) == 0.0, "Airborne lateral force cannot trigger carving")
	sim.grounded = true
	sim.time_since_landing = 0.1
	check(Camera.carve_factor(sim) == 0.0, "Landing transient cannot trigger carving")
	sim.time_since_landing = 1.0
	sim.velocity = Vector3.BACK * 30.0 / 3.6
	check(is_zero_approx(Camera.carve_factor(sim)), "Low speed cannot trigger carving")
	sim.velocity *= 5.0
	camera.add_mouse_look(Vector2(200, 0))
	update(0.1)
	check(camera.carve_blend == 0.0, "Manual look suppresses carving")
	camera.reset()
	camera.close_view = true
	update(0.1)
	check(camera.carve_blend == 0.0, "First person suppresses carving")
	camera.close_view = false
	update(0.1, 120, true)
	check(camera.carve_blend == 0.0, "Summit suppresses carving")
	update(0.1, 120, false, false)
	check(camera.carve_blend == 0.0, "Inactive presentation suppresses carving")
	camera.effects_enabled = false
	update(0.1)
	check(camera.carve_blend == 0.0, "Comfort suppresses carving")

func _look_checks() -> void:
	reset()
	camera.add_mouse_look(Vector2(900, 100))
	update(0.1)
	check(absf(rad_to_deg(camera.look_yaw) + 90.0) < 0.001 and camera.look_pitch < 0.0, "Mouse right/down turns view right/down")
	var held = Vector2(camera.look_yaw, camera.look_pitch)
	update(3.0)
	check(held.is_equal_approx(Vector2(camera.look_yaw, camera.look_pitch)), "Stationary view holds indefinitely")
	camera.recenter_look()
	update(1.5)
	check(absf(camera.look_yaw) < 0.03, "Explicit recenter works while stationary")
	reset(100)
	camera.add_mouse_look(Vector2(900, 0))
	update(1.0 / 120.0)
	update(0.7)
	check(absf(rad_to_deg(camera.look_yaw) + 90.0) < 0.001, "Moving look holds through idle delay")
	update(0.45)
	check(absf(rad_to_deg(camera.look_yaw) + 90.0 / exp(1.0)) < 0.01, "Return integrates only time beyond 0.8 s")
	reset()
	camera.set_stick_look(Vector2(1, 0))
	update(1.0 / 120.0)
	check(absf(rad_to_deg(camera.look_yaw) + 1.25) < 0.001, "Full stick yaw rate is 150 degrees per second")
	reset()
	camera.close_view = true
	camera.add_mouse_look(Vector2(1700, -2000))
	update(0.1)
	check(absf(rad_to_deg(camera.look_yaw) + 120.0) < 0.001 and rad_to_deg(camera.look_pitch) <= 60.01, "First-person yaw and pitch have safe limits")
	check(absf(camera.global_basis.z.y) < 0.99 and camera.global_basis.determinant() > 0.99, "First-person optical pitch does not flip")
	camera.add_mouse_look(Vector2(4000, 0))
	update(0.1)
	check(absf(rad_to_deg(camera.look_yaw) + 120.0) < 0.001, "Large first-person mouse motion cannot wrap across the yaw stop")
	reset()
	camera.add_mouse_look(Vector2(1700, 0))
	update(0.1, 120, true)
	check(absf(rad_to_deg(camera.look_yaw) + 170.0) < 0.001 and camera.position.z > 0.0, "Summit supports orbit behind the chosen heading")
	update(3.0, 120, true)
	check(absf(rad_to_deg(camera.look_yaw) + 170.0) < 0.001, "Summit retains chosen look")
	reset()
	camera.effects_enabled = false
	camera.add_mouse_look(Vector2(500, 0))
	update(0.1)
	check(camera.look_yaw < -0.8, "Comfort does not disable look")
	camera.add_mouse_look(Vector2(100, 0))
	camera.set_stick_look(Vector2.ONE)
	camera.reset()
	check(camera.pending_mouse.is_zero_approx() and camera.pending_stick.is_zero_approx() and camera.look_yaw == 0.0 and camera.carve_blend == 0.0, "Reset clears view and pending controls")

func _input_checks() -> void:
	var router = Router.new()
	Input.action_press("look_right", 0.17)
	check(router.sample_camera_look().is_zero_approx(), "Stick drift inside radial deadzone is ignored")
	Input.action_press("look_right", 0.59)
	check(absf(router.sample_camera_look().x - 0.25) < 0.001, "Stick response is progressive after deadzone")
	Input.action_press("look_down", 1.0)
	Input.action_press("look_right", 1.0)
	check(absf(router.sample_camera_look().length() - 1.0) < 0.001, "Diagonal stick input is bounded")
	var intent = router.sample()
	check(intent.steer == 0.0 and intent.tuck == 0.0 and intent.brake == 0.0, "Camera actions never become skier input")
	for action in ["look_right", "look_down"]: Input.action_release(action)
	for item in [["look_left", JOY_AXIS_RIGHT_X, -1.0], ["look_right", JOY_AXIS_RIGHT_X, 1.0], ["look_up", JOY_AXIS_RIGHT_Y, -1.0], ["look_down", JOY_AXIS_RIGHT_Y, 1.0]]:
		var found = false
		for event in InputMap.action_get_events(item[0]):
			if event is InputEventJoypadMotion and event.axis == item[1] and event.axis_value == item[2]: found = true
		check(found, "Logical controller binding: " + item[0])
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.pressed = true
	var pad = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_RIGHT_STICK
	pad.pressed = true
	check(mouse.is_action_pressed("camera_recenter") and pad.is_action_pressed("camera_recenter"), "Middle mouse and R3 recenter")

func _clearance_checks() -> void:
	# Preferred clearance is measured above the snow behind the skier.
	# Actual collision corrections still retain priority over stabilization.
	for slope in [0.0, 0.7, 1.3]:
		for kmh in [0, 30, 90, 150, 200, 240]:
			reset(kmh)
			field.slope = slope
			update(0.1)
			var clearance: float = camera.position.y - field.sample(camera.position.x, camera.position.z).height
			var minimum = Camera.PREFERRED_SNOW_CLEARANCE
			check(clearance >= minimum - 0.01, "Preferred clearance above uphill snow at %.1f slope / %d km/h" % [slope, kmh])
	reset(150)
	field.slope = 1.3
	sim.edge_angle = deg_to_rad(35)
	sim.lateral_acceleration = 1.3 * 9.81
	update(1.0)
	var carve_clearance: float = camera.position.y - field.sample(camera.position.x, camera.position.z).height
	check(carve_clearance >= 1.99, "Hard carving retains preferred clearance on steep snow")
	camera.effects_enabled = false
	update(3.0)
	check(camera.position.y - field.sample(camera.position.x, camera.position.z).height >= 1.99, "Comfort retains preferred clearance on steep snow")
	reset()
	update(0.1)
	var automatic_height: float = camera.position.y
	camera.add_mouse_look(Vector2(0, -500))
	update(0.8)
	check(camera.position.y < automatic_height - 0.5, "Intentional look up can lower the raised orbit")
	camera.recenter_look()
	update(3.0)
	check(absf(camera.position.y - automatic_height) < 0.05, "Recenter restores configured framing after look up")
	for slope in [0.0, 0.7, 1.3]:
		for yaw in [-170.0, -90.0, 0.0, 90.0, 170.0]:
			reset(150)
			field.slope = slope
			field.ridge = true
			camera.add_mouse_look(Vector2(yaw * 10, 500))
			update(0.5)
			check(camera.position.y >= field.sample(camera.position.x, camera.position.z).height + 0.99, "Orbit clears terrain slope %.1f / yaw %.0f" % [slope, yaw])
	reset(200)
	update(0.1)
	var offset: Vector3 = camera.position - sim.position
	sim.position += Vector3(500, -200, 700)
	field.slope = 0.0
	sim.position.y = 0.0
	update(1.0 / 120.0)
	check((camera.position - sim.position).distance_to(offset) < 0.001, "Translation does not accumulate high-speed boom lag")

func _rate_checks() -> void:
	var results: Array[Vector3] = []
	for hz in [30, 60, 120, 240]:
		reset()
		update(1.0 / hz, hz)
		sim.velocity = Vector3.BACK * 200.0 / 3.6
		sim.edge_angle = deg_to_rad(35)
		sim.lateral_acceleration = 1.3 * 9.81
		update(0.6, hz)
		var carve: float = camera.carve_blend
		camera.add_mouse_look(Vector2(900, 0))
		update(1.0 / hz, hz)
		update(1.5, hz)
		results.append(Vector3(camera.fov, camera.look_yaw, carve))
	for result in results:
		check(absf(result.x - results[0].x) < 0.05 and absf(result.y - results[0].y) < 0.001 and absf(result.z - results[0].z) < 0.001, "Speed, look return and carve smoothing agree at 30–240 Hz")

func _stabilization_checks() -> void:
	for close in [false,true]:
		var step_results: Array = []
		for hz in [30,60,120,240]:
			for strength in [0.0,50.0,100.0]:
				reset()
				camera.close_view = close
				camera.effects_enabled = false
				configure({"vertical_smoothing":strength})
				sim.position.y = 10.0
				update(0.1,hz)
				var start_y: float = camera.position.y
				var start_pitch = optical_pitch()
				sim.position.y += 0.18
				field.ahead_offset = 0.4
				update(0.2,hz)
				var tau = Camera.MAX_SMOOTHING_TAU*strength/100.0
				var expected = 0.18 if strength == 0.0 else 0.18*(1.0-exp(-0.2/tau))
				check(absf(camera.position.y-start_y-expected)<0.0001,"Vertical step follows time-based damping: view %s / %d Hz / %.0f%%" % [close,hz,strength])
				check(absf(optical_pitch()-start_pitch)<deg_to_rad(0.1),"Rider and terrain height steps cannot change optical pitch")
				if strength == 50.0: step_results.append(camera.position.y)
			var direct = _bump_metrics(hz,0.0,close)
			var moderate = _bump_metrics(hz,50.0,close)
			var strong = _bump_metrics(hz,100.0,close)
			check(moderate.vertical_rms < direct.vertical_rms*0.65,"Default stabilization reduces repeated vertical bumps at %d Hz / view %s" % [hz,close])
			check(strong.vertical_rms < moderate.vertical_rms,"Stronger stabilization progressively reduces vertical motion")
			check(maxf(direct.pitch_rms,maxf(moderate.pitch_rms,strong.pitch_rms))<0.0001,"Bumps cannot rotate the view even with stabilization disabled")
			smoothing_metrics.append({"hz":hz,"first_person":close,"off":direct,"default":moderate,"maximum":strong})
			reset(90)
			camera.close_view = close
			camera.effects_enabled = false
			configure({"vertical_smoothing":100.0})
			field.height_offset = -300.0
			sim.position.y = 100.0
			update(0.1,hz)
			var horizontal = Vector2(camera.position.x-sim.position.x,camera.position.z-sim.position.z)
			var max_lag = 0.2 if close else 1.5
			var bounded = true
			var translation = true
			for frame in hz*3:
				sim.position += Vector3(0,-20.0,25.0)/hz
				camera.update_camera(sim,field,sim.position,1.0/hz)
				bounded = bounded and absf(camera.position.y-camera.follow_position.y)<=max_lag+0.001
				translation = translation and Vector2(camera.position.x-sim.position.x,camera.position.z-sim.position.z).distance_to(horizontal)<0.001
			check(bounded and translation,"Sustained descent bounds vertical lag and follows horizontal travel immediately")
		for result in step_results:
			check(absf(result-step_results[0])<0.0001,"Equal elapsed time gives the same vertical step at 30–240 Hz")
		_lifecycle_stabilization_checks(close)
		var manual_results: Array = []
		for strength in [0.0,100.0]:
			reset()
			camera.close_view = close
			camera.effects_enabled = false
			configure({"vertical_smoothing":strength})
			sim.position.y = 10.0
			update(0.1)
			camera.add_mouse_look(Vector2(100,-100))
			update(0.05)
			manual_results.append(camera.transform)
		check(manual_results[0].is_equal_approx(manual_results[1]),"Maximum stabilization adds no delay to the actual manual orbit or optical pose")
	reset()
	configure({"rest_height":2.0})
	update(0.1)
	field.ridge = true
	update(1.0/120.0)
	check(camera.position.y >= field.sample(camera.position.x,camera.position.z).height+0.99,"A sudden uphill obstruction overrides damping")
	check(absf(camera.stabilized_height+camera.follow_manual_height-camera.position.y)<0.0001,"Collision correction reconciles stabilization state")
	update(3.0)
	field.ridge = false
	var previous_y: float = camera.position.y
	var monotonic = true
	for frame in 360:
		update(1.0/120.0)
		monotonic = monotonic and camera.position.y<=previous_y+0.0001 and camera.position.y>=1.0
		previous_y = camera.position.y
	check(monotonic and absf(camera.position.y-2.0)<0.02,"Clearing an obstruction settles without repeated upward kicks")
	reset()
	update(0.1)
	var unobstructed_boom: Vector3 = camera.position
	reset()
	var rocks = RockSurface.new()
	camera.update_camera(sim,rocks,sim.position,1.0/120.0)
	check(absf(camera.position.z)<3.0 and camera.position.y>=1.0,"Rock obstruction still retracts the stabilized boom")
	rocks.blocked = false
	for frame in 360: camera.update_camera(sim,rocks,sim.position,1.0/120.0)
	check(camera.position.distance_to(unobstructed_boom)<0.01,"Boom releases smoothly after rock obstruction clears")

func _bump_metrics(hz: int, strength: float, close: bool) -> Dictionary:
	reset()
	camera.close_view = close
	camera.effects_enabled = false
	configure({"vertical_smoothing":strength})
	sim.position.y = 10.0
	update(0.1,hz)
	var previous_y: float = camera.position.y
	var previous_pitch: float = camera.rotation.x
	var vertical_energy = 0.0
	var pitch_energy = 0.0
	for frame in hz*2:
		var wave = sin(TAU*8.0*float(frame+1)/hz)
		sim.position.y = 10.0+0.12*wave
		field.ahead_offset = 0.6*wave
		camera.update_camera(sim,field,sim.position,1.0/hz)
		if frame>=hz:
			vertical_energy += pow((camera.position.y-previous_y)*hz,2)
			pitch_energy += pow((camera.rotation.x-previous_pitch)*hz,2)
		previous_y = camera.position.y
		previous_pitch = camera.rotation.x
	return {"vertical_rms":sqrt(vertical_energy/hz),"pitch_rms":sqrt(pitch_energy/hz)}

func _lifecycle_stabilization_checks(close: bool) -> void:
	reset()
	camera.close_view = close
	camera.effects_enabled = false
	sim.position.y = 10.0
	update(0.1)
	sim.position.y += 0.18
	update(1.0/120.0)
	var paused_y: float = camera.position.y
	update(1.0/120.0,120,false,false)
	check(camera.position.y>paused_y and camera.position.y<camera.follow_position.y,"Pause retains and settles the existing follow state")
	var resumed_y: float = camera.position.y
	update(1.0/120.0)
	check(camera.position.y>resumed_y and camera.position.y<camera.follow_position.y,"Resume continues smoothly without a reset snap")
	sim.grounded = false
	update(0.2)
	var air_pitch = optical_pitch()
	sim.grounded = true
	update(1.0/120.0)
	check(absf(optical_pitch()-air_pitch)<deg_to_rad(0.1),"Landing preserves airborne optical pitch")
	var before = [sim.position,sim.velocity,sim.heading,sim.grounded]
	camera.add_mouse_look(Vector2(100,-100))
	update(1.0/120.0)
	check(absf(camera.look_yaw-deg_to_rad(-10.0))<0.0001 and absf(camera.look_pitch-deg_to_rad(10.0))<0.0001,"Manual look is not filtered by vertical stabilization")
	check(before == [sim.position,sim.velocity,sim.heading,sim.grounded],"Stabilization and look never change completed simulation state")
	camera.reset()
	sim.position = Vector3(500,50,500)
	update(1.0/120.0)
	check(absf(camera.position.y-camera.follow_position.y)<0.0001 and camera.look_yaw==0.0,"Restart or teleport reset initializes stabilization directly")
	camera.close_view = not close
	update(1.0/120.0)
	check(absf(camera.position.y-camera.follow_position.y)<0.0001,"View changes reseed stabilization even when the caller omits reset")
	reset()
	update(0.1,120,true)
	sim.position += Vector3(0,1,0)
	var summit_y: float = camera.position.y
	update(1.0/120.0,120,true)
	check(absf(camera.position.y-summit_y-1.0)<0.001,"Summit translation retains its original immediate response")
	reset()
	sim.crashed = true
	configure({"rest_height":2.0})
	update(0.1)
	check(camera.boom_height == 12.0 and camera.position.y >= 12.0,"Crash retains its former elevated framing independently of riding height")
	var crash_y: float = camera.position.y
	sim.position.y += 1.0
	update(1.0/120.0)
	check(absf(camera.position.y-crash_y-1.0)<0.001,"Crash follow bypasses added stabilization")

func optical_pitch() -> float:
	return asin(clampf(-camera.global_basis.z.y,-1.0,1.0))

func _pitch_checks() -> void:
	# Built-in presets must retain a visible skier on ordinary and steep snow.
	for preset in Preferences.BUILT_INS:
		for slope in [0.0,0.7,1.3]:
			for kmh in [0,60,90,150,200]:
				reset(kmh)
				camera.settings.apply_preset("chase",preset)
				field.slope = slope
				update(0.1)
				var body_point = sim.position + Vector3.UP*0.8
				check(not camera.is_position_behind(body_point) and root.get_visible_rect().has_point(camera.unproject_position(body_point)),"Preset keeps skier in frame: %s / %.1f slope / %d kmh" % [preset,slope,kmh])
	# These are controlled presentation inputs, not a claim about solver motion.
	# At fixed speed, even effects-enabled impacts must leave optical pitch alone.
	for close in [false,true]:
		for hz in [30,60,120,240]:
			for strength in [0.0,40.0,100.0]:
				for custom in [false,true]:
					var maxima = {}
					for event in ["isolated_bump","repeated_bumps","brief_airtime","landing","terrain_clearance","rock_clearance"]:
						reset(150)
						camera.close_view = close
						if custom: configure({"rest_distance":1.0,"fast_distance":3.0,"rest_height":2.0,"fast_height":4.0,"rest_tilt":-60.0,"fast_tilt":-60.0,"rest_fov":95.0,"fast_fov":65.0})
						configure({"vertical_smoothing":strength})
						var rocks = RockSurface.new()
						rocks.blocked = false
						var surface = rocks if event == "rock_clearance" else field
						camera.update_camera(sim,surface,sim.position,1.0/hz)
						var initial_pitch = optical_pitch()
						var maximum = 0.0
						var clearance_ok = true
						for frame in hz*2:
							var t = float(frame+1)/hz
							match event:
								"isolated_bump":
									var bump = sin(PI*clampf((t-0.3)/0.2,0.0,1.0))
									sim.position.y = bump*0.6
									field.ahead_offset = bump*1.5
								"repeated_bumps":
									var bump = sin(TAU*8.0*t)
									sim.position.y = bump*0.12
									field.ahead_offset = bump*0.6
								"brief_airtime":
									sim.grounded = not (t>=0.4 and t<0.45 or t>=0.8 and t<0.85)
								"landing":
									sim.grounded = t>=0.6
									sim.position.y = 1.0 if not sim.grounded else 0.0
									sim.landing_force = 80.0 if t>=0.6 and t<0.8 else 0.0
									sim.normal_load = 80.0 if sim.landing_force>0.0 else 9.81
									sim.effective_tuck = 1.0 if sim.grounded else 0.0
									sim.edge_load = 1.0
								"terrain_clearance":
									field.ridge = t>=0.4 and t<1.0
									field.height_offset = 2.0 if field.ridge else 0.0
								"rock_clearance":
									rocks.blocked = t>=0.4 and t<1.0
							var before = [sim.position,sim.velocity,sim.heading,sim.grounded,sim.landing_force,sim.normal_load,sim.effective_tuck]
							camera.update_camera(sim,surface,sim.position,1.0/hz)
							maximum = maxf(maximum,absf(optical_pitch()-initial_pitch))
							clearance_ok = clearance_ok and camera.position.y >= surface.sample(camera.position.x,camera.position.z).height+(0.799 if close else 0.999)
							assert(before == [sim.position,sim.velocity,sim.heading,sim.grounded,sim.landing_force,sim.normal_load,sim.effective_tuck],"Camera mutated simulation state")
						maxima[event] = rad_to_deg(maximum)
						check(maximum<deg_to_rad(0.1),"%s has <0.1 degree pitch excursion: view %s / %d Hz / %.0f%% / custom %s" % [event,close,hz,strength,custom])
						# Rock retraction retains the existing pivot clearance behavior.
						if event == "terrain_clearance": check(clearance_ok,"Terrain correction retains clearance without a pitch kick")
					pitch_metrics.append({"first_person":close,"hz":hz,"smoothing":strength,"custom":custom,"max_pitch_excursion_degrees":maxima})
		for kmh in [0,90,200]:
			reset(kmh)
			camera.close_view = close
			update(0.1)
			var base_pitch = optical_pitch()
			if close: check(absf(rad_to_deg(base_pitch)+10.0)<0.001,"First-person flat-ground pitch stays ten degrees down at every speed")
			camera.add_mouse_look(Vector2(900,-100))
			update(1.0/120.0)
			check(absf(optical_pitch()-base_pitch-deg_to_rad(10.0))<0.001,"Manual pitch is applied immediately after automatic orientation")
			var view_forward: Vector3 = -camera.global_basis.z
			check(Vector2(view_forward.x,view_forward.z).normalized().distance_to(Vector2(-1,0))<0.001,"Manual yaw turns the optical view immediately while the chase boom follows")
			camera.recenter_look()
			update(4.0)
			check(absf(optical_pitch()-base_pitch)<0.001,"Recenter restores the steady base pitch")
		reset(150)
		camera.close_view = close
		update(0.1)
		var prior_pitch = optical_pitch()
		sim.edge_angle = deg_to_rad(35.0)
		sim.lateral_acceleration = 1.3*9.81
		sim.effective_tuck = 1.0
		update(1.0)
		check(absf(optical_pitch()-prior_pitch)<deg_to_rad(0.1),"Carving, bank and tuck cannot steer automatic pitch")

func configure(values: Dictionary) -> void:
	for view in Preferences.VIEWS: camera.settings.update_profile(view,values)

func _framing_checks() -> void:
	for view in Preferences.VIEWS:
		for preset in Preferences.BUILT_INS:
			for kmh in [0,60,100,120,160,200,240]:
				reset(kmh)
				camera.settings.apply_preset(view,preset)
				camera.close_view = view=="first_person"
				update(0.1)
				var expected: Vector4 = camera.settings.framing(view,kmh)
				check(absf(camera.fov-expected.x)<.001 and absf(rad_to_deg(optical_pitch())-(expected.w+(15.0 if view=="first_person" else 30.0)))<.001,"Live framing adds flat-ground correction to evaluator: %s / %s / %d" % [view,preset,kmh])
				if view=="chase": check(absf(camera.boom_distance-expected.y)<.001 and absf(camera.boom_height-expected.z)<.001,"Boom uses same speed progression")
				var before = [sim.position,sim.velocity,sim.heading,sim.ticks]
				camera.reset()
				camera.update_camera(sim,field,sim.position,.1,false,false,false,120)
				check(absf(camera.fov-camera.settings.framing(view,120).x)<.001,"Preview uses shared evaluator")
				check(before==[sim.position,sim.velocity,sim.heading,sim.ticks],"Preview cannot mutate simulation")
	for endpoints in [Vector2(50,120),Vector2(80,50),Vector2(65,65)]:
		reset(100)
		configure({"rest_fov":endpoints.x,"fast_fov":endpoints.y,"rest_tilt":-55,"fast_tilt":-35})
		update(.1)
		check(absf(camera.fov-lerpf(endpoints.x,endpoints.y,pow(.5,1.6)))<.001,"Custom and reversed lens endpoints")
		check(absf(rad_to_deg(optical_pitch())-(lerpf(-55,-35,pow(.5,1.6))+30.0))<.001,"Configured tilt interpolates independently of slope correction")
		var pitch = optical_pitch()
		configure({"rest_distance":12,"fast_distance":16,"rest_height":12,"fast_height":16})
		update(3)
		check(absf(optical_pitch()-pitch)<.001,"Changing geometry never changes configured optical tilt")
	for context in ["menu","summit","crash"]:
		reset(160)
		sim.crashed = context=="crash"
		camera.clock = 0.0
		camera.update_camera(sim,field,sim.position,.1,context=="menu",true,context=="summit")
		var original = [camera.transform,camera.fov]
		configure({"rest_fov":50,"fast_fov":50,"rest_tilt":-80,"fast_tilt":-80,"rest_distance":18,"fast_distance":18,"rest_height":20,"fast_height":20})
		camera.reset()
		camera.clock = 0.0
		camera.update_camera(sim,field,sim.position,.1,context=="menu",true,context=="summit")
		check(camera.transform.is_equal_approx(original[0]) and is_equal_approx(camera.fov,original[1]),"Riding profiles cannot change "+context)
	reset(200)
	configure({"rest_tilt":-35,"fast_tilt":-60})
	camera.effects_enabled = false
	update(.1)
	check(camera.fov==55 and camera.boom_distance==3 and absf(rad_to_deg(optical_pitch())+5)<.001,"V keeps resting framing, chosen tilt and slope following")
	reset(120)
	camera.settings.set_value("shared","auto_recenter",false)
	camera.settings.set_value("shared","invert_y",true)
	camera.settings.set_value("shared","mouse_sensitivity",.2)
	camera.add_mouse_look(Vector2(100,100))
	update(.1)
	check(absf(rad_to_deg(camera.look_yaw)+20)<.001 and absf(rad_to_deg(camera.look_pitch)-20)<.001,"Look sensitivity and inversion apply")
	update(3)
	check(absf(rad_to_deg(camera.look_yaw)+20)<.001,"Automatic return can be disabled")
	camera.recenter_look()
	update(4)
	check(absf(camera.look_yaw)<.001,"Explicit recenter remains available")
	for strength in [0,50,100]:
		reset(150)
		configure({"carve_strength":strength,"bank_strength":strength,"compression_strength":strength,"tuck_strength":strength})
		sim.edge_angle = deg_to_rad(35)
		sim.lateral_acceleration = 9.81
		sim.normal_load = 30
		sim.effective_tuck = 1
		update(2)
		check(camera.carve_blend<=strength/100.0+.001 and absf(camera.bank)<=.035*strength/100.0+.001,"Individual motion controls bound carve and bank")
		if strength==0: check(absf(camera.compression)<.001 and absf(camera.boom_height-camera.settings.framing("chase",150).z)<.001,"Tuck and compression can be disabled")
