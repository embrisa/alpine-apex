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
	# Typed assignments of every FIELDS entry; identical values to the former
	# reflective set/get loop without 48 dynamic property calls per frame.
	storm = lerpf(a.storm,b.storm,weight)
	thunder = lerpf(a.thunder,b.thunder,weight)
	cloud_coverage = lerpf(a.cloud_coverage,b.cloud_coverage,weight)
	snow = lerpf(a.snow,b.snow,weight)
	rain = lerpf(a.rain,b.rain,weight)
	spindrift = lerpf(a.spindrift,b.spindrift,weight)
	wind_velocity = a.wind_velocity.lerp(b.wind_velocity,weight)
	sky_top = a.sky_top.lerp(b.sky_top,weight)
	sky_horizon = a.sky_horizon.lerp(b.sky_horizon,weight)
	cloud_color = a.cloud_color.lerp(b.cloud_color,weight)
	sun_color = a.sun_color.lerp(b.sun_color,weight)
	sun_energy = lerpf(a.sun_energy,b.sun_energy,weight)
	ambient_color = a.ambient_color.lerp(b.ambient_color,weight)
	ambient_energy = lerpf(a.ambient_energy,b.ambient_energy,weight)
	fog_color = a.fog_color.lerp(b.fog_color,weight)
	fog_density = lerpf(a.fog_density,b.fog_density,weight)
