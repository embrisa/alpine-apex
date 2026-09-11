extends RefCounted
## Completed-tick observer. No Nodes, RNG, terrain queries or simulation writes.
var airborne_seconds: float = 0.0
var air_announced: bool = false
var flight_spoken: bool = false
var previous_reserve: float = 1.0
var landing_wait: float = -1.0
var landing_damage: float = 0.0
var major_landing: bool = false
var breathing: bool = false
var low_seconds: float = 0.0
var injured_announced: bool = false
var high_seconds: float = 0.0
var extreme_seconds: float = 0.0
var speed_reset_seconds: float = 0.0
var high_announced: bool = false
var extreme_announced: bool = false
var candidates: Array[String] = []

func reset(reserve: float = 1.0) -> void:
	airborne_seconds = 0.0
	air_announced = false
	flight_spoken = false
	previous_reserve = reserve
	landing_wait = -1.0
	landing_damage = 0.0
	major_landing = false
	breathing = false
	low_seconds = 0.0
	injured_announced = false
	high_seconds = 0.0
	extreme_seconds = 0.0
	speed_reset_seconds = 0.0
	high_announced = false
	extreme_announced = false
	candidates.clear()

func mark_spoken() -> void:
	if airborne_seconds > 0.0 or landing_wait >= 0.0: flight_spoken = true

func sample(sim, dt: float) -> String:
	var found = sample_candidates(sim,dt)
	return found[0] if not found.is_empty() else ""

func sample_candidates(sim, dt: float) -> Array[String]:
	candidates.clear()
	var damage: float = maxf(0.0,previous_reserve-sim.impacts.reserve)
	previous_reserve = sim.impacts.reserve
	if sim.crashed:
		breathing = false
		landing_wait = -1.0
		return candidates
	if sim.impacts.reserve <= 0.23:
		breathing = true
		low_seconds += dt
	else: low_seconds = 0.0
	if sim.impacts.reserve >= 0.42:
		breathing = false
		injured_announced = false
	if low_seconds >= 6.0 and not injured_announced:
		injured_announced = true
		candidates.append("injured")
	if not sim.grounded:
		if airborne_seconds == 0.0:
			flight_spoken = false
			air_announced = false
		landing_wait = -1.0
		airborne_seconds += dt
		if airborne_seconds >= 3.0 and sim.velocity.length() >= 18.0 and not air_announced:
			air_announced = true
			if not flight_spoken:
				var huge: bool = sim.predicted_landing_time >= 0.0 and airborne_seconds+sim.predicted_landing_time >= 6.0
				candidates.push_front("air_huge" if huge else "big_air")
	else:
		if airborne_seconds > 0.0:
			major_landing = airborne_seconds >= 3.0
			if airborne_seconds >= 1.5:
				landing_wait = 0.24
				landing_damage = 0.0
			airborne_seconds = 0.0
			air_announced = false
		if landing_wait >= 0.0:
			landing_damage += damage
			landing_wait -= dt
			if landing_wait <= 0.0:
				landing_wait = -1.0
				if not flight_spoken:
					if landing_damage >= (0.10 if major_landing else 0.25): candidates.push_front("landing_bad")
					elif major_landing: candidates.push_front("land_big")
			damage = 0.0 # Classify landing damage once, never as a second impact.
	if damage >= 0.35: candidates.push_front("impact")
	elif damage >= 0.15: candidates.push_front("impact_small")
	var kmh: float = sim.velocity.length()*3.6
	high_seconds = high_seconds+dt if kmh >= 180.0 else 0.0
	extreme_seconds = extreme_seconds+dt if kmh >= 220.0 else 0.0
	speed_reset_seconds = speed_reset_seconds+dt if kmh < 150.0 else 0.0
	if speed_reset_seconds >= 10.0:
		high_announced = false
		extreme_announced = false
	if extreme_seconds >= 5.0 and not extreme_announced:
		extreme_announced = true
		high_announced = true
		candidates.append("speed_extreme")
	elif high_seconds >= 8.0 and not high_announced:
		high_announced = true
		candidates.append("speed_high")
	return candidates

static func finish_event(session) -> String:
	if not session.finished or not session.eligible or not session.save_error.is_empty(): return ""
	if session.new_best: return "personal_best"
	if session.previous_best <= 0.0 or not is_finite(session.previous_best): return "finish"
	var ratio: float = session.elapsed/session.previous_best
	if ratio <= 1.03: return "finish_good"
	if ratio >= 1.10: return "finish_bad"
	return "finish"
