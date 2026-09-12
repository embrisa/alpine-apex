extends RefCounted
## Terrain input has one explicit owner, separate from focus and rider actions.
var terrain_active: bool = false
var stick = Vector2.ZERO
var zoom_axis: float = 0.0
var axes_armed: bool = false
var confirm_armed: bool = false
var keys: Dictionary = {}
var held_buttons: Dictionary = {}

func enter(controller: bool) -> void:
	reset()
	terrain_active = true
	# The button which activated Add/Move must be released before placement.
	confirm_armed = not controller

func reset() -> void:
	terrain_active = false
	stick = Vector2.ZERO
	zoom_axis = 0.0
	axes_armed = false
	confirm_armed = false
	keys.clear()
	held_buttons.clear()

func motion(axis: int, value: float) -> void:
	if not terrain_active: return
	if axis == JOY_AXIS_LEFT_X: stick.x = value
	elif axis == JOY_AXIS_LEFT_Y: stick.y = value
	elif axis == JOY_AXIS_RIGHT_Y: zoom_axis = value
	if stick.length()<.25 and absf(zoom_axis)<.25: axes_armed = true

func button(index: int, pressed: bool) -> String:
	if not terrain_active: return ""
	if not pressed:
		held_buttons.erase(index)
		if index == JOY_BUTTON_A: confirm_armed = true
		return ""
	if held_buttons.has(index): return ""
	held_buttons[index] = true
	if index == JOY_BUTTON_A: return "confirm" if confirm_armed else ""
	if index in [JOY_BUTTON_B,JOY_BUTTON_START]: return "back"
	if index == JOY_BUTTON_X: return "panel"
	return ""

func key(event: InputEventKey) -> String:
	var code = event.physical_keycode if event.physical_keycode else event.keycode
	if not event.pressed:
		keys.erase(code)
		return ""
	if event.echo or keys.has(code): return ""
	keys[code] = true
	if code == KEY_ESCAPE: return "back"
	if code == KEY_TAB: return "panel"
	return ""

func pan() -> Vector2:
	if not terrain_active: return Vector2.ZERO
	var result = Vector2(float(keys.has(KEY_D) or keys.has(KEY_RIGHT))-float(keys.has(KEY_A) or keys.has(KEY_LEFT)),float(keys.has(KEY_S) or keys.has(KEY_DOWN))-float(keys.has(KEY_W) or keys.has(KEY_UP)))
	if axes_armed and stick.length()>.25:
		result += stick.normalized()*clampf((stick.length()-.25)/.75,0.0,1.0)
	return result.limit_length(1.0)

func zoom() -> float:
	return zoom_axis if terrain_active and axes_armed and absf(zoom_axis)>.25 else 0.0
