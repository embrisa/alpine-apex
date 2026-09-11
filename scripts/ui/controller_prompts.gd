extends RefCounted
## Presentation names for Godot's logical controls. InputRouter owns bindings.
const BUTTON_LABELS = {
	JOY_BUTTON_A: ["×", "A", "South button"],
	JOY_BUTTON_B: ["○", "B", "East button"],
	JOY_BUTTON_X: ["□", "X", "West button"],
	JOY_BUTTON_Y: ["△", "Y", "North button"],
	JOY_BUTTON_LEFT_SHOULDER: ["L1", "LB", "Left shoulder"],
	JOY_BUTTON_RIGHT_SHOULDER: ["R1", "RB", "Right shoulder"],
	JOY_BUTTON_LEFT_STICK: ["L3", "LS click", "Left stick click"],
	JOY_BUTTON_RIGHT_STICK: ["R3", "RS click", "Right stick click"],
	JOY_BUTTON_START: ["Options", "Menu", "Start"],
	JOY_BUTTON_BACK: ["Share / Create", "View", "Back button"],
}

static func device_family(mapped_name: String, info: Dictionary = {}) -> String:
	var names = (mapped_name + " " + str(info.get("raw_name",""))).to_lower()
	# SDL returns decimal strings for these IDs in the bundled runtime.
	if int(info.get("vendor_id",0)) == 0x054c: return "playstation"
	for name_part in ["dualshock","dualsense","playstation","ps3","ps4","ps5"]:
		if name_part in names: return "playstation"
	if "xbox" in names or "xinput" in names or info.has("xinput_index") or int(info.get("vendor_id",0)) == 0x045e: return "xbox"
	return "gamepad"

static func button(index: int, family: String) -> String:
	var column = 0 if family == "playstation" else 1 if family == "xbox" else 2
	return BUTTON_LABELS[index][column] if BUTTON_LABELS.has(index) else "Button %d" % index

static func axis(index: int, direction: float, family: String) -> String:
	if index == JOY_AXIS_TRIGGER_LEFT: return "L2" if family == "playstation" else "LT" if family == "xbox" else "left trigger"
	if index == JOY_AXIS_TRIGGER_RIGHT: return "R2" if family == "playstation" else "RT" if family == "xbox" else "right trigger"
	if index == JOY_AXIS_LEFT_X: return "Left stick left" if direction < 0 else "Left stick right"
	if index == JOY_AXIS_LEFT_Y: return "Left stick forward" if direction < 0 else "Left stick back"
	if index == JOY_AXIS_RIGHT_X: return "Right stick left" if direction < 0 else "Right stick right"
	if index == JOY_AXIS_RIGHT_Y: return "Right stick up" if direction < 0 else "Right stick down"
	return "Axis %d" % index

static func binding(action: String, family: String) -> String:
	if not InputMap.has_action(action): return "Unbound"
	for event in InputMap.action_get_events(action):
		if family == "keyboard":
			if event is InputEventKey: return OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE: return "Middle mouse"
		else:
			if event is InputEventJoypadButton: return button(event.button_index,family)
			if event is InputEventJoypadMotion: return axis(event.axis,event.axis_value,family)
	return "Unbound"

static func menu(family: String, authoring: bool = false) -> String:
	if family == "keyboard": return "Arrows / Tab  Navigate     Enter  Select     Esc  Back     Q / E  Categories" + ("     Mouse  Place gate · WASD  Survey" if authoring else "")
	return "D-pad / LS  Navigate     %s  Select     %s  Back     %s / %s  Categories%s" % [button(JOY_BUTTON_A,family),button(JOY_BUTTON_B,family),button(JOY_BUTTON_LEFT_SHOULDER,family),button(JOY_BUTTON_RIGHT_SHOULDER,family),"     Mouse  Terrain placement" if authoring else ""]

static func summit(family: String) -> String:
	return "%s  Direction   ·   %s  Look   ·   %s / %s  Drop in   ·   %s  Pause" % ["A / D" if family == "keyboard" else "Left stick","Mouse" if family == "keyboard" else "Right stick",binding("tuck",family),binding("begin_run",family),binding("pause_run",family)]

static func guide(family: String) -> Dictionary:
	var keyboard = family == "keyboard"
	return {
		"Menu controls": menu(family) + (". Select a text field to type." if keyboard else ". Select a text field to open the controller keyboard."),
		"Skiing": "%s: steer. %s: tuck. %s: brake. Hold %s and release to hop. At the summit, %s or %s drops in." % ["A / D or Left / Right" if keyboard else "Left stick",binding("tuck",family),binding("brake",family),binding("jump",family),binding("tuck",family),binding("begin_run",family)],
		"Air control": ("I / K: forward / backward flips. Q / E: spins. W / S or Up / Down: limited pitch." if keyboard else "Center the left stick after takeoff, then forward / back flips. Left / right turns. %s + stick remains optional for flips / fast spins." % binding("trick_modifier",family)) + " %s: grab." % binding("grab",family),
		"Camera": "%s: look. %s: recenter. %s: change view." % ["Mouse" if keyboard else "Right stick",binding("camera_recenter",family),binding("camera_mode",family)],
		"Shortcuts & tools": "%s: pause. %s: retry while skiing. %s: telemetry. Keyboard shortcuts: H hides the HUD; G toggles the ghost; F2 Physics Workbench; F4 races; F6 records; F7 compares wind. Terrain gate placement uses a pointer." % [binding("pause_run",family),binding("restart",family),binding("debug_overlay",family)],
		"Comfort": "Keyboard shortcuts: V toggles camera motion; M mutes audio. Vibration strength is in Physics Workbench → Feedback.",
	}
