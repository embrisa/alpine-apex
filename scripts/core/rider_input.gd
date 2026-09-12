class_name RiderInput
extends RefCounted
## Movement-model contract. Other equipment can interpret these intents differently.
var steer: float = 0.0 # Negative = travel-left; positive = travel-right, including switch.
var tuck: float = 0.0 # Forward intent: poles on slow snow, tuck at speed.
var brake: float = 0.0
var jump: bool = false # One release request; recorded for deterministic simulation.
var jump_held: bool = false # Preparation cancels pole thrust; never changes hop impulse.
var air_pitch: float = 0.0 # -backflip / +frontflip, rotation intent only.
var air_yaw: float = 0.0 # -left / +right spin, independent of camera.
var air_tilt: float = 0.0 # -nose up / +nose down; bounded pitch after neutral in flight.
var grab: bool = false # Original cosmetic safety pose; no inertia/drag change.

func copy() -> RiderInput:
	var result = RiderInput.new()
	result.steer = steer
	result.tuck = tuck
	result.brake = brake
	result.jump = jump
	result.jump_held = jump_held
	result.air_pitch = air_pitch
	result.air_yaw = air_yaw
	result.air_tilt = air_tilt
	result.grab = grab
	return result
