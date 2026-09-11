extends "res://tests/carve_direction_capture.gd"
## Final-pose entry on a steep fall line: slope-relative clip checks miss the
## apparent counterlean when terrain up turns sideways in the rider's frame.
const ENTRY_CASES = ["steep_left","steep_right","tucked_left","tucked_right"]
class EntrySlope:
	extends RefCounted
	func sample(_x: float,z: float) -> Dictionary:
		return {"height":-.7*z,"normal":Vector3(0,1,.7).normalized()}
	func sweep_obstacle(_a: Vector3,_b: Vector3) -> String: return ""

func run():
	probe = true
	scenarios = ENTRY_CASES.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--scenarios="): scenarios=Array(arg.trim_prefix("--scenarios=").split(","))
	assert(not FileAccess.file_exists(output+"/manifest.json"),"Preserve existing captures")
	DirAccess.make_dir_recursive_absolute(output)
	report={"version":1,"created_utc":Time.get_datetime_string_from_system(true),"engine":Engine.get_version_info().string,"physics":Sim.MODEL_VERSION,"capture_fps":60,"simulation_hz":120,"frame_origin":0,"unranked":true,"sources":source_hashes(),"scenarios":[],"failures":[],"notes":["35 degree fall line, 25 m/s start, steering from straight at 0.5 s; hard and gradual tucked entry in both directions."]}
	scene=Node3D.new();root.add_child(scene)
	skier=Visual.new();skier.preview_only=true;scene.add_child(skier);await process_frame
	report.rig={"names":[],"parents":[],"rest":[]}
	for i in skier.skeleton.get_bone_count():
		report.rig.names.append(skier.skeleton.get_bone_name(i));report.rig.parents.append(skier.skeleton.get_bone_parent(i));report.rig.rest.append(pack(skier.rest[i]))
	for name in scenarios:
		assert(name in ENTRY_CASES)
		field=EntrySlope.new()
		await capture_sequence(name,{"origin":Vector3.ZERO,"heading":0.0,"grade":.7})
	report.sources_after=source_hashes();report.stable_sources=report.sources==report.sources_after
	if not report.stable_sources:report.failures.append("Production source changed during capture")
	FileAccess.open(output+"/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CARVE_ENTRY_CAPTURE ",output," failures=",report.failures)
	scene.queue_free();await process_frame;quit(0 if report.failures.is_empty() else 1)

func source_hashes() -> Dictionary:
	var hashes=super.source_hashes()
	hashes["res://tests/carve_entry_capture.gd"]=FileAccess.get_sha256("res://tests/carve_entry_capture.gd")
	return hashes

func frame_count(_name: String) -> int:return 180

func intent_at(name: String,tick: int):
	var input=RiderInput.new()
	if name.begins_with("tucked"):input.tuck=1.0
	if tick>=60 and tick<270:
		input.steer=(-1.0 if name.ends_with("left") else 1.0)*(minf((tick-59)/60.0,1.0)*.55 if name.begins_with("tucked") else 1.0)
	return input
