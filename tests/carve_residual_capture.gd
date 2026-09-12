extends "res://tests/carve_direction_capture.gd"
## Frozen production pose chronology for the residual-bank regression and neighbors.
const CASES = ["reversal25_left","reversal25_right","reversal40_left","reversal40_right","mild25_left","mild40_right","strong25_left","strong40_right","tuck25_left","tuck40_right","hop25_left","hop40_right","weak25_left","weak40_right"]
func capture_cases() -> Array:return CASES.duplicate()
func reset_sim(name: String,fixture: Dictionary):
	var sim=Sim.new();sim.reset(fixture.origin);sim.prime_contacts(field)
	sim.velocity=sim.support_basis().z*(40.0 if "40" in name else 25.0);sim.reset_pose_history()
	return sim
func frame_count(name: String) -> int:return capture_frames(name)
static func capture_frames(name: String) -> int:return 420 if name.begins_with("hop") else 330
func intent_at(name: String,tick: int):return test_intent(name,tick)
static func test_intent(name: String,tick: int):
	var input=RiderInput.new()
	if name.begins_with("tuck"):input.tuck=1.0
	if tick>=240 and tick<420:
		input.steer=(-1.0 if name.ends_with("left") else 1.0)*(.1 if name.begins_with("mild") or name.begins_with("tuck") else 1.0 if name.begins_with("strong") else .55)
		if (name.begins_with("reversal") or name.begins_with("weak")) and tick>=330:input.steer*=-1
	if name.begins_with("weak") and tick>=420:
		input.steer=(1.0 if name.ends_with("left") else -1.0)*.1
	if name.begins_with("hop"):
		input.jump_held=tick>=450 and tick<480
		input.jump=tick==480
	return input

func source_hashes() -> Dictionary:
	var hashes=super.source_hashes()
	hashes["res://tests/carve_residual_capture.gd"]=FileAccess.get_sha256("res://tests/carve_residual_capture.gd")
	return hashes

func capture_sequence(name: String,fixture: Dictionary):
	report.notes=["240 unsteered warm-up ticks at 120 Hz before measured input.","Reversal: 90 ticks at 55 percent, 90 opposite, then release. Gravity/heading views retain bank.","Final bones and equipment come from production composition; no session or personal records."]
	fixture.initial_speed_m_s=40.0 if "40" in name else 25.0
	fixture.warmup_ticks=240
	await super.capture_sequence(name,fixture)
