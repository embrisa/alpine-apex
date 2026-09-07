class_name RiderInput
extends RefCounted
## Movement-model contract. Other equipment can interpret these intents differently.
var steer: float = 0.0 # Negative = rider-left; positive = rider-right.
var tuck: float = 0.0
var brake: float = 0.0
var jump: bool = false # One release request; recorded for deterministic simulation.
var jump_held: bool = false # Presentation readiness only; does not change impulse.

func copy() -> RiderInput:
	var result = RiderInput.new()
	result.steer = steer
	result.tuck = tuck
	result.brake = brake
	result.jump = jump
	result.jump_held = jump_held
	return result
