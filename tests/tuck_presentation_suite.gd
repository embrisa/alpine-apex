extends SceneTree
## Regression for initial/resumed tuck through completed physics and final fitting.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const TestSlope = preload("res://tests/physics_suite.gd").TestPlane
const Lab = preload("res://scripts/world/test_slope.gd")
const Replay = preload("res://scripts/racing/run_replay.gd")
const DT = 1.0/120.0
var output = "res://artifacts/tuck_consistency/suite.json"
var motion_script = ""
var checks = 0
var failures: Array = []
var cases: Array = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
	print("PASS: " if ok else "FAIL: ",message)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--motion-script="): motion_script = arg.trim_prefix("--motion-script=")
	var visual = Visual.new(); visual.preview_only = true
	if not motion_script.is_empty(): visual.animation.full_motion = load(motion_script).new()
	root.add_child(visual); await process_frame
	for spec in [{"name":"lab","speed":65.0/3.6,"slope":0.0},
		{"name":"shallow_slow","speed":12.0,"slope":.18},
		{"name":"shallow_fast","speed":30.0,"slope":.18},
		{"name":"medium","speed":25.0,"slope":.30},
		{"name":"steep","speed":25.0,"slope":.46}]:
		var surface = Lab.new() if spec.name=="lab" else TestSlope.new(spec.slope)
		var sim = Sim.new(); var control = Sim.new()
		for model in [sim,control]:
			model.reset(surface.spawn_point() if spec.name=="lab" else Vector3.ZERO)
			if spec.name=="lab": model.surface_normal = surface.contact_normal(model.position.x,model.position.z)
			model.prime_contacts(surface)
			# Match start_speed_lab: launch down the sampled fall line, which can
			# differ slightly from the rider heading and leave a small loaded edge.
			var direction: Vector3 = Vector3.DOWN.slide(surface.sample(model.position.x,model.position.z).normal).normalized() if spec.name=="lab" else model.support_basis().z
			model.velocity = direction*spec.speed
			model.reset_pose_history()
		visual.reset_animation(sim)
		var equal = true; var last = {}; var max_step = 0.0
		var initial: Array = []; var resumed: Array = []; var released = {}
		for tick in 840:
			var intent = RiderInput.new()
			if tick>=16 and tick<720: intent.tuck = 1.0
			if tick>=196 and tick<256:
				intent.steer = .667159080505371; intent.tuck = intent.steer
			sim.step(DT,intent,surface); control.step(DT,intent,surface)
			visual.step_animation(DT,sim,intent,surface); visual.pose(sim,1.0)
			equal = equal and Replay.snapshot(tick*DT,sim)==Replay.snapshot(tick*DT,control) and sim.body.joints==control.body.joints
			var j = visual.rendered_joints; var r = visual.rendered_rotations
			for bone in last: max_step = maxf(max_step,j[bone].distance_to(last[bone]))
			last = j.duplicate()
			var up: Vector3 = (r.LeftFoot.y+r.RightFoot.y).normalized()
			var forward: Vector3 = (r.LeftFoot.z+r.RightFoot.z).slide(up).normalized()
			var row = {"tick":tick+1,"tuck":sim.effective_tuck,"hip":(j.Hips-(j.LeftFoot+j.RightFoot)*.5).dot(up),
				"pitch":rad_to_deg(atan2(r.Spine.y.dot(forward),r.Spine.y.dot(up))),
				"downhill":visual.animation.full_motion.downhill_amount,"grounded":sim.grounded}
			if tick>=176 and tick<196: initial.append(row)
			if tick>=700 and tick<720: resumed.append(row)
			if tick==839: released = row
		var a = average(initial); var b = average(resumed)
		check(equal and not sim.crashed,spec.name+": presentation preserves the complete physical run")
		check(max_step<.08,spec.name+": entry, turn, resumption and release remain continuous")
		check(a.tuck>.98 and b.tuck>.98,spec.name+": comparison actually reaches full solver tuck")
		check(a.hip<.60 and a.pitch>55.0,spec.name+": initial held tuck visibly compresses")
		# This fixture allows 3.8 s after steering for the physical path to settle.
		# Do not gate the regression on the very animation weight being tested.
		check(absf(a.hip-b.hip)<.06 and absf(a.pitch-b.pitch)<8.0,spec.name+": settled straight tuck has no entry-history mismatch")
		check(released.tuck<.001 and released.hip>a.hip+.10,spec.name+": release restores the ready stance")
		cases.append({"spec":spec,"initial":a,"resumed":b,"released":released,"max_joint_step_m":max_step,"physics_equal":equal})
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	preload("res://tests/test_report.gd").write(output,JSON.stringify({"checks":checks,"failures":failures,"cases":cases},"\t"))
	print("TUCK_PRESENTATION_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	visual.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)

func average(rows: Array) -> Dictionary:
	var result = {"tuck":0.0,"hip":0.0,"pitch":0.0,"downhill":0.0}
	for row in rows:
		for key in result: result[key] += row[key]/rows.size()
	return result
