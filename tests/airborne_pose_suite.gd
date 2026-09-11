extends SceneTree
const Sim = preload("res://scripts/core/ski_simulation.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const DT = 1.0/120.0
var skier
var failures: Array = []
var checks = 0
var local_joint_step_m = 0.0
var metrics = {"boot_gap_m":0.0,"limb_error_m":0.0,"spine_error_m":0.0,"joint_step_m":0.0,"cuff_side_deg":0.0,"cuff_flex_deg":0.0,"torso_up_min":1.0,"chest_up_min":1.0,"neck_angle_deg":0.0,"switches":0}
func _initialize(): call_deferred("run")
func check(ok,label):
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run():
	skier = preload("res://scripts/presentation/skier_visual.gd").new()
	root.add_child(skier)
	await process_frame
	var surface = TestPlane.new(.46)
	for reverse in [false,true]:
		var sim = Sim.new()
		sim.reset(Vector3(0,1000,0))
		sim.prime_contacts(surface)
		sim.velocity = Vector3(0,0,12)
		sim.grounded = false
		sim.facing_backward = reverse
		sim.facing_pose.capture(sim,true)
		sim.body.roll_velocity = 2.0
		sim.body.pitch_velocity = 1.0
		skier.reset_animation(sim)
		var intent = RiderInput.new()
		var previous: Dictionary = {}
		var previous_frame = Basis.IDENTITY
		for tick in 1200:
			var before_facing: bool = sim.facing_backward
			intent.steer = 1.0 if tick<720 else -1.0
			intent.tuck = .8 if tick%240<120 else 0.0
			intent.brake = .6 if tick%240>=120 else 0.0
			sim.step(DT,intent,surface)
			if before_facing!=sim.facing_backward: metrics.switches += 1
			skier.step_animation(DT,sim,intent,surface)
			for alpha in [0.0,.5,1.0]: inspect(sim,alpha)
			var now: Dictionary = {}
			for id in ["Hips","Spine","Head"]:
				now[id] = skier.to_global(skier.rendered_joints[id])-sim.position
				if previous.has(id):
					# Deliberately faster angular control moves a rigid skeleton farther
					# in world space. Measure pose discontinuity after carrying its frame.
					var carried: Vector3 = skier.global_basis*previous_frame.transposed()*previous[id]
					local_joint_step_m = maxf(local_joint_step_m,now[id].distance_to(carried))
				if previous.has(id) and now[id].distance_to(previous[id])>metrics.joint_step_m:
					metrics.joint_step_m = now[id].distance_to(previous[id])
					metrics.worst_step = {"tick":tick,"joint":id,"switch":reverse,"roll":sim.body.roll,"pitch":sim.body.pitch,"from":str(previous[id]),"to":str(now[id]),"motion":skier.animation.current.duplicate()}
			previous = now
			previous_frame = skier.global_basis
		check(not sim.crashed,"Long airborne turning keeps a valid rider, initial switch %s"%reverse)
	check(metrics.switches==0,"Free flight retains its facing convention throughout continuous yaw")
	check(metrics.boot_gap_m<.0005 and metrics.limb_error_m<.002,"Forward/backward flight retains rigid boots and limb lengths")
	check(metrics.cuff_side_deg<12 and metrics.cuff_flex_deg<40,"Both facing poses retain anatomical cuff limits")
	check(metrics.torso_up_min>0 and metrics.spine_error_m<.0001,"Combined air animations retain an upright, connected spine")
	check(metrics.chest_up_min>=cos(deg_to_rad(78))-.001 and metrics.neck_angle_deg<60,"Every final airborne chest/neck pose remains within the combined anatomical envelope")
	metrics.local_joint_step_m = local_joint_step_m
	check(local_joint_step_m<.08,"Facing changes and reversals keep pose changes below 8 cm after accounting for commanded whole-rider rotation")
	var sim = Sim.new()
	sim.reset(Vector3(0,8,0))
	sim.prime_contacts(surface)
	sim.grounded = false
	sim.velocity = Vector3(0,-3,20)
	sim.facing_backward = true
	sim.step(DT,RiderInput.new(),surface)
	skier.reset_animation(sim)
	skier.pose(sim)
	var targets: Dictionary = skier.targets.duplicate()
	sim.body.roll_velocity = .7
	sim.body.pitch_velocity = -.35
	sim.crash("SWITCH FIXTURE")
	skier.ragdoll.start(sim)
	var momentum = Vector3.ZERO
	var gap = 0.0
	var angular_error = 0.0
	for id in skier.ragdoll.bodies:
		var expected: Transform3D = skier.skeleton.global_transform*targets[skier.bone_ids[id]]
		gap = maxf(gap,expected.origin.distance_to(skier.ragdoll.bone_world(id).origin))
		var bone = skier.ragdoll.bodies[id]
		momentum += bone.linear_velocity*bone.mass
		angular_error = maxf(angular_error,bone.angular_velocity.distance_to(sim.body.pose_frame.basis*Vector3(-.35,0,.7)))
	check(gap<.001 and (momentum/sim.tuning.rider_mass).distance_to(sim.velocity)<.001,"Backward crash seeds the composed pose and retains total incoming momentum")
	check(angular_error<.001,"Backward facing preserves the physical world angular velocity at crash handoff")
	FileAccess.open("res://artifacts/jump_v13/pose_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	print("AIRBORNE_POSE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	skier.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
func inspect(sim, alpha):
	skier.pose(sim,alpha)
	var points: Dictionary = skier.rendered_joints
	var rotations: Dictionary = skier.rendered_rotations
	metrics.torso_up_min = minf(metrics.torso_up_min,(points.neck-points.Hips).normalized().y)
	metrics.chest_up_min = minf(metrics.chest_up_min,rotations.Spine.y.y)
	for pair in [["Spine","neck"],["neck","Head"]]:
		metrics.neck_angle_deg = maxf(metrics.neck_angle_deg,rad_to_deg(rotations[pair[0]].get_rotation_quaternion().angle_to(rotations[pair[1]].get_rotation_quaternion())))
	for pair in [["Hips","Spine02"],["Spine02","Spine01"],["Spine01","Spine"],["Spine","neck"],["neck","Head"]]:
		metrics.spine_error_m = maxf(metrics.spine_error_m,absf(points[pair[0]].distance_to(points[pair[1]])-sim.Body.REST[pair[0]].distance_to(sim.Body.REST[pair[1]])))
	for i in range(2):
		var prefix = "Right" if i==0 else "Left"
		var ankle: Vector3 = skier.skis[i].get_child(1).global_transform*Vector3(0,sim.Body.REST[prefix+"Foot"].y,0)
		metrics.boot_gap_m = maxf(metrics.boot_gap_m,ankle.distance_to(skier.to_global(points[prefix+"Foot"])))
		for pair in [["UpLeg","Leg"],["Leg","Foot"],["Arm","ForeArm"],["ForeArm","Hand"]]:
			metrics.limb_error_m = maxf(metrics.limb_error_m,absf(points[prefix+pair[0]].distance_to(points[prefix+pair[1]])-sim.Body.REST[prefix+pair[0]].distance_to(sim.Body.REST[prefix+pair[1]])))
		var axis: Vector3 = rotations[prefix+"Foot"].transposed()*(points[prefix+"Leg"]-points[prefix+"Foot"]).normalized()
		metrics.cuff_side_deg = maxf(metrics.cuff_side_deg,absf(rad_to_deg(atan2(axis.x,axis.y))))
		metrics.cuff_flex_deg = maxf(metrics.cuff_flex_deg,absf(rad_to_deg(atan2(axis.z,axis.y))))
