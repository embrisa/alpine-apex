extends RefCounted
## Durable choices/history only; live fronts belong to WeatherController.
signal changed
const Store = preload("res://scripts/ui/preference_store.gd")
const Rules = preload("res://scripts/presentation/weather_rules.gd")
const PATH = "user://weather_v1.cfg"
const DEFAULTS = {"automatic":true,"time_cycle":true,"random_weather":true,"random_time":true,
	"forest_style":1,"rare_storms":true,"quality":2,"lightning":2,"manual_weather":"clear","manual_time":"day"}
var values: Dictionary = DEFAULTS.duplicate()
var last_weather = ""
var last_band = ""
var free_seconds = 0.0
var cooldown = Rules.STORM_DELAY
var storm_at_exit = false

func set_value(key: String, value: Variant) -> void:
	if not _valid(key,value) or values[key]==value: return
	values[key] = value
	changed.emit()

func _valid(key: String, value: Variant) -> bool:
	if not DEFAULTS.has(key) or typeof(value)!=typeof(DEFAULTS[key]): return false
	if key=="manual_weather": return value in Rules.PRESETS
	if key=="manual_time": return value in Rules.TIMES
	if key=="forest_style": return value>=0 and value<=1
	if key in ["quality","lightning"]: return value>=0 and value<=2
	return true

func snapshot() -> Dictionary:
	return {"choices":values.duplicate(),"last_weather":last_weather,"last_band":last_band,
		"free_seconds":free_seconds,"cooldown":cooldown,"storm_at_exit":storm_at_exit}

func restore(data: Dictionary) -> void:
	values = DEFAULTS.duplicate()
	if data.get("choices") is Dictionary:
		for key in data.choices:
			if _valid(key,data.choices[key]): values[key] = data.choices[key]
	last_weather = data.get("last_weather","") if data.get("last_weather") in Rules.PRESETS else ""
	last_band = data.get("last_band","") if data.get("last_band") in Rules.TIMES else ""
	free_seconds = 0.0; cooldown = Rules.STORM_DELAY; storm_at_exit = false
	if _finite(data.get("free_seconds")) and _finite(data.get("cooldown")) and data.get("storm_at_exit") is bool:
		if data.free_seconds>=0 and data.cooldown>=0 and data.cooldown<=Rules.STORM_DELAY:
			free_seconds = data.free_seconds; cooldown = data.cooldown; storm_at_exit = data.storm_at_exit

static func _finite(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func load_preferences(path: String = PATH) -> void:
	restore(Store.read_values(path,1))

func save_preferences(path: String = PATH) -> Error:
	return Store.write_values(path,1,snapshot())

static func weighted_weather(rng: RandomNumberGenerator, excluded: String = "") -> String:
	var weights = [3,3,3,1]
	var total = 0
	for i in 4:
		if Rules.ORDINARY[i]!=excluded: total += weights[i]
	var draw = rng.randi_range(0,total-1)
	for i in 4:
		if Rules.ORDINARY[i]==excluded: continue
		draw -= weights[i]
		if draw<0: return Rules.ORDINARY[i]
	return "clear"

static func hour_outside(rng: RandomNumberGenerator, band: String) -> float:
	# Direct conditional draw; no unbounded rejection loop, including Night's wrap.
	var intervals = {"dawn":[[0.0,5.0],[8.0,24.0]],"day":[[0.0,8.0],[16.0,24.0]],
		"dusk":[[0.0,16.0],[19.0,24.0]],"night":[[5.0,19.0]]}
	var spans: Array = intervals[band]
	var length = 0.0
	for span in spans: length += span[1]-span[0]
	var draw = rng.randf()*length
	for span in spans:
		if draw<span[1]-span[0]: return span[0]+draw
		draw -= span[1]-span[0]
	return spans[-1][1]-.000001

func launch(rng: RandomNumberGenerator, args: PackedStringArray, personal: bool) -> Dictionary:
	var result = {"preset":"clear","hour":12.0,"automatic":false,"time_cycle":false,"quality":2,"rare_storms":false,"lightning":2}
	var fixed_weather = ""; var fixed_time = ""
	for arg in args:
		if arg.begins_with("--weather=") and arg.get_slice("=",1) in Rules.PRESETS: fixed_weather = arg.get_slice("=",1)
		if arg.begins_with("--time-of-day=") and arg.get_slice("=",1) in Rules.TIMES: fixed_time = arg.get_slice("=",1)
	if personal:
		for key in ["automatic","time_cycle","quality","rare_storms","lightning"]: result[key] = values[key]
		var rw: bool = values.random_weather and fixed_weather.is_empty()
		var rt: bool = values.random_time and fixed_time.is_empty()
		result.preset = fixed_weather if not fixed_weather.is_empty() else weighted_weather(rng) if rw else values.manual_weather
		result.hour = Rules.TIMES[fixed_time] if not fixed_time.is_empty() else rng.randf()*24.0 if rt else Rules.TIMES[values.manual_time]
		if result.preset==last_weather and Rules.time_band(result.hour)==last_band:
			if rt: result.hour = hour_outside(rng,last_band)
			elif rw: result.preset = weighted_weather(rng,last_weather)
	if not fixed_weather.is_empty(): result.preset = fixed_weather; result.automatic = false
	if not fixed_time.is_empty(): result.hour = Rules.TIMES[fixed_time]; result.time_cycle = false
	for arg in args:
		if arg in ["--weather-auto","--weather-auto=on","--weather-auto=off"]: result.automatic = arg!="--weather-auto=off"
		if arg in ["--time-cycle","--time-cycle=on","--time-cycle=off"]: result.time_cycle = arg!="--time-cycle=off"
		if arg.begins_with("--weather-quality="):
			var q = ["off","low","high"].find(arg.get_slice("=",1))
			if q>=0: result.quality = q
	if personal:
		last_weather = result.preset; last_band = Rules.time_band(result.hour)
		if storm_at_exit: cooldown = Rules.STORM_DELAY
	return result
