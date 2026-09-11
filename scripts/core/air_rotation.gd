extends RefCounted
## Whole-equipment quaternion control at 120 Hz. World rad/s and rad/s².
## Never writes linear state. Ordinary pitch and explicit tricks own the same frame.
var angular_velocity = Vector3.ZERO
var angular_acceleration = Vector3.ZERO
var assist_acceleration = Vector3.ZERO
var manual_active = false
var orientation_flight = false
var tilt_flight = false # intentional ordinary pitch, distinct from yaw-only steering
var trick_flight = false
var flip_flight = false
var flip_direction = 0.0 # rider-relative; source names use the imported convention
var assist_motion = false
var integrated_pitch = 0.0 # physical ski X axis diagnostic, including ordinary tilt
var integrated_yaw = 0.0
var tilt_armed = false
var tilt_angle = 0.0 # accumulated ordinary pitch; neutral does not rebase it
var pitch_velocity = 0.0 # rider-relative component, excluding world-up yaw
var flip_settling = false
var reversal_active = false

func reset() -> void:
	angular_velocity = Vector3.ZERO
	angular_acceleration = Vector3.ZERO
	assist_acceleration = Vector3.ZERO
	manual_active = false
	orientation_flight = false
	tilt_flight = false
	trick_flight = false
	flip_flight = false
	flip_direction = 0.0
	assist_motion = false
	integrated_pitch = 0.0
	integrated_yaw = 0.0
	tilt_armed = false
	tilt_angle = 0.0
	pitch_velocity = 0.0
	flip_settling = false
	reversal_active = false

func cancel_input() -> void:
	# Lifecycle changes gate new pitch, preserving physical attitude/momentum.
	tilt_armed = false

static func pitch_component(omega: Vector3, side: Vector3) -> float:
	# Separate pitch from yaw on cross slopes. Parallel axes share one finite
	# rotation, so use that axis instead of dividing by a vanishing determinant.
	var denominator = 1.0-side.y*side.y
	return (omega.dot(side)-omega.y*side.y)/denominator if denominator>.00001 else omega.dot(side)

func step(dt: float, sim, intent) -> void:
	if sim.grounded: reset(); return
	var frame: Basis = sim.support_basis()
	var side: Vector3 = frame.x*(-1.0 if sim.facing_backward else 1.0)
	var pitch: float = clampf(intent.air_pitch,-1.0,1.0)
	var yaw: float = clampf(intent.air_yaw,-1.0,1.0)
	var tilt: float = clampf(intent.air_tilt,-1.0,1.0)
	pitch_velocity = pitch_component(angular_velocity,side)
	if absf(pitch)>.000001:
		flip_settling = true; tilt_armed = false
		flip_flight = true; flip_direction = signf(pitch)
	elif flip_settling and absf(pitch_velocity)<.00001:
		# The flip has physically stopped. The current attitude is zero trim;
		# neither the flight frame nor accumulated rotation changes.
		flip_settling = false; tilt_angle = 0.0
	if not flip_settling and absf(tilt)<.000001: tilt_armed = true
	manual_active = absf(pitch)+absf(yaw)+absf(tilt)+absf(intent.steer)>.000001 or intent.grab
	if absf(pitch)+absf(yaw)>.000001: trick_flight = true
	# Ordinary turning rotates the complete rider too. Transporting the torso
	# against this commanded frame makes strong yaw twist into its joint stops.
	if absf(pitch)+absf(yaw)+absf(intent.steer)>.000001: orientation_flight = true
	var desired = Vector3.ZERO
	var acceleration: float = sim.tuning.air_rotation_acceleration
	var assisted = not manual_active and not orientation_flight and sim.landing_assist.strength>0.0
	if assisted:
		assist_motion = true
		desired = sim.landing_assist.requested_angular_velocity
		acceleration = sim.tuning.air_assist_acceleration
	elif manual_active or orientation_flight:
		assist_motion = false
		var pitch_goal: float = pitch*sim.tuning.air_flip_rate
		if not flip_settling and tilt_armed and absf(tilt)>.000001:
			orientation_flight = true
			tilt_flight = true
			var remaining: float = maxf(0.0,sim.tuning.air_tilt_limit-signf(tilt)*tilt_angle)
			# Ease before the stop, retaining deceleration room during yaw.
			# Never clamp or reconstruct the frame from Euler angles.
			pitch_goal = signf(tilt)*minf(absf(tilt)*sim.tuning.air_tilt_rate,remaining*8.0)
		var yaw_goal: float = -(yaw*sim.tuning.air_spin_rate+intent.steer*sim.tuning.air_steer_rate)
		var yaw_velocity: float = angular_velocity.y-pitch_velocity*side.y
		desired = side*pitch_goal+Vector3.UP*yaw_goal
		desired = desired.limit_length(sim.tuning.air_rotation_rate_limit)
		if desired.dot(angular_velocity)<0.0 or pitch_goal*pitch_velocity<0.0 or yaw_goal*yaw_velocity<0.0:
			reversal_active = true
		if reversal_active or desired.length_squared()<angular_velocity.length_squared():
			acceleration = sim.tuning.air_rotation_braking
	elif assist_motion:
		acceleration = sim.tuning.air_assist_acceleration
	else:
		acceleration = sim.tuning.air_rotation_braking
	var old = angular_velocity
	angular_velocity = angular_velocity.move_toward(desired,acceleration*dt)
	if angular_velocity.is_equal_approx(desired): reversal_active = false
	pitch_velocity = pitch_component(angular_velocity,side)
	if orientation_flight and not flip_settling:
		tilt_angle += pitch_velocity*dt
	angular_acceleration = (angular_velocity-old)/dt
	assist_acceleration = angular_acceleration if assisted or (assist_motion and not manual_active and not orientation_flight) else Vector3.ZERO
	var speed = angular_velocity.length()
	if speed>.000001:
		integrated_pitch += angular_velocity.dot(frame.x)*dt
		integrated_yaw += angular_velocity.dot(Vector3.UP)*dt
		frame = (Basis(angular_velocity/speed,speed*dt)*frame).orthonormalized()
	# Wrapped heading is a diagnostic; it cannot reconstruct an inverted flip.
	if Vector2(frame.z.x,frame.z.z).length_squared()>.00001:
		sim.heading = atan2(frame.z.x,frame.z.z)
	sim.flight_frame = frame
	sim.flight_heading = sim.heading
