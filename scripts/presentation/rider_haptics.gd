extends RefCounted
## Contact observation at 120 Hz; finite presentation envelopes, no device calls.
const Events = preload("res://scripts/presentation/riding_audio_events.gd")
const IMPACT_THRESHOLD_MPS = 3.5
const IMPACT_FULL_MPS = 14.0
const ROCK_DURATION = .030
const ROCK_INTERVAL = .450
var observer = Events.new()
var last_tick = -1
var pending_impact = 0.0
var rock_contact = 0.0
var impact_remaining = 0.0
var impact_age = 0.0
var impact_motors = Vector2.ZERO
var rock_remaining = 0.0
var rock_cooldown = 0.0
var pulse_id = 0

func reset() -> void:
	observer.reset()
	last_tick = -1
	pending_impact = 0.0
	rock_contact = 0.0
	impact_remaining = 0.0
	impact_age = 0.0
	impact_motors = Vector2.ZERO
	rock_remaining = 0.0
	rock_cooldown = 0.0

func observe_tick(sim, dt: float) -> void:
	if sim.ticks==last_tick: return
	if sim.ticks<last_tick: reset()
	last_tick = sim.ticks
	rock_contact = clampf(sim.rock_contact,0.0,1.0) if sim.grounded and sim.normal_load>0.0 and not sim.crashed and sim.velocity.length()>2.0 else 0.0
	for event in observer.sample(sim,dt):
		if event.kind in [Events.Kind.LANDING,Events.Kind.IMPACT] and event.speed>=IMPACT_THRESHOLD_MPS:
			pending_impact = maxf(pending_impact,event.speed)
	if sim.tuning.vibration_intensity<=0.0:
		pending_impact = 0.0
		rock_contact = 0.0

func advance(dt: float, riding: bool, crash_visible: bool, intensity: float) -> Vector3:
	# x/y: weak/strong motors, z: remaining seconds. Age existing pulses before
	# starting queued onsets so a 30 ms tap survives a slow rendering frame.
	if (not riding and not crash_visible) or not is_finite(intensity) or intensity<=0.0:
		reset()
		return Vector3.ZERO
	dt = maxf(0.0,dt)
	impact_age += dt
	impact_remaining = maxf(0.0,impact_remaining-dt)
	rock_remaining = maxf(0.0,rock_remaining-dt)
	rock_cooldown = maxf(0.0,rock_cooldown-dt)
	if pending_impact>=IMPACT_THRESHOLD_MPS:
		# Normal closing speed measures the physical contact, not travel speed
		# or reserve damage. Squared speed weights impact energy so marginal
		# landings stay faint and heavier hits have room to grow before the cap.
		var speed = minf(pending_impact,IMPACT_FULL_MPS)
		var severity = inverse_lerp(IMPACT_THRESHOLD_MPS*IMPACT_THRESHOLD_MPS,IMPACT_FULL_MPS*IMPACT_FULL_MPS,speed*speed)
		var motors = Vector2(lerpf(.08,.55,severity),lerpf(.02,1.0,severity))
		var duration = lerpf(.045,.180,severity)
		if impact_remaining<=0.0:
			impact_age = 0.0
			impact_motors = motors
		else:
			impact_motors = Vector2(maxf(impact_motors.x,motors.x),maxf(impact_motors.y,motors.y))
		# One overlapping cluster may grow stronger, never extend past 180 ms.
		impact_remaining = maxf(impact_remaining,duration-impact_age)
		pending_impact = 0.0
		rock_remaining = 0.0
		pulse_id += 1
	if not riding or rock_contact<=0.0: rock_remaining = 0.0
	var strength = clampf(intensity,0.0,1.0)
	if impact_remaining>0.0:
		return Vector3(impact_motors.x*strength,impact_motors.y*strength,impact_remaining)
	if riding and rock_contact>0.0 and rock_cooldown<=0.0:
		rock_remaining = ROCK_DURATION
		rock_cooldown = ROCK_INTERVAL
		pulse_id += 1
	if rock_remaining>0.0:
		return Vector3(.12*rock_contact*strength,0.0,rock_remaining)
	return Vector3.ZERO
