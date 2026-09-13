extends RefCounted
## Explicit diagnostic rules. Never installed by competitive or ordinary skiing.
const VERSION = 1
const DEFAULTS = {"hold_speed":false,"speed_kmh":120.0,"immortal":false,"trees":true,"rocks":true}
var values: Dictionary = DEFAULTS.duplicate()
var pending: Array = []
var applied: Array = []
var speed_delta = Vector3.ZERO
var error = ""

static func settings_error(value: Variant) -> String:
	if not value is Dictionary or value.size()!=DEFAULTS.size(): return "Incomplete test controls"
	for key in ["hold_speed","immortal","trees","rocks"]:
		if not value.get(key) is bool: return "Invalid test switch: "+key
	var speed = value.get("speed_kmh")
	if not (speed is float or speed is int) or not is_finite(float(speed)) or speed<0 or speed>300 or (value.hold_speed and speed<1): return "Set speed to 0–300 km/h; holding requires at least 1 km/h."
	return ""

func queue_settings(settings: Dictionary) -> String:
	error = settings_error(settings)
	if error.is_empty(): pending.append({"kind":"settings","value":settings.duplicate()})
	return error

func queue_speed(speed: float) -> String:
	if not is_finite(speed) or speed<0 or speed>300: return "Speed must be 0–300 km/h."
	pending.append({"kind":"speed","value":speed})
	return ""

func before_tick(sim, surface, tick: int, overlap_points: Array = []) -> Array:
	applied = []; speed_delta = Vector3.ZERO; error = ""
	for command in pending:
		if command.kind=="settings":
			var next: Dictionary = command.value
			if sim.crashed and (next.immortal!=values.immortal or next.hold_speed!=values.hold_speed or next.speed_kmh!=values.speed_kmh):
				error = "Speed and immortality are unavailable during crash aftermath."; continue
			var points = overlap_points if not overlap_points.is_empty() else [sim.position]
			var blocked = false
			for category in ["trees","rocks"]:
				if next[category] and not values[category]:
					for point in points:
						if surface.overlaps(point,category): blocked = true
			if blocked:
				error = "Move clear of the rider and equipment before enabling these collisions."; continue
			if next.immortal and not values.immortal: sim.impacts.reserve = 1.0
			values = next.duplicate()
		elif command.kind=="reset_input":
			sim.air_control.cancel_input(); sim.clear_input_buffer()
		elif command.kind=="speed":
			if sim.crashed: error = "Speed is unavailable during crash aftermath."; continue
			_set_speed(sim,float(command.value))
		var event: Dictionary = command.duplicate(true); event.tick = tick
		applied.append(event)
	pending.clear()
	if values.hold_speed and not sim.crashed: _set_speed(sim,values.speed_kmh)
	return applied

func _set_speed(sim, speed: float) -> void:
	var direction: Vector3 = sim.velocity.normalized()
	if direction.length_squared()<.5:
		direction = Vector3(sin(sim.heading),0,cos(sim.heading))
		if sim.grounded: direction = direction.slide(sim.surface_normal).normalized()
	var incoming: Vector3 = sim.velocity
	sim.velocity = direction*(speed/3.6)
	speed_delta += sim.velocity-incoming

static func at_tick(initial: Dictionary, events: Array, tick: int) -> Dictionary:
	var settings = initial.duplicate()
	for event in events:
		if event.tick>tick: break
		if event.kind=="settings": settings = event.value.duplicate()
	return settings
