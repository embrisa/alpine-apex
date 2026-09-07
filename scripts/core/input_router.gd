extends RefCounted
## Uses Godot's SDL-backed logical controls, independent of device name/model.
const Intent = preload("res://scripts/core/rider_input.gd")

func _init() -> void:
	_add("steer_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add("steer_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add("tuck", [KEY_W, KEY_UP], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add("brake", [KEY_S, KEY_DOWN], JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add("jump", [KEY_SPACE], -1, 0.0, JOY_BUTTON_A)
	_add("restart", [KEY_R], -1, 0.0, JOY_BUTTON_Y)
	_add("pause_run", [KEY_ESCAPE], -1, 0.0, JOY_BUTTON_START)
	_add("camera_mode", [KEY_C], -1, 0.0, JOY_BUTTON_RIGHT_SHOULDER)
	_add("debug_overlay", [KEY_F3], -1, 0.0, JOY_BUTTON_BACK)
	_add("tuning", [KEY_F2])
	_add("toggle_audio", [KEY_M])
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

func sample() -> RiderInput:
	var frame = Intent.new()
	frame.steer = Input.get_axis("steer_left", "steer_right")
	frame.tuck = Input.get_action_strength("tuck")
	frame.brake = Input.get_action_strength("brake")
	frame.jump = Input.is_action_just_released("jump")
	frame.jump_held = Input.is_action_pressed("jump")
	return frame

func device_label() -> String:
	var pads = Input.get_connected_joypads()
	return Input.get_joy_name(pads[0]) if not pads.is_empty() else "KEYBOARD"
