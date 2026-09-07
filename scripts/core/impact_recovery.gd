extends RefCounted
## An impact reserve, independent of steering balance and physical G readings.
## Rough contacts spend reserve by severity; smooth supported riding restores it.
var reserve: float = 1.0
var dizziness: float:
	get: return 1.0-reserve
var since_hit: float = 60.0
var last_speed: float = 0.0 # normal closing speed, m/s (includes landing alignment cost)
var last_reason: String = ""
var event_damage: float = 0.0

func reset() -> void:
	reserve = 1.0
	since_hit = 60.0
	last_speed = 0.0
	last_reason = ""
	event_damage = 0.0

func step(dt: float, supported: bool, tuning) -> void:
	since_hit = minf(60.0,since_hit+dt)
	if supported and since_hit>=tuning.impact_recovery_delay:
		reserve = minf(1.0,reserve+dt/maxf(tuning.impact_recovery_time,.1))
		if reserve>1.0-.000001: reserve = 1.0

func hit(speed: float, reference_speed: float, reason: String, tuning) -> bool:
	var severity: float = maxf(0.0,(speed/maxf(reference_speed,.01)-tuning.impact_soft_ratio)/maxf(.01,1.0-tuning.impact_soft_ratio))
	var damage: float = minf(tuning.impact_max_damage,severity*tuning.impact_reference_damage)
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
