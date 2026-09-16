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

# Rest geometry is immutable for this script lifetime. Dynamic joint rotations,
# anatomical limits, iteration order and convergence remain evaluated per pose.
static var rest_sides: Dictionary = prepare_rest_sides()

static func prepare_rest_sides() -> Dictionary:
	var result = {}
	for prefix in ["Right","Left"]:
		var upper: Vector3 = Body.REST[prefix+"ForeArm"]-Body.REST[prefix+"Arm"]
		var lower: Vector3 = Body.REST[prefix+"Hand"]-Body.REST[prefix+"ForeArm"]
		var arm_axis = upper.cross(Vector3.BACK).normalized()
		var lower_unit = lower.normalized()
		var zero = Basis(Quaternion(lower_unit,lower_unit.slide(arm_axis).normalized()))
		var thigh_vector: Vector3 = Body.REST[prefix+"Leg"]-Body.REST[prefix+"UpLeg"]
		var shin_vector: Vector3 = Body.REST[prefix+"Foot"]-Body.REST[prefix+"Leg"]
		var leg_axis = thigh_vector.cross(shin_vector).normalized()
		var thigh: float = Body.REST[prefix+"UpLeg"].distance_to(Body.REST[prefix+"Leg"])
		var shin: float = Body.REST[prefix+"Leg"].distance_to(Body.REST[prefix+"Foot"])
		var side = {"arm_axis":arm_axis,"leg_axis":leg_axis,"arm_upper":upper,"arm_lower":lower,
			"arm_upper_unit":upper.normalized(),"arm_lower_unit":lower_unit,"elbow_zero":zero,
			"rest_bend":upper.signed_angle_to(zero*lower,arm_axis),
			"arm_upper_inverse":segment_frame(upper.normalized(),arm_axis).transposed(),
			"arm_lower_inverse":segment_frame(lower_unit,arm_axis).transposed(),
			"leg_upper_inverse":segment_frame(thigh_vector.normalized(),leg_axis).transposed(),
			"leg_lower_inverse":segment_frame(shin_vector.normalized(),leg_axis).transposed(),
			"hip_offset":Body.REST[prefix+"UpLeg"]-Body.REST.Hips,"thigh":thigh,"shin":shin,
			"minimum":sqrt(thigh*thigh+shin*shin+2.0*thigh*shin*cos(deg_to_rad(150.0)))}
		side.make_read_only(); result[prefix] = side
	result.make_read_only()
	return result

static func hinge_axis(prefix: String, arm: bool) -> Vector3:
	return rest_sides[prefix].arm_axis if arm else rest_sides[prefix].leg_axis

static func elbow_zero(prefix: String) -> Basis:
	return rest_sides[prefix].elbow_zero

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
	if native_limits_enabled: return native_fit_kernel.local_limit(id,rotation,pole_carry,forearm_carry)
	return reference_local_limit(id,rotation,pole_carry,forearm_carry)

static func reference_local_limit(id: String, rotation: Basis, pole_carry: float = 0.0, forearm_carry: float = 0.0) -> Basis:
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
		var rest: Dictionary = rest_sides[prefix]
		var upper: Vector3 = rest.arm_upper
		var lower: Vector3 = rest.arm_lower
		var zero: Basis = rest.elbow_zero
		var rest_bend: float = rest.rest_bend
		var direction = (rotation*lower).slide(axis).normalized()
		var angle = upper.signed_angle_to(direction,axis)
		# Elbow flexion stays in one plane. Forearm pronation rotates about the
		# lower segment afterwards, so it cannot move the wrist off that plane.
		angle = clampf(angle,deg_to_rad(6.0),deg_to_rad(145.0))
		var hinge = Basis(axis,angle-rest_bend)*zero
		var roll = twist_angle(hinge.transposed()*rotation,rest.arm_lower_unit)
		return hinge*Basis(rest.arm_lower_unit,clampf(roll,-deg_to_rad(170)*forearm_carry,deg_to_rad(170)*forearm_carry))
	if id.ends_with("Arm"):
		var axis: Vector3 = rest_sides[prefix].arm_upper_unit
		return swing_twist(rotation,axis,125.0,55.0)
	if id.ends_with("Hand"):
		var axis: Vector3 = rest_sides[prefix].arm_lower_unit
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
	rotations[a] = segment_frame(u,normal)*(rest_sides[prefix].arm_upper_inverse if arm else rest_sides[prefix].leg_upper_inverse)
	rotations[b] = segment_frame(l,normal)*(rest_sides[prefix].arm_lower_inverse if arm else rest_sides[prefix].leg_lower_inverse)

static func leg_twist(prefix: String, hip: Vector3, knee: Vector3, ankle: Vector3, boot: Basis) -> float:
	var lower = (ankle-knee).normalized()
	var normal = (knee-hip).normalized().cross(lower).normalized()
	var shin = segment_frame(lower,normal)*rest_sides[prefix].leg_lower_inverse
	return twist_angle(boot.transposed()*shin,Vector3.UP)

# Native math keeps this reference implementation available for verification
# and platforms without a packaged library. No solver or pose cadence changes.
static var native_fit_kernel = prepare_native_fit()
static var native_fit_enabled = native_fit_kernel!=null
static var native_limits_enabled = native_fit_kernel!=null
static var native_render_knee_enabled = native_fit_kernel!=null

static func prepare_native_fit():
	var kernel = preload("res://scripts/core/skier_kernel.gd").create("AlpineSkierAnatomy")
	if kernel!=null: kernel.configure(rest_sides)
	return kernel

static func fit_render_knee(prefix: String, hip: Vector3, ankle: Vector3, source_knee: Vector3, boot: Basis, thigh: float, shin: float, weight: float) -> Vector3:
	if native_render_knee_enabled: return native_fit_kernel.fit_render_knee(prefix,hip,ankle,source_knee,boot,thigh,shin,weight)
	return reference_render_knee(prefix,hip,ankle,source_knee,boot,thigh,shin,weight)

static func reference_render_knee(prefix: String, hip: Vector3, ankle: Vector3, source_knee: Vector3, boot: Basis, thigh: float, shin: float, weight: float) -> Vector3:
	# Retain source knee direction only inside the rigid cuff and twist envelope.
	# Fade an undefined source pole near the hip/ankle axis before normalizing.
	var cuff = Body.leg_joint(hip,ankle,thigh,shin,boot)
	var delta = (ankle-hip).normalized()
	var hint = (cuff-hip).slide(delta).normalized()
	var source_pole = (source_knee-hip).slide(delta)
	var native_hint = source_pole.normalized()
	var pole_weight = smoothstep(.03,.12,source_pole.length())
	var angle = hint.cross(native_hint).dot(delta)*deg_to_rad(10.0)*weight*pole_weight
	var lo = 0.0; var hi = 1.0
	var knee = cuff
	for iteration in 10:
		var t = (lo+hi)*.5
		var candidate = Body.joint(hip,ankle,thigh,shin,hint.rotated(delta,angle*t))
		var axis = boot.transposed()*(candidate-ankle).normalized()
		var side_angle = absf(atan2(axis.x,axis.y))
		var flex = atan2(axis.z,axis.y)
		if side_angle<=deg_to_rad(10.05) and flex>=deg_to_rad(-.05) and flex<=deg_to_rad(CUFF_FLEX_DEGREES+.05) and absf(leg_twist(prefix,hip,candidate,ankle,boot))<deg_to_rad(18.0):
			lo = t; knee = candidate
		else: hi = t
	return knee

static func fit_pelvis(hips: Vector3, pelvis: Basis, ankles: Array[Vector3], boots: Array[Basis]) -> Vector3:
	if native_fit_enabled: return native_fit_kernel.fit_pelvis(hips,pelvis,ankles,boots)
	return reference_fit_pelvis(hips,pelvis,ankles,boots)

static func reference_fit_pelvis(hips: Vector3, pelvis: Basis, ankles: Array[Vector3], boots: Array[Basis]) -> Vector3:
	# Cuff position alone permits a sideways folded thigh with a twisted tibia.
	# Fit the shared pelvis to the hinge planes as well as the two reach spheres.
	var sides: Array = [rest_sides.Right,rest_sides.Left]
	var hip_offsets: Array[Vector3] = [pelvis*sides[0].hip_offset,pelvis*sides[1].hip_offset]
	var boot_inverse: Array[Basis] = [boots[0].transposed(),boots[1].transposed()]
	for iteration in 12:
		hips = Body.fit_hips(hips,pelvis,ankles,boots)
		var largest = 0.0
		for i in 2:
			var prefix = "Right" if i==0 else "Left"
			var hip: Vector3 = hips+hip_offsets[i]
			var thigh: float = sides[i].thigh
			var shin: float = sides[i].shin
			var minimum: float = sides[i].minimum
			var delta = hip-ankles[i]
			if delta.length()<minimum:
				var shift = delta.normalized()*(minimum-delta.length())
				hips += shift; hip += shift; largest = maxf(largest,shift.length())
			var knee = Body.leg_joint(hip,ankles[i],thigh,shin,boots[i])
			# A low rigid ski boot cannot follow the old 32-degree forward shin
			# pose. Recover that excess through the shared pelvis, not by pushing
			# a knee independently or stretching the trouser calf above the cuff.
			var cuff_axis: Vector3 = boot_inverse[i]*(knee-ankles[i]).normalized()
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
