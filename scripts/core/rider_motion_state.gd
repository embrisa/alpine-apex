extends RefCounted
## Reused completed-tick view. Consumers read it; capture belongs to the solver.
## All points/velocities/frames are world SI; angular quantities use radians.
var tick = -1
var velocity_world_mps = Vector3.ZERO
var speed_mps = 0.0
var support_frame = Basis.IDENTITY
var supported = true
var switch_facing = false
var turn_rate_rad_s = 0.0
var slip_rad = 0.0
var edge_rad = 0.0
var angular_velocity_world_rad_s = Vector3.ZERO
var air_age_s = 0.0
var manual_rotation = false
var jump_executed = false
var prediction_valid = false
var prediction_age_s = 1.0
var contact_time_s = -1.0
var contact_normal_world = Vector3.UP
var contact_point_world = Vector3.ZERO
var predicted_velocity_world_mps = Vector3.ZERO
var reserve_01 = 1.0
var time_since_damage_s = 60.0
var recovery_active = false
var landing_episode = 0
var landing_age_s = 60.0
var landing_speed_mps = 0.0
var obstacle_episode = 0
var obstacle_age_s = 60.0
var obstacle_contact = {}
var skis = [{},{}]

func reset() -> void:
	tick = -1
	velocity_world_mps = Vector3.ZERO
	landing_episode = 0; landing_age_s = 60.0; landing_speed_mps = 0.0
	obstacle_episode = 0; obstacle_age_s = 60.0

func capture(sim, dt: float) -> void:
	if tick==sim.ticks: return
	var old = velocity_world_mps
	tick = sim.ticks
	velocity_world_mps = sim.velocity
	speed_mps = sim.velocity.length()
	support_frame = sim.support_basis()
	supported = sim.grounded
	switch_facing = sim.facing_backward
	var a = old.slide(sim.surface_normal).normalized()
	var b: Vector3 = sim.velocity.slide(sim.surface_normal).normalized()
	turn_rate_rad_s = atan2(a.cross(b).dot(sim.surface_normal),a.dot(b))/dt if old.length()>1.0 and speed_mps>1.0 else 0.0
	slip_rad = sim.slip_angle; edge_rad = sim.edge_angle
	angular_velocity_world_rad_s = sim.air_control.angular_velocity+support_frame*Vector3(sim.body.pitch_velocity,0,sim.body.roll_velocity)
	air_age_s = sim.airtime; manual_rotation = sim.air_control.manual_active
	jump_executed = sim.jump_executed
	prediction_valid = sim.landing_assist.valid
	prediction_age_s = sim.landing_assist.prediction_age
	contact_time_s = sim.predicted_landing_time
	contact_normal_world = sim.predicted_landing_normal
	contact_point_world = sim.landing_assist.contact_position
	predicted_velocity_world_mps = sim.landing_assist.predicted_velocity
	reserve_01 = sim.impacts.reserve
	time_since_damage_s = minf(sim.impacts.since_hit,sim.impacts.since_rock)
	recovery_active = supported and sim.normal_load>0 and sim.rock_contact==0 and time_since_damage_s>=sim.tuning.impact_recovery_delay and reserve_01<1.0
	landing_age_s += dt; obstacle_age_s += dt
	var impact = 0.0
	for i in 2:
		var ski = sim.skis[i]
		skis[i].position_world_m = ski.position; skis[i].orientation_world = ski.orientation
		skis[i].supported = ski.grounded; skis[i].load_n = ski.load_n
		skis[i].extension_m = ski.extension # signed reach; positive extends the leg
		skis[i].compression_m = maxf(0.0,-ski.extension)
		skis[i].landing_speed_mps = ski.landing_speed
		impact = maxf(impact,ski.landing_speed)
	if sim.time_since_landing<dt*.5: impact = maxf(impact,sim.landing_force)
	if impact>.5:
		if landing_age_s>=sim.tuning.impact_contact_grace:
			landing_episode += 1; landing_age_s = 0.0; landing_speed_mps = 0.0
		landing_speed_mps = maxf(landing_speed_mps,impact)
	obstacle_contact = sim.obstacle_contact
	if not obstacle_contact.is_empty() and obstacle_age_s>=sim.tuning.impact_contact_grace:
		obstacle_episode += 1; obstacle_age_s = 0.0
