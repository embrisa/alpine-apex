extends RefCounted
## Source action owns torso/arms before tracking; connected snow contact is cosmetic.
const Anatomy = preload("res://scripts/presentation/skier_anatomy.gd")
const Body = preload("res://scripts/core/rider_body.gd")
const Motion = preload("res://assets/animation/pole_push_cycle.tres")
const TIP_LENGTH = 1.18

static func apply(pose: Dictionary, library: Dictionary, phase: float, amount: float) -> void:
	if amount<=.000001: return
	var control = Motion.sample(phase)
	var joints = {"Hips":Vector3.ZERO}
	var rotations = {}
	for name in ["Hips","Spine02","Spine01","Spine","neck","Head"]:
		var i: int = library.names.find(name)
		var pitch: float = control.hips if name=="Hips" else control.spine if name in ["Spine02","Spine01"] else -4.0 if name=="Spine" else -10.0
		pose.q[i] = pose.q[i].slerp(Quaternion(Vector3.RIGHT,deg_to_rad(pitch)),amount)
		var local = Anatomy.local_limit(name,Basis(pose.q[i]))
		if name=="Hips": rotations[name] = local; continue
		var parent: String = library.names[library.parents[i]]
		rotations[name] = rotations[parent]*local
		joints[name] = joints[parent]+rotations[parent]*(Body.REST[name]-Body.REST[parent])
	for prefix in ["Right","Left"]:
		var side = -1.0 if prefix=="Right" else 1.0
		var shoulder = prefix+"Shoulder"; var arm = prefix+"Arm"
		var elbow = prefix+"ForeArm"; var hand = prefix+"Hand"
		var ci: int = library.names.find(shoulder); var ai: int = library.names.find(arm)
		var ei: int = library.names.find(elbow); var hi: int = library.names.find(hand)
		pose.q[ci] = pose.q[ci].slerp(Quaternion.IDENTITY,amount)
		rotations[shoulder] = rotations.Spine*Basis(pose.q[ci])
		joints[shoulder] = joints.Spine+rotations.Spine*(Body.REST[shoulder]-Body.REST.Spine)
		joints[arm] = joints[shoulder]+rotations[shoulder]*(Body.REST[arm]-Body.REST[shoulder])
		var wrist: Vector3 = control.wrist
		wrist = Vector3(side*wrist.x,joints[arm].y+wrist.y,joints[arm].z+wrist.z)
		var upper: float = Body.REST[arm].distance_to(Body.REST[elbow])
		var lower: float = Body.REST[elbow].distance_to(Body.REST[hand])
		wrist = joints[arm]+(wrist-joints[arm]).limit_length(upper+lower-.012)
		joints[hand] = wrist
		joints[elbow] = Body.joint(joints[arm],wrist,upper,lower,Vector3(side*.65,-1.0,-.15))
		rotations[arm] = rotations[shoulder]*Basis(pose.q[ai])
		Anatomy.fit_hinge(prefix,true,joints,rotations)
		var arm_local: Basis = rotations[shoulder].transposed()*rotations[arm]
		arm_local = Anatomy.local_limit(arm,arm_local)
		var elbow_local: Basis = rotations[arm].transposed()*rotations[elbow]
		rotations[arm] = rotations[shoulder]*arm_local
		rotations[elbow] = rotations[arm]*elbow_local
		var trail: Vector3 = control.trail; trail.x *= side
		var z = -trail
		var x = rotations[elbow].x.slide(z).normalized()
		var wrist_local: Basis = rotations[elbow].transposed()*Basis(x,z.cross(x),z)
		var axis: Vector3 = (Body.REST[hand]-Body.REST[elbow]).normalized()
		var roll = Anatomy.twist_angle(wrist_local,axis)
		elbow_local *= Basis(axis,roll)
		wrist_local = Basis(axis,-roll)*wrist_local
		pose.q[ai] = pose.q[ai].slerp(arm_local.get_rotation_quaternion(),amount)
		pose.q[ei] = pose.q[ei].slerp(elbow_local.get_rotation_quaternion(),amount)
		pose.q[hi] = pose.q[hi].slerp(wrist_local.get_rotation_quaternion(),amount)

static func contact_weight(phase: float) -> float:
	# Loaded contact is never amplitude-blended. After release, recover through
	# zero at .90, then approach the NEXT plant before wrap (not in the first force tick).
	var recover = clampf((phase-.90)/.10,0.0,1.0)
	return 1.0-smoothstep(.76,.90,phase)+recover*recover*recover*(recover*(recover*6.0-15.0)+10.0)

static func wrist_on_sphere(wrist: Vector3, shoulder: Vector3, anchor: Vector3, radius: float, reach: float) -> Vector3:
	# Finite alternating projections stay continuous at near-tangent reach.
	# The exact two-sphere circle collapses with an unbounded derivative there,
	# producing a 23 cm hand step in the native flat stroke. Any unreachable
	# remainder is measured as plant slide; final rigid tips still fit the snow.
	var wanted = wrist
	for iteration in 4:
		wanted = anchor+(wanted-anchor).normalized()*radius
		wanted = shoulder+(wanted-shoulder).limit_length(reach)
	return wanted

static func ground_target(wrist: Vector3, anchor: Vector3, normal: Vector3, radius: float, fallback: Vector3) -> Vector3:
	var height = (wrist-anchor).dot(normal)
	var center = wrist-normal*height
	var radial = (anchor-center).normalized()
	if radial.length_squared()<.5: radial = fallback.slide(normal).normalized()
	return center+radial*sqrt(maxf(0.0,radius*radius-height*height))

static func arm_candidate(context: Dictionary, angle: float) -> Dictionary:
	var position: Vector3 = context.position; var wanted: Vector3 = context.wanted
	var shoulder: Basis = context.shoulder
	var upper_rest: Vector3 = context.upper_rest; var lower_rest: Vector3 = context.lower_rest
	var bend: Vector3 = Basis(context.direction,angle)*context.hint
	var point = Body.joint(position,wanted,context.upper_length,context.lower_length,bend)
	var up = (point-position).normalized(); var down = (wanted-point).normalized()
	var normal = up.cross(down).normalized()
	var upper: Basis = Anatomy.segment_frame(up,normal)*context.upper_frame
	var lower: Basis = Anatomy.segment_frame(down,normal)*context.lower_frame
	var upper_local = Anatomy.local_limit(context.arm,context.shoulder_inverse*upper)
	var lower_local = Anatomy.local_limit(context.elbow,upper.transposed()*lower,0.0,1.0)
	var fitted_elbow = position+shoulder*upper_local*upper_rest
	var fitted_wrist = fitted_elbow+shoulder*upper_local*lower_local*lower_rest
	return {"upper":upper_local,"lower":lower_local,"cost":fitted_wrist.distance_squared_to(wanted)+.015*fitted_elbow.distance_squared_to(context.old_elbow),"angle":angle}

static func connected_arm(prefix: String, shoulder: Basis, position: Vector3, wanted: Vector3, old_elbow: Vector3, carry_weight: float) -> Dictionary:
	var upper_rest: Vector3 = Body.REST[prefix+"ForeArm"]-Body.REST[prefix+"Arm"]
	var lower_rest: Vector3 = Body.REST[prefix+"Hand"]-Body.REST[prefix+"ForeArm"]
	var axis = Anatomy.hinge_axis(prefix,true)
	var hint = old_elbow-position
	var side = -1.0 if prefix=="Right" else 1.0
	# The projected old elbow can cross the wrist axis during a loaded tuck.
	# Bias the bend outward as contact takes ownership, with source-relative
	# displacement still in the objective; carry fades on action cancellation.
	# Contact can rise to .89 in the first grounded sample after a fast
	# landing. Preserve the source elbow longer while the arm takes ownership;
	# wrists and poles retain the snow contact/aim weight. This reaches
	# the unchanged outward hint at full carry before any loaded stroke.
	var bend_weight = carry_weight*carry_weight
	bend_weight *= bend_weight*carry_weight
	hint = hint.lerp(Vector3(side,-.15,0.0).normalized()*hint.length(),bend_weight)
	var context = {"position":position,"wanted":wanted,"shoulder":shoulder,"shoulder_inverse":shoulder.transposed(),"upper_rest":upper_rest,"lower_rest":lower_rest,"upper_length":upper_rest.length(),"lower_length":lower_rest.length(),"upper_frame":Anatomy.segment_frame(upper_rest.normalized(),axis).transposed(),"lower_frame":Anatomy.segment_frame(lower_rest.normalized(),axis).transposed(),"arm":prefix+"Arm","elbow":prefix+"ForeArm","direction":(wanted-position).normalized(),"hint":hint,"old_elbow":old_elbow}
	# A hard winning probe/ternary interval can switch bend planes in one frame.
	# Smooth the angular objective, then solve ONCE at that angle: averaging
	# wrists or final bone matrices would violate rigid link closure.
	var trials: Array = []; var minimum = INF
	for probe in 9:
		var trial = arm_candidate(context,lerpf(-PI*.5,PI*.5,float(probe)/8.0))
		trials.append(trial); minimum = minf(minimum,trial.cost)
	# Snow release must not simultaneously collapse the bend objective and
	# rotate its reference back toward a tucked elbow. Keep it broad while the
	# action carries poles; fade only on completed action entry/cancellation.
	var width = maxf(.004*carry_weight*carry_weight,.00000001)
	var angle = 0.0; var total = 0.0
	for trial in trials:
		var contribution = exp(-(trial.cost-minimum)/width)
		angle += trial.angle*contribution; total += contribution
	var result = arm_candidate(context,angle/total)
	result.probes = 10
	return result

static func fit_tips(joints: Dictionary, rotations: Dictionary, root_frame: Transform3D, anchors: Array, normals: Array, weight: float, phase: float = 0.0, carry_weight: float = 0.0) -> Dictionary:
	carry_weight = maxf(carry_weight,weight)
	var gaps = []; var heights = []; var moves = []; var targets = []; var angles = []
	var wrist_targets = []; var elbow_angles = []; var probe_counts = []; var reach_errors = []
	var result = {"tip_gap_m":gaps,"tip_ground_height_m":heights,"tip_wrist_fit_m":moves,"tip_fit_rad":angles,"tip_anchors":anchors.duplicate(),"tip_targets":targets,"tip_contact_weight":weight,"tip_carry_weight":carry_weight,"tip_wrist_targets":wrist_targets,"tip_elbow_fit_rad":elbow_angles,"tip_arm_probes":probe_counts,"tip_reach_residual_m":reach_errors}
	if carry_weight<=.000001 or anchors.size()!=2 or normals.size()!=2: return result
	var inverse = root_frame.affine_inverse()
	var control = Motion.sample(phase)
	for i in 2:
		var prefix = "Right" if i==0 else "Left"
		var side = -1.0 if i==0 else 1.0
		var hand = prefix+"Hand"; var elbow = prefix+"ForeArm"; var arm = prefix+"Arm"
		var shoulder = prefix+"Shoulder"
		var grip_offset = Vector3(side*.070,0.0,.018)
		# Include the fixed socket in the wrist-to-tip sphere. Aiming from an old
		# grip and then rotating that offset was another source of contact error.
		var wrist_to_tip = grip_offset-Vector3.BACK*TIP_LENGTH
		var radius = wrist_to_tip.length()
		var anchor: Vector3 = inverse*anchors[i]
		var normal: Vector3 = (inverse.basis*normals[i]).normalized()
		var old_wrist: Vector3 = joints[hand]
		var old_hand: Basis = rotations[hand]
		var upper: float = Body.REST[arm].distance_to(Body.REST[elbow])
		var lower: float = Body.REST[elbow].distance_to(Body.REST[hand])
		# Preserve the source's lateral carry, with room outside the jacket.
		# A free 3D sphere projection otherwise pulls tucked hands inward while
		# solving vertical reach. Solve only in this arm's sagittal slice.
		var reference = old_wrist
		reference.x = side*maxf(absf(reference.x),.32)
		# Keep the exported backward stroke during the fast/intensity-tapered
		# tuck too. Closest-to-tracked-wrist alone delayed that stroke until AFTER
		# force. The source Y/lateral carry and 30 cm accommodation bound remain.
		reference.z = lerpf(old_wrist.z,joints[arm].z+control.wrist.z,.5)
		var sagittal_anchor = Vector3(reference.x,anchor.y,anchor.z)
		var sagittal_shoulder = Vector3(reference.x,joints[arm].y,joints[arm].z)
		var pole_radius = sqrt(maxf(0.0,radius*radius-pow(reference.x-anchor.x,2.0)))
		var reach = upper+lower-.012
		var arm_radius = sqrt(maxf(0.0,reach*reach-pow(reference.x-joints[arm].x,2.0)))
		var wanted = wrist_on_sphere(reference,sagittal_shoulder,sagittal_anchor,pole_radius,arm_radius)
		# Limit only cosmetic wrist accommodation. The source still supplies the
		# torso, shoulders, elbow hint and closest wrist; no pelvis/legs are touched.
		wanted = old_wrist+(wanted-old_wrist).limit_length(.30)
		var minimum = sqrt(upper*upper+lower*lower+2.0*upper*lower*cos(deg_to_rad(145.0)))
		if wanted.distance_to(joints[arm])<minimum:
			wanted = joints[arm]+(wanted-joints[arm]).normalized()*minimum
		# Blend the reach before IK, never independently slerp two parent-local
		# arm rotations across competing bend planes during release.
		# Retain up to 3 cm of the bounded reach during unloaded carry. Returning
		# fully to the tracked wrist compounded source recovery with >14 cm
		# steep release/approach steps. This fades with carry and is exactly the
		# existing fit at full contact, leaving loaded strokes unchanged.
		var reach_weight = weight+(1.0-weight)*carry_weight*.10
		wanted = old_wrist.lerp(wanted,reach_weight)
		# Unloaded hands still carry full shafts outside the jacket/hips. C's
		# contact blend pulled them into tuck midway through recovery, causing
		# actual-mesh hits even though loaded contact and fixed grips passed.
		wanted.x = lerpf(wanted.x,side*maxf(side*wanted.x,.32),carry_weight)
		wanted = old_wrist+(wanted-old_wrist).limit_length(.30)
		var fitted = connected_arm(prefix,rotations[shoulder],joints[arm],wanted,joints[elbow],carry_weight)
		rotations[arm] = rotations[shoulder]*fitted.upper
		rotations[elbow] = rotations[arm]*fitted.lower
		wrist_targets.append(wanted); elbow_angles.append(fitted.angle); probe_counts.append(fitted.probes)
		reach_errors.append(absf(wanted.distance_to(anchor)-radius))
		# Reconstruct both connected links after joint limits; never keep an IK
		# position that the limited rotation cannot actually reach.
		joints[elbow] = joints[arm]+rotations[arm]*(Body.REST[elbow]-Body.REST[arm])
		joints[hand] = joints[elbow]+rotations[elbow]*(Body.REST[hand]-Body.REST[elbow])
		var target = ground_target(joints[hand],anchor,normal,radius,-old_hand.z)
		# Blend the shaft direction before pronation/wrist limits. Global hand
		# slerp toward the old tuck orientation let a connected pole cut inward.
		var recovery = joints[hand]+old_hand*wrist_to_tip
		recovery.x = side*maxf(side*recovery.x,side*joints[hand].x+.10)
		target = joints[hand]+(recovery-joints[hand]).lerp(target-joints[hand],weight).normalized()*radius
		var axis: Vector3 = (Body.REST[hand]-Body.REST[elbow]).normalized()
		var z = -(target-joints[hand]).normalized()
		var x: Vector3 = (rotations[elbow]*axis*signf(axis.x)).slide(z).normalized()
		if x.length_squared()<.5: x = old_hand.x.slide(z).normalized()
		var carry = Basis(x,z.cross(x),z)
		var aimed = Basis(Quaternion((carry*wrist_to_tip).normalized(),(target-joints[hand]).normalized()))*carry
		# Pronation belongs in the forearm. Keep the established elbow hinge and
		# transfer only roll; this cannot move the wrist or loosen the glove grip.
		var hinge = Anatomy.local_limit(elbow,rotations[arm].transposed()*rotations[elbow],0.0,0.0)
		var neutral: Basis = rotations[arm]*hinge
		var roll = clampf(Anatomy.twist_angle(neutral.transposed()*aimed,axis),-deg_to_rad(170.0),deg_to_rad(170.0))
		var pronated: Basis = neutral*Basis(axis,roll)
		rotations[elbow] = rotations[elbow].orthonormalized().slerp(pronated.orthonormalized(),carry_weight)
		var limited: Basis = rotations[elbow]*Anatomy.local_limit(hand,rotations[elbow].transposed()*aimed,0.0,1.0)
		rotations[hand] = old_hand.orthonormalized().slerp(limited.orthonormalized(),carry_weight)
		var tip: Vector3 = joints[hand]+rotations[hand]*wrist_to_tip
		gaps.append(tip.distance_to(anchor))
		heights.append((tip-anchor).dot(normal))
		moves.append(joints[hand].distance_to(old_wrist))
		targets.append(root_frame*target)
		angles.append(Anatomy.vector((old_hand.transposed()*rotations[hand]).get_rotation_quaternion()).length())
	return result
