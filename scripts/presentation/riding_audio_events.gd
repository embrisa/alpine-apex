extends RefCounted
## Completed-tick audio observer. No physics writes or simulation RNG.
const Condition = preload("res://scripts/presentation/snow_condition.gd")
enum Kind { LANDING, IMPACT, EQUIPMENT, NEAR_MISS }
enum AudioMaterial { SNOW, ROCK, WOOD, GENERIC }
enum EquipmentProfile { BINDING_RATTLE, SHAFT_TICK, METAL_CLINK, MIXED_KNOCK }
const LOAD_JOLT_RATE = 6.0 # Change in nominal per-ski body weights per second.
const LOAD_SETTLED_RATE = 2.0
const LOAD_REARM_SECONDS = .12
const LOAD_RATTLE_GAP_SECONDS = .50 # Longer than the native binding rattle's .43 s tail.
var events: Array[Dictionary] = []
var clock = 0.0
var last_equipment = -60.0
var last_near = -60.0
var last_hit = -60.0
var previous_force = 0.0
var previous_position = Vector3.ZERO
var initialized = false
var previous_load = [0.0,0.0]
var previous_grounded = [false,false]
var load_rattle_armed = false
var load_quiet_time = 0.0
var pending_landing: Dictionary = {}
var landing_until = 0.0

func reset() -> void:
	events.clear()
	clock = 0.0
	last_equipment = -60.0
	last_near = -60.0
	last_hit = -60.0
	previous_force = 0.0
	initialized = false
	previous_load = [0.0,0.0]
	previous_grounded = [false,false]
	load_rattle_armed = false
	load_quiet_time = 0.0
	pending_landing.clear()
	landing_until = 0.0

static func material_for_reason(reason: String) -> int:
	var label = reason.to_upper()
	if "TREE" in label or "WOOD" in label: return AudioMaterial.WOOD
	if "ROCK" in label or "MINERAL" in label or "CLIFF" in label: return AudioMaterial.ROCK
	return AudioMaterial.GENERIC

func sample(sim, dt: float, near_passes: Array = []) -> Array[Dictionary]:
	events.clear()
	clock += maxf(0.0,dt)
	if initialized and previous_position.distance_to(sim.position)>maxf(30.0,sim.velocity.length()*dt*3.0):
		reset()
		previous_position = sim.position
		return events
	previous_position = sim.position
	var landing_speed = 0.0
	var material = AudioMaterial.SNOW
	var change = 0.0
	var load_activity = 0.0
	var contact_changed = not initialized
	for i in range(2):
		var ski = sim.skis[i]
		if ski.landing_speed>landing_speed:
			landing_speed = ski.landing_speed
			material = ski.material_kind
		if initialized and ski.grounded and previous_grounded[i]:
			var rate: float = (ski.load_n-previous_load[i])/maxf(sim.tuning.rider_mass*9.81*.5,1.0)/maxf(dt,.001)
			change = maxf(change,rate)
			load_activity = maxf(load_activity,absf(rate))
		contact_changed = contact_changed or ski.grounded!=previous_grounded[i]
		previous_load[i] = ski.load_n
		previous_grounded[i] = ski.grounded
	# Bottom-outs raise this decaying telemetry without necessarily losing contact.
	if initialized and sim.landing_force>maxf(0.0,previous_force-dt*12.0)+.1:
		landing_speed = maxf(landing_speed,sim.landing_force)
	previous_force = sim.landing_force
	initialized = true
	var obstacle: Dictionary = sim.obstacle_contact
	if not obstacle.is_empty() and float(obstacle.closing_speed_mps)>.35:
		if clock-last_hit>=.06:
			events.append(_event(Kind.IMPACT,material_for_reason(obstacle.reason),obstacle.closing_speed_mps,0.0,0.0))
			last_hit = clock
		pending_landing.clear() # One onset cannot play both a landing and obstacle hit.
	elif landing_speed>.35:
		if pending_landing.is_empty(): landing_until = clock+.06
		if landing_speed>float(pending_landing.get("speed",0.0)):
			pending_landing = _event(Kind.LANDING,material,landing_speed,0.0,0.0)
	if not pending_landing.is_empty() and (clock>=landing_until or sim.crashed):
		events.append(pending_landing.duplicate())
		pending_landing.clear()
		last_hit = clock
	# One onset per pressure disturbance. Unloading consumes the episode quietly;
	# rebounds, support flicker and cooldown expiry must not become new rattles.
	if sim.crashed or not sim.grounded or sim.velocity.length()<=2 or contact_changed:
		load_rattle_armed = false
		load_quiet_time = 0.0
	elif load_activity>LOAD_JOLT_RATE:
		var onset = load_rattle_armed
		load_rattle_armed = false
		load_quiet_time = 0.0
		if onset and change>LOAD_JOLT_RATE and pending_landing.is_empty() and obstacle.is_empty() and clock-last_equipment>=LOAD_RATTLE_GAP_SECONDS and clock-last_hit>.12:
			events.append(_equipment(EquipmentProfile.BINDING_RATTLE,minf(change*.25,8.0),0.0,clampf(change/40,0,1)))
			last_equipment = clock
	elif load_activity<=LOAD_SETTLED_RATE:
		load_quiet_time += maxf(0.0,dt)
		if load_quiet_time>=LOAD_REARM_SECONDS: load_rattle_armed = true
	else:
		load_quiet_time = 0.0
	if not sim.crashed and clock-last_near>=.25 and obstacle.is_empty() and not near_passes.is_empty():
		var closest: Dictionary = near_passes[0]
		for entry in near_passes:
			if entry.gap_m<closest.gap_m: closest=entry
		var right: Vector3 = sim.support_basis().x*(-1.0 if sim.facing_backward else 1.0)
		var side: float = signf((closest.position-sim.position).dot(right))
		events.append(_event(Kind.NEAR_MISS,material_for_reason(closest.reason),sim.velocity.length(),side*.8,1.0-clampf(closest.gap_m,0,1)))
		last_near = clock
	return events

static func _event(kind: int, material: int, speed: float, pan: float, detail: float) -> Dictionary:
	return {"kind":kind,"material":material,"speed":speed,"pan":pan,"detail":detail}

static func _equipment(profile: int, speed: float, pan: float, detail: float) -> Dictionary:
	var event = _event(Kind.EQUIPMENT,AudioMaterial.GENERIC,speed,pan,detail)
	event.profile = profile
	return event
