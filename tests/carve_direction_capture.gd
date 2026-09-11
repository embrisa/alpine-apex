extends "res://tests/pose_reference_capture.gd"
## Reproduce steering entry against an existing cross-slope bank without choosing
## terrain by its agreement with input. Uses the production solver and pose writer.
const DIRECTION_CASES = ["flat_left","flat_right","cross_left","cross_right","cross_mirror_left","cross_mirror_right","reversal","taps","tuck_turn"]

class DirectionSlope:
	extends RefCounted
	var cross_gradient = 0.0
	func sample(x: float, z: float) -> Dictionary:
		return {"height":x*cross_gradient-z*.30,"normal":Vector3(-cross_gradient,1,.30).normalized()}
	func sweep_obstacle(_a: Vector3, _b: Vector3) -> String: return ""

func run():
	probe = true
	scenarios = DIRECTION_CASES.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--scenarios="): scenarios = Array(arg.trim_prefix("--scenarios=").split(","))
	for name in scenarios: assert(name in DIRECTION_CASES,"Unknown direction case")
	if FileAccess.file_exists(output+"/manifest.json"):
		push_error("Capture exists; choose a new revision."); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	report = {"version":1,"created_utc":Time.get_datetime_string_from_system(true),"engine":Engine.get_version_info().string,
		"physics":Sim.MODEL_VERSION,"capture_fps":60,"simulation_hz":120,"frame_origin":0,"unranked":true,
		"scope":"Production solver and final pose on analytic planar and mirrored cross-slope fixtures; no race session.",
		"sources":source_hashes(),"scenarios":[],"failures":[],"notes":["Input starts after 0.5 s of unsteered support settling.","Cross-slope fixtures deliberately retain counterbank; no pose-based selection."]}
	scene = Node3D.new(); root.add_child(scene)
	skier = Visual.new(); skier.preview_only = true; scene.add_child(skier); await process_frame
	report.rig = {"names":[],"parents":[],"rest":[]}
	for i in skier.skeleton.get_bone_count():
		report.rig.names.append(skier.skeleton.get_bone_name(i))
		report.rig.parents.append(skier.skeleton.get_bone_parent(i))
		report.rig.rest.append(pack(skier.rest[i]))
	for name in scenarios:
		field = DirectionSlope.new()
		field.cross_gradient = (-.22 if name.begins_with("cross_mirror") else .22) if name.begins_with("cross") else 0.0
		await capture_sequence(name,{"origin":Vector3.ZERO,"heading":0.0,"cross_gradient":field.cross_gradient})
	report.sources_after = source_hashes()
	report.stable_sources = report.sources==report.sources_after
	if not report.stable_sources: report.failures.append("Production source changed during capture")
	FileAccess.open(output+"/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CARVE_DIRECTION_CAPTURE ",output," failures=",report.failures)
	scene.queue_free(); await process_frame; quit(0 if report.failures.is_empty() else 1)

func source_hashes() -> Dictionary:
	var hashes = super.source_hashes()
	hashes["res://tests/carve_direction_capture.gd"] = FileAccess.get_sha256("res://tests/carve_direction_capture.gd")
	return hashes

func reset_sim(_name: String, fixture: Dictionary):
	var sim = Sim.new(); sim.reset(fixture.origin,fixture.heading); sim.prime_contacts(field)
	sim.velocity = sim.support_basis().z*25.0; sim.reset_pose_history()
	return sim

func frame_count(_name: String) -> int: return 210

func intent_at(name: String, tick: int):
	var input = RiderInput.new()
	if name=="tuck_turn": input.tuck = 1.0
	if tick<60 or tick>=330: return input
	input.steer = -.55 if name.ends_with("left") else .55
	if name=="reversal": input.steer = .55 if tick<180 else -.55
	if name=="taps": input.steer = .8 if int((tick-60)/12)%2==0 else -.8
	return input
