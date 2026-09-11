extends "res://tests/skier_anatomy_suite.gd"
## Silhouette regression through the actual solver and final skeleton writer.
## Joint envelopes alone passed the earlier visually rejected tuck.
var tuck_cases = {}

func library_checks():
	super.library_checks()
	for request in [
		{"name":"upright","tuck":0.0}, {"name":"half_tuck","tuck":.5},
		{"name":"deep_tuck","tuck":1.0}, {"name":"release_return","tuck":1.0,"cycle":true},
		{"name":"full_stick_tuck","tuck":1.0,"turn":true},
		{"name":"tuck_prepare_hop","tuck":1.0,"hop":true},
		{"name":"switch_tuck","tuck":1.0,"switch":true}]:
		tuck_ride(request)
	check(tuck_cases.deep_tuck.pitch_mean_deg>tuck_cases.half_tuck.pitch_mean_deg+5.0 and tuck_cases.half_tuck.pitch_mean_deg>tuck_cases.upright.pitch_mean_deg+5.0,"Partial and full tuck progressively fold the torso forward")
	check(tuck_cases.deep_tuck.pitch_min_deg>80.0 and tuck_cases.deep_tuck.pitch_max_deg<108.0,"Held deep tuck retains a near-horizontal chest through complete source loops")
	check(tuck_cases.deep_tuck.hand_span_max_m<.58 and tuck_cases.deep_tuck.elbow_span_max_m<.49,"Deep tuck keeps gloves outside the thighs and elbows alongside the ribs")
	check(tuck_cases.deep_tuck.hand_span_min_m>.20,"Compact tuck retains room between the gloves")
	check(tuck_cases.deep_tuck.pitch_max_deg-tuck_cases.deep_tuck.pitch_min_deg>1.0,"The deep tuck retains time-varying source motion")
	DirAccess.make_dir_recursive_absolute("res://artifacts/deep_tuck")
	FileAccess.open("res://artifacts/deep_tuck/silhouette.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":tuck_cases,"failures":failures},"\t"))

func tuck_ride(request: Dictionary):
	var surface = TestPlane.new(.30)
	var sim = Sim.new(); var control = Sim.new()
	for model in [sim,control]:
		model.reset(Vector3.ZERO); model.prime_contacts(surface)
		model.velocity = model.support_basis().z*30.0
		if request.get("switch",false): model.facing_backward = true; model.facing_pose.capture(model,true)
	skier.animation.full_motion.enabled = true; skier.reset_animation(sim)
	var intent = MotionInput.new()
	var equal = true; var last = {}; var step_m = 0.0
	var row = {"pitch_min_deg":INF,"pitch_max_deg":-INF,"pitch_mean_deg":0.0,"hand_span_min_m":INF,"hand_span_max_m":0.0,"elbow_span_max_m":0.0,"samples":0}
	for tick in 720:
		intent.tuck = request.tuck
		if request.get("cycle",false): intent.tuck = 0.0 if tick<120 or (tick>=360 and tick<480) else 1.0
		intent.steer = (1.0 if tick%240<120 else -1.0) if request.get("turn",false) else 0.0
		intent.jump_held = request.get("hop",false) and tick>=300 and tick<336
		intent.jump = request.get("hop",false) and tick==336
		sim.step(DT,intent,surface); control.step(DT,intent,surface)
		skier.step_animation(DT,sim,intent,surface)
		equal = equal and Replay.snapshot(tick*DT,sim)==Replay.snapshot(tick*DT,control) and sim.body.joints==control.body.joints
		for alpha in [0.0,.5,1.0]: inspect(sim,alpha)
		var joints = skier.rendered_joints; var rotations = skier.rendered_rotations
		for id in last:
			var delta: float = joints[id].distance_to(last[id])
			if delta>step_m:
				step_m = delta
				row.peak_step = {"tick":tick,"bone":id,"delta_m":delta,"body_roll":sim.body.roll,"fitting":skier.animation.full_motion.diagnostics.duplicate(true)}
		last = joints.duplicate()
		if tick>=120:
			var forward: Vector3 = rotations.Spine*Vector3.UP
			var pitch = rad_to_deg(atan2(forward.z,forward.y))
			row.pitch_min_deg = minf(row.pitch_min_deg,pitch); row.pitch_max_deg = maxf(row.pitch_max_deg,pitch)
			row.pitch_mean_deg += pitch
			var span: float = (joints.LeftHand-joints.RightHand).dot(rotations.Spine.x)
			row.hand_span_min_m = minf(row.hand_span_min_m,span); row.hand_span_max_m = maxf(row.hand_span_max_m,span)
			row.elbow_span_max_m = maxf(row.elbow_span_max_m,(joints.LeftForeArm-joints.RightForeArm).dot(rotations.Spine.x))
			row.samples += 1
	row.pitch_mean_deg /= row.samples
	row.max_joint_step_m = step_m; row.physics_identical = equal; row.crash = sim.crash_reason
	tuck_cases[request.name] = row
	check(equal and not sim.crashed,request.name+": corrected pose preserves the physical run and replay")
	check(step_m<.08,request.name+": final joints remain continuous through tuck controls")
