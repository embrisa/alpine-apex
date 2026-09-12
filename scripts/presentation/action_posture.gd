extends RefCounted
## Action-specific articulation before the existing fixed-tick pose tracker.
## Input channels are presentation telemetry; this never writes solver state.
const Anatomy = preload("res://scripts/presentation/skier_anatomy.gd")
const Body = preload("res://scripts/core/rider_body.gd")
const Downhill = preload("res://scripts/presentation/downhill_posture.gd")

static func weights(state: Dictionary, landing_age: float, forward: bool, physical_bank: float, free_air: float) -> Vector3:
	if not forward: return Vector3.ZERO
	var free: float = (1.0-state.grab)*(1.0-state.recoil)
	# Set the brace before contact, then preserve it across the support blend.
	# A maximum of the two channels makes the elbows flare at touchdown.
	var brace: float = smoothstep(0.0,.65,state.ready)
	var land: float = (1.0-smoothstep(.25,.80,landing_age))*(1.0-state.air)+brace*state.air
	var balancing: float = state.turn_strength if state.has("turn_strength") else maxf(1.0-Downhill.straight(state),smoothstep(.25,.60,absf(physical_bank)))
	var turn: float = balancing*(1.0-state.air)*(1.0-state.prepare)*(1.0-state.brake)*(1.0-land)
	# Complementary support/air weights preserve the prepared carry at release.
	# Taking their maximum would halve it mid-transition and pull hands forward.
	# Keep ordinary small-hop carry until the brace takes over. Returning to
	# compact legacy carry after .44 s swept shafts into the thighs. The
	# existing wide-air/trick gate still releases authored airborne motion.
	var depart: float = (state.prepare*(1.0-state.air)+state.air*(1.0-free_air))*(1.0-brace)
	return Vector3(turn,depart,land)*free

static func apply(pose: Dictionary, library: Dictionary, state: Dictionary, action: Vector3, air_age: float) -> void:
	var amount = clampf(action.x+action.y+action.z,0.0,1.0)
	if amount<.00001: return
	var mix = action/maxf(action.x+action.y+action.z,.00001)
	# Carving keeps the authored shoulder/elbow extension and its moving
	# counterbalance. The stable body target must not pin both arms to one pose.
	# Departure/impact retain their reviewed connected-chain targets.
	var arm_amount = clampf(action.x*.25+action.y+action.z,0.0,1.0)
	var bank: float = state.carve
	var extension: float = smoothstep(.025,.23,air_age)*state.air
	var impact: float = state.impact
	# Open the chest during a bank, extend out of preparation on departure,
	# and fold hips/back together at impact instead of playing an upright sit.
	var angles = {
		"Hips":Vector3(25+5*absf(bank),lerpf(38,12,extension),26+16*impact),
		"Spine02":Vector3(4,lerpf(8,2,extension),5+5*impact),
		"Spine01":Vector3(3,lerpf(6,2,extension),3+4*impact),
		"Spine":Vector3(-4,-3,-4)}
	for name in angles:
		var i: int = library.names.find(name)
		var v = Anatomy.vector(pose.q[i])
		var roll = bank*(24.0 if name=="Hips" else -3.5)*mix.x
		var yaw: float = -state.steer*(7.0 if name=="Hips" else -2.0)*mix.x
		var target = Vector3(deg_to_rad(angles[name].dot(mix)),deg_to_rad(yaw)+v.y*.10,deg_to_rad(roll)+v.z*.10)
		pose.q[i] = pose.q[i].slerp(Anatomy.basis(target).get_rotation_quaternion(),amount)
	var joints = {"Hips":Vector3.ZERO}
	var rotations = {"Hips":Anatomy.local_limit("Hips",Basis(pose.q[library.names.find("Hips")]))}
	for name in ["Spine02","Spine01","Spine","neck","Head"]:
		var i: int = library.names.find(name)
		var parent: String = library.names[library.parents[i]]
		if name in ["neck","Head"]:
			var pitch: float = atan2(rotations[parent].y.z,rotations[parent].y.y)
			var correction = clampf(deg_to_rad(8)-pitch,deg_to_rad(-20 if name=="neck" else -28),deg_to_rad(18))
			pose.q[i] = pose.q[i].slerp(Quaternion(Vector3.RIGHT,correction),amount)
		rotations[name] = rotations[parent]*Anatomy.local_limit(name,Basis(pose.q[i]))
		joints[name] = joints[parent]+rotations[parent]*(Body.REST[name]-Body.REST[parent])
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
		pose.q[ci] = pose.q[ci].slerp(Quaternion.IDENTITY,arm_amount*.85)
		rotations[clavicle] = rotations.Spine*Anatomy.local_limit(clavicle,Basis(pose.q[ci]))
		joints[clavicle] = joints.Spine+rotations.Spine*(Body.REST[clavicle]-Body.REST.Spine)
		joints[arm] = joints[clavicle]+rotations[clavicle]*(Body.REST[arm]-Body.REST[clavicle])
		var shoulder: Vector3 = joints[arm]
		# Free forward balance in a turn, soft backward sweep on departure,
		# hands ahead of the knees during absorption. No tuck coordinates.
		var turn_wrist = Vector3(side*(.37+.055*absf(bank)),shoulder.y-.24+side*bank*.07,shoulder.z+.25)
		var departure_open = Vector3(side*.38,shoulder.y-.20,shoulder.z+.27)
		var departure_trail = Vector3(side*.38,shoulder.y-.40,-.10)
		# The crouch provides time to sweep out of the compact racing hold.
		# Begin beside the ribs and settle behind them before physical release;
		# waiting for support loss forces the shafts across a rising jacket.
		var sweep: float = maxf(smoothstep(.30,.85,state.prepare),state.air)
		var departure_wrist = departure_open.lerp(departure_trail,sweep)
		var landing_wrist = Vector3(side*(.33+.055*impact),shoulder.y-.28,shoulder.z+.28)
		var wrist: Vector3 = turn_wrist*mix.x+departure_wrist*mix.y+landing_wrist*mix.z
		var upper: float = Body.REST[arm].distance_to(Body.REST[elbow])
		var lower: float = Body.REST[elbow].distance_to(Body.REST[hand])
		joints[hand] = wrist
		joints[elbow] = Body.joint(shoulder,wrist,upper,lower,Vector3(side*(.7-.20*mix.z),-1.0,-.15*mix.y))
		rotations[arm] = rotations[clavicle]*Basis(pose.q[ai])
		Anatomy.fit_hinge(prefix,true,joints,rotations)
		var arm_local: Basis = rotations[clavicle].transposed()*rotations[arm]
		var elbow_local: Basis = rotations[arm].transposed()*rotations[elbow]
		arm_local = Anatomy.local_limit(arm,Anatomy.local_limit(arm,arm_local))
		rotations[arm] = rotations[clavicle]*arm_local
		rotations[elbow] = rotations[arm]*elbow_local
		# Fixed grip, rigid shaft. Pronation belongs in the forearm, not all
		# in a twisted wrist. Keep the existing anatomical carry envelope.
		var trail = Vector3(side*(.24*mix.x+.12*mix.y+.18*mix.z),-.62,-1.0).normalized()
		var z = -trail
		var x = rotations[elbow].x.slide(z).normalized()
		var aimed = Basis(x,z.cross(x),z)
		var hand_axis = (Body.REST[hand]-Body.REST[elbow]).normalized()
		var wrist_local: Basis = rotations[elbow].transposed()*aimed
		var roll = Anatomy.twist_angle(wrist_local,hand_axis)
		elbow_local *= Basis(hand_axis,roll)
		wrist_local = Basis(hand_axis,-roll)*wrist_local
		pose.q[ai] = pose.q[ai].slerp(arm_local.get_rotation_quaternion(),arm_amount)
		pose.q[ei] = pose.q[ei].slerp(elbow_local.get_rotation_quaternion(),arm_amount)
		pose.q[hi] = pose.q[hi].slerp(wrist_local.get_rotation_quaternion(),arm_amount)

static func balance_roll(pose: Dictionary, library: Dictionary, bank: float, grounded_weight: float) -> void:
	if grounded_weight<.00001: return
	# Sequential partial posture blends retain part of the source's opposite
	# world bank. Give the grounded chain one support-relative roll target,
	# keeping small source sway and independent hip/spine counterbalance.
	for name in ["Hips","Spine02","Spine01","Spine"]:
		var i: int = library.names.find(name)
		var v = Anatomy.vector(pose.q[i])
		v.z = lerpf(v.z,deg_to_rad(bank*(24.0 if name=="Hips" else -3.5))+v.z*.05,grounded_weight)
		pose.q[i] = Anatomy.basis(v).get_rotation_quaternion()

static func tracked_grip_target(id: String, original: Basis, tracked: Array[Quaternion], library: Dictionary, action: Vector3) -> Basis:
	var amount = clampf(action.x+action.y+action.z,0.0,1.0)
	if amount<.00001 or not (id.ends_with("ForeArm") or id.ends_with("Hand")): return original
	var prefix = "Right" if id.begins_with("Right") else "Left"
	var side = -1.0 if prefix=="Right" else 1.0
	# Parent joints have already advanced this tick. Resolve palm aim in that
	# actual chain before the same velocity/acceleration tracker advances this
	# joint; independently tracking a wrist target in the future chest frame
	# otherwise sweeps a correctly aimed rigid shaft through the jacket.
	var rotations = {}; var joints = {}
	for i in tracked.size():
		var name: String = library.names[i]
		# Imported end markers (for example head_end) are not physical joints.
		# Match the fitted body's FK traversal instead of indexing REST for them.
		if not Body.REST.has(name): continue
		var parent: int = library.parents[i]
		if parent<0:
			rotations[name] = Basis(tracked[i]); joints[name] = Vector3.ZERO
		else:
			var pid: String = library.names[parent]
			rotations[name] = rotations[pid]*Basis(tracked[i])
			joints[name] = joints[pid]+rotations[pid]*(Body.REST[name]-Body.REST[pid])
	var lower = (Body.REST[prefix+"Hand"]-Body.REST[prefix+"ForeArm"]).normalized()
	var forearm: Basis = rotations[prefix+"ForeArm"]
	var hinge = Anatomy.local_limit(prefix+"ForeArm",original,0,0)
	if id.ends_with("ForeArm"): forearm = rotations[prefix+"Arm"]*hinge
	var wrist: Vector3 = joints[prefix+"ForeArm"]+forearm*(Body.REST[prefix+"Hand"]-Body.REST[prefix+"ForeArm"])
	var mix = action/maxf(action.x+action.y+action.z,.00001)
	var trail = Vector3(side*(.24*mix.x+.12*mix.y+.18*mix.z),-.62,-1.0).normalized()
	# While either preparing or bracing with the hands forward, keep the shaft
	# outside the pelvis. Releasing this corridor as departure becomes brace
	# sweeps the right shaft through the jacket despite clear endpoint poses.
	# Grip offset matters: the shaft is not centred on the wrist joint.
	var passage = Vector3(side*.38,-.05,0.0)
	var grip = wrist
	var corridor = trail
	for iteration in 3:
		# Keep the established departure passage; lower it with a low brace grip.
		passage.y = lerpf(-.05,minf(-.05,grip.y-.20),mix.z)
		corridor = (passage-grip).normalized()
		var aim_z = -corridor
		var aim_x = forearm.x.slide(aim_z).normalized()
		grip = wrist+Basis(aim_x,aim_z.cross(aim_x),aim_z)*Vector3(side*.070,0,.018)
	# A brace can finish while the tracked carving hand is still ahead of the
	# body. Keep that narrow forward grip's shaft in the hip corridor until
	# the arm has opened; otherwise its tip cuts across the inside knee during
	# a loaded post-landing bank. Wide balance arms retain their free trail.
	var near_body = 1.0-smoothstep(.32,.48,absf(wrist.x))
	var route = (mix.y+mix.z+mix.x*near_body)*smoothstep(.08,.32,wrist.z)
	trail = trail.slerp(corridor,route).normalized()
	var z = -trail
	var x = forearm.x.slide(z).normalized()
	var palm = Basis(x,z.cross(x),z)
	var wanted: Basis = forearm.transposed()*palm
	if id.ends_with("ForeArm"):
		wanted = hinge*Basis(lower,Anatomy.twist_angle(wanted,lower))
	# FK and palm projection can accumulate roundoff. Basis.slerp casts both
	# inputs directly to quaternions, so restore rigid rotations first.
	return original.orthonormalized().slerp(wanted.orthonormalized(),amount)


