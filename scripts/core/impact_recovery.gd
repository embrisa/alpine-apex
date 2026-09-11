extends RefCounted
## An impact reserve, independent of steering balance and physical G readings.
## Rough contacts spend reserve by severity; smooth supported riding restores it.
var reserve: float = 1.0
var dizziness: float:
	get: return 1.0-reserve
var since_hit: float = 60.0
var last_speed: float = 0.0 # measured normal closing speed, m/s; never absorption-scaled
var last_reason: String = ""
var event_damage: float = 0.0
var since_rock: float = 60.0 # Separate timer: abrasion must not group unrelated impacts.

func reset() -> void:
	reserve = 1.0
	since_hit = 60.0
	last_speed = 0.0
	last_reason = ""
	event_damage = 0.0
	since_rock = 60.0

func step(dt: float, supported: bool, tuning) -> void:
	since_hit = minf(60.0,since_hit+dt)
	since_rock = minf(60.0,since_rock+dt)
	if supported and minf(since_hit,since_rock)>=tuning.impact_recovery_delay:
		reserve = minf(1.0,reserve+dt/maxf(tuning.impact_recovery_time,.1))
		if reserve>1.0-.000001: reserve = 1.0

func abrade(dt: float, rate: float) -> bool:
	if rate<=0.0: return false
	since_rock = 0.0
	reserve = maxf(0.0,reserve-rate*dt)
	return reserve<=.000001

func hit(speed: float, reference_speed: float, reason: String, tuning) -> bool:
	return _apply_damage(_rough_damage(speed,reference_speed,tuning),speed,reason,tuning)

func landing_hit(normal_speed: float, alignment_cost: float, reference_speed: float, fit: float, reason: String, tuning) -> bool:
	var reference: float = maxf(reference_speed,.01)
	var rough: float = _rough_damage(normal_speed+alignment_cost,reference,tuning)
	var clean: float = tuning.landing_clean_damage_scale*tuning.impact_reference_damage*maxf(0.0,normal_speed-reference)/(reference*maxf(.01,1.0-tuning.impact_soft_ratio))
	clean = minf(tuning.impact_max_damage,clean)
	return _apply_damage(lerpf(rough,clean,clampf(fit,0.0,1.0)),normal_speed,reason,tuning)

func _rough_damage(speed: float, reference_speed: float, tuning) -> float:
	var severity: float = maxf(0.0,(speed/maxf(reference_speed,.01)-tuning.impact_soft_ratio)/maxf(.01,1.0-tuning.impact_soft_ratio))
	return minf(tuning.impact_max_damage,severity*tuning.impact_reference_damage)

func _apply_damage(damage: float, speed: float, reason: String, tuning) -> bool:
	if damage<=.000001: return false
	# One landing/ski pair or contact cluster spends its largest damage once.
	if since_hit<tuning.impact_contact_grace:
		reserve = maxf(0.0,reserve-maxf(0.0,damage-event_damage))
		event_damage = maxf(event_damage,damage)
		if speed>last_speed:
			last_speed = speed
			last_reason = reason
		return reserve<=.000001
	last_speed = speed
	last_reason = reason
	since_hit = 0.0
	event_damage = damage
	reserve = maxf(0.0,reserve-damage)
	return reserve<=.000001
