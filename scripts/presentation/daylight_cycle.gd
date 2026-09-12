extends RefCounted
## Artistic alpine daylight, independent of physics and the wall-clock date.
const PRESETS = {"dawn":6.5,"day":12.0,"dusk":17.5,"night":0.0}
const CYCLE_SECONDS = 3600.0
var hour: float = 12.0
var automatic: bool = false

func set_preset(id: String) -> void:
	if PRESETS.has(id):
		hour = PRESETS[id]

func advance(dt: float, active: bool) -> void:
	if automatic and active:
		hour = fposmod(hour + maxf(dt,0.0)*24.0/CYCLE_SECONDS,24.0)

func label() -> String:
	if hour>=5.0 and hour<8.0:
		return "Dawn"
	if hour>=8.0 and hour<16.0:
		return "Day"
	if hour>=16.0 and hour<19.0:
		return "Dusk"
	return "Night"

func apply(state) -> void:
	var phase = (hour-6.0)*PI/12.0
	# Low winter sun: noon preserves the original 24° / -58° lighting.
	var direction = Vector3(cos(phase),sin(phase)*sin(deg_to_rad(24.0)),sin(phase)*cos(deg_to_rad(24.0)))
	state.sun_direction = direction.rotated(Vector3.UP,deg_to_rad(-58.0)).normalized()
	var altitude: float = state.sun_direction.y
	var daylight = smoothstep(-0.13,0.16,altitude)
	var sun_visibility = smoothstep(0.0,0.16,altitude)
	var twilight = (1.0-smoothstep(0.055,0.28,altitude))*smoothstep(-0.16,0.035,altitude)
	var warm_light = Color("ff9253") if hour<12.0 else Color("ff764c")
	state.sun_color *= warm_light.lerp(Color.WHITE,smoothstep(0.03,0.30,altitude))
	var weather_light: float = clampf(state.sun_energy/1.25,0.25,1.0)
	state.sun_energy *= sun_visibility
	state.moon_energy = 0.22*smoothstep(0.01,0.20,-altitude)*lerpf(0.55,1.0,weather_light)
	state.moon_color = Color("a7c5f5")
	var dusk_top = Color("66516f") if hour>=12.0 else Color("73687f")
	var dusk_horizon = Color("e79c78") if hour>=12.0 else Color("f0bb88")
	var glow = twilight*(1.0-state.cloud_coverage*0.65)
	state.sky_top = Color("061020").lerp(state.sky_top.lerp(dusk_top,glow),daylight)
	state.sky_horizon = Color("243b56").lerp(state.sky_horizon.lerp(dusk_horizon,glow),daylight)
	state.cloud_color = Color("344965").lerp(state.cloud_color.lerp(warm_light,glow*0.38),daylight)
	state.ambient_color = Color("91afd7").lerp(state.ambient_color,daylight)
	state.ambient_energy = lerpf(0.22,state.ambient_energy,daylight)
	state.fog_color = Color("263e5b").lerp(state.fog_color.lerp(dusk_horizon,glow*0.3),daylight)
	state.time_label = label()
	state.time_hour = hour
