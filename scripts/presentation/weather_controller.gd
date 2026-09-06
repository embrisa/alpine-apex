extends Node
## Render-time weather. No global RNG, scene-tree timer, solver or record writes.
signal settings_changed
const State = preload("res://scripts/presentation/weather_state.gd")
const Preset = preload("res://scripts/presentation/weather_preset.gd")
const PRESETS = {
	"clear": preload("res://config/weather/clear.tres"),
	"cloudy": preload("res://config/weather/cloudy.tres"),
	"snowfall": preload("res://config/weather/snowfall.tres"),
	"rain": preload("res://config/weather/rain.tres")
}
const CYCLE = ["clear","cloudy","snowfall","cloudy","rain","cloudy"]
const HOLD_SECONDS = 180.0
const BLEND_SECONDS = 20.0
enum Quality { OFF, LOW, HIGH }
var state = State.new()
var quality: Quality = Quality.HIGH
var automatic: bool = false
var selected_preset: String = "clear"
var cycle_index: int = 0
var phase_seconds: float = 0.0
var visual_time: float = 0.0
var original = Preset.new()
var daylight = preload("res://scripts/presentation/daylight_cycle.gd").new()

func _init() -> void:
	_sample()

func set_preset(id: String) -> void:
	if not PRESETS.has(id):
		return
	selected_preset = id
	cycle_index = CYCLE.find(id)
	phase_seconds = 0.0
	_sample()
	settings_changed.emit()

func set_automatic(value: bool) -> void:
	if automatic == value:
		return
	# Keep the visible blend when disabling auto. Selecting a preset explicitly
	# starts a new hold; resuming auto continues the suspended phase.
	automatic = value
	settings_changed.emit()

func set_quality(value: int) -> void:
	quality = clampi(value,Quality.OFF,Quality.HIGH) as Quality
	_sample()
	settings_changed.emit()

func set_time_of_day(id: String) -> void:
	daylight.set_preset(id)
	_sample()
	settings_changed.emit()

func set_time_cycle(value: bool) -> void:
	daylight.automatic = value
	settings_changed.emit()

func update_weather(dt: float, active: bool, title: bool = false) -> void:
	var previous_label: String = daylight.label()
	daylight.advance(dt,active)
	if active or title:
		visual_time += maxf(0.0,dt)
	if active and automatic:
		phase_seconds += maxf(0.0,dt)
		while phase_seconds >= HOLD_SECONDS + BLEND_SECONDS:
			phase_seconds -= HOLD_SECONDS + BLEND_SECONDS
			cycle_index = (cycle_index+1) % CYCLE.size()
			selected_preset = CYCLE[cycle_index]
			settings_changed.emit()
	_sample()
	if daylight.label() != previous_label:
		settings_changed.emit()

func _sample() -> void:
	state.enabled = quality != Quality.OFF
	state.visual_time = visual_time
	if not state.enabled:
		state.blend(original,original,0.0)
		state.label = "Clear · FX off"
		state.wind_velocity = Vector3.ZERO
		state.spindrift = 0.0
		state.gust = 0.0
		daylight.apply(state)
		return
	var a: Resource = PRESETS[selected_preset]
	var b: Resource = PRESETS[CYCLE[(cycle_index+1)%CYCLE.size()]]
	var weight = smoothstep(HOLD_SECONDS,HOLD_SECONDS+BLEND_SECONDS,phase_seconds)
	state.blend(a,b,weight)
	state.label = a.label if weight <= 0.0 else "%s → %s" % [a.label,b.label]
	state.gust = clampf(0.5 + sin(visual_time*0.71)*0.32 + sin(visual_time*1.37)*0.18,0.0,1.0)
	state.wind_velocity *= 0.75 + state.gust*0.5
	daylight.apply(state)
