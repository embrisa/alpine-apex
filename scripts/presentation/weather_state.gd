extends RefCounted
## One shared, mutable presentation snapshot. Never passed into SkiSimulation.
const FIELDS = ["storm","thunder","cloud_coverage","snow","rain","spindrift","wind_velocity","sky_top","sky_horizon","cloud_color","sun_color","sun_energy","ambient_color","ambient_energy","fog_color","fog_density"]
var storm = 0.0
var thunder = 0.0
var cloud_offset = Vector2.ZERO
var active_seconds = 0.0
var variation_seed = 849205174
var lightning_flash = 0.0
var label: String = "Clear"
var enabled: bool = true
var cloud_coverage: float = 0.2
var snow: float = 0.0
var rain: float = 0.0
var spindrift: float = 0.12
var wind_velocity = Vector3.ZERO
var sky_top: Color
var sky_horizon: Color
var cloud_color: Color
var sun_color: Color
var sun_energy: float
var ambient_color: Color
var ambient_energy: float
var fog_color: Color
var fog_density: float
var gust: float = 0.0
var visual_time: float = 0.0
var sun_direction = Vector3(-0.775,0.407,0.484)
var moon_energy: float = 0.0
var moon_color = Color("a7c5f5")
var time_label: String = "Day"
var time_hour: float = 12.0

func blend(a: Resource, b: Resource, weight: float) -> void:
	for field in FIELDS:
		set(field, lerp(a.get(field),b.get(field),weight))
