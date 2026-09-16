extends RefCounted
## Articulated balance controller; no Nodes or renderer input.
## Segment masses contribute to COM/inertia. Ground reaction is limited by the
## two ski support footprints. Unavailable corrective torque causes a real tip.
## This is a reduced articulated model, not a muscle-level biomechanics model.
const REST = {
	"Hips":Vector3(-0.003958083,0.943544447,-0.003973159), "Spine02":Vector3(-0.003298420,1.084721804,-0.007147864),
	"Spine01":Vector3(-0.002638743,1.225899220,-0.010322602), "Spine":Vector3(-0.001979074,1.367076635,-0.013497341),
	"neck":Vector3(-0.000776333,1.477390528,-0.015977990), "Head":Vector3(-0.000000045,1.548590779,-0.017579107),
	"LeftUpLeg":Vector3(0.095908880,0.852389991,0.000678669), "LeftLeg":Vector3(0.135657951,0.487772942,0.019285798),
	"LeftFoot":Vector3(0.159827322,0.128576815,-0.014148883), "LeftToeBase":Vector3(0.165624097,0.039606314,0.090552315),
	"LeftShoulder":Vector3(0.033646420,1.423791885,-0.022500698), "LeftArm":Vector3(0.176148430,1.423792124,-0.031503983),
	"LeftForeArm":Vector3(0.421829909,1.367325664,-0.063995592), "LeftHand":Vector3(0.691058993,1.345480204,-0.045295171),
	"RightUpLeg":Vector3(-0.100625038,0.852850258,0.000869500), "RightLeg":Vector3(-0.139401495,0.490074009,0.020240113),
	"RightFoot":Vector3(-0.159828484,0.139169499,-0.021754257), "RightToeBase":Vector3(-0.164755791,0.039735761,0.086811207),
	"RightShoulder":Vector3(-0.037024513,1.420703292,-0.022500224), "RightArm":Vector3(-0.177206248,1.420703053,-0.031503197),
	"RightForeArm":Vector3(-0.437117070,1.366866827,-0.063992567), "RightHand":Vector3(-0.696885765,1.344823122,-0.043770604)}
# Fractions of whole rider mass, including clothing. Sum is exactly one.
const SEGMENTS = [["Hips","Spine02",.15],["Spine02","Spine",.32],["neck","Head",.08],
	["LeftUpLeg","LeftLeg",.105],["RightUpLeg","RightLeg",.105],
	["LeftLeg","LeftFoot",.045],["RightLeg","RightFoot",.045],
	["LeftFoot","LeftToeBase",.015],["RightFoot","RightToeBase",.015],
	["LeftArm","LeftForeArm",.03],["RightArm","RightForeArm",.03],
	["LeftForeArm","LeftHand",.025],["RightForeArm","RightHand",.025],
	["LeftHand","LeftHand",.005],["RightHand","RightHand",.005]]
# Immutable per-side names and rest geometry, derived once from REST with the
# same operations the pose used to repeat every call (identical values).
const SIDE_PREFIX = ["Right","Left"]
const TORSO_IDS = ["Spine02","Spine01","Spine","neck","Head"]
static var _side_geometry: Array = _prepare_side_geometry()
static var _torso_offsets: Array = _prepare_torso_offsets()

static func _prepare_side_geometry() -> Array:
	var result: Array = []
	for prefix in SIDE_PREFIX:
		result.append({
			"up_leg":prefix+"UpLeg","leg":prefix+"Leg","foot":prefix+"Foot","toe":prefix+"ToeBase",
			"shoulder":prefix+"Shoulder","arm":prefix+"Arm","forearm":prefix+"ForeArm","hand":prefix+"Hand",
			"hip_offset":REST[prefix+"UpLeg"]-REST.Hips,"thigh":REST[prefix+"UpLeg"].distance_to(REST[prefix+"Leg"]),
			"shin":REST[prefix+"Leg"].distance_to(REST[prefix+"Foot"]),"foot_y":REST[prefix+"Foot"].y,
			"toe_offset":REST[prefix+"ToeBase"]-REST[prefix+"Foot"],
			"shoulder_offset":REST[prefix+"Shoulder"]-REST.Hips,"arm_offset":REST[prefix+"Arm"]-REST.Hips,
			"arm_length":REST[prefix+"Arm"].distance_to(REST[prefix+"ForeArm"]),
			"forearm_length":REST[prefix+"ForeArm"].distance_to(REST[prefix+"Hand"])})
	return result

static func _prepare_torso_offsets() -> Array:
	var result: Array = []
	for id in TORSO_IDS: result.append(REST[id]-REST.Hips)
	return result

var joints: Dictionary = {}
var rotations: Dictionary = {}
var previous_joints: Dictionary = {}
var previous_rotations: Dictionary = {}
# Coordinate frames belonging to the two joint snapshots. Presentation must
# interpolate these with the joints, never combine old joints with a new root.
var pose_frame = Transform3D.IDENTITY
var previous_pose_frame = Transform3D.IDENTITY
var com = Vector3(0,.9,0)
var inertia = Vector2(50,50) # roll / pitch, kg m² about ski support
var angular_momentum = Vector2.ZERO # kg m²/s, roll/pitch
var roll = 0.0
var pitch = 0.0
var roll_velocity = 0.0
var pitch_velocity = 0.0
var pelvis_height = .94
var height_velocity = 0.0
var cop = Vector2.ZERO # lateral / fore-aft, metres in support coordinates
var requested_cop = Vector2.ZERO
var support_margin = .22
var pressure_reserve = .12
var correction_torque = Vector2.ZERO # roll / pitch, N m
var load_fractions = Vector2(.5,.5) # right / left
var recovery = 0.0
var tipped = false
var recovering_pose = false
var hands: Array[Vector3] = [Vector3(-.18,-.32,.20),Vector3(.18,-.32,.20)]
var hand_velocities: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var initialized = false
var _carve_recovery_envelope = false
var _carve_transfer_shift = 0.0

func reset() -> void:
	_carve_recovery_envelope = false
	_carve_transfer_shift = 0.0
	angular_momentum = Vector2.ZERO
	roll = 0.0
	pitch = 0.0
	roll_velocity = 0.0
	pitch_velocity = 0.0
	pelvis_height = .94
	height_velocity = 0.0
	cop = Vector2.ZERO
	requested_cop = Vector2.ZERO
	load_fractions = Vector2(.5,.5)
	support_margin = .22
	recovery = 0.0
	tipped = false
	recovering_pose = false
	initialized = false
	joints.clear()
	rotations.clear()
	previous_joints.clear()
	previous_rotations.clear()
	pose_frame = Transform3D.IDENTITY
	previous_pose_frame = Transform3D.IDENTITY
	hands = [Vector3(-.18,-.32,.20),Vector3(.18,-.32,.20)]
	hand_velocities = [Vector3.ZERO,Vector3.ZERO]

func step(dt: float, sim, intent, acceleration_world: Vector3) -> void:
	# A supported pelvis transfer changes actual fitted COM, never root velocity.
	var shift_goal: float = -intent.steer*sim.tuning.arcade_transfer_shift_m*sim.carve_blend if sim.grounded and roll*intent.steer<0.0 else 0.0
	_carve_transfer_shift = move_toward(_carve_transfer_shift,shift_goal,dt*sim.tuning.arcade_transfer_shift_speed)
	pressure_reserve = sim.tuning.transfer_pressure_reserve if roll*intent.steer<0.0 else lerpf(.12,sim.tuning.bank_pressure_reserve,smoothstep(.05,.5,absf(intent.steer)))
	# Keep pressure for initiating the bank, then make the established support
	# available to carve. The actual footprint still bounds every reaction.
	if roll*intent.steer>=0.0:
		var established = smoothstep(sim.tuning.arcade_bank_start,sim.tuning.arcade_bank_full,absf(roll))
		var building = smoothstep(sim.tuning.arcade_build_start,sim.tuning.arcade_build_full,absf(roll))
		var carve_reserve = lerpf(sim.tuning.arcade_initiation_reserve,sim.tuning.arcade_build_reserve,building)
		carve_reserve = lerpf(carve_reserve,sim.tuning.arcade_pressure_reserve,established)
		pressure_reserve = lerpf(pressure_reserve,carve_reserve,sim.carve_blend)
	var frame: Basis = sim.support_basis()
	var has_support: bool = sim.grounded or not sim.landing_support_positions.is_empty()
	if initialized and (has_support or not sim.air_control.orientation_flight):
		# Roll/pitch live in the moving support frame. Preserve the existing
		# world lean when terrain/heading rotates that frame; otherwise every
		# bank change instantly rotates the mass and injects a false tip.
		var transport = frame.transposed()*pose_frame.basis
		var up = transport*(Basis(Vector3.BACK,roll)*Basis(Vector3.RIGHT,pitch)).y
		roll = atan2(-up.x,up.y)
		pitch = asin(clampf(up.z,-1.0,1.0))
		var omega = transport*Vector3(pitch_velocity,0.0,roll_velocity)
		pitch_velocity = omega.x
		roll_velocity = omega.z
	angular_momentum = inertia*Vector2(roll_velocity,pitch_velocity)
	previous_joints = joints.duplicate()
	previous_rotations = rotations.duplicate()
	previous_pose_frame = pose_frame
	pose_frame = Transform3D(frame,sim.position)
	var inverse = frame.transposed()
	var acceleration: Vector3 = inverse*acceleration_world
	# Air drag acts on the body, not through the ski support footprint.
	var gravity: Vector3 = inverse*(sim.gravity_vector+sim.air_acceleration)
	# Balance must use the reaction that changed velocity THIS tick, including
	# landing support. sim.normal_load is the next contact's support estimate;
	# using it here pairs a landing/braking impulse with near-zero support.
	var normal_load: float = maxf(acceleration.y-gravity.y,.1)
	var anticipated: float = sim.turn_demand*sim.velocity.length()
	# requested_lateral_acceleration already describes the ski reaction, with
	# gravity excluded. Subtracting cross-slope gravity again drives excessive
	# bank as support unloads, even after a tiny steering input is released.
	# Anticipation also needs support. Do not demand a full bank from a tiny
	# steering correction while the skis are almost weightless over a crest.
	var lean_limit: float = lerpf(sim.tuning.maximum_body_lean,sim.tuning.high_speed_body_lean,smoothstep(30.0/3.6,60.0/3.6,sim.velocity.length()))
	lean_limit = lerpf(lean_limit,sim.tuning.arcade_body_lean,sim.carve_blend)
	var anticipated_limit: float = normal_load*tan(lean_limit)
	anticipated = clampf(anticipated,-anticipated_limit,anticipated_limit)
	var anticipation_blend: float = lerpf(.2,sim.tuning.turn_anticipation,smoothstep(.05,.5,absf(intent.steer)))
	anticipation_blend = lerpf(anticipation_blend,sim.tuning.arcade_anticipation,sim.carve_blend)
	var lean_force: float = lerpf(sim.requested_lateral_acceleration,anticipated,anticipation_blend)
	# Retract the target bank as the skis unload. Dividing steering demand by
	# a vanishing reaction instead asked for maximum lean just before takeoff,
	# when the feet no longer had the torque to stop that angular motion.
	var lean_support = maxf(normal_load,-gravity.y)
	var goal_roll = clampf(-atan2(lean_force,lean_support),-lean_limit,lean_limit) if sim.grounded else clampf(roll,-1.15,1.15)
	# During an edge change request a modest opposite bank through the same
	# pressure-limited controller. This avoids lingering around neutral while
	# waiting for the old turn force to disappear; it never assigns body roll.
	if sim.grounded and intent.steer*sim.requested_lateral_acceleration>0.0:
		goal_roll = intent.steer*minf(sim.tuning.turn_transfer_bank,lean_limit)
	var goal_pitch: float = -intent.brake*.45 if sim.grounded else clampf(pitch,-.70,.70)
	var goal_height: float = .94-sim.effective_tuck*.22-clampf((sim.normal_load/9.81-1.0)*.035+sim.landing_force*.012,-.035,.11)
	# Transition from tuck to turning stance without stacking both crouches.
	goal_height -= sim.carve_blend*sim.tuning.arcade_carve_crouch*(1.0-sim.effective_tuck)
	goal_height -= sim.snow_control_blend*sim.tuning.snow_control_crouch*(1.0-sim.effective_tuck)
	if not sim.grounded:
		# Bring the knees up after release instead of extending rigidly into
		# the missing support. This changes the articulated pose/inertia only.
		goal_height = .86-sim.effective_tuck*.08
	var height_force = (goal_height-pelvis_height)*110.0-height_velocity*20.0
	height_velocity += height_force*dt
	pelvis_height = clampf(pelvis_height+height_velocity*dt,.56,1.0)
	_pose(sim,dt)
	_mass_properties(sim.tuning.rider_mass)
	if has_support:
		var minimum = INF
		var maximum = -INF
		var points: Array[Vector3] = sim.landing_support_positions.duplicate()
		if points.is_empty():
			for ski in sim.skis:
				if ski.grounded: points.append(ski.position)
		for support_position in points:
			var point: Vector3 = inverse*(support_position-sim.position)
			minimum = minf(minimum,point.x-sim.tuning.ski_width*.5)
			maximum = maxf(maximum,point.x+sim.tuning.ski_width*.5)
		var support_force: float = sim.tuning.rider_mass*normal_load
		var fx: float = sim.tuning.rider_mass*(acceleration.x-gravity.x)
		var fz: float = sim.tuning.rider_mass*(acceleration.z-gravity.z)
		var roll_damping: float = lerpf(sim.tuning.balance_recovery_damping,sim.tuning.balance_damping,smoothstep(.05,.5,absf(intent.steer)))
		var roll_torque: float = clampf((goal_roll-roll)*sim.tuning.balance_stiffness-roll_velocity*roll_damping,-sim.tuning.balance_max_torque,sim.tuning.balance_max_torque)
		var pitch_torque: float = clampf((goal_pitch-pitch)*sim.tuning.balance_stiffness-pitch_velocity*sim.tuning.balance_damping,-sim.tuning.balance_max_torque,sim.tuning.balance_max_torque)
		requested_cop = Vector2(com.x+(roll_torque-com.y*fx)/support_force,com.z-(pitch_torque+com.y*fz)/support_force)
		var length_limit: float = sim.tuning.ski_length*.40
		cop = Vector2(clampf(requested_cop.x,minimum,maximum),clampf(requested_cop.y,-length_limit,length_limit))
		correction_torque = Vector2((cop.x-com.x)*support_force+com.y*fx,(com.z-cop.y)*support_force-com.y*fz)
		roll_velocity += correction_torque.x/maxf(inertia.x,1.0)*dt
		pitch_velocity += correction_torque.y/maxf(inertia.y,1.0)*dt
		var equilibrium = Vector2(com.x-com.y*fx/support_force,com.z-com.y*fz/support_force)
		support_margin = minf(minf(equilibrium.x-minimum,maximum-equilibrium.x),length_limit-absf(equilibrium.y))
		# Pressure beyond one foot unloads the other; it cannot pull on the snow.
		var left_share = clampf(.5+cop.x/(2.0*sim.tuning.half_stance),0.0,1.0)
		load_fractions = Vector2(1.0-left_share,left_share)
	else:
		# No ground-reaction torque in free flight. Angular momentum persists.
		correction_torque = Vector2.ZERO
		support_margin = 0.0
		load_fractions = Vector2.ZERO
	if not has_support:
		# Limb/tuck movement changes inertia, not external angular momentum.
		roll_velocity = angular_momentum.x/maxf(inertia.x,1.0)
		pitch_velocity = angular_momentum.y/maxf(inertia.y,1.0)
	else:
		angular_momentum = inertia*Vector2(roll_velocity,pitch_velocity)
	roll += roll_velocity*dt
	pitch += pitch_velocity*dt
	if not has_support:
		# This model articulates above attached boots; it has no whole-rider flip
		# degree of freedom. Unbounded angles orbit the torso around the cuffs.
		roll = clampf(roll,-1.15,1.15)
		pitch = clampf(pitch,-.70,.70)
		if absf(roll)>=1.15 and roll_velocity*roll>0.0: roll_velocity = 0.0
		if absf(pitch)>=.70 and pitch_velocity*pitch>0.0: pitch_velocity = 0.0

		angular_momentum = inertia*Vector2(roll_velocity,pitch_velocity)
	# Supported self-righting assist bounds the articulated pose after a stumble.
	# Remove outward angular speed, never redirect root velocity or add a snow force.
	# Flight has anatomical limits and explicit neutral-input help; tilt is not health.
	if has_support:
		# Retain the larger envelope through release until the bank settles.
		# Pure rock/neutral riding never opts into a snow-carving recovery limit.
		if sim.carve_blend>0.0: _carve_recovery_envelope = true
		elif absf(roll)<=1.15: _carve_recovery_envelope = false
		var roll_limit: float = sim.tuning.arcade_roll_limit if _carve_recovery_envelope else 1.15
		if absf(roll)>roll_limit or absf(pitch)>.70: recovering_pose = true
		if recovering_pose:
			roll = move_toward(clampf(roll,-roll_limit,roll_limit),goal_roll,dt*2.0)
			pitch = move_toward(clampf(pitch,-.70,.70),goal_pitch,dt*2.0)
			if roll_velocity*(roll-goal_roll)>0.0: roll_velocity = 0.0
			if pitch_velocity*(pitch-goal_pitch)>0.0: pitch_velocity = 0.0
			if absf(roll-goal_roll)<.1 and absf(pitch-goal_pitch)<.1: recovering_pose = false
		angular_momentum = inertia*Vector2(roll_velocity,pitch_velocity)
	recovery = clampf(maxf(0.0,-support_margin-.10)*2.0+maxf(0.0,absf(roll)-.8)*3.0,0.0,2.0) if sim.grounded else 0.0
	tipped = absf(roll)>1.25 or absf(pitch)>.85
	_pose(sim,0.0)
	_mass_properties(sim.tuning.rider_mass)
	if not sim.grounded:
		roll_velocity = angular_momentum.x/maxf(inertia.x,1.0)
		pitch_velocity = angular_momentum.y/maxf(inertia.y,1.0)
	if not initialized:
		previous_joints = joints.duplicate()
		previous_rotations = rotations.duplicate()
		previous_pose_frame = pose_frame
		initialized = true

func _pose(sim, dt: float) -> void:
	var tuck: float = sim.effective_tuck
	var pelvis_basis = Basis(Vector3.BACK,roll)*Basis(Vector3.RIGHT,.06+tuck*.32+pitch)
	var torso_basis = Basis(Vector3.BACK,roll*.80)*Basis(Vector3.RIGHT,.10+tuck*.42+pitch)
	var hips = Vector3(-sin(roll)*pelvis_height*.55,cos(roll)*cos(pitch)*pelvis_height,-.09-tuck*.08+sin(pitch)*pelvis_height)
	# Fit both reach spheres and boot cuffs by moving one shared pelvis.
	var frame: Basis = sim.support_basis()
	var ankles: Array[Vector3] = []
	var boots: Array[Basis] = []
	for i in range(2):
		var geometry: Dictionary = _side_geometry[i]
		ankles.append(frame.transposed()*(sim.skis[i].position-sim.position+sim.skis[i].orientation.y*(.110+geometry.foot_y)))
		boots.append(frame.transposed()*sim.skis[i].orientation)
	hips.x += _carve_transfer_shift
	hips = fit_hips(hips,pelvis_basis,ankles,boots)
	joints.Hips = hips
	rotations.Hips = pelvis_basis
	for index in TORSO_IDS.size():
		var id: String = TORSO_IDS[index]
		joints[id] = hips+torso_basis*_torso_offsets[index]
		rotations[id] = torso_basis if id!="Head" else Basis(Vector3.BACK,roll*.8)*Basis(Vector3.RIGHT,pitch+tuck*.12)
	for i in range(2):
		var side = -1.0 if i==0 else 1.0
		var geometry: Dictionary = _side_geometry[i]
		var ankle: Vector3 = ankles[i]
		var hip: Vector3 = hips+pelvis_basis*geometry.hip_offset
		var a: float = geometry.thigh
		var b: float = geometry.shin
		var knee = leg_joint(hip,ankle,a,b,boots[i])
		joints[geometry.up_leg] = hip
		joints[geometry.leg] = knee
		joints[geometry.foot] = ankle
		rotations[geometry.foot] = boots[i]
		joints[geometry.toe] = ankle+boots[i]*geometry.toe_offset
		joints[geometry.shoulder] = hips+torso_basis*geometry.shoulder_offset
		joints[geometry.arm] = hips+torso_basis*geometry.arm_offset
		var turn: float = clampf(sim.edge_angle/.65,-1.0,1.0)
		var hand_goal = Vector3(side*(.18-tuck*.14+(.08 if not sim.grounded else 0.0)+recovery*.04)-turn*.045,
			-.32+tuck*.18+side*turn*.05+sim.landing_force*.008,.20+tuck*.13+side*turn*.065-clampf(sim.acceleration*.0025,-.05,.05))
		if dt>0.0:
			var offset = hands[i]-hand_goal
			var response = hand_velocities[i]+offset*11.0
			var decay = exp(-11.0*dt)
			hands[i] = hand_goal+(offset+response*dt)*decay
			hand_velocities[i] = (hand_velocities[i]-response*11.0*dt)*decay
		var arm_length: float = geometry.arm_length
		var forearm_length: float = geometry.forearm_length
		var offset = hands[i].limit_length(arm_length+forearm_length-.025)
		var arm_joint: Vector3 = joints[geometry.arm]
		var hand: Vector3 = arm_joint+offset
		joints[geometry.forearm] = joint(arm_joint,hand,arm_length,forearm_length,Vector3(side*(.65-tuck*.25),-.55,-.35))
		joints[geometry.hand] = hand

func _mass_properties(mass: float) -> void:
	com = Vector3.ZERO
	inertia = Vector2.ZERO
	for segment in SEGMENTS:
		var center: Vector3 = (joints[segment[0]]+joints[segment[1]])*.5
		var weight: float = segment[2]
		com += center*weight
		inertia += Vector2(center.x*center.x+center.y*center.y,center.z*center.z+center.y*center.y)*weight*mass

# Native math keeps this reference implementation available for verification
# and platforms without a packaged library. No solver or pose cadence changes.
static var native_fit_kernel = prepare_native_fit()
static var native_fit_enabled = native_fit_kernel!=null

static func prepare_native_fit():
	var kernel = preload("res://scripts/core/skier_kernel.gd").create("AlpineBodyFit")
	if kernel!=null: kernel.configure(REST)
	return kernel

static func fit_hips(hips: Vector3, pelvis: Basis, ankles: Array[Vector3], boots: Array[Basis]) -> Vector3:
	if native_fit_enabled: return native_fit_kernel.fit(hips,pelvis,ankles,boots)
	return reference_fit_hips(hips,pelvis,ankles,boots)

static func reference_fit_hips(hips: Vector3, pelvis: Basis, ankles: Array[Vector3], boots: Array[Basis]) -> Vector3:
	# Project the shared pelvis against both leg lengths AND cuff flexion
	# envelopes. A position-only IK solve can satisfy lengths with a broken
	# ankle; moving the shared pelvis keeps torso and both hips connected.
	for iteration in range(16):
		var largest = 0.0
		for i in range(2):
			var geometry: Dictionary = _side_geometry[i]
			var hip: Vector3 = hips+pelvis*geometry.hip_offset
			var thigh: float = geometry.thigh
			var shin: float = geometry.shin
			var reach = thigh+shin-.004
			var extension = hip.distance_to(ankles[i])-reach
			if extension>0.0:
				var shift = (ankles[i]-hip).normalized()*extension
				hips += shift
				hip += shift
				largest = maxf(largest,extension)
			var knee = leg_joint(hip,ankles[i],thigh,shin,boots[i])
			var axis = boots[i].transposed()*(knee-ankles[i]).normalized()
			var side_angle = clampf(atan2(axis.x,axis.y),-.174533,.174533) # ±10°
			var flex = clampf(asin(clampf(axis.z,-1.0,1.0)),0.0,.558505) # 0–32°
			var allowed = Vector3(sin(side_angle)*cos(flex),cos(side_angle)*cos(flex),sin(flex))
			if axis.distance_squared_to(allowed)<.00000001: continue
			var cuff_knee = ankles[i]+boots[i]*allowed*shin
			var corrected_hip = cuff_knee+(hip-cuff_knee).normalized()*thigh
			var correction = corrected_hip-hip
			hips += correction
			largest = maxf(largest,correction.length())
		if largest<.00001: break
	return hips

static func leg_joint(hip: Vector3, ankle: Vector3, thigh: float, shin: float, boot: Basis) -> Vector3:
	# Select the knee on the two-bone reach circle nearest the boot cuff's
	# forward-flexion plane. A world-forward pole twists the ankle when edged.
	# Favor forward bend enough to keep the knees above the boots rather than
	# pushing them outwards as the narrower hips drop into a crouch.
	return joint(hip,ankle,thigh,shin,boot.y+boot.z*.45)

static func joint(a: Vector3,b: Vector3,first: float,second: float,hint: Vector3) -> Vector3:
	var delta = b-a
	var length_value = clampf(delta.length(),absf(first-second)+.0001,first+second-.0001)
	var direction = delta.normalized()
	var along = (first*first-second*second+length_value*length_value)/(2.0*length_value)
	var height_value = sqrt(maxf(0.0,first*first-along*along))
	var bend = hint-direction*hint.dot(direction)
	if bend.length_squared()<.0001: bend = Vector3.RIGHT.slide(direction)
	return a+direction*along+bend.normalized()*height_value

func available_lateral(direction: float, load: float, tuning) -> float:
	# Reserve part of the support width for changing lean. Edge force builds as
	# the rider actually banks, rather than applying full grip to an upright COM.
	return maxf(0.0,(tuning.half_stance+tuning.ski_width*.5-pressure_reserve+direction*com.x)*maxf(load,0.0)/maxf(com.y,.4))

func available_braking(direction: float, load: float, tuning) -> float:
	return maxf(0.0,(tuning.ski_length*.40-.06-direction*com.z)*maxf(load,0.0)/maxf(com.y,.4))
