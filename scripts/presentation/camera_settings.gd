extends RefCounted
## Local presentation profiles. Never serialized into physics or replay identity.
const PATH = "user://camera_v2.cfg"
const VIEWS = ["chase", "first_person"]
const BUILT_INS = ["Connected", "Race", "Stable"]
const DEFAULTS = {
	"rest_fov":55.0, "fast_fov":75.0,
	"rest_distance":3.0, "fast_distance":4.5, "rest_height":3.0, "fast_height":3.5,
	"rest_tilt":-45.0, "fast_tilt":-45.0, "eye_height":1.45, "tuck_lowering":0.35,
	"speed_start":0.0, "speed_full":200.0, "speed_exponent":1.6,
	"acceleration_time":0.4, "deceleration_time":0.4,
	"vertical_smoothing":50.0, "boom_response":7.5, "heading_response":5.5,
	"slope_follow":100.0, "slope_smoothing":0.35,
	"carve_strength":50.0, "tuck_strength":50.0, "compression_strength":50.0,
	"bank_strength":35.0, "chatter_strength":0.0, "blur_strength":50.0, "streak_strength":50.0,
}
const SHARED_DEFAULTS = {
	"mouse_sensitivity":0.1, "stick_yaw_speed":150.0, "stick_pitch_speed":100.0,
	"stick_deadzone":0.18, "stick_exponent":2.0, "invert_y":false,
	"auto_recenter":true, "recenter_delay":0.8, "recenter_time":0.35,
	"forest_visibility":60.0, "forest_visibility_size":88.0,
}
const RANGES = {
	"rest_fov":Vector3(50,120,1), "fast_fov":Vector3(50,120,1),
	"rest_distance":Vector3(1,20,0.25), "fast_distance":Vector3(1,20,0.25),
	"rest_height":Vector3(2,20,0.25), "fast_height":Vector3(2,20,0.25),
	"rest_tilt":Vector3(-80,80,1), "fast_tilt":Vector3(-80,80,1),
	"eye_height":Vector3(1,2,0.05), "tuck_lowering":Vector3(0,0.5,0.05),
	"speed_start":Vector3(0,299,1), "speed_full":Vector3(1,300,1),
	"speed_exponent":Vector3(0.5,3,0.05),
	"acceleration_time":Vector3(0,2,0.05), "deceleration_time":Vector3(0,2,0.05),
	"vertical_smoothing":Vector3(0,100,1),
	"slope_follow":Vector3(0,100,1), "slope_smoothing":Vector3(0,2,0.05),
	"boom_response":Vector3(3,16,0.5), "heading_response":Vector3(1,16,0.5),
	"carve_strength":Vector3(0,100,1), "tuck_strength":Vector3(0,100,1),
	"compression_strength":Vector3(0,100,1), "bank_strength":Vector3(0,100,1),
	"chatter_strength":Vector3(0,100,1), "blur_strength":Vector3(0,100,1),
	"streak_strength":Vector3(0,100,1),
	"mouse_sensitivity":Vector3(0.01,0.5,0.01),
	"stick_yaw_speed":Vector3(30,360,5), "stick_pitch_speed":Vector3(30,240,5),
	"stick_deadzone":Vector3(0.05,0.4,0.01), "stick_exponent":Vector3(1,3,0.05),
	"recenter_delay":Vector3(0,5,0.1), "recenter_time":Vector3(0.05,2,0.05),
	"forest_visibility":Vector3(0,100,1), "forest_visibility_size":Vector3(20,100,1),
}
var profiles: Dictionary = {}
var shared: Dictionary = SHARED_DEFAULTS.duplicate()
var selected: Dictionary = {}
var presets: Dictionary = {"chase":{}, "first_person":{}}

func _init() -> void:
	reset()

static func defaults(view: String, preset: String = "Connected") -> Dictionary:
	var result = DEFAULTS.duplicate()
	if view == "first_person": result.merge({"rest_tilt":-25.0,"fast_tilt":-25.0},true)
	if preset == "Race":
		result.merge({"rest_fov":60.0,"fast_fov":80.0,"rest_distance":3.5,"fast_distance":5.5,"rest_height":3.5,"fast_height":4.5,"rest_tilt":-22.0 if view=="first_person" else -40.0,"fast_tilt":-22.0 if view=="first_person" else -40.0},true)
		for key in result:
			if key.ends_with("_strength"): result[key] = 100.0
	elif preset == "Stable":
		result.merge({"rest_fov":60.0,"fast_fov":60.0,"rest_distance":3.5,"fast_distance":3.5,"rest_height":3.5,"fast_height":3.5,"vertical_smoothing":75.0},true)
		for key in result:
			if key.ends_with("_strength"): result[key] = 0.0
	return result

func profile(view: String) -> Dictionary:
	return profiles[view]

func value(scope: String, key: String) -> Variant:
	return shared.get(key) if scope=="shared" else profiles.get(scope,{}).get(key)

static func validated(values: Dictionary, baseline: Dictionary) -> Dictionary:
	var result = baseline.duplicate()
	for key in baseline:
		if not values.has(key): continue
		var item = values[key]
		if baseline[key] is bool:
			if item is bool: result[key] = item
		elif typeof(item) in [TYPE_FLOAT,TYPE_INT]:
			var bounds: Vector3 = RANGES[key]
			# Vector3 steps are float32. Normalize to the menu's two decimal places
			# so repeated save/load is stable and snapping cannot exceed a bound.
			if is_finite(float(item)): result[key] = float("%.2f" % clampf(snappedf(float(item),bounds.z),bounds.x,bounds.y))
	if result.has("speed_start"):
		result.speed_full = maxf(result.speed_full,result.speed_start+1.0)
	return result

func set_value(scope: String, key: String, item: Variant) -> bool:
	if scope=="shared":
		if not SHARED_DEFAULTS.has(key): return false
		shared = validated({key:item},shared)
	elif scope in VIEWS:
		if not DEFAULTS.has(key): return false
		update_profile(scope,{key:item})
	else: return false
	return true

func update_profile(view: String, values: Dictionary) -> void:
	if view not in VIEWS: return
	profiles[view] = validated(values,profiles[view])
	selected[view] = "Custom"

static func speed_factor(kmh: float, values: Dictionary) -> float:
	return pow(clampf((kmh-values.speed_start)/(values.speed_full-values.speed_start),0.0,1.0),values.speed_exponent)

static func sample_framing(values: Dictionary, blend: float) -> Vector4:
	return Vector4(lerpf(values.rest_fov,values.fast_fov,blend),lerpf(values.rest_distance,values.fast_distance,blend),lerpf(values.rest_height,values.fast_height,blend),lerpf(values.rest_tilt,values.fast_tilt,blend))

func framing(view: String, kmh: float) -> Vector4:
	return sample_framing(profiles[view],speed_factor(kmh,profiles[view]))

func apply_preset(view: String, name: String) -> bool:
	if view not in VIEWS: return false
	if name in BUILT_INS: profiles[view] = defaults(view,name)
	elif presets[view].has(name): profiles[view] = presets[view][name].duplicate()
	else: return false
	selected[view] = name
	return true

func valid_name(view: String, name: String) -> bool:
	return view in VIEWS and not name.is_empty() and name.length()<=40 and name==name.strip_edges() and name not in BUILT_INS and name!="Custom" and not "\n" in name and not "\r" in name

func save_preset(view: String, name: String, replace: bool = false) -> bool:
	if not valid_name(view,name) or (presets[view].has(name) and not replace): return false
	if replace and not presets[view].has(name): return false
	presets[view][name] = profiles[view].duplicate()
	selected[view] = name
	return true

func rename_preset(view: String, old_name: String, new_name: String) -> bool:
	if not valid_name(view,new_name) or not presets[view].has(old_name) or presets[view].has(new_name): return false
	presets[view][new_name] = presets[view][old_name]
	presets[view].erase(old_name)
	if selected[view]==old_name: selected[view] = new_name
	return true

func delete_preset(view: String, name: String) -> bool:
	if view not in VIEWS or not presets[view].has(name): return false
	presets[view].erase(name)
	if selected[view]==name: selected[view] = "Custom"
	return true

func reset_view(view: String) -> void:
	apply_preset(view,"Connected")

func reset() -> void:
	shared = SHARED_DEFAULTS.duplicate()
	for view in VIEWS: apply_preset(view,"Connected")

func snapshot() -> Dictionary:
	return {"version":2,"profiles":profiles.duplicate(true),"shared":shared.duplicate(),"selected":selected.duplicate(),"presets":presets.duplicate(true)}

func restore(data: Dictionary) -> void:
	if data.get("version") != 2: return
	reset()
	presets = {"chase":{},"first_person":{}}
	if data.get("shared") is Dictionary: shared = validated(data.shared,SHARED_DEFAULTS)
	for view in VIEWS:
		if data.get("profiles") is Dictionary and data.profiles.get(view) is Dictionary:
			profiles[view] = validated(data.profiles[view],defaults(view))
		if data.get("presets") is Dictionary and data.presets.get(view) is Dictionary:
			for name in data.presets[view]:
				if name is String and valid_name(view,name) and data.presets[view][name] is Dictionary:
					presets[view][name] = validated(data.presets[view][name],defaults(view))
		var name: Variant = data.get("selected",{}).get(view,"Custom") if data.get("selected",{}) is Dictionary else "Custom"
		selected[view] = "Custom"
		if name is String and (name in BUILT_INS or presets[view].has(name)):
			var saved: Dictionary = defaults(view,name) if name in BUILT_INS else presets[view][name]
			if saved==profiles[view]: selected[view] = name

func load_preferences(path: String = PATH) -> void:
	var config = ConfigFile.new()
	if config.load(path)!=OK: return
	var data = config.get_value("camera","data",{})
	if data is Dictionary: restore(data)

func save_preferences(path: String = PATH) -> Error:
	var config = ConfigFile.new()
	config.set_value("camera","data",snapshot())
	return config.save(path)
