extends RefCounted
## Explicit benchmark-only driver. Never installed by ordinary gameplay/replay.
const VERSION = 1
const SOURCE = "res://tests/performance_stress.gd"
const MAX_SPEED_KMH = 300.0

class Simulation extends "res://scripts/core/ski_simulation.gd":
	var target_speed_kmh = 170.0
	var prevented_crashes: Dictionary = {}
	var obstacle_queries = 0
	var nonblocking_contacts = 0
	var travelled_m = 0.0
	var measured_ticks = 0
	var min_speed_kmh = INF
	var max_speed_kmh = 0.0
	var speed_sum_kmh = 0.0
	var grounded_ticks = 0

	func reset(spawn: Vector3, yaw: float = 0.0) -> void:
		super.reset(spawn,yaw)
		reset_measurement()

	func reset_measurement() -> void:
		prevented_crashes.clear(); obstacle_queries = 0; nonblocking_contacts = 0
		travelled_m = 0.0; measured_ticks = 0; grounded_ticks = 0
		min_speed_kmh = INF; max_speed_kmh = 0.0; speed_sum_kmh = 0.0

	func prime_contacts(surface) -> void:
		super.prime_contacts(surface)
		_hold_speed()

	func _hold_speed() -> void:
		var direction = velocity.normalized()
		if direction.length_squared()<.5:
			direction = Vector3(sin(heading),0,cos(heading))
			if grounded: direction = direction.slide(surface_normal).normalized()
		velocity = direction*(target_speed_kmh/3.6)
		peak_speed = maxf(peak_speed,velocity.length())

	func step(dt: float, intent: RiderInput, surface) -> void:
		_hold_speed()
		var before = position
		super.step(dt,intent,surface)
		_hold_speed()
		# The normal solver already published this tick's contact/pose events.
		# Only synchronize the two velocity fields changed by the stress driver;
		# recapturing would double-advance landing/obstacle episode ages.
		motion.velocity_world_mps = velocity; motion.speed_mps = velocity.length()
		travelled_m += position.distance_to(before)
		measured_ticks += 1
		if grounded: grounded_ticks += 1
		var speed = speed_kmh()
		min_speed_kmh = minf(min_speed_kmh,speed)
		max_speed_kmh = maxf(max_speed_kmh,speed); speed_sum_kmh += speed

	func crash(reason: String) -> void:
		prevented_crashes[reason] = prevented_crashes.get(reason,0)+1

	func _resolve_obstacle(surface, from: Vector3) -> void:
		# Retain real broad/narrow-phase queries and impact observations. A tree
		# or cliff must not pin an immortal rider in place at a displayed 170.
		var endpoint = position
		var incoming = velocity
		obstacle_queries += 1
		super._resolve_obstacle(surface,from)
		if position!=endpoint or not obstacle_contact.is_empty(): nonblocking_contacts += 1
		position = endpoint; velocity = incoming

	func report() -> Dictionary:
		return {"target_speed_kmh":target_speed_kmh,"immortal":true,"obstacles":"queries_and_events_without_translation_stop",
			"ticks":measured_ticks,"speed_kmh":{"min":min_speed_kmh if measured_ticks else 0.0,
			"max":max_speed_kmh,"mean":speed_sum_kmh/maxi(measured_ticks,1)},"travelled_m":travelled_m,
			"grounded_ticks":grounded_ticks,"obstacle_queries":obstacle_queries,"nonblocking_contacts":nonblocking_contacts,
			"prevented_crashes":prevented_crashes.duplicate()}

static func create(tuning, speed: float):
	var sim = Simulation.new(tuning)
	sim.target_speed_kmh = speed
	return sim

static func metadata(speed: float, start: Vector3) -> Dictionary:
	return {"version":VERSION,"speed_kmh":speed,"immortal":true,"collision_policy":"query_only",
		"source_sha256":FileAccess.get_sha256(SOURCE),"start":[start.x,start.y,start.z]}

static func preflight_error(data, speed: float) -> String:
	if speed==0.0: return "Speed-controlled trace requires explicit --stress-speed-kmh" if data!=null else ""
	if not is_finite(speed) or speed<=0.0 or speed>MAX_SPEED_KMH: return "Invalid stress speed"
	if not data is Dictionary: return "Generate a matching speed-controlled stress trace first"
	if data.get("version")!=VERSION or data.get("source_sha256")!=FileAccess.get_sha256(SOURCE): return "Stale stress driver identity"
	if data.get("speed_kmh")!=speed or data.get("immortal")!=true or data.get("collision_policy")!="query_only": return "Stress driver settings do not match the trace"
	if not data.get("start") is Array or data.start.size()!=3: return "Invalid stress start"
	for value in data.start:
		if not (value is float or value is int) or not is_finite(float(value)): return "Invalid stress start"
	return ""
