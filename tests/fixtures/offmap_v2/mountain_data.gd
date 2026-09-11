extends "res://scripts/world/mountain_data.gd"
## Explicit comparison only: v2's noisy rectangular apron continuation.
func _landform(p: Vector2, field) -> float:
	if field.is_summit_mountain():
		return field.continuation_height(p.x,p.y)+maxf(0,detail.get_noise_2d(p.x,p.y))*160*smoothstep(3100,3800,p.length())
	return super._landform(p,field)
