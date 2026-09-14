extends RefCounted
## Presentation time only. Readiness always wins over the reveal timeline.
const LEGIBLE_SECONDS = 0.45
const REVEAL_SECONDS = 1.85
const FADE_SECONDS = 0.28
var elapsed: float = 0.0
var fading: bool = false
var fade_elapsed: float = 0.0
var finished: bool = false
var skipped: bool = false
var reduced_motion: bool = false

func advance(delta: float, destination_ready: bool, menu_ready: bool = false) -> void:
	if finished: return
	var dt = maxf(0.0,delta)
	elapsed += dt
	if not fading and destination_ready and (menu_ready or skipped or elapsed >= REVEAL_SECONDS):
		fading = true
		return # Time before the transition must never count as time spent dissolving.
	if fading:
		fade_elapsed += dt
		finished = fade_elapsed >= FADE_SECONDS

func skip(event: InputEvent) -> bool:
	if fading or finished or elapsed < LEGIBLE_SECONDS: return false
	var deliberate = event is InputEventKey and event.pressed and not event.echo
	deliberate = deliberate or event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]
	deliberate = deliberate or event is InputEventJoypadButton and event.pressed
	if not deliberate: return false
	skipped = true
	return true

func opacity() -> float:
	return 1.0-smoothstep(0.0,FADE_SECONDS,fade_elapsed)

func motion_time() -> float:
	return 0.0 if reduced_motion else minf(elapsed,REVEAL_SECONDS)
