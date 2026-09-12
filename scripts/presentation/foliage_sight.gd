extends RefCounted
## Full-screen nearby canopy aid. Never changes obstacles or rider input.
var parameters = Vector4.ZERO # activation, full-depth limit, outer limit, transparency
var initialized = false
var previous_actor = Vector3.ZERO

func update(camera: Camera3D, actor: Vector3, dt: float, riding: bool, reach_percent: float, transparency_percent: float = 100.0) -> void:
	var reach = clampf(reach_percent/100.0,0.0,1.0) if is_finite(reach_percent) else .6
	parameters.w = clampf(transparency_percent/100.0,0.0,1.0) if is_finite(transparency_percent) else 1.0
	var valid_pose = is_instance_valid(camera) and actor.is_finite()
	if valid_pose: valid_pose = camera.global_position.is_finite()
	var enabled = riding and valid_pose and reach>0.0
	var elapsed = clampf(dt,0.0,.1) if is_finite(dt) else 0.0
	var blend = 1.0-exp(-elapsed/.16)
	var reset = not initialized or (actor.is_finite() and actor.distance_squared_to(previous_actor)>900.0)
	if actor.is_finite():
		previous_actor = actor
		initialized = true
	if reset: parameters.x = 0.0
	var target = 1.0 if enabled else 0.0
	parameters.x = lerpf(parameters.x,target,blend)
	if absf(parameters.x-target)<.002: parameters.x = target
	# Explicit off takes effect immediately; menu transitions retain their easing.
	if reach==0.0: parameters.x = 0.0
	if not enabled: return
	var depth = clampf(camera.global_position.distance_to(actor)+lerpf(8.0,18.0,reach),8.0,28.0)
	parameters.y = depth*.78
	parameters.z = depth
