extends Camera3D
var close_view: bool = false
var initialized: bool = false
var smoothed_forward = Vector3.BACK
var clock: float = 0.0
var effects_enabled: bool = true
var previous_rider_position = Vector3.ZERO
var compression: float = 0.0
var bank: float = 0.0
var motion_intensity: float = 0.0

func reset() -> void:
	initialized = false
	compression = 0.0
	bank = 0.0
	motion_intensity = 0.0

func update_camera(sim, field, rider_position: Vector3, dt: float, menu: bool = false, active: bool = true) -> void:
	var speed: float = sim.velocity.length()
	# Travel-driven chatter stops with the rider and eases out during flight.
	clock += dt * speed
	var forward = Vector3(sin(sim.heading), 0, cos(sim.heading))
	if speed > 2.0:
		var motion = Vector3(sim.velocity.x, 0, sim.velocity.z).normalized()
		forward = motion.lerp(forward, 0.22 if close_view else 0.12).normalized()
	smoothed_forward = smoothed_forward.lerp(forward, 1.0 - exp(-5.5 * dt)).normalized() if initialized else forward
	var intensity = smoothstep(60.0, 200.0, sim.speed_kmh()) if effects_enabled and active and not menu else 0.0
	motion_intensity = lerpf(motion_intensity, intensity, 1.0 - exp(-4.0 * dt))
	var load_offset = clampf((sim.normal_load / 9.81 - 1.0) * 0.09 + sim.landing_force * 0.027, -0.08, 0.24) if sim.grounded and active and effects_enabled else 0.0
	compression = lerpf(compression, load_offset, 1.0 - exp(-12.0 * dt))
	# Raised chase boom reveals the snow immediately ahead of the skier.
	var distance_value = lerpf(5.6, 4.8, smoothstep(30.0, 150.0, sim.speed_kmh()))
	var desired = rider_position - smoothed_forward * distance_value + Vector3.UP * (4.8 - sim.effective_tuck * 0.25 - compression)
	if close_view:
		desired = rider_position + smoothed_forward * 0.12 + Vector3.UP * (1.45 - sim.effective_tuck * 0.35 - compression)
	if menu:
		desired = rider_position + Vector3(-4.5, 3.1, -7.0)
	desired.y = maxf(desired.y, field.sample(desired.x, desired.z).height + (0.8 if close_view else 1.0))
	# Follow translation immediately: boom lag must never accumulate travel.
	if initialized:
		position += rider_position - previous_rider_position
	position = position.lerp(desired, 1.0 - exp(-sim.tuning.camera_response * dt)) if initialized else desired
	for i in range(1, 6):
		var probe = (rider_position+Vector3.UP*1.1).lerp(position, i / 5.0)
		var ground_y: float = field.sample(probe.x, probe.z).height
		if probe.y < ground_y + 0.6:
			position.y += (ground_y + 0.6 - probe.y) * 5.0 / i
	var anticipation = 10.0 + speed * 0.15
	var look_point = rider_position + smoothed_forward * anticipation
	look_point.y = field.sample(look_point.x, look_point.z).height + (0.5 if close_view else 1.4)
	if not sim.grounded:
		look_point.y = lerpf(look_point.y, rider_position.y + 0.5, 0.50)
	if menu:
		look_point = rider_position + Vector3(5, -5.0, 22)
	look_at(look_point)
	var bank_target = clampf(sim.lateral_acceleration / 9.81, -1.5, 1.5) * 0.035 if effects_enabled and active else 0.0
	bank = lerpf(bank, bank_target, 1.0 - exp(-5.0 * dt))
	var chatter = motion_intensity * (0.25 + sim.edge_load * 0.75) if sim.grounded else 0.0
	rotation.z += bank + sin(clock * 2.7) * chatter * 0.002
	rotation.x += (sin(clock * 4.9) + sin(clock * 7.3) * 0.4) * chatter * 0.0012
	var speed_fov = (smoothstep(0.0,60.0,sim.speed_kmh())*0.20 + smoothstep(60.0,120.0,sim.speed_kmh())*0.50 + smoothstep(120.0,200.0,sim.speed_kmh())*0.30) if effects_enabled and not menu else 0.0
	fov = lerpf(fov, sim.tuning.base_fov + sim.tuning.speed_fov * speed_fov, 1.0 - exp(-2.5 * dt))
	initialized = true
	previous_rider_position = rider_position
