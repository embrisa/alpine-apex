extends SceneTree
## Real 120 Hz solver + production skeleton writer; no preview dependencies.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const MotionInput = preload("res://scripts/core/rider_input.gd")
const TestPlane = preload("res://tests/physics_suite.gd").TestPlane
const Replay = preload("res://scripts/racing/run_replay.gd")
const DT = 1.0/120.0
const OUTPUT = "res://artifacts/steep_motion_gameplay"
var skier
var checks = 0
var failures: Array[String] = []
var metrics = {"foot_error_m":0.0,"toe_marker_error_m":0.0,"segment_error_m":0.0,"cuff_side_rad":0.0,"cuff_min_rad":0.0,"cuff_max_rad":0.0,"grip_error_m":0.0,"joint_step_m":0.0,"posture_step_rad":0.0,"angular_accel_rad_s2":0.0,"raw_to_fitted_hand_m":0.0}
var cases = []
var ski_grip_error = 0.0
var ski_grip_samples = 0
var active_case = ""
var case_segment_peak = 0.0
var baseline_air = false

func _initialize(): call_deferred("run")
func check(value: bool, message: String):
	checks += 1
	if not value: failures.append(message)
	print("PASS: " if value else "FAIL: ",message)

func run():
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	baseline_air = "--baseline-air-rates" in OS.get_cmdline_user_args()
	skier = preload("res://scripts/presentation/skier_visual.gd").new()
	root.add_child(skier); await process_frame
	library_checks()
	for name in ["glide","turns","tuck_prepare","ordinary_hop","natural_ledge","asymmetric","recovery","grab","mute","grab_reentry","spin","flip","switch_flip","tilt","switch_tilt","backflip","toggle"]:
		if baseline_air and name in ["tilt","switch_tilt"]: continue
		if "--grab-only" in OS.get_cmdline_user_args() and name not in ["grab","mute"]: continue
		ride(name)
	assistance_checks()
	check(metrics.foot_error_m<.0005,"Rigid boots close to physical skis at every sampled render fraction")
	check(metrics.toe_marker_error_m<.000001,"Published toe markers match the rigid boot children written to the skeleton")
	check(metrics.segment_error_m<.002,"All fitted body segments retain target rest lengths")
	check(metrics.cuff_side_rad<deg_to_rad(12.0) and metrics.cuff_min_rad>deg_to_rad(-5.0) and metrics.cuff_max_rad<deg_to_rad(40.0),"Native knee planes respect the existing cuff envelope")
	check(metrics.grip_error_m<.00001,"Every rendered pole stays in the glove grip frame")
	check(ski_grip_samples>30 and ski_grip_error<.04,"Safety/Mute glove reach remains within 4 cm of the grab target; joint stops take precedence over forced contact")
	metrics.ski_grip_error_m = ski_grip_error
	metrics.ski_grip_samples = ski_grip_samples
	check(metrics.posture_step_rad<=12.0*DT+.0001 and metrics.angular_accel_rad_s2<160.01,"Posture retargets retain velocity within angular speed and acceleration bounds")
	var result = {"checks":checks,"failures":failures,"metrics":metrics,"cases":cases,"physics":Sim.MODEL_VERSION,"replay":Replay.VERSION}
	result.baseline_air_rates = baseline_air
	FileAccess.open(OUTPUT+("/suite_air_baseline.json" if baseline_air else "/suite.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("FULL_MOTION_RESULTS ",JSON.stringify(result))
	skier.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)

func library_checks():
	var full = skier.animation.full_motion
	check(full.library.clips.size()==33 and full.library.names.size()==24,"33 verified full-curve clips share the existing 24-bone body")
	var seam_error = 0.0
	var varied = true
	for name in full.library.clips:
		var duration: float = full.duration(name)
		var seam = minf(.25,duration*.2)
		var a = full.sample_clip(name,duration-seam-.000001,true)
		var b = full.sample_clip(name,duration-seam+.000001,true)
		for i in a.q.size(): seam_error = maxf(seam_error,full.rotation_vector(a.q[i]*b.q[i].inverse()).length())
		var start = full.sample_clip(name,0.0)
		var middle = full.sample_clip(name,duration*.5)
		var motion = 0.0
		for i in start.q.size(): motion += start.q[i].angle_to(middle.q[i])
		varied = varied and motion>.01
	check(varied,"Every clip retains time-varying joint curves, not scalar pose averages")
	check(seam_error<.003,"Repetition joins clip ends without a quaternion reset (%.6f rad)"%seam_error)
	var clip = full.sample_clip("NAV_MED_LEFT",.73)
	var mirrored = full.mirror_pose(full.mirror_pose(clip))
	var same = clip.root.is_equal_approx(mirrored.root)
	for i in clip.q.size(): same = same and absf(clip.q[i].dot(mirrored.q[i]))>.99999
	check(same,"Opposite-direction drift reflection is an involution with quaternion continuity")

func ride(name: String):
	active_case = name; case_segment_peak = 0.0
	var air = name in ["asymmetric","grab","mute","grab_reentry","spin","flip","switch_flip","tilt","switch_tilt","backflip"]
	var surface = preload("res://tests/jump_suite.gd").Ledge.new() if name=="natural_ledge" else TestPlane.new(.30)
	var sim = Sim.new(); var control = Sim.new()
	for model in [sim,control]:
		if baseline_air:
			# Current presentation with the old rates isolates unrelated pose failures.
			model.tuning.air_spin_rate = 4.5; model.tuning.air_flip_rate = 3.8; model.tuning.air_steer_rate = .65
			model.tuning.air_rotation_acceleration = 10.0; model.tuning.air_rotation_braking = 10.0; model.tuning.air_rotation_rate_limit = 4.5
		model.reset(Vector3(0,40.0 if air else 0.0,0)); model.prime_contacts(surface)
		model.velocity = Vector3(0,0,18).slide(model.surface_normal)
		if air: model._begin_flight(model.support_basis())
		if name=="asymmetric": model.flight_frame *= Basis(Vector3.BACK,.16)
		if name in ["switch_flip","switch_tilt"]: model.facing_backward = true
		if name=="recovery": model.impacts.reserve = .25; model.impacts.since_hit = 0.0
		model.reset_pose_history()
	skier.animation.full_motion.enabled = true
	skier.animation.full_motion.grab_style = "mute" if name=="mute" else "safety"
	skier.reset_animation(sim)
	var input = MotionInput.new()
	var equality = true; var repeated = true; var finite = true
	var last = {}; var max_step = 0.0; var phase_counts = {}; var residuals = []
	var idle_sampler_seen = false
	var grab_latch_valid = true
	var switch_shape_valid = true
	var ordinary_pitch_shape = true
	var backflip_shape = true
	var last_tick_pose: Array[Quaternion] = skier.animation.full_motion.current.duplicate()
	var peak_change = {}
	for tick in (620 if name=="toggle" else 420):
		input.steer = (.8 if tick%160<80 else -.8) if name in ["turns","toggle"] else 0.0
		input.tuck = 1.0 if name=="tuck_prepare" and tick<180 else 0.0
		input.jump_held = (tick>=180 and tick<210) if name=="tuck_prepare" else (tick<24 and name=="ordinary_hop")
		input.jump = tick==24 and name=="ordinary_hop"
		input.grab = name in ["grab","mute","grab_reentry"] and tick>=36 and tick<210
		if name=="grab_reentry":
			if tick==110: skier.animation.full_motion.grab_style = "mute"
			if tick>=140 and tick<146: input.grab = false
			if tick>=300 and tick<340: input.grab = true
		input.air_pitch = 1.0 if name in ["flip","switch_flip"] and tick<160 else 0.0
		if name=="backflip": input.air_pitch = -1.0 if tick<160 else 0.0
		input.air_tilt = (1.0 if tick<150 else -1.0) if name in ["tilt","switch_tilt"] and tick>0 and tick<280 else 0.0
		input.air_yaw = 1.0 if name=="spin" and tick<160 else 0.0
		if name=="toggle": skier.animation.full_motion.enabled = tick<100 or tick>=320
		sim.step(DT,input,surface); control.step(DT,input,surface)
		skier.step_animation(DT,sim,input,surface)
		var full = skier.animation.full_motion
		if name in ["tilt","switch_tilt"]:
			ordinary_pitch_shape = ordinary_pitch_shape and not full.weights.has("AIR_BACKFLIP_LONG") and not full.weights.has("AIR_FRONTFLIP_LONG")
		if name=="backflip" and tick>=45 and tick<150:
			backflip_shape = backflip_shape and full.weights.has("AIR_FRONTFLIP_LONG") and not full.weights.has("AIR_BACKFLIP_LONG")
		if name=="switch_flip" and tick>=45 and tick<150:
			switch_shape_valid = switch_shape_valid and full.weights.has("AIR_BACKFLIP_LONG") and not full.weights.has("AIR_FRONTFLIP_LONG")
		if name=="grab_reentry" and tick>=110 and tick<210:
			grab_latch_valid = grab_latch_valid and full.active_grab_style=="safety" and full.grab_age>.5
		if name=="grab_reentry" and tick>=300 and tick<340:
			grab_latch_valid = grab_latch_valid and full.active_grab_style=="mute"
		idle_sampler_seen = idle_sampler_seen or (not full.enabled and full.amount==0.0 and full.step_microseconds==0)
		for i in full.current.size(): metrics.posture_step_rad = maxf(metrics.posture_step_rad,last_tick_pose[i].angle_to(full.current[i]))
		last_tick_pose = full.current.duplicate()
		metrics.angular_accel_rad_s2 = maxf(metrics.angular_accel_rad_s2,full.diagnostics.get("max_posture_accel_rad_s2",0.0))
		equality = equality and Replay.snapshot(tick*DT,sim)==Replay.snapshot(tick*DT,control) and sim.body.com==control.body.com and sim.body.inertia==control.body.inertia and sim.impacts.reserve==control.impacts.reserve
		for alpha in [0.0,.5,1.0]: inspect(sim,alpha)
		var frozen = full.current.duplicate(); var root_before = full.root_position
		skier.pose(sim,1.0)
		repeated = repeated and frozen==full.current and full.root_position==root_before
		phase_counts[full.phase] = phase_counts.get(full.phase,0)+1
		if not last.is_empty():
			for id in skier.rendered_joints:
				var step_distance: float = skier.rendered_joints[id].distance_to(last[id])
				if step_distance>max_step:
					max_step = step_distance
					peak_change = {"tick":tick,"joint":id,"grounded":sim.grounded,"impact":sim.landing_force,"state":skier.animation.current.duplicate(),"diagnostics":full.diagnostics.duplicate()}
		last = skier.rendered_joints.duplicate()
		for id in last: finite = finite and last[id].is_finite()
		if tick%20==0: residuals.append(full.diagnostics.duplicate())
		if sim.crashed: break
	metrics.joint_step_m = maxf(metrics.joint_step_m,max_step)
	check(equality,name+": animation leaves every physical/replay snapshot identical to playback disabled")
	check(repeated and finite,name+": repeated renders preserve animation state and finite fitted joints")
	# Contacts and source events may be quick, but ordinary controls/toggles
	# must never select a discontinuous fitted branch.
	if name in ["glide","turns","tuck_prepare","toggle"]: check(max_step<.08,name+": final fitted joints stay below 8 cm per physical tick")
	if name in ["grab","mute","grab_reentry"]: check(max_step<.10,name+": fitted grab entry and release retain continuous hand/shoulder motion")
	if name=="grab_reentry": check(grab_latch_valid,"Style changes and brief releases retain the held target/phase; the next settled grab adopts the new style")
	if name=="switch_flip": check(switch_shape_valid,"Switch flips choose source posture in the rider's lateral-axis convention")
	if name in ["tilt","switch_tilt"]: check(ordinary_pitch_shape,"Limited pitch retains ordinary airborne poses: "+name)
	if name=="backflip": check(backflip_shape,"Negative pitch chooses the opposite imported flip posture")
	if name=="toggle": check(idle_sampler_seen,"Settled procedural comparison stops sampling, then resumes through the live blend")
	full_hold_check()
	cases.append({"name":name,"max_joint_step_m":max_step,"segment_error_m":case_segment_peak,"peak_change":peak_change,"phases":phase_counts,"residual_samples":residuals})

func full_hold_check():
	skier.animation.hold()
	check(skier.animation.full_motion.sample(0.0)==skier.animation.full_motion.sample(1.0),"Pause collapses full-curve interpolation without rewinding")

func inspect(sim, alpha: float):
	skier.pose(sim,alpha)
	var joints: Dictionary = skier.rendered_joints
	var rotations: Dictionary = skier.rendered_rotations
	var full = skier.animation.full_motion
	if full.diagnostics.get("grip_phase",0.0)>.9999:
		var foot = "LeftFoot" if full.active_grab_style=="mute" else "RightFoot"
		var grip: Vector3 = joints[foot]+rotations[foot]*full.SKI_GRIP
		ski_grip_error = maxf(ski_grip_error,(joints.RightHand+rotations.RightHand*full.GLOVE_GRIP).distance_to(grip))
		ski_grip_samples += 1
	for i in skier.skeleton.get_bone_count():
		var id: String = skier.skeleton.get_bone_name(i)
		var parent: int = skier.skeleton.get_bone_parent(i)
		if parent<0: continue
		var pid: String = skier.skeleton.get_bone_name(parent)
		if not joints.has(id) or not joints.has(pid): continue
		var wanted: float = skier.rest[i].origin.distance_to(skier.rest[parent].origin)
		var error: float = absf(joints[id].distance_to(joints[pid])-wanted)
		case_segment_peak = maxf(case_segment_peak,error)
		if error>metrics.segment_error_m:
			metrics.segment_error_m = error
			metrics.worst_segment = {"case":active_case,"tick":sim.ticks,"alpha":alpha,"bone":id,"parent":pid,"wanted":wanted,"actual":joints[id].distance_to(joints[pid])}
	for i in 2:
		var prefix = "Right" if i==0 else "Left"
		var toe = prefix+"ToeBase"
		metrics.toe_marker_error_m = maxf(metrics.toe_marker_error_m,joints[toe].distance_to(skier.desired[skier.bone_ids[toe]].origin))
		var ankle: Vector3 = skier.skis[i].get_child(1).global_transform*Vector3(0,skier._origin(prefix+"Foot").y,0)
		metrics.foot_error_m = maxf(metrics.foot_error_m,skier.to_global(joints[prefix+"Foot"]).distance_to(ankle))
		var axis: Vector3 = rotations[prefix+"Foot"].transposed()*(joints[prefix+"Leg"]-joints[prefix+"Foot"]).normalized()
		metrics.cuff_side_rad = maxf(metrics.cuff_side_rad,absf(atan2(axis.x,axis.y)))
		metrics.cuff_min_rad = minf(metrics.cuff_min_rad,atan2(axis.z,axis.y)); metrics.cuff_max_rad = maxf(metrics.cuff_max_rad,atan2(axis.z,axis.y))
		metrics.grip_error_m = maxf(metrics.grip_error_m,skier.poles[i].position.distance_to(skier.probes[prefix.to_lower()+"_hand"]))

func assistance_checks():
	var surface = TestPlane.new(.35)
	var sim = Sim.new(); sim.reset(Vector3.ZERO); sim.prime_contacts(surface)
	sim.velocity = Vector3(8,-5,24); sim.tuning.ground_assist_enabled = true
	var input = MotionInput.new(); var last = 0.0; var max_accel = 0.0
	for tick in 300:
		if tick==100: input.steer = .6
		if tick==150: input.steer = 0.0
		if tick==230: sim.tuning.ground_assist_enabled = false
		sim.landing_assist.step(DT,sim,input,surface)
		var velocity: float = sim.landing_assist.ground_velocity
		max_accel = maxf(max_accel,absf(velocity-last)/DT); last = velocity
	check(max_accel<=sim.tuning.ground_assist_acceleration+.00001,"Ground help ramps entry, manual handover, re-entry and toggle exit without erasing yaw rate")
	var peak_accel = 0.0; var peak_step = 0.0; var manual_wins = true
	sim.reset(Vector3(0,1000,0)); sim.prime_contacts(surface); sim._begin_flight(Basis(Vector3.RIGHT,.6)); sim.velocity = Vector3(8,-15,22)
	sim.tuning.landing_assist_enabled = true; input = MotionInput.new()
	for tick in 360:
		if tick==80: sim.position.y = .8
		if tick==140: surface.gradient = -.25
		if tick==190: sim.position.y = 1000
		if tick==220: input.air_pitch = .3
		if tick==250: input.air_pitch = 0.0
		if tick==280: sim.tuning.landing_assist_enabled = false
		var old: Basis = sim.support_basis(); var omega: Vector3 = sim.air_control.angular_velocity
		sim.landing_assist.step(DT,sim,input,surface); sim.air_control.step(DT,sim,input)
		var delta: float = skier.animation.full_motion.rotation_vector(sim.support_basis().get_rotation_quaternion()*old.get_rotation_quaternion().inverse()).length()
		peak_step = maxf(peak_step,delta)
		var limit: float = sim.tuning.air_rotation_braking if sim.air_control.manual_active or sim.air_control.orientation_flight else sim.tuning.air_assist_acceleration
		peak_accel = maxf(peak_accel,(sim.air_control.angular_velocity-omega).length()/DT-limit)
		if input.air_pitch!=0.0: manual_wins = manual_wins and sim.air_control.assist_acceleration==Vector3.ZERO and sim.landing_assist.strength==0.0
	check(peak_accel<.001 and peak_step<=sim.tuning.air_rotation_rate_limit*DT+.001 and manual_wins,"Air prediction/retarget/expiry/manual/trick release stays rate bounded with immediate manual ownership")
