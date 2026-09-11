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
	var previous = 0.0
	for kmh in [0, 30, 60, 90, 120, 150, 200, 240]:
		reset(kmh)
		update(0.1)
		check(camera.fov >= previous and camera.fov <= 110.0, "FOV monotonic and capped at %d km/h" % kmh)
		previous = camera.fov
	check(is_equal_approx(camera.fov, 110.0), "200+ FOV settles at 110 degrees")
	check(is_equal_approx(camera.boom_distance, 7.0) and is_equal_approx(camera.boom_height, 8.0), "Fast straight framing is 7 m / 8 m")
	reset()
	update(0.1)
	check(is_equal_approx(camera.fov, 72.0) and is_equal_approx(camera.boom_distance, 3.0) and is_equal_approx(camera.boom_height, 6.0), "Rest framing is 72 degrees / 3 m / 6 m")
	sim.velocity = Vector3.BACK * 200.0 / 3.6
	update(0.1)
	check(camera.fov > 72.0 and camera.fov < 100.0, "Acceleration widens smoothly without a snap")
	update(4.0)
	check(absf(camera.fov - 110.0) < 0.01, "Acceleration converges to 110")
	sim.velocity = Vector3.ZERO
	update(0.1)
	check(camera.fov > 90.0 and camera.fov < 110.0, "Braking narrows smoothly")
	reset(200)
	camera.close_view = true
	update(0.1)
	check(is_equal_approx(camera.fov, 110.0) and camera.position.distance_to(sim.position) < 2.0, "First person widens lens while retaining eye position")
	reset(200)
	camera.effects_enabled = false
	update(0.1)
	check(camera.fov == 72.0 and camera.boom_distance == 3.0 and camera.boom_height == 6.0, "Comfort uses configured stationary framing")
	reset()
	update(0.1, 120, true)
	check(camera.fov == 72.0 and absf(camera.position.distance_to(sim.position) - Vector2(30.0,45.0).length()) < 0.01, "Summit retains its overview scale after chase framing changes")
	_carve_checks()
	_look_checks()
	_input_checks()
	_clearance_checks()
	_rate_checks()
	_settings_checks()
	_lens_tilt_checks()
	_stabilization_checks()
	_pitch_checks()
	camera.queue_free()
	await process_frame
	var report = {"checks":checks, "failures":failures,"smoothing_metrics":smoothing_metrics,"pitch_metrics":pitch_metrics}
	DirAccess.make_dir_recursive_absolute("res://artifacts/camera_upgrade")
	FileAccess.open("res://artifacts/camera_upgrade/camera_results.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("CAMERA_RESULTS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _carve_checks() -> void:
	reset(150)
	sim.edge_angle = deg_to_rad(35.0)
	sim.lateral_acceleration = 1.3 * 9.81
	update(0.12)
	var attack: float = camera.carve_blend
	check(attack > 0.60 and attack < 0.65, "Carve enters with 0.12 s time constant")
	update(1.0)
	var straight_distance = lerpf(3.0, 7.0, Camera.speed_factor(150))
	var straight_height = lerpf(6.0, 8.0, Camera.speed_factor(150))
	check(absf(camera.boom_distance - (straight_distance - 0.6)) < 0.01 and absf(camera.boom_height - (straight_height - 0.25)) < 0.01, "Hard carve is bounded to 0.6 m inward / 0.25 m downward")
	var left: float = Camera.carve_factor(sim)
	sim.lateral_acceleration *= -1.0
	sim.edge_angle *= -1.0
	check(is_equal_approx(left, Camera.carve_factor(sim)), "Left and right carve response is symmetric")
	for i in 20:
		sim.lateral_acceleration *= -1.0
		sim.edge_angle *= -1.0
		update(0.1)
	check(camera.carve_blend <= 1.0 and camera.boom_distance >= 2.4 and camera.boom_height >= 5.25, "Repeated S turns cannot accumulate compression")
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
	check(camera.position.y < automatic_height - 2.0, "Intentional look up can lower the raised orbit")
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
		check(absf(result.x - results[0].x) < 0.05 and absf(result.y - results[0].y) < 0.001 and absf(result.z - results[0].z) < 0.001, "Speed, look return and carve smoothing agree at 30â€“240 Hz")

func _settings_checks() -> void:
	var preferences = Preferences.new()
	preferences.restore({"rest_distance":-10.0,"fast_distance":999.0})
	check(preferences.rest_distance == 1.0 and preferences.fast_distance == 20.0, "Saved distances are bounded to the menu range")
	preferences.restore({"rest_distance":NAN,"fast_distance":INF})
	check(preferences.snapshot() == Preferences.DEFAULTS, "Nonfinite saved distances recover safe defaults")
	preferences.restore({"rest_distance":5.23,"fast_distance":12.5})
	check(preferences.rest_distance == 5.25, "Distances use quarter-metre increments")
	preferences.restore({"rest_height":-10.0,"fast_height":999.0,"vertical_smoothing":999.0})
	check(preferences.rest_height == 2.0 and preferences.fast_height == 20.0 and preferences.vertical_smoothing == 100.0, "Height and smoothing use their own menu bounds")
	preferences.restore({"rest_height":NAN,"fast_height":INF,"vertical_smoothing":-INF})
	check(preferences.rest_height == 6.0 and preferences.fast_height == 8.0 and preferences.vertical_smoothing == 50.0, "Nonfinite new preferences recover safe defaults")
	preferences.restore({"rest_height":5.23,"fast_height":3.12,"vertical_smoothing":73.3})
	check(preferences.rest_height == 5.25 and preferences.fast_height == 3.0 and preferences.vertical_smoothing == 73.0, "Height and smoothing snap to quarter metres and whole percent")
	for key in ["rest_fov","fast_fov","chase_pitch_offset","first_person_pitch_offset"]:
		var bounds: Vector3 = Preferences.RANGES[key]
		for value in [-999.0,999.0]:
			preferences.restore({key:value})
			check(preferences.get(key) == (bounds.x if value < 0.0 else bounds.y),"Lens/tilt bounds: " + key)
		for value in [NAN,INF,-INF]:
			preferences.restore({key:value})
			check(preferences.get(key) == Preferences.DEFAULTS[key],"Nonfinite lens/tilt recovers default: " + key)
		preferences.restore({key:78.4 if key.ends_with("fov") else -12.4})
		var selected: float = preferences.get(key)
		check(selected == (78.0 if key.ends_with("fov") else -12.0),"Lens/tilt uses whole degrees: " + key)
		for value in ["invalid",true,[],Vector2.ONE]: preferences.restore({key:value})
		check(preferences.get(key) == selected,"Malformed lens/tilt types are ignored: " + key)
	var path = "user://camera_suite_%d.cfg" % Time.get_ticks_usec()
	check(preferences.save_preferences(path) == OK, "Camera preferences save to an isolated test file")
	var restored = Preferences.new()
	restored.load_preferences(path)
	check(restored.snapshot() == preferences.snapshot(), "All nine camera preferences survive reload")
	var legacy = ConfigFile.new()
	legacy.set_value("camera","rest_distance",4.5)
	legacy.set_value("camera","fast_distance",9.5)
	legacy.save(path)
	var old_preferences = Preferences.new()
	old_preferences.load_preferences(path)
	check(old_preferences.rest_distance == 4.5 and old_preferences.fast_distance == 9.5 and old_preferences.rest_height == 6.0 and old_preferences.fast_height == 8.0 and old_preferences.vertical_smoothing == 50.0, "Existing distance-only config gains defaults without losing distances")
	check(old_preferences.rest_fov == 72.0 and old_preferences.fast_fov == 110.0 and old_preferences.chase_pitch_offset == 0.0 and old_preferences.first_person_pitch_offset == 0.0,"Missing lens/tilt keys use original framing defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	preferences.restore({"rest_distance":"invalid","fast_distance":Vector2.ONE})
	preferences.restore({"rest_height":false,"fast_height":[],"vertical_smoothing":"invalid","unexpected":1.0})
	check(preferences.snapshot() == restored.snapshot(), "Malformed preference types are ignored")
	reset()
	camera.settings.restore({"rest_distance":4.0,"fast_distance":9.0})
	update(0.1)
	check(camera.boom_distance == 4.0 and camera.fov == 72.0, "Rest view applies the chosen distance without changing FOV")
	sim.velocity = Vector3.BACK * 200.0 / 3.6
	update(4.0)
	check(absf(camera.boom_distance - 9.0) < 0.01 and absf(camera.fov - 110.0) < 0.01, "Speed blends toward the chosen fast distance with the agreed FOV")
	camera.effects_enabled = false
	update(4.0)
	check(absf(camera.boom_distance - 4.0) < 0.01, "Motion effects off uses the configured resting distance")
	camera.reset()
	check(camera.settings.rest_distance == 4.0 and camera.settings.fast_distance == 9.0, "View reset preserves camera preferences")
	camera.settings.reset()
	for heights in [Vector2(2.0,20.0),Vector2(20.0,2.0)]:
		for kmh in [0,100,200,240]:
			reset(kmh)
			camera.settings.restore({"rest_height":heights.x,"fast_height":heights.y})
			update(0.1)
			var expected = lerpf(heights.x,heights.y,Camera.speed_factor(kmh))
			check(absf(camera.boom_height-expected)<0.001,"Both height endpoint orders blend at %d km/h" % kmh)
	camera.effects_enabled = false
	update(4.0)
	check(absf(camera.boom_height-20.0)<0.01,"Comfort uses selected resting height")
	camera.reset()
	check(camera.settings.rest_height == 20.0,"Camera reset retains height preferences")
	camera.settings.reset()

func _lens_tilt_checks() -> void:
	check(camera.keep_aspect == Camera3D.KEEP_HEIGHT,"FoV preferences measure the vertical angle")
	for close in [false,true]:
		for endpoints in [Vector2(50,120),Vector2(85,85),Vector2(120,50)]:
			for kmh in [0,60,120,200,240]:
				reset(kmh)
				camera.close_view = close
				camera.settings.restore({"rest_fov":endpoints.x,"fast_fov":endpoints.y})
				update(0.1)
				check(absf(camera.fov-lerpf(endpoints.x,endpoints.y,Camera.speed_factor(kmh)))<0.001,"Custom, fixed and reversed FoV: view %s / %s / %d kmh" % [close,endpoints,kmh])
		var rate_results: Array[float] = []
		for hz in [30,60,120,240]:
			reset()
			camera.close_view = close
			camera.settings.restore({"rest_fov":120.0,"fast_fov":50.0})
			update(0.1,hz)
			sim.velocity = Vector3.BACK * 200.0 / 3.6
			update(0.6,hz)
			rate_results.append(camera.fov)
			check(camera.fov>50.0 and camera.fov<120.0,"Custom FoV changes smoothly")
			update(4.0,hz)
			check(absf(camera.fov-50.0)<0.01,"Custom fast FoV converges")
			camera.effects_enabled = false
			update(4.0,hz)
			check(absf(camera.fov-120.0)<0.01,"Motion effects off returns to the configured resting FoV")
		for result in rate_results:
			check(absf(result-rate_results[0])<0.001,"Custom FoV response agrees across 30-240 Hz")
		for kmh in [0,90,200]:
			for offset in [-30.0,0.0,30.0]:
				reset(kmh)
				camera.close_view = close
				update(0.1)
				var original_pitch = optical_pitch()
				var original_position: Vector3 = camera.position
				camera.settings.restore({"chase_pitch_offset":offset if not close else -offset,"first_person_pitch_offset":offset if close else -offset})
				update(0.1)
				var configured_pitch = clampf(original_pitch+deg_to_rad(offset),deg_to_rad(-80.0),deg_to_rad(80.0))
				check(absf(optical_pitch()-configured_pitch)<0.001,"Selected view applies its own tilt with the correct sign")
				check(camera.position.distance_to(original_position)<0.001,"Tilt leaves camera position unchanged")
				camera.add_mouse_look(Vector2(0,-100))
				update(1.0/120.0)
				check(absf(optical_pitch()-clampf(original_pitch+deg_to_rad(offset+10.0),deg_to_rad(-80.0),deg_to_rad(80.0)))<0.001,"Manual look adds immediately to configured tilt")
				camera.recenter_look()
				update(4.0)
				check(absf(optical_pitch()-configured_pitch)<0.001,"Recenter restores configured tilt")
				camera.add_mouse_look(Vector2(0,9999))
				update(1.0/120.0)
				check(absf(rad_to_deg(optical_pitch()))<=80.001,"Combined downward look and tilt cannot flip vertically")
				camera.add_mouse_look(Vector2(0,-19999))
				update(1.0/120.0)
				check(absf(rad_to_deg(optical_pitch()))<=80.001,"Combined upward look and tilt cannot flip vertically")
		reset(200)
		camera.close_view = close
		camera.effects_enabled = false
		camera.settings.restore({"rest_fov":95.0,"chase_pitch_offset":8.0,"first_person_pitch_offset":-7.0})
		update(0.1)
		var comfort_pitch = optical_pitch()
		camera.settings.chase_pitch_offset = 0.0
		camera.settings.first_person_pitch_offset = 0.0
		update(0.1)
		check(absf(comfort_pitch-optical_pitch()-deg_to_rad(-7.0 if close else 8.0))<0.001,"Tilt remains active with motion effects off")
		camera.settings.restore({"rest_fov":95.0,"fast_fov":65.0,"chase_pitch_offset":8.0,"first_person_pitch_offset":-7.0})
		var saved: Dictionary = camera.settings.snapshot()
		camera.close_view = not close
		camera.reset()
		update(0.1)
		check(camera.settings.snapshot()==saved,"View switching and camera reset retain all preferences")
	for context in ["menu","summit","crash"]:
		reset(150)
		camera.clock = 0.0
		sim.crashed = context == "crash"
		camera.update_camera(sim,field,sim.position,0.1,context=="menu",true,context=="summit")
		var original_transform: Transform3D = camera.transform
		var original_fov: float = camera.fov
		camera.settings.restore({"rest_fov":120.0,"fast_fov":50.0,"chase_pitch_offset":30.0,"first_person_pitch_offset":-30.0})
		camera.reset()
		camera.clock = 0.0
		camera.update_camera(sim,field,sim.position,0.1,context=="menu",true,context=="summit")
		check(camera.transform.is_equal_approx(original_transform) and is_equal_approx(camera.fov,original_fov),"Lens/tilt leaves existing %s framing unchanged" % context)
	reset()

func _stabilization_checks() -> void:
	for close in [false,true]:
		var step_results: Array = []
		for hz in [30,60,120,240]:
			for strength in [0.0,50.0,100.0]:
				reset()
				camera.close_view = close
				camera.effects_enabled = false
				camera.settings.vertical_smoothing = strength
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
			camera.settings.vertical_smoothing = 100.0
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
			camera.settings.vertical_smoothing = strength
			sim.position.y = 10.0
			update(0.1)
			camera.add_mouse_look(Vector2(100,-100))
			update(0.05)
			manual_results.append(camera.transform)
		check(manual_results[0].is_equal_approx(manual_results[1]),"Maximum stabilization adds no delay to the actual manual orbit or optical pose")
	reset()
	camera.settings.rest_height = 2.0
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
	var rocks = RockSurface.new()
	camera.update_camera(sim,rocks,sim.position,1.0/120.0)
	check(absf(camera.position.z)<3.0 and camera.position.y>=1.0,"Rock obstruction still retracts the stabilized boom")
	rocks.blocked = false
	for frame in 360: camera.update_camera(sim,rocks,sim.position,1.0/120.0)
	check(absf(camera.position.z+3.0)<0.01,"Boom releases smoothly after rock obstruction clears")

func _bump_metrics(hz: int, strength: float, close: bool) -> Dictionary:
	reset()
	camera.close_view = close
	camera.effects_enabled = false
	camera.settings.vertical_smoothing = strength
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
	camera.settings.rest_height = 2.0
	update(0.1)
	check(camera.boom_height == 12.0 and camera.position.y >= 12.0,"Crash retains its former elevated framing independently of riding height")
	var crash_y: float = camera.position.y
	sim.position.y += 1.0
	update(1.0/120.0)
	check(absf(camera.position.y-crash_y-1.0)<0.001,"Crash follow bypasses added stabilization")

func optical_pitch() -> float:
	return asin(clampf(-camera.global_basis.z.y,-1.0,1.0))

func _pitch_checks() -> void:
	# Nominal chase framing must also work at the user's short distances on
	# steep ground. Checking the projected body catches fixed-aim cropping.
	for slope in [0.0,0.7,1.3]:
		for kmh in [0,60,90,150,200]:
			reset(kmh)
			camera.settings.restore({"rest_distance":1.0,"fast_distance":3.0,"rest_height":2.0,"fast_height":4.0,"vertical_smoothing":40.0})
			field.slope = slope
			update(0.1)
			var body_point = sim.position + Vector3.UP*0.8
			check(not camera.is_position_behind(body_point) and root.get_visible_rect().has_point(camera.unproject_position(body_point)),"Close chase keeps the skier in frame at %.1f slope / %d kmh" % [slope,kmh])
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
						if custom: camera.settings.restore({"rest_distance":1.0,"fast_distance":3.0,"rest_height":2.0,"fast_height":4.0,"chase_pitch_offset":-30.0,"first_person_pitch_offset":30.0,"rest_fov":95.0,"fast_fov":65.0})
						camera.settings.vertical_smoothing = strength
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
			if close: check(absf(rad_to_deg(base_pitch)+10.0)<0.001,"First-person base pitch stays ten degrees down at every speed")
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
