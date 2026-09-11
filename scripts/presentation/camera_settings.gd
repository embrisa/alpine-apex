extends RefCounted
## Local presentation preferences; never part of physics or replay identity.
const PATH = "user://camera_v1.cfg"
const DEFAULTS = {
	"rest_fov":72.0, "fast_fov":110.0,
	"rest_distance":3.0, "fast_distance":7.0, "rest_height":6.0, "fast_height":8.0,
	"chase_pitch_offset":0.0, "first_person_pitch_offset":0.0, "vertical_smoothing":50.0,
	"forest_visibility":60.0,
}
const MIN_DISTANCE = 1.0
const MAX_DISTANCE = 20.0
const DISTANCE_STEP = 0.25
const RANGES = {
	"rest_fov":Vector3(50.0, 120.0, 1.0),
	"fast_fov":Vector3(50.0, 120.0, 1.0),
	"rest_distance":Vector3(MIN_DISTANCE, MAX_DISTANCE, DISTANCE_STEP),
	"fast_distance":Vector3(MIN_DISTANCE, MAX_DISTANCE, DISTANCE_STEP),
	"rest_height":Vector3(2.0, 20.0, 0.25),
	"fast_height":Vector3(2.0, 20.0, 0.25),
	"chase_pitch_offset":Vector3(-30.0, 30.0, 1.0),
	"first_person_pitch_offset":Vector3(-30.0, 30.0, 1.0),
	"vertical_smoothing":Vector3(0.0, 100.0, 1.0),
	"forest_visibility":Vector3(0.0, 100.0, 1.0),
}
var rest_fov: float = DEFAULTS.rest_fov
var fast_fov: float = DEFAULTS.fast_fov
var rest_distance: float = DEFAULTS.rest_distance
var fast_distance: float = DEFAULTS.fast_distance
var rest_height: float = DEFAULTS.rest_height
var fast_height: float = DEFAULTS.fast_height
var chase_pitch_offset: float = DEFAULTS.chase_pitch_offset
var first_person_pitch_offset: float = DEFAULTS.first_person_pitch_offset
var vertical_smoothing: float = DEFAULTS.vertical_smoothing
var forest_visibility: float = DEFAULTS.forest_visibility

func snapshot() -> Dictionary:
	var values = {}
	for key in DEFAULTS: values[key] = get(key)
	return values

func restore(values: Dictionary) -> void:
	for key in DEFAULTS:
		if not values.has(key): continue
		var value = values[key]
		if typeof(value) not in [TYPE_FLOAT, TYPE_INT]: continue
		var bounds: Vector3 = RANGES[key]
		set(key, snappedf(clampf(float(value), bounds.x, bounds.y), bounds.z) if is_finite(float(value)) else DEFAULTS[key])

func reset() -> void:
	restore(DEFAULTS)

func load_preferences(path: String = PATH) -> void:
	var config = ConfigFile.new()
	if config.load(path) != OK: return
	var values = {}
	for key in DEFAULTS: values[key] = config.get_value("camera", key, DEFAULTS[key])
	restore(values)

func save_preferences(path: String = PATH) -> Error:
	var config = ConfigFile.new()
	for key in DEFAULTS: config.set_value("camera", key, get(key))
	return config.save(path)
