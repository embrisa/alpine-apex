extends RefCounted
## Reviewed downhill articulation, applied before the existing tick tracker.
## Model-space joint targets only: never writes physical rider or ski state.
const Anatomy = preload("res://scripts/presentation/skier_anatomy.gd")
const Body = preload("res://scripts/core/rider_body.gd")

static func straight(state: Dictionary) -> float:
	# Full-curve navigation supplies one physical response weight to source,
	# posture and pelvis fitting. Keep the procedural comparison's own channels.
	if state.has("turn_strength"): return 1.0-state.turn_strength
	# Release for light steering and keep it released while the existing bank
	# or turn rate persists after the rider lets go of the steering input.
	# The carve channel contains up to 0.20 of load asymmetry even while going
	# straight. That alone must not trigger a turn pose on uneven snow.
	return (1.0-smoothstep(.015,.06,absf(state.get("steer",0.0))))*(1.0-smoothstep(.22,.40,absf(state.get("carve",0.0))))*(1.0-smoothstep(.10,.25,absf(state.get("turn_follow",0.0))))

static func weight(state: Dictionary) -> float:
	return straight(state)*(1.0-state.get("air",0.0))*(1.0-state.get("brake",0.0))*(1.0-state.get("grab",0.0))

static func apply(pose: Dictionary, library: Dictionary, state: Dictionary, amount: float) -> void:
	if amount<.00001: return
	var tuck: float = clampf(state.tuck,0,1)
	var prep: float = smoothstep(0,1,state.prepare)
	var fold = pow(tuck,.65)
	# Progressive hip hinge, continuous lumbar curve and open upper chest.
	# Small source deviations preserve breathing and counterbalance in the clip.
	var angles = {
		"Hips":lerpf(lerpf(16,52,fold),52,prep),
		"Spine02":lerpf(lerpf(3,13,fold),15,prep),
		"Spine01":lerpf(lerpf(3,12,fold),12,prep),
		"Spine":lerpf(lerpf(-2,-7,fold),-7,prep)}
	for name in angles:
		var i: int = library.names.find(name)
		var v = Anatomy.vector(pose.q[i])
		var target = Vector3(deg_to_rad(angles[name]),v.y*.25,v.z*.30)
		pose.q[i] = pose.q[i].slerp(Anatomy.basis(target).get_rotation_quaternion(),amount)
	var joints = {"Hips":Vector3.ZERO}
	var rotations = {"Hips":Basis(pose.q[library.names.find("Hips")])}
	for name in ["Spine02","Spine01","Spine","neck","Head"]:
		var i: int = library.names.find(name)
		var parent: String = library.names[library.parents[i]]
		if name in ["neck","Head"]:
			var parent_pitch: float = atan2(rotations[parent].y.z,rotations[parent].y.y)
			var correction = clampf(deg_to_rad(8)-parent_pitch,deg_to_rad(-22 if name=="neck" else -30),deg_to_rad(18))
			pose.q[i] = pose.q[i].slerp(Quaternion(Vector3.RIGHT,correction),amount)
		rotations[name] = rotations[parent]*Anatomy.local_limit(name,Basis(pose.q[i]))
		joints[name] = joints[parent]+rotations[parent]*(Body.REST[name]-Body.REST[parent])
	var compact: float = maxf(tuck,prep)
	# Settle the narrower carry only once the chest has folded. Retain room
	# between the sleeve and torso while entering or rising out of the tuck.
	var settle = smoothstep(.85,.98,compact)
	for prefix in ["Right","Left"]:
		var side = -1.0 if prefix=="Right" else 1.0
		var clavicle = prefix+"Shoulder"
		var arm = prefix+"Arm"
		var elbow = prefix+"ForeArm"
		var hand = prefix+"Hand"
		var ci: int = library.names.find(clavicle)
		var ai: int = library.names.find(arm)
		var ei: int = library.names.find(elbow)
		var hi: int = library.names.find(hand)
		pose.q[ci] = pose.q[ci].slerp(Quaternion.IDENTITY,amount*.85)
		rotations[clavicle] = rotations.Spine*Anatomy.local_limit(clavicle,Basis(pose.q[ci]))
		joints[clavicle] = joints.Spine+rotations.Spine*(Body.REST[clavicle]-Body.REST.Spine)
		joints[arm] = joints[clavicle]+rotations[clavicle]*(Body.REST[arm]-Body.REST[clavicle])
		var shoulder: Vector3 = joints[arm]
		var gather = smoothstep(0.0,.65,compact)
		var wrist = Vector3(side*lerpf(.26,.10,gather),shoulder.y+lerpf(-.24,-.18,smoothstep(.25,1.0,compact)),shoulder.z+.26)
		wrist += Vector3(side*.04,-.035,-.025)*settle
		var upper: float = Body.REST[arm].distance_to(Body.REST[elbow])
		var lower: float = Body.REST[elbow].distance_to(Body.REST[hand])
		joints[hand] = wrist
		var elbow_out = lerpf(.8,.5,smoothstep(0.0,.5,compact))-.20*settle
		joints[elbow] = Body.joint(shoulder,wrist,upper,lower,Vector3(side*elbow_out,-1.0,0.0))
		rotations[arm] = rotations[clavicle]*Basis(pose.q[ai])
		Anatomy.fit_hinge(prefix,true,joints,rotations)
		var arm_local: Basis = rotations[clavicle].transposed()*rotations[arm]
		var elbow_local: Basis = rotations[arm].transposed()*rotations[elbow]
		arm_local = Anatomy.local_limit(arm,Anatomy.local_limit(arm,arm_local))
		rotations[arm] = rotations[clavicle]*arm_local
		rotations[elbow] = rotations[arm]*elbow_local
		joints[elbow] = shoulder+rotations[arm]*(Body.REST[elbow]-Body.REST[arm])
		joints[hand] = joints[elbow]+rotations[elbow]*(Body.REST[hand]-Body.REST[elbow])
		# Aim the fixed palm socket through a narrow passage beside the hip.
		# Resolve the same anatomical roll branch on both sides; the forearm
		# takes pronation while the wrist retains a modest bend.
		var passage = Vector3(side*.25,lerpf(-.12,.07,compact)-.07*settle,0.0)
		var grip: Vector3 = joints[hand]
		var aimed = Basis.IDENTITY
		for iteration in 4:
			var z = (grip-passage).normalized()
			var x = rotations[elbow].x.slide(z).normalized()
			aimed = Basis(x,z.cross(x),z)
			grip = joints[hand]+aimed*Vector3(side*.070,0,.018)
		var hand_axis = (Body.REST[hand]-Body.REST[elbow]).normalized()
		var wrist_local: Basis = rotations[elbow].transposed()*aimed
		var roll = Anatomy.twist_angle(wrist_local,hand_axis)
		elbow_local *= Basis(hand_axis,roll)
		wrist_local = Basis(hand_axis,-roll)*wrist_local
		pose.q[ai] = pose.q[ai].slerp(arm_local.get_rotation_quaternion(),amount)
		pose.q[ei] = pose.q[ei].slerp(elbow_local.get_rotation_quaternion(),amount)
		pose.q[hi] = pose.q[hi].slerp(wrist_local.get_rotation_quaternion(),amount)
