extends SceneTree
## Mechanical final-pose/replay checks. Native capture + clothing audit still required.
const Fixtures = preload("res://tests/pole_push_suite.gd")
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const Replay = preload("res://scripts/racing/run_replay.gd")
const GhostPose = preload("res://scripts/presentation/ghost_pose.gd")
const DT = 1.0/120.0
var checks = 0
var failures: Array = []
var cases: Array = []
var output = "res://artifacts/orchestration_20260912/poles/validation/pose.json"

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var visual = Visual.new(); visual.preview_only = true; root.add_child(visual); await process_frame
	for degrees in [0.0,10.0,28.0,34.0]:
		var surface = Fixtures.SlopePlane.new(degrees)
		var sim = Fixtures.make_sim(surface); var control = Fixtures.make_sim(surface)
		visual.reset_animation(sim); visual.pose(sim,1)
		var replay = Replay.new(); var key = Replay.key("pole-pose-%s"%degrees)
		replay.begin(sim,key); replay.capture_presentation(0,GhostPose.capture(visual,sim,surface))
		var last = {}; var step_max = 0.0; var grip_error = 0.0; var tip_gap = 0.0
		var wrist_front = -INF; var wrist_back = INF; var equal = true; var phase_equal = true
		var count = 0; var timing_us = 0
		for tick in 720:
			var intent = RiderInput.new(); intent.tuck = 1.0 if tick<600 else 0.0
			sim.step(DT,intent,surface); control.step(DT,intent,surface)
			var started = Time.get_ticks_usec()
			visual.step_animation(DT,sim,intent,surface)
			timing_us += Time.get_ticks_usec()-started
			phase_equal = phase_equal and visual.animation.full_motion.pole_phase==sim.pole_push_phase
			replay.record(DT,(tick+1)*DT,sim,intent,1.0 if tick==719 else -1.0)
			if tick%2==0 and tick!=719: continue
			started = Time.get_ticks_usec(); visual.pose(sim,1.0); timing_us += Time.get_ticks_usec()-started
			equal = equal and sim.position==control.position and sim.velocity==control.velocity and sim.body.joints==control.body.joints
			if replay.wants_presentation_sample(): replay.capture_presentation((tick+1)*DT,GhostPose.capture(visual,sim,surface))
			var j = visual.rendered_joints; var r = visual.rendered_rotations
			for name in last: step_max = maxf(step_max,j[name].distance_to(last[name]))
			last = j.duplicate()
			for i in 2:
				var prefix = "Right" if i==0 else "Left"
				var expected: Vector3 = visual.to_global(j[prefix+"Hand"]+r[prefix+"Hand"]*Vector3(-.070 if i==0 else .070,0,.018))
				grip_error = maxf(grip_error,expected.distance_to(visual.poles[i].global_position))
			var diagnostic = visual.animation.full_motion.diagnostics
			for gap in diagnostic.get("tip_gap_m",[]): tip_gap = maxf(tip_gap,gap)
			if sim.pole_push_intensity>.5 and tick>120:
				var z: float = (j.RightHand-j.RightArm).z
				wrist_front = maxf(wrist_front,z); wrist_back = minf(wrist_back,z); count += 1
		check(equal,"%s degrees: full animation leaves physics unchanged"%degrees)
		check(phase_equal,"%s degrees: action samples completed actuator phase"%degrees)
		check(grip_error<.0001,"%s degrees: rigid poles remain in fixed glove sockets"%degrees)
		check(count>10 and wrist_front-wrist_back>.12,"%s degrees: final fitting retains a visible backward arm stroke"%degrees)
		check(step_max<.14,"%s degrees: final joint entry/cycle/release has no large step"%degrees)
		var frozen: Array = visual.animation.full_motion.current.duplicate()
		var position: Vector3 = sim.position; var phase: float = sim.pole_push_phase
		visual.animation.hold()
		for frame in 8: visual.pose(sim,float(frame)/7.0)
		check(frozen==visual.animation.full_motion.current and visual.animation.full_motion.previous==frozen and sim.position==position and sim.pole_push_phase==phase,"%s degrees: paused presentation collapses interpolation without advancing the stroke"%degrees)
		var restored = Replay.decode(replay.to_data(),key,6.0)
		check(restored!=null,"%s degrees: final production pose and pole inputs roundtrip"%degrees)
		if restored!=null:
			check(restored.presentation.size()==replay.presentation.size() and restored.presentation[-1]==replay.presentation[-1],"%s degrees: archived equipment and skeleton bytes survive"%degrees)
			var wraps = 0; var wrap_ok = true
			for i in range(1,restored.samples.size()):
				var before: float = restored.samples[i-1][Replay.POLE_START]
				var after: float = restored.samples[i][Replay.POLE_START]
				if before>.9 and after<.1:
					var mid: float = restored.pose_at((restored.sample_times[i-1]+restored.sample_times[i])*.5).pole_push_phase
					wraps += 1; wrap_ok = wrap_ok and (mid>.85 or mid<.15)
			check(wraps>0 and wrap_ok,"%s degrees: replay wraps phase across the seam without a spurious half-stroke"%degrees)
		cases.append({"degrees":degrees,"final_wrist_sweep_m":wrist_front-wrist_back,"max_joint_step_m":step_max,
			"max_grip_error_m":grip_error,"max_tip_anchor_gap_m":tip_gap,"step_and_fit_cpu_us":timing_us,
			"tip_contact_accepted":false,"note":"Tip residual is a visible review finding, not force eligibility or clothing clearance."})
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases,"scope":"Mechanical headless pose/replay; no rendered or human acceptance"},"\t"))
	print("POLE_POSE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"output":output}))
	visual.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
