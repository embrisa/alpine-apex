extends Node
## Complete resumable weather owner. Private RNG; no solver or wall-clock timers.
signal settings_changed
signal choice_changed(key: String, value: Variant)
signal transients_cleared
const State = preload("res://scripts/presentation/weather_state.gd")
const Preset = preload("res://scripts/presentation/weather_preset.gd")
const Rules = preload("res://scripts/presentation/weather_rules.gd")
const PRESETS = {
	"clear":preload("res://config/weather/clear.tres"),"cloudy":preload("res://config/weather/cloudy.tres"),
	"snowfall":preload("res://config/weather/snowfall.tres"),"rain":preload("res://config/weather/rain.tres"),
	"snowstorm":preload("res://config/weather/snowstorm.tres"),"thunderstorm":preload("res://config/weather/thunderstorm.tres")}
const SNAPSHOT_KEYS = ["quality","automatic","selected_preset","target_preset","phase","phase_seconds","duration",
	"visual_time","active_seconds","free_seconds","cooldown","pending_storm","automatic_storm","rare_storms",
	"cloud_offset","cloud_x","cloud_z","variation_seed","race_mode","race_elapsed","race_practice","lightning"]
enum Quality { OFF, LOW, HIGH }
var state = State.new()
var quality: Quality = Quality.HIGH
var automatic = false
var rare_storms = true
var lightning = 2
var selected_preset = "clear"
var target_preset = "clear"
var phase = "hold"
var phase_seconds = 0.0
var duration = 300.0
var visual_time = 0.0
var active_seconds = 0.0
var free_seconds = 0.0
var cooldown = Rules.STORM_DELAY
var pending_storm = ""
var automatic_storm = false
var cloud_offset = Vector2.ZERO
var cloud_x = 0.0
var cloud_z = 0.0
var variation_seed = 849205174
var race_mode = false
var race_elapsed = 0.0
var race_practice = false
var rng = RandomNumberGenerator.new()
var original = Preset.new()
var daylight = preload("res://scripts/presentation/daylight_cycle.gd").new()

func _init() -> void:
	seed_stream(849205174)
	_sample()

func seed_stream(value: int) -> void:
	rng.seed = value
	variation_seed = value
	duration = rng.randf_range(240.0,420.0)

func configure_launch(values: Dictionary, progress = null) -> void:
	selected_preset = values.preset; target_preset = selected_preset
	quality = values.quality; automatic = values.automatic; daylight.automatic = values.time_cycle
	daylight.hour = values.hour; rare_storms = values.rare_storms; lightning = values.lightning
	if progress:
		free_seconds = progress.free_seconds; cooldown = progress.cooldown
	_sample()

func set_preset(id: String) -> void:
	if not PRESETS.has(id): return
	if race_mode: race_practice = true
	# An explicit selection begins a hold, without changing the automatic toggle.
	if automatic_storm or selected_preset in ["snowstorm","thunderstorm"]: cooldown = Rules.STORM_DELAY
	selected_preset = id; target_preset = id; phase = "hold"; phase_seconds = 0.0
	pending_storm = ""; automatic_storm = false; duration = rng.randf_range(240.0,420.0)
	_sample(); transients_cleared.emit(); settings_changed.emit(); choice_changed.emit("manual_weather",id)

func set_automatic(value: bool) -> void:
	if automatic==value: return
	automatic = value
	if race_mode and value: race_practice = true
	settings_changed.emit(); choice_changed.emit("automatic",value)

func set_quality(value: int) -> void:
	quality = clampi(value,0,2) as Quality
	_sample(); transients_cleared.emit(); settings_changed.emit(); choice_changed.emit("quality",quality)

func set_time_of_day(id: String) -> void:
	if not id in Rules.TIMES: return
	daylight.set_preset(id)
	_sample(); transients_cleared.emit(); settings_changed.emit(); choice_changed.emit("manual_time",id)

func set_time_cycle(value: bool) -> void:
	daylight.automatic = value
	settings_changed.emit(); choice_changed.emit("time_cycle",value)

func snapshot() -> Dictionary:
	var result = {"rng_seed":rng.seed,"rng_state":rng.state,"hour":daylight.hour,"time_cycle":daylight.automatic}
	for key in SNAPSHOT_KEYS: result[key] = get(key)
	return result.duplicate(true)

func restore(values: Dictionary) -> void:
	for key in SNAPSHOT_KEYS: set(key,values[key])
	rng.seed = values.rng_seed; rng.state = values.rng_state
	daylight.hour = values.hour; daylight.automatic = values.time_cycle
	_sample(); transients_cleared.emit(); settings_changed.emit()

func begin_race(preset: String, time_band: String, identity: String) -> void:
	race_mode = true; race_elapsed = 0.0; race_practice = false
	seed_stream(Rules.seed_for(identity))
	selected_preset = preset; target_preset = preset
	phase = "hold"; phase_seconds = 0.0; automatic_storm = false; pending_storm = ""
	automatic = false; daylight.automatic = false; daylight.hour = Rules.TIMES[time_band]
	visual_time = 0.0; active_seconds = 0.0; cloud_offset = Vector2.ZERO; cloud_x = 0.0; cloud_z = 0.0
	_sample(); transients_cleared.emit(); settings_changed.emit()

func sample_race(elapsed: float) -> void:
	# Session elapsed is authoritative: frame rate, camera, pause and FX cannot shift the schedule.
	var dt = maxf(0.0,elapsed-race_elapsed)
	update_weather(dt,true,false,false)
	race_elapsed = elapsed; visual_time = elapsed; active_seconds = elapsed
	# Fixed conditions integrate the analytic mean wind exactly from elapsed zero.
	if not race_practice:
		var wind: Vector3 = PRESETS[selected_preset].wind_velocity
		cloud_x = wind.x*elapsed; cloud_z = wind.z*elapsed
	_sample()

func update_weather(dt: float, active: bool, title: bool = false, free_ski: bool = true) -> void:
	if not is_finite(dt) or dt<=0.0: _sample(); return
	# Bound pathological catch-up to one day. Real frame deltas are far smaller.
	dt = minf(dt,86400.0)
	if active:
		daylight.advance(dt,true)
		active_seconds += dt; visual_time += dt
		var remaining = dt
		while remaining>0.00000001:
			var step = minf(remaining,maxf(0.0,duration-phase_seconds)) if automatic else remaining
			_integrate_clouds(step)
			if free_ski and not race_mode:
				free_seconds += step
				if not automatic_storm: cooldown = maxf(0.0,cooldown-step)
			if automatic: phase_seconds += step
			remaining -= step
			if automatic and phase_seconds>=duration-0.00000001: _next_phase(free_ski and not race_mode)
	elif title and not race_mode:
		visual_time += dt
		# Menu ambience moves the frozen front without spending front/day/storm time.
		var wind = _mean_wind()
		cloud_x += wind.x*dt; cloud_z += wind.z*dt
	_sample()

func _integrate_clouds(dt: float) -> void:
	var wind: Vector3 = PRESETS[selected_preset].wind_velocity
	if phase in ["blend","recovery"] and not automatic:
		wind = _mean_wind()
		cloud_x += wind.x*dt; cloud_z += wind.z*dt
	elif phase in ["blend","recovery"]:
		var u = clampf(phase_seconds/duration,0.0,1.0)
		var v = clampf((phase_seconds+dt)/duration,0.0,1.0)
		# Integral of smoothstep, preserving offsets across arbitrary render steps.
		var area = duration*((v*v*v-0.5*v*v*v*v)-(u*u*u-0.5*u*u*u*u))
		var target: Vector3 = PRESETS[target_preset].wind_velocity
		cloud_x += wind.x*dt+(target.x-wind.x)*area
		cloud_z += wind.z*dt+(target.z-wind.z)*area
	else: cloud_x += wind.x*dt; cloud_z += wind.z*dt

func _mean_wind() -> Vector3:
	return PRESETS[selected_preset].wind_velocity.lerp(PRESETS[target_preset].wind_velocity,_weight())

func _weight() -> float:
	return smoothstep(0.0,duration,phase_seconds) if phase in ["blend","recovery"] else 0.0

func _next_phase(free_ski: bool) -> void:
	phase_seconds = 0.0
	# A preference changed during a race also applies to the suspended free front.
	if not rare_storms: pending_storm = ""
	if phase in ["blend","recovery"]:
		var recovered = phase=="recovery"
		selected_preset = target_preset
		if recovered:
			automatic_storm = false; cooldown = Rules.STORM_DELAY
		if automatic_storm and selected_preset in ["snowstorm","thunderstorm"]:
			phase = "peak"; duration = rng.randf_range(90.0,150.0)
		else: phase = "hold"; duration = rng.randf_range(240.0,420.0)
	elif phase=="peak" or selected_preset in ["snowstorm","thunderstorm"]:
		target_preset = "snowfall" if selected_preset=="snowstorm" else "rain"
		phase = "recovery"; duration = rng.randf_range(45.0,75.0)
	else:
		if not pending_storm.is_empty():
			target_preset = pending_storm; pending_storm = ""; automatic_storm = true
		elif free_ski and rare_storms and cooldown<=0.0 and free_seconds>=Rules.STORM_DELAY and rng.randf()<0.05:
			var storm = "snowstorm" if selected_preset=="snowfall" else "thunderstorm" if selected_preset=="rain" else ["snowstorm","thunderstorm"][rng.randi_range(0,1)]
			if selected_preset=="clear":
				target_preset = "cloudy"; pending_storm = storm
			else: target_preset = storm; automatic_storm = true
		else:
			var choices: Array = {"clear":["cloudy"],"cloudy":["clear","snowfall","rain"],"snowfall":["cloudy"],"rain":["cloudy"]}[selected_preset]
			target_preset = choices[rng.randi_range(0,choices.size()-1)]
		phase = "blend"; duration = rng.randf_range(45.0,75.0)
	settings_changed.emit()

var blend_label_from: String = ""
var blend_label_to: String = ""
var blend_label: String = ""

func _sample() -> void:
	var previous_time: String = state.time_label
	state.enabled = quality!=Quality.OFF
	state.visual_time = visual_time; state.active_seconds = active_seconds
	cloud_offset = Vector2(cloud_x,cloud_z)
	state.cloud_offset = cloud_offset; state.variation_seed = variation_seed
	state.lightning_flash = 0.0
	if not state.enabled:
		state.blend(original,original,0.0); state.label = "Clear · FX off"
		state.wind_velocity = Vector3.ZERO; state.spindrift = 0.0; state.gust = 0.0
		daylight.apply(state)
		if previous_time!=state.time_label: settings_changed.emit()
		return
	var a: Resource = PRESETS[selected_preset]; var b: Resource = PRESETS[target_preset]
	var weight = _weight()
	state.blend(a,b,weight)
	if weight<=0.0: state.label = a.label
	else:
		if blend_label_from!=a.label or blend_label_to!=b.label:
			blend_label_from = a.label; blend_label_to = b.label
			blend_label = "%s → %s" % [a.label,b.label]
		state.label = blend_label
	var offset = float(variation_seed%8192)*0.013
	state.gust = clampf(0.5+sin(active_seconds*0.071+offset)*0.32+sin(active_seconds*0.137+offset*1.7)*0.18,0.0,1.0)
	state.wind_velocity *= 0.8+state.gust*0.4
	var intensity = 0.88+state.gust*0.12
	state.snow *= intensity; state.rain *= intensity
	daylight.apply(state)
	if previous_time!=state.time_label: settings_changed.emit()
