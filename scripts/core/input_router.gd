extends RefCounted
## Uses Godot's SDL-backed logical controls, independent of device name/model.
const Intent = preload("res://scripts/core/rider_input.gd")
var stick_flip_armed = false

func _init() -> void:
	_add("steer_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add("steer_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add("tuck", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0)
	# Keep keyboard tuck available when L1 gives the left stick to tricks.
	_add("tuck_keyboard", [KEY_W, KEY_UP])
	_add("brake", [KEY_S, KEY_DOWN], JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add("jump", [KEY_SPACE], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add("spin_left", [KEY_Q])
	_add("spin_right", [KEY_E])
	_add("flip_forward", [KEY_I])
	_add("flip_backward", [KEY_K])
	_add("trick_modifier", [], -1, 0.0, JOY_BUTTON_LEFT_SHOULDER)
	_add("trick_pitch_forward", [], JOY_AXIS_LEFT_Y, -1.0)
	_add("trick_pitch_backward", [], JOY_AXIS_LEFT_Y, 1.0)
	_add("air_tilt_forward", [KEY_W, KEY_UP])
	_add("air_tilt_backward", [KEY_S, KEY_DOWN])
	_add("grab", [KEY_SHIFT], -1, 0.0, JOY_BUTTON_X)
	_add("restart", [KEY_R], -1, 0.0, JOY_BUTTON_Y)
	_add("pause_run", [KEY_ESCAPE], -1, 0.0, JOY_BUTTON_START)
	_add("camera_mode", [KEY_C], -1, 0.0, JOY_BUTTON_RIGHT_SHOULDER)
	_add("look_left", [], JOY_AXIS_RIGHT_X, -1.0)
	_add("look_right", [], JOY_AXIS_RIGHT_X, 1.0)
	_add("look_up", [], JOY_AXIS_RIGHT_Y, -1.0)
	_add("look_down", [], JOY_AXIS_RIGHT_Y, 1.0)
	_add("camera_recenter", [], -1, 0.0, JOY_BUTTON_RIGHT_STICK)
	var recenter_mouse = InputEventMouseButton.new()
	recenter_mouse.button_index = MOUSE_BUTTON_MIDDLE
	if not InputMap.action_has_event("camera_recenter", recenter_mouse):
		InputMap.action_add_event("camera_recenter", recenter_mouse)
	_add("debug_overlay", [KEY_F3], -1, 0.0, JOY_BUTTON_BACK)
	_add("tuning", [KEY_F2])
	_add("toggle_audio", [KEY_M])
	_add("compare_wind", [KEY_F7])
	_add("toggle_hud", [KEY_H])
	_add("begin_run", [KEY_ENTER], -1, 0.0, JOY_BUTTON_A)
	_add("race_library", [KEY_F4])
	_add("run_records", [KEY_F6])
	_add("toggle_ghost", [KEY_G])

func _add(action: String, keys: Array, axis: int = -1, direction: float = 0.0, button: int = -1) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.12)
	for key in keys:
		var event = InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	if axis >= 0:
		var event = InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = direction
		InputMap.action_add_event(action, event)
	if button >= 0:
		var event = InputEventJoypadButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)

func cancel_air_input() -> void:
	stick_flip_armed = false

func sample(grounded: bool = true) -> RiderInput:
	var frame = Intent.new()
	frame.steer = Input.get_axis("steer_left", "steer_right")
	frame.tuck = Input.get_action_strength("tuck")
	frame.brake = Input.get_action_strength("brake")
	frame.jump = Input.is_action_just_released("jump")
	frame.jump_held = Input.is_action_pressed("jump")
	frame.air_yaw = Input.get_axis("spin_left","spin_right")
	frame.air_pitch = Input.get_axis("flip_backward","flip_forward")
	frame.air_tilt = Input.get_axis("air_tilt_backward","air_tilt_forward")
	frame.grab = Input.is_action_pressed("grab")
	var stick_pitch = Input.get_axis("trick_pitch_backward","trick_pitch_forward")
	# Observe center in flight before sharing the grounded tuck axis with flips.
	# Record the resolved air_pitch intent; replay never depends on router state.
	if grounded: cancel_air_input()
	elif absf(stick_pitch)<.000001: stick_flip_armed = true
	if Input.is_action_pressed("trick_modifier"):
		frame.air_yaw = clampf(frame.air_yaw+frame.steer,-1.0,1.0)
		if absf(frame.air_pitch)<.000001: frame.air_pitch = stick_pitch
		frame.steer = 0.0
		frame.air_tilt = 0.0
		frame.tuck = Input.get_action_strength("tuck_keyboard")
	elif stick_flip_armed and absf(frame.air_pitch)<.000001:
		frame.air_pitch = stick_pitch
	return frame

func sample_camera_look(deadzone: float = 0.18, exponent: float = 2.0) -> Vector2:
	# get_vector applies one radial deadzone using raw action strengths.
	var stick = Input.get_vector("look_left", "look_right", "look_up", "look_down", deadzone)
	return stick.normalized() * pow(stick.length(),exponent) if not stick.is_zero_approx() else Vector2.ZERO
