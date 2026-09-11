extends Camera3D
## Render-time presentation only. Look input never enters RiderInput or the solver.
const BASE_FOV = 72.0
const FAST_FOV = 110.0
# Framing is presentation only, independent of the replay/physics resource.
const CameraSettings = preload("res://scripts/presentation/camera_settings.gd")
var settings = CameraSettings.new()
const PREFERRED_SNOW_CLEARANCE = 2.0
# Retain the existing elevated ragdoll framing; riding height controls do not
# change the crash presentation owned by the ragdoll focus in main.
const CRASH_HEIGHT = Vector2(12.0, 14.0)
const CRASH_SNOW_CLEARANCE = Vector2(10.0, 12.0)
const MAX_SMOOTHING_TAU = 0.24
const CHASE_VERTICAL_LAG = 1.5
const FIRST_PERSON_VERTICAL_LAG = 0.2
var close_view: bool = false
var initialized: bool = false
var smoothed_forward = Vector3.BACK
var clock: float = 0.0
var effects_enabled: bool = true
var previous_rider_position = Vector3.ZERO
var compression: float = 0.0
var bank: float = 0.0
var motion_intensity: float = 0.0
var speed_blend: float = 0.0
var carve_blend: float = 0.0
var boom_distance: float = CameraSettings.DEFAULTS.rest_distance
var boom_height: float = CameraSettings.DEFAULTS.rest_height
var look_yaw: float = 0.0
var look_pitch: float = 0.0
var look_idle: float = 0.8
var recentering: bool = false
var pending_mouse = Vector2.ZERO
var pending_stick = Vector2.ZERO
# Keep the existing boom response separate from vertical stabilization. Manual
# orbit height passes through that response only, never the new low-pass filter.
var follow_position = Vector3.ZERO
var follow_manual_height: float = 0.0
var stabilized_height: float = 0.0
var stabilization_mode: int = -2

func reset() -> void:
	if Engine.has_singleton("AlpineFidelityFX"): Engine.get_singleton("AlpineFidelityFX").reset_history()
	initialized = false
	compression = 0.0
	bank = 0.0
	motion_intensity = 0.0
	speed_blend = 0.0
	carve_blend = 0.0
	look_yaw = 0.0
	look_pitch = 0.0
	stabilization_mode = -2
	clear_look_input()

func clear_look_input() -> void:
	pending_mouse = Vector2.ZERO
	pending_stick = Vector2.ZERO
	look_idle = settings.shared.recenter_delay
	recentering = false

func add_mouse_look(screen_delta: Vector2) -> void:
	pending_mouse += screen_delta

func set_stick_look(value: Vector2) -> void:
	pending_stick = value.limit_length()

func recenter_look() -> void:
	clear_look_input()
	recentering = true

func has_manual_look() -> bool:
	return absf(look_yaw) + absf(look_pitch) > 0.001 or look_idle < settings.shared.recenter_delay

static func overview_speed_factor(kmh: float) -> float:
	return smoothstep(0.0, 60.0, kmh) * 0.20 + smoothstep(60.0, 120.0, kmh) * 0.50 + smoothstep(120.0, 200.0, kmh) * 0.30

static func carve_factor(sim) -> float:
	if not sim.grounded or sim.crashed or sim.speed_kmh() <= 30.0 or sim.time_since_landing < 0.2:
		return 0.0
	var force = smoothstep(0.5, 1.3, absf(sim.lateral_acceleration) / 9.81)
	var edge = smoothstep(deg_to_rad(5.0), deg_to_rad(15.0), absf(sim.edge_angle))
	var grip = 1.0 - smoothstep(deg_to_rad(20.0), deg_to_rad(40.0), absf(sim.slip_angle))
	return force * edge * grip * smoothstep(30.0, 45.0, sim.speed_kmh())

func _update_look(dt: float, kmh: float, enabled: bool, summit: bool) -> void:
	if not enabled:
		clear_look_input()
		return
	var controls: Dictionary = settings.shared
	var delta = pending_mouse * deg_to_rad(controls.mouse_sensitivity) + pending_stick * Vector2(controls.stick_yaw_speed,controls.stick_pitch_speed) * PI / 180.0 * dt
	if controls.invert_y: delta.y = -delta.y
	pending_mouse = Vector2.ZERO
	pending_stick = Vector2.ZERO
	if not delta.is_zero_approx():
		var yaw = look_yaw - delta.x
		look_yaw = clampf(yaw, deg_to_rad(-120.0), deg_to_rad(120.0)) if close_view and not summit else wrapf(yaw, -PI, PI)
		look_pitch = clampf(look_pitch - delta.y, deg_to_rad(-65.0), deg_to_rad(60.0))
		look_idle = 0.0
		recentering = false
	else:
		# Integrate only the part of this frame after the idle threshold.
		var previous_idle = look_idle
		look_idle += dt
		var return_dt = dt if recentering else maxf(0.0, look_idle - maxf(controls.recenter_delay, previous_idle))
		if recentering or (controls.auto_recenter and kmh > 5.0 and not summit):
			var retain = exp(-return_dt / controls.recenter_time)
			look_yaw *= retain
			look_pitch *= retain
			if absf(look_yaw) + absf(look_pitch) < 0.001:
				look_yaw = 0.0
				look_pitch = 0.0
				recentering = false
	if close_view and not summit:
		look_yaw = clampf(look_yaw, deg_to_rad(-120.0), deg_to_rad(120.0))

func update_camera(sim, field, rider_position: Vector3, dt: float, menu: bool = false, active: bool = true, summit: bool = false, preview_kmh: float = -1.0) -> void:
	var speed: float = sim.velocity.length()
	var kmh: float = preview_kmh if preview_kmh>=0.0 else sim.speed_kmh()
	var riding = not menu and not summit and not sim.crashed
	var profile: Dictionary = settings.profile("first_person" if close_view else "chase")
	_update_look(dt, kmh, active and not menu, summit)
	clock += dt * speed
	# Handling yaw is travel-oriented even when the rendered rider faces back.
	# Cosmetic facing must never flip chase/first-person anticipation or look.
	var forward = Vector3(sin(sim.heading), 0, cos(sim.heading))
	if speed > 2.0 and not summit:
		var motion = Vector3(sim.velocity.x, 0, sim.velocity.z)
		if motion.length_squared() > 0.01:
			forward = motion.normalized().lerp(forward, 0.22 if close_view else 0.12).normalized()
	smoothed_forward = smoothed_forward.lerp(forward, 1.0 - exp(-(profile.heading_response if riding else 5.5) * dt)).normalized() if initialized else forward
	var animated = effects_enabled and active and not menu and not summit
	var intensity = smoothstep(60.0, 200.0, kmh) if animated else 0.0
	motion_intensity = lerpf(motion_intensity, intensity, 1.0 - exp(-4.0 * dt))
	var load_offset = clampf((sim.normal_load / 9.81 - 1.0) * 0.09 + sim.landing_force * 0.027, -0.08, 0.24) if sim.grounded and animated else 0.0
	if riding: load_offset *= profile.compression_strength / 100.0
	compression = lerpf(compression, load_offset, 1.0 - exp(-12.0 * dt))
	var target_speed = (CameraSettings.speed_factor(kmh,profile) if riding else overview_speed_factor(kmh)) if effects_enabled and not menu and not summit else 0.0
	var speed_tau: float = (profile.acceleration_time if target_speed>speed_blend else profile.deceleration_time) if riding else 0.4
	speed_blend = lerpf(speed_blend, target_speed, 1.0 - exp(-dt / speed_tau)) if initialized and speed_tau>0.0 else target_speed
	# Local lens preferences apply only to riding. Keep the overview and crash
	# lens independent, just like their existing position and aim.
	var framing: Vector4 = CameraSettings.sample_framing(profile,speed_blend) if riding else Vector4(lerpf(BASE_FOV,FAST_FOV,speed_blend),lerpf(3.0,7.0,speed_blend),lerpf(6.0,8.0,speed_blend),-10.0)
	fov = framing.x
	var carving = animated and not close_view and not has_manual_look()
	var target_carve = carve_factor(sim) if carving else 0.0
	if riding: target_carve *= profile.carve_strength / 100.0
	if not carving:
		carve_blend = 0.0
	else:
		var tau = 0.12 if target_carve > carve_blend else 0.6
		carve_blend = lerpf(carve_blend, target_carve, 1.0 - exp(-dt / tau))
	boom_distance = maxf(0.4, framing.y - carve_blend * 0.6)
	var tuck_strength: float = profile.tuck_strength / 100.0 if riding else 1.0
	var height_offset = carve_blend * 0.25 + (sim.effective_tuck * 0.25 * tuck_strength if animated else 0.0) + compression
	boom_height = maxf(1.0, framing.z - height_offset)
	if sim.crashed:
		boom_height = maxf(11.25, lerpf(CRASH_HEIGHT.x, CRASH_HEIGHT.y, speed_blend) - height_offset)
	var orbit_forward = smoothed_forward.rotated(Vector3.UP, look_yaw)
	var distance_value = 30.0 if summit else boom_distance
	var height_value = 45.0 if summit else boom_height
	var chase = not close_view and not summit and not menu
	var preferred_clearance = PREFERRED_SNOW_CLEARANCE
	var collision_clearance = 1.0
	if chase and sim.crashed:
		preferred_clearance = maxf(9.25, lerpf(CRASH_SNOW_CLEARANCE.x, CRASH_SNOW_CLEARANCE.y, speed_blend) - height_offset)
		collision_clearance = lerpf(preferred_clearance, 1.0, smoothstep(0.0, deg_to_rad(30.0), maxf(0.0, look_pitch)))
	if chase:
		# Aim for useful snow clearance without forcing an overhead perspective.
		# The final collision pass enforces 1 m, allowing bumps to be smoothed.
		var behind = rider_position - orbit_forward * distance_value
		height_value = maxf(height_value, field.sample(behind.x, behind.z).height + preferred_clearance - rider_position.y)
	var automatic_height = rider_position.y + height_value
	var radius = Vector2(distance_value, height_value).length()
	var elevation = clampf(atan2(height_value, distance_value) - look_pitch, deg_to_rad(5.0), deg_to_rad(80.0))
	var desired = rider_position - orbit_forward * (cos(elevation) * radius) + Vector3.UP * (sin(elevation) * radius)
	var manual_height = desired.y - automatic_height
	if chase:
		var look_up_weight = smoothstep(0.0, deg_to_rad(30.0), maxf(0.0, look_pitch))
		desired.y = maxf(desired.y, field.sample(desired.x, desired.z).height + lerpf(preferred_clearance, 1.0, look_up_weight))
	if close_view and not summit:
		var eye_height: float = profile.eye_height if riding else 1.45
		var tuck_lowering: float = profile.tuck_lowering * tuck_strength if riding else 0.35
		desired = rider_position + smoothed_forward * 0.12 + Vector3.UP * (eye_height - (sim.effective_tuck * tuck_lowering if animated else 0.0) - compression)
		manual_height = 0.0
	if menu:
		desired = rider_position + Vector3(-4.5, 3.1, -7.0)
		manual_height = 0.0
	# Translation is immediate in the base follow, so horizontal travel cannot
	# accumulate lag. Only automatic elevation gets additional stabilization.
	var mode = -1 if menu or summit or sim.crashed else (1 if close_view else 0)
	var fresh = not initialized or mode != stabilization_mode
	var boom_blend = 1.0 - exp(-(profile.boom_response if riding else 7.5) * dt)
	if initialized:
		if mode != stabilization_mode: follow_position = position
		follow_position += rider_position - previous_rider_position
	follow_position = follow_position.lerp(desired, boom_blend) if initialized else desired
	follow_manual_height = lerpf(follow_manual_height, manual_height, boom_blend) if initialized else manual_height
	var tau = MAX_SMOOTHING_TAU * profile.vertical_smoothing / 100.0
	var blend = 1.0 if fresh or mode < 0 or tau <= 0.0 else 1.0 - exp(-dt / tau)
	var max_lag = FIRST_PERSON_VERTICAL_LAG if close_view else CHASE_VERTICAL_LAG
	var target_height = follow_position.y - follow_manual_height
	stabilized_height = _smooth_height(stabilized_height, target_height, blend, max_lag)
	position = follow_position
	position.y = stabilized_height + follow_manual_height
	var before_clearance = position
	_clear_terrain(field, rider_position, close_view and not summit, collision_clearance)
	# Collision wins; retain its correction to avoid fighting the obstacle every
	# frame or springing back into it when the low-pass state catches up.
	follow_position += position - before_clearance
	stabilized_height = position.y - follow_manual_height
	if mode >= 0:
		# Explicit optical aim is independent of the boom, terrain correction and
		# contact switches. The same evaluator supplies the paused preview.
		var pitch = deg_to_rad(framing.w)
		look_at(position + smoothed_forward)
		global_basis = Basis(Vector3.UP, look_yaw) * global_basis
		rotate_object_local(Vector3.RIGHT, clampf(pitch + look_pitch, deg_to_rad(-80.0), deg_to_rad(80.0)))
	else:
		# Summit, menu and crash retain their existing terrain/ragdoll framing.
		var anticipation = 400.0 if summit else (10.0 + speed * 0.15 if close_view else lerpf(4.0, 6.0, speed_blend))
		var look_point = rider_position + smoothed_forward * anticipation
		look_point.y = field.sample(look_point.x, look_point.z).height + (0.5 if close_view and not summit else (0.6 if chase else 1.4))
		if not sim.grounded and not summit:
			look_point.y = lerpf(look_point.y, rider_position.y + 0.5, 0.50)
		if not close_view or summit:
			var away = maxf(absf(look_yaw), absf(look_pitch))
			var orbit_weight = smoothstep(0.0, deg_to_rad(60.0), away)
			look_point = look_point.lerp(rider_position + Vector3.UP * 1.4, orbit_weight)
		if menu:
			look_point = rider_position + Vector3(5, -5.0, 22)
		look_at(look_point)
		if close_view and not summit and not menu:
			global_basis = Basis(Vector3.UP, look_yaw) * global_basis
			rotate_object_local(Vector3.RIGHT, look_pitch)
			rotation.x = clampf(rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))
	var bank_target = clampf(sim.lateral_acceleration / 9.81, -1.5, 1.5) * 0.035 if animated and not has_manual_look() else 0.0
	if riding: bank_target *= profile.bank_strength / 100.0
	bank = lerpf(bank, bank_target, 1.0 - exp(-5.0 * dt))
	var chatter = motion_intensity * (0.25 + sim.edge_load * 0.75) if sim.grounded and animated and not has_manual_look() else 0.0
	if riding: chatter *= profile.chatter_strength / 100.0
	rotation.z += bank + sin(clock * 2.7) * chatter * 0.002
	if mode < 0:
		rotation.x += (sin(clock * 4.9) + sin(clock * 7.3) * 0.4) * chatter * 0.0012
	initialized = true
	previous_rider_position = rider_position
	stabilization_mode = mode

static func _smooth_height(previous: float, target: float, blend: float, max_lag: float) -> float:
	return clampf(lerpf(previous, target, blend), target - max_lag, target + max_lag)

func _clear_terrain(field, rider_position: Vector3, first_person: bool, snow_clearance: float = 1.0) -> void:
	position.y = maxf(position.y, field.sample(position.x, position.z).height + (0.8 if first_person else snow_clearance))
	var pivot = rider_position + Vector3.UP * 1.1
	# Bounded samples also cover the longer summit boom, independent of Nodes.
	var probes = clampi(ceili(Vector2(position.x - pivot.x, position.z - pivot.z).length() / 2.0), 5, 32)
	for i in range(1, probes + 1):
		var fraction = float(i) / probes
		var probe = pivot.lerp(position, fraction)
		var ground_y: float = field.sample(probe.x, probe.z).height
		if probe.y < ground_y + 0.6:
			position.y += (ground_y + 0.6 - probe.y) / fraction

	# Retract the boom before a rock obstruction; terrain support remains unchanged.
	if field.has_method("ray_geology"):
		var hit: Dictionary = field.ray_geology(pivot,position,.65)
		if not hit.is_empty():
			position = pivot.lerp(position,maxf(0.0,float(hit.fraction)-.015)) + hit.normal*.04
