extends "res://scripts/presentation/chase_camera.gd"
## Replays only sampled look/view intent; production camera still follows physics.
var recorded_look: Array = []
var sample_index = 0
func update_camera(sim, field, rider_position: Vector3, dt: float, menu: bool = false, active: bool = true, summit: bool = false, preview_kmh: float = -1.0) -> void:
	if not recorded_look.is_empty():
		sample_index = clampi(sim.ticks,0,recorded_look.size()-1)
		close_view = recorded_look[sample_index][0]
	super.update_camera(sim,field,rider_position,dt,menu,active,summit,preview_kmh)
func _update_look(dt: float, kmh: float, enabled: bool, summit: bool) -> void:
	if recorded_look.is_empty(): super._update_look(dt,kmh,enabled,summit); return
	var sample: Array = recorded_look[sample_index]
	look_yaw = sample[1]; look_pitch = sample[2]; look_idle = sample[3]
	pending_mouse = Vector2.ZERO; pending_stick = Vector2.ZERO; recentering = false
