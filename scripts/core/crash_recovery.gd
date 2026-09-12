extends RefCounted
## Deterministic local recovery; terrain/props remain the sole support authority.
const RULES_VERSION = 1
const MAX_RADIUS_M = 8.0
const MAX_DROP_M = 2.0
const MAX_RISE_M = 6.0
const MAX_SLOPE_DEGREES = 40.0
const PATH_STEP_M = 1.0
const PATH_BREAK_M = 0.6
const FOOTPRINT_HALF_LENGTH_M = 1.25
const FOOTPRINT_HALF_WIDTH_M = 0.55
const Simulation = preload("res://scripts/core/ski_simulation.gd")
var anchor: Dictionary = {}
var last_support: Dictionary = {}
var candidates_checked = 0
var height_queries = 0
var obstacle_queries = 0
var support_primes = 0
var query_usec = 0

func invalidate() -> void:
	anchor.clear()
	last_support.clear()

func observe_support(sim) -> void:
	# A cheap completed-state copy, never an extra terrain/obstacle workload per tick.
	if not sim.crashed and sim.grounded and sim.contacts_initialized and sim.contact_count==2:
		last_support = {"position":sim.position,"heading":sim.heading}

func capture(sim, attempt: int, surface_id: int) -> void:
	if not anchor.is_empty(): return
	anchor = {"position":sim.position,"heading":sim.heading,"attempt":attempt,
		"surface_id":surface_id,"support":last_support.duplicate(true),"tuning":sim.tuning}

func matches(attempt: int, surface_id: int) -> bool:
	return not anchor.is_empty() and anchor.attempt==attempt and anchor.surface_id==surface_id

func resolve(field, surface, session, zone = null, timed: bool = true) -> Dictionary:
	var started = Time.get_ticks_usec()
	candidates_checked = 0; height_queries = 0; obstacle_queries = 0; support_primes = 0
	var result = _resolve(field,surface,session,zone,timed)
	query_usec = Time.get_ticks_usec()-started
	return result

func _resolve(field, surface, session, zone, timed: bool) -> Dictionary:
	if anchor.is_empty(): return {"error":"This crash location is no longer available. Try again from the start."}
	var onset: Vector3 = anchor.position
	if not onset.is_finite(): return _unavailable()
	var origins: Array[Vector3] = [onset]
	var supported: Dictionary = anchor.support
	if not supported.is_empty():
		var p: Vector3 = supported.position
		if p.is_finite() and _horizontal(p-onset).length()<=MAX_RADIUS_M and absf(p.y-onset.y)<=MAX_RISE_M:
			origins.append(p)
	# Exact onset first, then the last supported pose, then 2/4/6/8 m rings.
	var candidates: Array[Vector3] = origins.duplicate()
	var probe = Simulation.new(anchor.tuning)
	for radius in [2.0,4.0,6.0,8.0]:
		for i in 8:
			var direction = Vector3(sin(TAU*i/8.0),0,cos(TAU*i/8.0))
			candidates.append(onset+direction*radius)
	for candidate in candidates:
		candidates_checked += 1
		if _horizontal(candidate-onset).length()>MAX_RADIUS_M+.000001: continue
		if not field.ski_bounds().grow(-2.0).has_point(Vector2(candidate.x,candidate.z)): continue
		if zone!=null and not zone.contains(candidate,2.0): continue
		var support = _sample(surface,candidate)
		candidate.y = support.height
		if onset.y-candidate.y>MAX_DROP_M or candidate.y-onset.y>MAX_RISE_M: continue
		if support.normal.y<cos(deg_to_rad(MAX_SLOPE_DEGREES)): continue
		var downhill: Vector3 = Vector3.DOWN.slide(support.normal)
		var heading: float = atan2(downhill.x,downhill.z) if _horizontal(downhill).length_squared()>.0001 else anchor.heading
		var progress_axis = Vector3(session.split_axis.x,0,session.split_axis.y) if timed else _horizontal(downhill).normalized()
		if progress_axis.length_squared()<.01: progress_axis = Vector3(sin(anchor.heading),0,cos(anchor.heading))
		if (candidate-onset).dot(progress_axis)>.000001: continue
		if timed and not _race_safe(session,onset,candidate): continue
		if not _footprint_clear(surface,candidate,heading): continue
		var connected = false
		for origin in origins:
			# Never project an airborne origin down a cliff to invent a path.
			var ground = _sample(surface,origin)
			if absf(origin.y-ground.height)>MAX_DROP_M: continue
			var seated = Vector3(origin.x,ground.height,origin.z)
			if _path_clear(surface,seated,candidate):
				connected = true
				break
		if connected:
			# Dry-run the existing authoritative contact initialization, without a
			# skiing tick or any mutation of the live rider/tuning. A geometric
			# snow footprint alone cannot guarantee two loaded ski contacts.
			support_primes += 1
			probe.reset(candidate,heading)
			probe.prime_contacts(surface)
			if probe.grounded and probe.contact_count==2 and probe.body.initialized:
				return {"position":candidate,"heading":heading,"error":""}
	return _unavailable()

func _race_safe(session, onset: Vector3, candidate: Vector3) -> bool:
	# No teleport crossing even outside the finite gate, and no approaching an
	# unearned split from its far side. Recovery can always retreat to its near side.
	for i in 3:
		var limit: float = session.split_length*float(i+1)/4.0
		if session.split_times[i]<0.0 and (Vector2(candidate.x,candidate.z)-session.split_origin).dot(session.split_axis)>=limit: return false
	if session.race:
		var race = session.race
		var normal = Vector3(sin(race.finish_heading),0,cos(race.finish_heading))
		var a: float = (onset-race.finish).dot(normal)
		var b: float = (candidate-race.finish).dot(normal)
		var start_side: float = (race.start-race.finish).dot(normal)
		if absf(b)<1.0 or a*b<0.0 or (absf(start_side)>1.0 and b*start_side<=0.0): return false
	else:
		if candidate.z>=session.finish_z-1.0: return false
		if (onset.z-session.finish_z)*(candidate.z-session.finish_z)<0.0: return false
	return session.finish_fraction(onset,candidate)<0.0

func _footprint_clear(surface, point: Vector3, heading: float) -> bool:
	var forward = Vector3(sin(heading),0,cos(heading))
	var side = Vector3(cos(heading),0,-sin(heading))
	var center = _sample(surface,point)
	var width = maxf(FOOTPRINT_HALF_WIDTH_M,anchor.tuning.half_stance+anchor.tuning.ski_width*.5)
	var length = maxf(FOOTPRINT_HALF_LENGTH_M,anchor.tuning.ski_length*.5)
	for lateral in [-width,0.0,width]:
		var previous = Vector3.ZERO
		for along in [-length,0.0,length]:
			var at = point+side*lateral+forward*along
			var support = _sample(surface,at)
			if support.normal.y<cos(deg_to_rad(MAX_SLOPE_DEGREES)): return false
			var plane_y: float = point.y-(center.normal.x*(at.x-point.x)+center.normal.z*(at.z-point.z))/center.normal.y
			if absf(support.height-plane_y)>.25: return false
			if surface.has_method("rock_fraction_at") and surface.rock_fraction_at(at.x,at.z)>.25: return false
			at.y = support.height
			if not _clear(surface,at,at): return false
			if along!=-length and not _clear(surface,previous,at): return false
			previous = at
	return true

func _path_clear(surface, from: Vector3, to: Vector3) -> bool:
	if not _clear(surface,from,from): return false
	var steps = maxi(1,ceili(_horizontal(to-from).length()/PATH_STEP_M))
	var previous = from
	var previous_support = _sample(surface,from)
	for i in range(1,steps+1):
		var at = from.lerp(to,float(i)/steps)
		var support = _sample(surface,at)
		if support.normal.y<cos(deg_to_rad(MAX_SLOPE_DEGREES)): return false
		var delta = at-previous
		var projected: float = previous.y-(previous_support.normal.x*delta.x+previous_support.normal.z*delta.z)/maxf(previous_support.normal.y,.01)
		if absf(support.height-projected)>PATH_BREAK_M: return false
		at.y = support.height
		if not _clear(surface,previous,at): return false
		previous = at; previous_support = support
	return true

func _sample(surface, point: Vector3) -> Dictionary:
	height_queries += 1
	return surface.sample(point.x,point.z)

func _clear(surface, from: Vector3, to: Vector3) -> bool:
	obstacle_queries += 1
	return surface.sweep_obstacle(from,to).is_empty()

static func _horizontal(v: Vector3) -> Vector3:
	return Vector3(v.x,0,v.z)

static func _unavailable() -> Dictionary:
	return {"error":"No safe snow within 8 m of this crash. Try again from the start."}

static func restore_at_rest(sim, placement: Dictionary, surface) -> void:
	var peak: float = sim.peak_speed
	var air: float = sim.total_airtime
	var ticks: int = sim.ticks
	sim.reset(placement.position,placement.heading)
	sim.prime_contacts(surface)
	# Contact priming fits the body, but its settling integration may leave tiny
	# angular/vertical rates. The recovery boundary has exactly zero motion.
	sim.velocity = Vector3.ZERO
	sim.air_control.reset()
	sim.body.angular_momentum = Vector2.ZERO
	sim.body.roll_velocity = 0.0; sim.body.pitch_velocity = 0.0; sim.body.height_velocity = 0.0
	sim.peak_speed = peak; sim.total_airtime = air; sim.ticks = ticks
	sim.reset_pose_history()
