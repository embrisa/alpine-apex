extends "res://tests/steep_motion_suite.gd"
## Inspect FINAL joint frames, after native composition, fitting and skin writes.
const Anatomy = preload("res://scripts/presentation/skier_anatomy.gd")
var anatomical = {"elbow_off_axis_rad":0.0,"knee_off_axis_rad":0.0,"wrist_swing_rad":0.0,"wrist_twist_rad":0.0,"elbow_min_rad":INF,"elbow_max_rad":0.0,"knee_min_rad":INF,"knee_max_rad":0.0,"spine_bend_rad":0.0,"spine_twist_rad":0.0,"spine_side_rad":0.0,"shin_twist_rad":0.0}
var samples = 0
var wrist_envelope_excess = 0.0
var wrist_twist_excess = 0.0
var worst = {}
var worst_grab = {"gap_m":0.0}

func inspect(sim, alpha: float):
	super.inspect(sim,alpha)
	var r: Dictionary = skier.rendered_rotations
	var j: Dictionary = skier.rendered_joints
	var full = skier.animation.full_motion
	if full.diagnostics.get("grip_phase",0.0)>.9999:
		var foot = "LeftFoot" if full.active_grab_style=="mute" else "RightFoot"
		var target: Vector3 = j[foot]+r[foot]*full.SKI_GRIP
		var gap: float = (j.RightHand+r.RightHand*full.GLOVE_GRIP).distance_to(target)
		if gap>worst_grab.gap_m:
			worst_grab = {"gap_m":gap,"style":full.active_grab_style,"tick":sim.ticks,"joints":var_to_str(j),"rotations":var_to_str(r),"target":var_to_str(target),"diagnostics":full.diagnostics.duplicate()}
	samples += 1
	for pair in [["Hips","Spine02"],["Spine02","Spine01"],["Spine01","Spine"]]:
		var v = Anatomy.vector((r[pair[0]].transposed()*r[pair[1]]).get_rotation_quaternion())
		anatomical.spine_bend_rad = maxf(anatomical.spine_bend_rad,absf(v.x))
		anatomical.spine_twist_rad = maxf(anatomical.spine_twist_rad,absf(v.y))
		anatomical.spine_side_rad = maxf(anatomical.spine_side_rad,absf(v.z))
	for prefix in ["Left","Right"]:
		for arm in [true,false]:
			var a = prefix+("Arm" if arm else "UpLeg")
			var b = prefix+("ForeArm" if arm else "Leg")
			var c = prefix+("Hand" if arm else "Foot")
			var relative: Basis = r[a].transposed()*r[b]
			if arm:
				# Pronation is around the forearm, not an extra elbow bend. Remove
				# that axial component before testing the calibrated hinge plane.
				var zero = Anatomy.elbow_zero(prefix)
				relative *= zero.transposed()
				var longitudinal: Vector3 = zero*(sim.Body.REST[c]-sim.Body.REST[b]).normalized()
				relative *= Basis(longitudinal,-Anatomy.twist_angle(relative,longitudinal))
			var v = Anatomy.vector(relative.get_rotation_quaternion())
			var axis = Anatomy.hinge_axis(prefix,arm)
			var key = "elbow" if arm else "knee"
			anatomical[key+"_off_axis_rad"] = maxf(anatomical[key+"_off_axis_rad"],v.slide(axis).length())
			var bend: float = (j[b]-j[a]).angle_to(j[c]-j[b])
			anatomical[key+"_min_rad"] = minf(anatomical[key+"_min_rad"],bend)
			anatomical[key+"_max_rad"] = maxf(anatomical[key+"_max_rad"],bend)
		var axis: Vector3 = (sim.Body.REST[prefix+"Hand"]-sim.Body.REST[prefix+"ForeArm"]).normalized()
		var wrist: Basis = r[prefix+"ForeArm"].transposed()*r[prefix+"Hand"]
		var twist = Anatomy.twist_angle(wrist,axis)
		anatomical.wrist_twist_rad = maxf(anatomical.wrist_twist_rad,absf(twist))
		anatomical.wrist_swing_rad = maxf(anatomical.wrist_swing_rad,Anatomy.vector((wrist*Basis(axis,-twist)).get_rotation_quaternion()).length())
		var state = skier.animation.sample(alpha)
		var carry: float = maxf(state.tuck,state.prepare)*(1.0-state.air)*skier.animation.full_motion.Downhill.straight(state)
		var sampled: Dictionary = skier.animation.full_motion.sample(alpha)
		var action: Vector3 = sampled.get("action",Vector3.ZERO)
		var downhill: float = clampf(sampled.get("downhill",0.0)+action.x+action.y+action.z,0.0,1.0)
		var allowed_swing = deg_to_rad(lerpf(lerpf(28,80,carry),80,downhill))
		wrist_twist_excess = maxf(wrist_twist_excess,absf(twist)-deg_to_rad(lerpf(lerpf(55,90,carry),30,downhill)))
		wrist_envelope_excess = maxf(wrist_envelope_excess,Anatomy.vector((wrist*Basis(axis,-twist)).get_rotation_quaternion()).length()-allowed_swing)
		var shin: Basis = r[prefix+"Foot"].transposed()*r[prefix+"Leg"]
		var shin_twist = absf(Anatomy.twist_angle(shin,Vector3.UP))
		if shin_twist>anatomical.shin_twist_rad:
			worst = {"phase":skier.animation.phase,"tick":sim.ticks,"joints":var_to_str(j),"hips_rotation":var_to_str(r.Hips),"boot":var_to_str(r[prefix+"Foot"]),"side":prefix,"twist_deg":rad_to_deg(shin_twist)}
		anatomical.shin_twist_rad = maxf(anatomical.shin_twist_rad,shin_twist)

func assistance_checks():
	super.assistance_checks()
	check(anatomical.elbow_off_axis_rad<.002,"Final elbows keep one calibrated hinge plane after source blend, grab fitting and F8 transitions")
	check(anatomical.knee_off_axis_rad<.002,"Final knees cannot bend sideways or retain independent thigh/shin twist")
	check(anatomical.elbow_min_rad>=deg_to_rad(5.9) and anatomical.elbow_max_rad<=deg_to_rad(145.1),"Elbows neither hyperextend nor fold past the authored skiing envelope")
	check(anatomical.knee_min_rad>=0.0 and anatomical.knee_max_rad<deg_to_rad(155.0),"Physical binding fit retains a finite forward knee bend")
	check(wrist_envelope_excess<deg_to_rad(.1) and wrist_twist_excess<deg_to_rad(.1),"Final wrists respect source envelopes and the downhill 80/30-degree flexion/twist envelope")
	check(anatomical.spine_bend_rad<deg_to_rad(20.1) and anatomical.spine_twist_rad<deg_to_rad(10.1) and anatomical.spine_side_rad<deg_to_rad(8.1),"Every spinal link stays inside its three-axis envelope, including grabs")
	check(anatomical.shin_twist_rad<deg_to_rad(18.0),"Shin skin orientation remains aligned with the rigid boot")
	DirAccess.make_dir_recursive_absolute("res://artifacts/skier_anatomy")
	FileAccess.open("res://artifacts/skier_anatomy/suite.json",FileAccess.WRITE).store_string(JSON.stringify({"metrics":anatomical,"worst":worst,"worst_grab":worst_grab,"samples":samples,"failures":failures},"\t"))
