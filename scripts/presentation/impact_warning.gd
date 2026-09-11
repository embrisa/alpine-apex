extends RefCounted
## Render-only reserve warning. Receives a value, never a simulation reference.
const ONSET = 0.7
const ATTACK_SECONDS = 0.45
const RECOVERY_SECONDS = 1.0
const PULSE_MIN_HZ = 0.5
const PULSE_MAX_HZ = 0.9
var strength: float = 0.0
var phase: float = 0.0 # cycles, integrated rather than multiplied by changing frequency
var pulse: float = 0.65

func reset() -> void:
	strength = 0.0
	phase = 0.0
	pulse = 0.65

func update(reserve: float, dt: float, pulsing: bool = true) -> void:
	if not is_finite(reserve) or not is_finite(dt):
		reset()
		return
	dt = maxf(0.0,dt)
	var target: float = pow(clampf((ONSET-reserve)/ONSET,0.0,1.0),1.8)
	var previous: float = strength
	var response: float = ATTACK_SECONDS if target>strength else RECOVERY_SECONDS
	var decay: float = exp(-dt/response)
	strength = target+(previous-target)*decay
	if target==0.0 and strength<0.0001:
		reset()
		return
	if pulsing:
		# Exact integral of the slower 0.5-0.9 Hz pulse, including its ramp.
		var frequency_range: float = PULSE_MAX_HZ-PULSE_MIN_HZ
		phase = fposmod(phase+dt*(PULSE_MIN_HZ+frequency_range*target)+frequency_range*(previous-target)*response*(1.0-decay),1.0)
		pulse = 0.65-0.35*cos(TAU*phase)
	else:
		phase = 0.0
		pulse = 0.65
