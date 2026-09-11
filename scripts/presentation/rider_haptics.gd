extends RefCounted
## Contact observation at 120 Hz; finite presentation envelopes, no device calls.
const Events = preload("res://scripts/presentation/riding_audio_events.gd")
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
		if event.kind in [Events.Kind.LANDING,Events.Kind.IMPACT] and event.speed>=1.0:
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
	if pending_impact>=1.0:
		var severity = clampf((pending_impact-1.0)/9.0,0.0,1.0)
		var motors = Vector2(lerpf(.16,.45,severity),lerpf(.05,.80,severity))
		var duration = lerpf(.060,.180,severity)
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
