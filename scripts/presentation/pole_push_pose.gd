extends RefCounted
## Source action owns torso/arms before tracking; connected snow contact is cosmetic.
const Anatomy = preload("res://scripts/presentation/skier_anatomy.gd")
const Body = preload("res://scripts/core/rider_body.gd")
const Motion = preload("res://assets/animation/pole_push_cycle.tres")
const TIP_LENGTH = 1.18

static func fit_carry_clearance(joints: Dictionary, rotations: Dictionary, pole_carry: float, articulated_carry: float) -> Array:
	# Final fitting can move a carrying wrist after the source aimed its pole.
	# Keep the rigid shaft outside small clothing envelopes in that FINAL pose.
	# This is cosmetic geometry only, with no terrain/physics query or history.
	var corrections: Array = []
	for prefix in ["Right","Left"]:
		var side = -1.0 if prefix=="Right" else 1.0
		var hand = prefix+"Hand"; var elbow = prefix+"ForeArm"; var arm = prefix+"Arm"
		var old_hand: Basis = rotations[hand]
		var grip: Vector3 = joints[hand]+old_hand*Vector3(side*.070,0,.018)
		var direction = -old_hand.z
		var envelopes = [[joints.Hips,joints.Spine02,.19],[joints.Spine02,joints.Spine,.20],
			[joints[prefix+"UpLeg"],joints[prefix+"Leg"],.115],
			[joints[arm],joints[elbow],.085],[joints[elbow],joints[hand],.065]]
		for iteration in 3:
			var changed = false
			for envelope_index in envelopes.size():
				var envelope = envelopes[envelope_index]
				var closest = Geometry3D.get_closest_points_between_segments(grip+direction*.10,grip+direction*TIP_LENGTH,envelope[0],envelope[1])
				var offset = closest[0]-closest[1]
				var radius: float = envelope[2]+.012
				var distance = offset.length()
				if distance>=radius: continue
				var away = offset/distance if distance>.0001 else Vector3.RIGHT*side
				var separation = radius-distance
				if envelope_index<3:
					# A pole above the thigh cannot always lift farther: the wrist
					# is already at its carry limit. Clear torso/legs to the side,
					# leaving the wrist hinge and fixed grip intact.
					var axis: Vector3 = (envelope[1]-envelope[0]).normalized()
					away = (Vector3.RIGHT*side).slide(axis).normalized()
					var along = offset.dot(away)
					separation = -along+sqrt(maxf(0.0,along*along+radius*radius-distance*distance))
				direction = (closest[0]+away*separation-grip).normalized()
				changed = true
			if not changed: break
		var correction = Anatomy.vector(Quaternion(-old_hand.z,direction)).limit_length(deg_to_rad(20.0))
		corrections.append(correction.length())
		if correction.length_squared()<.00000001: continue
		var aimed = Anatomy.basis(correction)*old_hand
		var axis: Vector3 = (Body.REST[hand]-Body.REST[elbow]).normalized()
		var hinge = Anatomy.local_limit(elbow,rotations[arm].transposed()*rotations[elbow],0.0,0.0)
		var neutral: Basis = rotations[arm]*hinge
		var roll = clampf(Anatomy.twist_angle(neutral.transposed()*aimed,axis),-deg_to_rad(170.0),deg_to_rad(170.0))
		rotations[elbow] = neutral*Basis(axis,roll)
		# The source has already passed the soft wrist limit. Applying its
		# easing again pulls a valid clearance correction back into the thigh.
		# Constrain this final geometric correction to the SAME hard envelope.
		var local: Basis = rotations[elbow].transposed()*aimed
		var twist = Anatomy.twist_angle(local,axis)
		var swing = Anatomy.vector((local*Basis(axis,-twist)).get_rotation_quaternion())
		var carry = clampf(pole_carry,0.0,1.0)
		var swing_limit = deg_to_rad(lerpf(lerpf(28.0,80.0,carry),80.0,articulated_carry))
		var twist_limit = deg_to_rad(lerpf(lerpf(55.0,90.0,carry),30.0,articulated_carry))
		rotations[hand] = rotations[elbow]*Anatomy.basis(swing.limit_length(swing_limit))*Basis(axis,clampf(twist,-twist_limit,twist_limit))
	return corrections

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
		joints[elbow] = Body.joint(joints[arm],wrist,upper,lower,Vector3(side*.25,-.5,-1.0))
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

static func connected_arm(prefix: String, shoulder: Basis, position: Vector3, wanted: Vector3, old_elbow: Vector3) -> Dictionary:
	# Keep the tracked source bend while fitting the planted wrist. Searching
	# for an outward bend or locking elbows to a frontal plane both displaced
	# the authored arm: the former flared it, the latter snapped below shoulder
	# height. One connected solve retains the source's compact elbow passage.
	var upper_rest: Vector3 = Body.REST[prefix+"ForeArm"]-Body.REST[prefix+"Arm"]
	var lower_rest: Vector3 = Body.REST[prefix+"Hand"]-Body.REST[prefix+"ForeArm"]
	var axis = Anatomy.hinge_axis(prefix,true)
	var elbow = Body.joint(position,wanted,upper_rest.length(),lower_rest.length(),old_elbow-position)
	var up = (elbow-position).normalized(); var down = (wanted-elbow).normalized()
	var normal = up.cross(down).normalized()
	var upper = Anatomy.segment_frame(up,normal)*Anatomy.segment_frame(upper_rest.normalized(),axis).transposed()
	var lower = Anatomy.segment_frame(down,normal)*Anatomy.segment_frame(lower_rest.normalized(),axis).transposed()
	return {"upper":Anatomy.local_limit(prefix+"Arm",shoulder.transposed()*upper),
		"lower":Anatomy.local_limit(prefix+"ForeArm",upper.transposed()*lower,0.0,1.0),"angle":0.0,"probes":1}

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
		reference.x = side*maxf(absf(reference.x),.28)
		# Keep the exported backward stroke during the fast/intensity-tapered
		# tuck too. Closest-to-tracked-wrist alone delayed that stroke until AFTER
		# force. The source Y/lateral carry and 30 cm accommodation bound remain.
		reference.z = lerpf(old_wrist.z,joints[arm].z+control.wrist.z,.45)
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
		# Apply lateral carry once from the unfitted source wrist. Blending the
		# already fitted wrist again makes first contact jump almost to full reach.
		wanted.x = lerpf(old_wrist.x,side*maxf(side*old_wrist.x,.28),carry_weight)
		wanted = old_wrist+(wanted-old_wrist).limit_length(.30)
		var fitted = connected_arm(prefix,rotations[shoulder],joints[arm],wanted,joints[elbow])
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
		# Blend the desired global palm first, then solve pronation and the
		# wrist against that one target. Blending the forearm before limiting
		# the wrist and blending the palm again changes the shaft's release arc.
		aimed = old_hand.orthonormalized().slerp(aimed.orthonormalized(),carry_weight)
		# Pronation belongs in the forearm. Keep the established elbow hinge and
		# transfer only roll; this cannot move the wrist or loosen the glove grip.
		var hinge = Anatomy.local_limit(elbow,rotations[arm].transposed()*rotations[elbow],0.0,0.0)
		var neutral: Basis = rotations[arm]*hinge
		var roll = clampf(Anatomy.twist_angle(neutral.transposed()*aimed,axis),-deg_to_rad(170.0),deg_to_rad(170.0))
		var pronated: Basis = neutral*Basis(axis,roll)
		rotations[elbow] = pronated
		var limited: Basis = rotations[elbow]*Anatomy.local_limit(hand,rotations[elbow].transposed()*aimed,0.0,1.0)
		rotations[hand] = limited
		var tip: Vector3 = joints[hand]+rotations[hand]*wrist_to_tip
		gaps.append(tip.distance_to(anchor))
		heights.append((tip-anchor).dot(normal))
		moves.append(joints[hand].distance_to(old_wrist))
		targets.append(root_frame*target)
		angles.append(Anatomy.vector((old_hand.transposed()*rotations[hand]).get_rotation_quaternion()).length())
	return result
