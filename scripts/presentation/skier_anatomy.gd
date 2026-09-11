extends RefCounted
## Presentation joint contract in calibrated model axes. These are authored
## skiing pose limits, not changes to RiderBody's physical mass or balance.
const Body = preload("res://scripts/core/rider_body.gd")
const CUFF_FLEX_DEGREES = 24.0

static func vector(q: Quaternion) -> Vector3:
	q = q.normalized()
	if q.w<0.0: q = -q
	var xyz = Vector3(q.x,q.y,q.z)
	return xyz.normalized()*2.0*atan2(xyz.length(),maxf(0.0,q.w))

static func basis(v: Vector3) -> Basis:
	return Basis(v.normalized(),v.length()) if v.length_squared()>.00000001 else Basis.IDENTITY

static func soft(value: float, low: float, high: float) -> float:
	# Identity through the inner 85%; finite smooth slope into a firm envelope.
	var limit = high if value>=0.0 else -low
	var magnitude = absf(value)
	var start = limit*.85
	if magnitude>start: magnitude = start+(limit-start)*(1.0-exp(-(magnitude-start)/(limit-start)))
	return signf(value)*magnitude

static func box(rotation: Basis, low: Vector3, high: Vector3) -> Basis:
	var v = vector(rotation.get_rotation_quaternion())
	for i in 3: v[i] = soft(v[i],deg_to_rad(low[i]),deg_to_rad(high[i]))
	return basis(v)

static func hinge_axis(prefix: String, arm: bool) -> Vector3:
	var a = prefix+("Arm" if arm else "UpLeg")
	var b = prefix+("ForeArm" if arm else "Leg")
	var c = prefix+("Hand" if arm else "Foot")
	# The almost straight rest forearm contains a small modelling offset. Its
	# cross product is not the functional elbow axis (it tilts ~30 degrees and
	# sends a flexed hand outwards). Elbows flex towards anatomical forward.
	if arm: return (Body.REST[b]-Body.REST[a]).cross(Vector3.BACK).normalized()
	return (Body.REST[b]-Body.REST[a]).cross(Body.REST[c]-Body.REST[b]).normalized()

static func elbow_zero(prefix: String) -> Basis:
	var lower: Vector3 = (Body.REST[prefix+"Hand"]-Body.REST[prefix+"ForeArm"]).normalized()
	var projected = lower.slide(hinge_axis(prefix,true)).normalized()
	return Basis(Quaternion(lower,projected))

static func twist_angle(rotation: Basis, axis: Vector3) -> float:
	var q = rotation.get_rotation_quaternion().normalized()
	return wrapf(2.0*atan2(Vector3(q.x,q.y,q.z).dot(axis),q.w),-PI,PI)

static func swing_twist(rotation: Basis, axis: Vector3, swing_degrees: float, twist_degrees: float) -> Basis:
	var twist = twist_angle(rotation,axis)
	var swing = rotation*Basis(axis,-twist)
	var v = vector(swing.get_rotation_quaternion())
	var angle = v.length()
	var limited = soft(angle,-deg_to_rad(swing_degrees),deg_to_rad(swing_degrees))
	return basis(v.normalized()*limited)*Basis(axis,soft(twist,-deg_to_rad(twist_degrees),deg_to_rad(twist_degrees)))

static func local_limit(id: String, rotation: Basis, pole_carry: float = 0.0, forearm_carry: float = 0.0) -> Basis:
	if id=="Hips": return box(rotation,Vector3(-18,-25,-32),Vector3(55,25,32))
	if id in ["Spine02","Spine01","Spine"]:
		return box(rotation,Vector3(-8,-10,-8),Vector3(20,10,8))
	if id=="neck": return box(rotation,Vector3(-22,-28,-14),Vector3(22,28,14))
	if id=="Head": return box(rotation,Vector3(-30,-30,-12),Vector3(24,30,12))
	var prefix = "Right" if id.begins_with("Right") else "Left"
	if id.ends_with("Shoulder"):
		return box(rotation,Vector3(-12,-15,-12),Vector3(12,15,12))
	if id.ends_with("ForeArm"):
		var axis = hinge_axis(prefix,true)
		var upper: Vector3 = Body.REST[prefix+"ForeArm"]-Body.REST[prefix+"Arm"]
		var lower: Vector3 = Body.REST[prefix+"Hand"]-Body.REST[prefix+"ForeArm"]
		var zero = elbow_zero(prefix)
		var rest_bend = upper.signed_angle_to(zero*lower,axis)
		var direction = (rotation*lower).slide(axis).normalized()
		var angle = upper.signed_angle_to(direction,axis)
		# Elbow flexion stays in one plane. Forearm pronation rotates about the
		# lower segment afterwards, so it cannot move the wrist off that plane.
		angle = clampf(angle,deg_to_rad(6.0),deg_to_rad(145.0))
		var hinge = Basis(axis,angle-rest_bend)*zero
		var roll = twist_angle(hinge.transposed()*rotation,lower.normalized())
		return hinge*Basis(lower.normalized(),clampf(roll,-deg_to_rad(170)*forearm_carry,deg_to_rad(170)*forearm_carry))
	if id.ends_with("Arm"):
		var axis: Vector3 = (Body.REST[prefix+"ForeArm"]-Body.REST[id]).normalized()
		return swing_twist(rotation,axis,125.0,55.0)
	if id.ends_with("Hand"):
		var axis: Vector3 = (Body.REST[id]-Body.REST[prefix+"ForeArm"]).normalized()
		# Downhill carry uses ForeArm for pronation and only bends the wrist to
		# cradle a backward pole. Other source contributions retain their limits.
		return swing_twist(rotation,axis,lerpf(lerpf(28.0,80.0,clampf(pole_carry,0,1)),80.0,forearm_carry),lerpf(lerpf(55.0,90.0,clampf(pole_carry,0,1)),30.0,forearm_carry))
	return rotation

static func segment_frame(direction: Vector3, hinge: Vector3) -> Basis:
	var normal = hinge.slide(direction).normalized()
	return Basis(direction,normal,direction.cross(normal).normalized())

static func fit_hinge(prefix: String, arm: bool, joints: Dictionary, rotations: Dictionary) -> void:
	var a = prefix+("Arm" if arm else "UpLeg")
	var b = prefix+("ForeArm" if arm else "Leg")
	var c = prefix+("Hand" if arm else "Foot")
	var u: Vector3 = (joints[b]-joints[a]).normalized()
	var l: Vector3 = (joints[c]-joints[b]).normalized()
	var normal = u.cross(l).normalized()
	if normal.length_squared()<.5: normal = rotations[a]*hinge_axis(prefix,arm)
	var original = hinge_axis(prefix,arm)
	rotations[a] = segment_frame(u,normal)*segment_frame((Body.REST[b]-Body.REST[a]).normalized(),original).transposed()
	rotations[b] = segment_frame(l,normal)*segment_frame((Body.REST[c]-Body.REST[b]).normalized(),original).transposed()

static func leg_twist(prefix: String, hip: Vector3, knee: Vector3, ankle: Vector3, boot: Basis) -> float:
	var lower = (ankle-knee).normalized()
	var normal = (knee-hip).normalized().cross(lower).normalized()
	var shin = segment_frame(lower,normal)*segment_frame((Body.REST[prefix+"Foot"]-Body.REST[prefix+"Leg"]).normalized(),hinge_axis(prefix,false)).transposed()
	return twist_angle(boot.transposed()*shin,Vector3.UP)

static func fit_pelvis(hips: Vector3, pelvis: Basis, ankles: Array[Vector3], boots: Array[Basis]) -> Vector3:
	# Cuff position alone permits a sideways folded thigh with a twisted tibia.
	# Fit the shared pelvis to the hinge planes as well as the two reach spheres.
	for iteration in 12:
		hips = Body.fit_hips(hips,pelvis,ankles,boots)
		var largest = 0.0
		for i in 2:
			var prefix = "Right" if i==0 else "Left"
			var hip: Vector3 = hips+pelvis*(Body.REST[prefix+"UpLeg"]-Body.REST.Hips)
			var thigh: float = Body.REST[prefix+"UpLeg"].distance_to(Body.REST[prefix+"Leg"])
			var shin: float = Body.REST[prefix+"Leg"].distance_to(Body.REST[prefix+"Foot"])
			var minimum = sqrt(thigh*thigh+shin*shin+2.0*thigh*shin*cos(deg_to_rad(150.0)))
			var delta = hip-ankles[i]
			if delta.length()<minimum:
				var shift = delta.normalized()*(minimum-delta.length())
				hips += shift; hip += shift; largest = maxf(largest,shift.length())
			var knee = Body.leg_joint(hip,ankles[i],thigh,shin,boots[i])
			# A low rigid ski boot cannot follow the old 32-degree forward shin
			# pose. Recover that excess through the shared pelvis, not by pushing
			# a knee independently or stretching the trouser calf above the cuff.
			var cuff_axis: Vector3 = boots[i].transposed()*(knee-ankles[i]).normalized()
			var flex = atan2(cuff_axis.z,cuff_axis.y)
			if flex>deg_to_rad(CUFF_FLEX_DEGREES):
				var allowed_axis = cuff_axis.rotated(Vector3.RIGHT,deg_to_rad(CUFF_FLEX_DEGREES)-flex)
				var fitted_knee = ankles[i]+boots[i]*allowed_axis*shin
				var cuff_shift = fitted_knee+(hip-fitted_knee).normalized()*thigh-hip
				hips += cuff_shift; hip += cuff_shift; largest = maxf(largest,cuff_shift.length())
				knee = Body.leg_joint(hip,ankles[i],thigh,shin,boots[i])
			var lower = (ankles[i]-knee).normalized()
			var normal = (knee-hip).normalized().cross(lower).normalized()
			var twist = leg_twist(prefix,hip,knee,ankles[i],boots[i])
			var allowed = soft(twist,-deg_to_rad(14.0),deg_to_rad(14.0))
			if absf(twist-allowed)<.0001: continue
			# Rotate the required hinge plane towards the boot, then project the
			# hip into that plane without changing the femur's length.
			var plane = normal.rotated(-lower,allowed-twist)
			var corrected = knee+(hip-knee).slide(plane).normalized()*thigh
			var shift = corrected-hip
			hips += shift; largest = maxf(largest,shift.length())
		if largest<.00005: break
	return Body.fit_hips(hips,pelvis,ankles,boots)
