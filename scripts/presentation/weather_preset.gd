extends Resource
## Presentation values only. Wind is in world-space metres per second.
@export var label: String = "Clear"
@export_range(0,1) var cloud_coverage: float = 0.2
@export_range(0,1) var snow: float = 0.0
@export_range(0,1) var rain: float = 0.0
@export_range(0,1) var spindrift: float = 0.18
@export var wind_velocity: Vector3 = Vector3(3,0,1)
@export var sky_top: Color = Color("2f6fa9")
@export var sky_horizon: Color = Color("c1d7e5")
@export var cloud_color: Color = Color("fff3df")
@export var sun_color: Color = Color("ffdfb1")
@export var sun_energy: float = 1.9
@export var ambient_color: Color = Color("b9d6f4")
@export var ambient_energy: float = 0.38
@export var fog_color: Color = Color("b4c9da")
@export var fog_density: float = 0.000065
