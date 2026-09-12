extends "res://tests/carve_direction_capture.gd"
## Matched small corrections and loaded turns, including opposing support edges.
const CASES = ["hold_05_left","hold_05_right","hold_10_left","hold_10_right","tap_10_left","tap_10_right","hold_20_right","hold_55_right","hold_100_left","hold_100_right","cross_10_right","mirror_10_left","reversal_55_right","tuck_10_right","tuck_55_left"]

func run():
	probe = true
	scenarios = CASES.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--scenarios="): scenarios=Array(arg.trim_prefix("--scenarios=").split(","))
	assert(not FileAccess.file_exists(output+"/manifest.json"),"Preserve existing captures")
	DirAccess.make_dir_recursive_absolute(output)
	report={"version":1,"created_utc":Time.get_datetime_string_from_system(true),"engine":Engine.get_version_info().string,"physics":Sim.MODEL_VERSION,"capture_fps":60,"simulation_hz":120,"frame_origin":0,"unranked":true,"sources":source_hashes(),"scenarios":[],"failures":[],"notes":["Analytic slope; no race session. Positive steer is rider right (-model X). Gravity/heading measurements preserve counterbank samples."]}
	scene=Node3D.new();root.add_child(scene)
	skier=Visual.new();skier.preview_only=true;scene.add_child(skier);await process_frame
	report.rig={"names":[],"parents":[],"rest":[]}
	for i in skier.skeleton.get_bone_count():
		report.rig.names.append(skier.skeleton.get_bone_name(i));report.rig.parents.append(skier.skeleton.get_bone_parent(i));report.rig.rest.append(pack(skier.rest[i]))
	for name in scenarios:
		assert(name in CASES)
		field=DirectionSlope.new()
		field.cross_gradient=.22 if name.begins_with("cross") else -.22 if name.begins_with("mirror") else 0.0
		await capture_sequence(name,{"origin":Vector3.ZERO,"heading":0.0,"cross_gradient":field.cross_gradient})
	report.sources_after=source_hashes();report.stable_sources=report.sources==report.sources_after
	if not report.stable_sources:report.failures.append("Production source changed during capture")
	FileAccess.open(output+"/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CARVE_PROPORTIONAL_CAPTURE ",output," failures=",report.failures)
	scene.queue_free();await process_frame;quit(0 if report.failures.is_empty() else 1)

func source_hashes() -> Dictionary:
	var hashes=super.source_hashes()
	hashes["res://tests/carve_proportional_capture.gd"]=FileAccess.get_sha256("res://tests/carve_proportional_capture.gd")
	return hashes

func frame_count(_name: String) -> int:return 210

func intent_at(name: String,tick: int):
	return test_intent(name,tick)

static func test_intent(name: String,tick: int):
	var input=RiderInput.new()
	var parts=name.split("_")
	var magnitude=float(parts[1])/100.0
	if name.begins_with("tuck"):input.tuck=1.0
	if tick>=60 and tick<(72 if name.begins_with("tap") else 240):
		input.steer=(-1.0 if name.ends_with("left") else 1.0)*magnitude
		if name.begins_with("reversal") and tick>=150:input.steer*=-1.0
	return input
