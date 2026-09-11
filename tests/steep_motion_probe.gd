extends SceneTree
const Sim = preload("res://scripts/core/ski_simulation.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const DT = 1.0/120.0
func _initialize(): call_deferred("run")
func run():
	var skier = preload("res://scripts/presentation/skier_visual.gd").new()
	root.add_child(skier)
	await process_frame
	var full_motion = skier.animation.full_motion
	for clip in ["NAV_MED_FWD","NAV_MED_LEFT","NAV_FAST_FWD_SPEED","NAV_OLLIE_FWD","AIR_LONG","GRAB_SAFETY","GRAB_MUTE","NAV_MED_TURNS_SWITCH"]:
		var p = full_motion.sample_clip(clip,full_motion.duration(clip)*.5)
		full_motion.current = p.q; full_motion.previous = p.q; full_motion.root_position = p.root; full_motion.previous_root = p.root
		var pose = full_motion.sample(1.0)
		print("SOURCE ",clip," pelvis ",p.root," pitch/bank ",pose.rotations.Hips.get_euler()," chest ",pose.rotations.Spine.get_euler()," hands ",pose.joints.LeftHand," ",pose.joints.RightHand)
	var surface = TestPlane.new(.46)
	var sim = Sim.new(); sim.reset(Vector3.ZERO); sim.prime_contacts(surface)
	skier.reset_animation(sim)
	var intent = RiderInput.new(); intent.tuck = 1.0
	sim.velocity = Vector3.BACK.slide(sim.surface_normal).normalized()*20.0
	for tick in 240:
		sim.step(DT,intent,surface); skier.step_animation(DT,sim,intent,surface)
	skier.pose(sim)
	var last: Dictionary = skier.rendered_joints.duplicate()
	var max_step = 0.0
	for tick in 480:
		intent.steer = .85 if tick%160<80 else -.85
		intent.tuck = .5; intent.jump_held = tick>400
		sim.step(DT,intent,surface); skier.step_animation(DT,sim,intent,surface)
		skier.pose(sim)
		var worst = 0.0; var joint = ""
		for id in skier.rendered_joints:
			var error: float = skier.rendered_joints[id].distance_to(last[id])
			if error>worst: worst = error; joint = id
		if worst>.07:
			print("STEP ",tick," ",joint," ",worst," ground ",sim.grounded," ",full_motion.diagnostics," hips ",skier.rendered_joints.Hips," root ",full_motion.root_position)
		max_step = maxf(max_step,worst)
		last = skier.rendered_joints.duplicate()
	print("MAX_STEP ",max_step)
	skier.queue_free(); await process_frame; quit()
