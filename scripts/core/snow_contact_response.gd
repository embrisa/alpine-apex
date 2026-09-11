extends RefCounted
## Local material law over the immutable terrain. All forces are acceleration
## per rider mass; compression is normal metres, damping power is watts/kg.
## This evaluator has no time integration and can safely be probed twice/tick.
var compression_m = 0.0
var elastic_acceleration = 0.0
var damper_acceleration = 0.0
var reaction = 0.0
var dissipated_per_kg = 0.0

func evaluate(clearance_m: float, normal_y: float, normal_speed: float, gravity_normal: float, depth: float, stiffness: float, damping: float, damping_limit: float, tuning) -> void:
	var displacement = clearance_m*normal_y
	compression_m = minf(maxf(0.0,-displacement),depth)
	var softness = smoothstep(0.0,.12,depth)*tuning.snow_compliance
	var spring = stiffness*lerpf(1.0,tuning.snow_spring_ratio,softness)
	# Progressive firming spends the final part of existing suspension travel.
	# Continuous potential; the derivative never changes sign across compression.
	var stop_start = tuning.leg_extension*normal_y*.65
	var end_compression = maxf(0.0,-displacement-stop_start)
	elastic_acceleration = -gravity_normal-spring*displacement+stiffness*tuning.snow_stop_progression*softness*end_compression*end_compression/maxf(tuning.leg_extension*normal_y-stop_start,.01)
	var closing = normal_speed<0.0
	var damping_ratio = tuning.snow_compression_damping_ratio if closing else tuning.snow_rebound_damping_ratio
	var limit_ratio = tuning.snow_compression_limit_ratio if closing else tuning.snow_rebound_limit_ratio
	var coefficient = damping*lerpf(1.0,damping_ratio,softness)
	var limit = damping_limit*lerpf(1.0,limit_ratio,softness)
	damper_acceleration = clampf(coefficient*normal_speed,-maxf(0.0,limit),maxf(0.0,limit))
	# A passive rebound damper cannot pull on snow. Limit its contribution to
	# the available compressive reaction before applying the unilateral clamp.
	if not closing: damper_acceleration = minf(damper_acceleration,maxf(0.0,elastic_acceleration))
	reaction = maxf(0.0,elastic_acceleration-damper_acceleration)
	dissipated_per_kg = maxf(0.0,damper_acceleration*normal_speed)
