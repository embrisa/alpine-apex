extends RefCounted
## Full skeletal curves. All state here is cosmetic, advanced at completed ticks.
## No AnimationPlayer or second skeleton writer participates in gameplay.
const SKI_GRIP = Vector3(-.045,-.12,.50)
const GLOVE_GRIP = Vector3(-.070,0.0,.018)
const Anatomy = preload("res://scripts/presentation/skier_anatomy.gd")
const Downhill = preload("res://scripts/presentation/downhill_posture.gd")
const Action = preload("res://scripts/presentation/action_posture.gd")
const PolePose = preload("res://scripts/presentation/pole_push_pose.gd")
const LIBRARY = preload("res://assets/animation/steep_ski_motion.res")
static var library: Dictionary = LIBRARY.data
# The imported resource is immutable for this script's lifetime. Decode once,
# before riding; no pose, clock, interpolation or equipment state is cached.
static var prepared_clips: Dictionary = prepare_clips()
static var grip_chains: Dictionary = prepare_grip_chains()
static var native_tracker = prepare_native_tracker()

static func prepare_native_tracker():
	var kernel = Anatomy.native_fit_kernel
	if kernel!=null: kernel.configure_tracking(library.names,library.parents,Anatomy.Body.REST,grip_chains)
	return kernel

static func prepare_clips() -> Dictionary:
	var result = {}
	for name in library.clips:
		var clip: Dictionary = library.clips[name]
		var values: PackedFloat32Array = clip.values
		var qs: Array[Quaternion] = []
		var roots = PackedVector3Array()
		qs.resize(clip.frames*library.names.size()); roots.resize(clip.frames)
		for frame in clip.frames:
			var offset: int = frame*library.names.size()*7
			roots[frame] = Vector3(values[offset],values[offset+1],values[offset+2])
			for i in library.names.size():
				var index: int = offset+i*7+3
				qs[frame*library.names.size()+i] = Quaternion(values[index],values[index+1],values[index+2],values[index+3]).normalized()
		qs.make_read_only()
		var prepared = {"duration":clip.duration,"frames":clip.frames,"rotations":qs,"roots":roots}
		prepared.make_read_only(); result[name] = prepared
	result.make_read_only()
	return result

static func prepare_grip_chains() -> Dictionary:
	var result = {}
	for prefix in ["Right","Left"]:
		var chain = PackedInt32Array()
		var index: int = library.names.find(prefix+"ForeArm")
		while index>=0:
			chain.append(index); index = library.parents[index]
		chain.reverse(); result[prefix+"ForeArm"] = chain; result[prefix+"Hand"] = chain
	result.make_read_only()
	return result
var enabled = true
var native_tracking_enabled = native_tracker!=null
var grab_style = "safety"
var active_grab_style = "safety"
var amount = 1.0
var previous_amount = 1.0
var amount_velocity = 0.0
var clock = 0.0
var air_age = 0.0
var landing_age = 60.0
var grab_age = 0.0
var grab_pose_active = false
var grip_amount = 0.0
var previous_grip = 0.0
var was_grounded = true
var last_landing_event = 0
var last_tick = -1
var current: Array[Quaternion] = []
var previous: Array[Quaternion] = []
var velocities: Array[Vector3] = []
var root_position = Vector3.ZERO
var previous_root = Vector3.ZERO
var root_velocity = Vector3.ZERO
var weights: Dictionary = {}
var phase = "glide"
var diagnostics: Dictionary = {}
var requested_joints: Dictionary = {}
var requested_rotations: Dictionary = {}
var step_microseconds = 0
var fit_microseconds = 0
var interpolation_microseconds = 0
var forward_downhill = true
var downhill_amount = 1.0
var previous_downhill = 1.0
var action_amount = Vector3.ZERO
var previous_action = Vector3.ZERO
var impact_posture = 0.0
var previous_impact_posture = 0.0
var support_response = 0.0
var previous_support_response = 0.0
var pole_amount = 0.0
var previous_pole_amount = 0.0
var pole_phase = 0.0
var previous_pole_phase = 0.0
var pole_plant = 0.0
var previous_pole_plant = 0.0
var pole_anchors: Array = []
var pole_targets: Array = []
var previous_pole_targets: Array = []
var pole_target_normals: Array = []
var previous_pole_target_normals: Array = []
var pole_release_origin = Vector3.ZERO
var pole_last_position = Vector3.ZERO
var pole_target_stage = "inactive"
var pole_entry = false
var pole_carry = 0.0
var previous_pole_carry = 0.0
var pole_normals: Array = []
var _pole_was_loaded = false
var frame_costs = preload("res://scripts/diagnostics/frame_costs.gd").new()

func _init() -> void:
	assert(library.get("version",0)==1,"Build the full motion library; see STEEP_MOTION_GAMEPLAY.md")

func reset(sim) -> void:
	clock = 0.0; air_age = 0.0; landing_age = 60.0; grab_age = 0.0
	grab_pose_active = false; active_grab_style = grab_style
	grip_amount = 0.0; previous_grip = 0.0
	was_grounded = sim.grounded; last_landing_event = 0; last_tick = sim.ticks
	amount = 1.0 if enabled else 0.0; previous_amount = amount; amount_velocity = 0.0
	var initial = sample_clip("NAV_MED_FWD",0.0,true)
	forward_downhill = not sim.facing_backward
	downhill_amount = float(sim.grounded and forward_downhill)
	previous_downhill = downhill_amount
	action_amount = Vector3.ZERO; previous_action = Vector3.ZERO
	impact_posture = 0.0; previous_impact_posture = 0.0
	support_response = 0.0; previous_support_response = 0.0
	pole_amount = 0.0; previous_pole_amount = 0.0
	pole_phase = 0.0; previous_pole_phase = 0.0
	pole_plant = 0.0; previous_pole_plant = 0.0
	pole_anchors.clear(); pole_normals.clear(); _pole_was_loaded = false
	pole_targets.clear(); previous_pole_targets.clear(); pole_target_normals.clear(); previous_pole_target_normals.clear()
	pole_release_origin = sim.position; pole_last_position = sim.position; pole_target_stage = "inactive"; pole_entry = false
	pole_carry = 0.0; previous_pole_carry = 0.0
	if sim.grounded and forward_downhill:
		Downhill.apply(initial,library,{"tuck":sim.effective_tuck,"prepare":0.0},1.0)
	current = initial.q
	for i in current.size(): current[i] = Anatomy.local_limit(library.names[i],Basis(current[i]),0.0,downhill_amount).get_rotation_quaternion()
	previous = current.duplicate()
	root_position = initial.root; previous_root = root_position; root_velocity = Vector3.ZERO
	velocities.clear()
	for i in current.size(): velocities.append(Vector3.ZERO)

func hold() -> void:
	previous = current.duplicate(); previous_root = root_position; previous_amount = amount
	previous_grip = grip_amount
	previous_downhill = downhill_amount
	previous_action = action_amount
	previous_impact_posture = impact_posture
	previous_support_response = support_response
	previous_pole_amount = pole_amount; previous_pole_phase = pole_phase
	previous_pole_plant = pole_plant; previous_pole_carry = pole_carry
	previous_pole_targets = pole_targets.duplicate(); previous_pole_target_normals = pole_target_normals.duplicate()

func step(dt: float, sim, intent, state: Dictionary, landing_event: int, surface = null) -> void:
	var start = Time.get_ticks_usec()
	if current.is_empty() or sim.ticks<last_tick: reset(sim)
	if sim.ticks==last_tick: return
	last_tick = sim.ticks
	forward_downhill = not sim.facing_backward
	hold()
	if sim.crashed: return
	step_poles(dt,sim,surface)
	amount_velocity += ((maxf(float(enabled),pole_amount)-amount)*225.0-amount_velocity*30.0)*dt
	amount = clampf(amount+amount_velocity*dt,0.0,1.0)
	clock += dt
	if was_grounded and not sim.grounded: air_age = 0.0
	if not sim.grounded: air_age += dt
	landing_age += dt
	if landing_event!=last_landing_event:
		landing_age = 0.0; last_landing_event = landing_event
	var grabbing: bool = intent.grab and not sim.grounded
	if grabbing and not grab_pose_active:
		grab_age = 0.0; grab_pose_active = true; active_grab_style = grab_style
	else: grab_age += dt
	# Keep a still-weighted pose through release/re-grab taps. Style changes
	# take effect on the next settled entry, never move a held hand between skis.
	if not grabbing and state.grab<.01: grab_pose_active = false
	# The source has an approach phase. Do not pull its still-raised hand to
	# the ski as soon as the input blend reaches one. Release keeps this phase.
	grip_amount = state.grab*smoothstep(.10,.65,grab_age)
	was_grounded = sim.grounded
	if not enabled and amount<.00001 and pole_amount<.00001:
		# A settled procedural comparison pays no skeletal sampler/fitting cost.
		# Re-entry keeps the previous pose/velocities and blends from weight zero.
		amount = 0.0; amount_velocity = 0.0; step_microseconds = 0; fit_microseconds = 0
		return
	weights.clear()
	var speed: float = sim.motion.speed_mps
	var turn = supported_turn(sim)
	# An edge can persist on a nearly straight path, or oppose the turn on a
	# cross-slope. Balance follows completed path curvature, gated by loaded
	# edging. Neither input nor a lingering bank commits the whole posture.
	# Motion turn rate is positive toward model +X (rider left).
	var path_balance = -atan(sim.motion.turn_rate_rad_s*speed/9.81)/.65
	var balance_turn = signf(path_balance)*minf(absf(turn),absf(path_balance))
	support_response = lerpf(support_response,balance_turn/turn if absf(turn)>.00001 else 0.0,1.0-exp(-12.0*dt))
	var turn_direction = signf(intent.steer) if absf(intent.steer)>.001 else signf(turn)
	var animation_turn = absf(balance_turn)*turn_direction
	state = state.duplicate()
	state.steer = animation_turn
	state.carve = balance_turn
	var turn_weight = smoothstep(.02,.85,absf(balance_turn))
	state.turn_strength = turn_weight
	var slow = 1.0-smoothstep(3.0,12.0,speed)
	var fast = smoothstep(16.0,28.0,speed)
	var tuck: float = state.tuck
	var air: float = state.air
	var preparation: float = smoothstep(0.0,1.0,state.prepare)*(1.0-air)
	var landing: float = (1.0-smoothstep(.25,.90,landing_age))*(1.0-air)
	var ground = (1.0-air)*(1.0-preparation)*(1.0-landing)
	var dir = "RIGHT" if turn_direction>0.0 else "LEFT"
	add("NAV_SLOW_FWD",ground*slow*(1.0-turn_weight)*(1.0-tuck),clock,true)
	add("NAV_SLOW_"+dir,ground*slow*turn_weight*(1.0-tuck),clock,true)
	add("NAV_MED_FWD",ground*(1.0-slow)*(1.0-fast)*(1.0-turn_weight)*(1.0-tuck),clock,true)
	add("NAV_FAST_FWD",ground*(1.0-slow)*fast*(1.0-turn_weight)*(1.0-tuck),clock,true)
	add("NAV_MED_"+dir,ground*(1.0-slow)*turn_weight*(1.0-tuck),clock,true)
	add("NAV_FAST_FWD_SPEED",ground*tuck*(1.0-turn_weight),clock,true)
	add("NAV_FAST_"+dir+"_SPEED",ground*tuck*turn_weight,clock,true)
	if sim.facing_backward:
		scale_weights(.30)
		add("NAV_MED_TURNS_SWITCH",ground*.70,clampf(.5+turn*.40,.0,1.0)*duration("NAV_MED_TURNS_SWITCH"),false)
	# Drift curves are mixed by actual slip/braking, not a fabricated ski yaw.
	var drift: float = maxf(state.skid*.40,state.brake*.75)*ground
	if drift>.001:
		scale_weights(1.0-drift)
		add("NAV_DRIFT_LEFT_FWD_10",drift*(1.0-state.brake),clock,true,turn>0.0)
		add("NAV_DRIFT_LEFT_FWD_90",drift*state.brake,clock,true,turn>0.0)
	var switch_suffix = "_SWITCH_HEAD_LEFT" if sim.facing_backward else ""
	add("NAV_OLLIE_FWD"+switch_suffix,preparation,clampf(state.prepare,0.0,1.0)*duration("NAV_OLLIE_FWD"+switch_suffix),false)
	var takeoff = (1.0-smoothstep(.06,.32,air_age))*air*(1.0-state.ready)
	# Ordinary hops/departures use ordinary source shapes, never backflip prep.
	add("OLLIE_HIGH_TO_AIR"+switch_suffix,takeoff,air_age,false)
	var flight = air*(1.0-state.grab)*(1.0-state.ready)-takeoff
	flight = maxf(0.0,flight)
	var air_clip = "AIR_LONG" if state.compact>.5 else "AIR"
	if sim.air_control.flip_flight:
		# Explicit flip direction is rider-relative, including switch. Imported
		# clip names have the opposite sign to our +nose-down convention.
		var rider_pitch: float = sim.air_control.flip_direction
		air_clip = "AIR_BACKFLIP_LONG" if rider_pitch>=0.0 else "AIR_FRONTFLIP_LONG"
	elif absf(sim.air_control.integrated_yaw)>.2:
		air_clip = "AIR_SPINLEFT_LONG" if sim.air_control.integrated_yaw>0.0 else "AIR_SPINRIGHT_LONG"
	add(air_clip,flight,air_age,true)
	add("AIR_TO_LAND",air*state.ready,clampf(state.ready,0.0,1.0)*duration("AIR_TO_LAND"),false)
	add("GRAB_MUTE" if active_grab_style=="mute" else "GRAB_SAFETY",air*state.grab,grab_age,false)
	var large = smoothstep(5.0,15.0,sim.motion.landing_speed_mps)
	if sim.facing_backward:
		add("LANDING_TO_FWD_MED_P01_01_SWITCH_HEAD_LEFT",landing,landing_age,false)
	else:
		add("LANDING_TO_FWD_MED_P01_01",landing*(1.0-large),landing_age,false)
		add("LANDING_TO_FWD_MED_P03_01",landing*large,landing_age,false)
	var recovery: float = maxf(state.recoil,state.impairment*.22)*(1.0-air)
	if recovery>.001:
		scale_weights(1.0-recovery)
		add("NAV_FWD_SOFT_COLLISION_01",recovery,clock,true)
	phase = "glide"
	if absf(balance_turn)>.1: phase = "turn"
	if tuck>.5: phase = "tuck"
	if preparation>.1: phase = "prepare"
	if air>.5: phase = "flight"
	if takeoff>.1: phase = "takeoff"
	if landing>.1: phase = "landing"
	if state.grab>.1: phase = "grab"
	var mixed: Dictionary = {}
	var total = 0.0
	var blend_started = frame_costs.begin()
	for name in weights:
		var entry: Dictionary = weights[name]
		var source_started = frame_costs.begin()
		var pose = sample_clip(name,entry.time,entry.loop)
		if entry.mirror: pose = mirror_pose(pose)
		frame_costs.end(&"animation_source",source_started)
		var weight: float = entry.weight
		if mixed.is_empty(): mixed = pose; total = weight; continue
		var fraction: float = weight/(total+weight)
		for i in current.size(): mixed.q[i] = mixed.q[i].slerp(pose.q[i],fraction).normalized()
		mixed.root = mixed.root.lerp(pose.root,fraction)
		total += weight
	if mixed.is_empty(): mixed = sample_clip("NAV_MED_FWD",clock,true)
	frame_costs.end(&"animation_source_blend",blend_started)
	var posture_started = frame_costs.begin()
	fit_tuck_flexion(mixed,state.tuck*(1.0-state.air)*(1.0-state.prepare))
	# Wide counterbalance belongs to sustained, well-cleared flight. Ordinary
	# takeoff and small hops keep the hands close instead of selecting wide arms
	# merely because snow contact has ended. Grabs retain their authored reach.
	var air_room = smoothstep(.8,2.5,maxf(sim.skis[0].clearance_m,sim.skis[1].clearance_m))
	var open_air = air_room*smoothstep(.35,.85,air_age)*state.air*(1.0-state.ready)
	# Source counterbalance belongs in gliding/carving. Gather only the tuck
	# and takeoff/ordinary-flight phases; large air retains its wider expression.
	var turning_release = Downhill.straight(state)
	var carry = maxf(state.tuck*(1.0-state.air)*turning_release,maxf(state.prepare,state.air*(1.0-open_air*.85)))
	fit_arm_carry(mixed,state.tuck*(1.0-state.air),state.prepare,carry*(1.0-state.grab))
	var downhill_weight = Downhill.weight(state)*(0.0 if sim.facing_backward else 1.0)*(1.0-landing)*(1.0-state.recoil)
	# A turn reversal passes through zero steer for a few ticks. Do not let
	# that transient replace a banked pelvis with a full straight-downhill pose.
	downhill_amount = lerpf(downhill_amount,downhill_weight,1.0-exp(-12.0*dt))
	Downhill.apply(mixed,library,state,downhill_amount)
	# The ordinary jump crosses the old .8 m broad-air threshold briefly.
	# Keep its departure carry until readiness; sustained high flight and
	# explicit tricks still release the authored counterbalance and grab poses.
	var action_free_air = smoothstep(2.5,4.0,maxf(sim.skis[0].clearance_m,sim.skis[1].clearance_m))*smoothstep(.35,.85,air_age)
	var action_target = Action.weights(state,landing_age,forward_downhill,sim.body.roll,maxf(action_free_air,float(sim.air_control.trick_flight)))
	# A reversal crosses neutral steer for one tick. The fitted pelvis uses
	# this weight directly, so it needs the same continuous handoff as downhill.
	# Tracking only the joint rotations leaves the whole body free to teleport.
	action_target.x = lerpf(action_amount.x,action_target.x,1.0-exp(-12.0*dt))
	action_amount = action_target
	# Match root absorption to the existing tracked articulation; the raw
	# impact envelope rises too quickly to apply directly to pelvis position.
	impact_posture = lerpf(impact_posture,state.impact,1.0-exp(-36.0*dt))
	Action.apply(mixed,library,state,action_amount,air_age)
	Action.balance_roll(mixed,library,balance_turn,clampf(downhill_amount+action_amount.x,0.0,1.0)*smoothstep(.001,.04,absf(balance_turn)))
	refine_authored_pose(mixed,state,action_amount)
	# This new source owns torso/arm channels AFTER downhill/tuck/action shaping.
	# The same tracker and final anatomical limits still own continuity.
	PolePose.apply(mixed,library,pole_phase,pole_amount)
	if pole_amount>.05: phase = "pole_push"
	var articulated_carry = maxf(pole_amount,clampf(downhill_amount+action_amount.x+action_amount.y+action_amount.z,0.0,1.0))
	# Continuous second-order tracking retains velocity on clip/phase changes.
	# The limit applies only to relative posture, never actor spin/flip motion.
	frame_costs.end(&"animation_posture",posture_started)
	var tracking_started = frame_costs.begin()
	var tracked_action = action_amount*(1.0-pole_amount)
	var pole_carry = maxf(state.tuck,state.prepare)*(1.0-state.air)*carry*(1.0-pole_amount)
	var tracking = track_pose(mixed.q,tracked_action,pole_carry,articulated_carry,dt)
	root_velocity += ((mixed.root-root_position)*900.0-root_velocity*60.0).limit_length(35.0)*dt
	root_velocity = root_velocity.limit_length(2.0)
	root_position += root_velocity*dt
	frame_costs.end(&"animation_tracking",tracking_started)
	diagnostics = {"phase":phase,"physical_turn":turn,"animation_turn":animation_turn,"balance_turn":balance_turn,"turn_strength":turn_weight,"max_posture_speed_rad_s":tracking.y,"max_posture_accel_rad_s2":tracking.x}
	diagnostics.pole_phase = pole_phase; diagnostics.pole_intensity = pole_amount
	diagnostics.pole_power = sim.pole_push_power; diagnostics.pole_acceleration_mps2 = sim.pole_push_acceleration
	diagnostics.pole_grade_degrees = sim.pole_push_grade_degrees; diagnostics.pole_limit_mps = sim.pole_push_limit_mps
	step_microseconds = Time.get_ticks_usec()-start

func track_pose(requested_pose: Array[Quaternion], action: Vector3, pole_carry: float, forearm_carry: float, dt: float) -> Vector2:
	if native_tracking_enabled:
		return native_tracker.track_pose(requested_pose,current,velocities,action,pole_carry,forearm_carry,dt)
	return reference_track_pose(requested_pose,action,pole_carry,forearm_carry,dt)

func reference_track_pose(requested_pose: Array[Quaternion], action: Vector3, pole_carry: float, forearm_carry: float, dt: float) -> Vector2:
	var max_accel = 0.0
	var max_speed = 0.0
	for i in current.size():
		var requested = Basis(requested_pose[i])
		if grip_chains.has(library.names[i]):
			requested = Action.tracked_grip_target(library.names[i],requested,current,library,action,grip_chains[library.names[i]])
		var target_rotation = Anatomy.local_limit(library.names[i],requested,pole_carry,forearm_carry).get_rotation_quaternion()
		var error = rotation_vector(target_rotation*current[i].inverse())
		var accel = (error*1600.0-velocities[i]*80.0).limit_length(160.0)
		velocities[i] = (velocities[i]+accel*dt).limit_length(12.0)
		var speed_i = velocities[i].length()
		if speed_i>.000001: current[i] = (Quaternion(velocities[i]/speed_i,speed_i*dt)*current[i]).normalized()
		max_accel = maxf(max_accel,accel.length()); max_speed = maxf(max_speed,speed_i)
	return Vector2(max_accel,max_speed)

func step_poles(dt: float, sim, surface) -> void:
	pole_phase = sim.pole_push_phase
	var wrap = pole_phase<previous_pole_phase
	# Force tapers continuously near the speed cap; a tiny remaining impulse
	# still belongs to a complete planted stroke. Keep its authored reach and
	# release, instead of shrinking the arm motion into tuck during that force.
	# Only the completed solver phase advances this envelope. At the cap finish
	# the current release, then return to tuck without beginning another plant.
	var finish_release = _pole_was_loaded and not wrap and pole_phase<.90
	var requested: bool = sim.pole_push.active and (sim.pole_push_intensity>0.0 or sim.pole_push_acceleration>0.0 or finish_release)
	pole_amount = move_toward(pole_amount,maxf(.5,sim.pole_push_intensity) if requested else 0.0,dt*sim.tuning.pole_push_blend_rate)
	if not sim.grounded or sim.facing_backward: pole_amount = 0.0
	# Seed during reach, before force begins. Anticipate bounded travel during
	# this authored contact interval so a fast plant does not begin behind an
	# arm that cannot reach it by the end of the same stroke.
	if requested and (not _pole_was_loaded or wrap) and surface!=null:
		pole_anchors.clear(); pole_normals.clear()
		var phase_rate = maxf(fposmod(pole_phase-previous_pole_phase,1.0)/maxf(dt,.000001),.5)
		var travel = sim.velocity.slide(sim.surface_normal).length()*minf(.55,maxf(0.0,.76-pole_phase)/phase_rate)
		# Five centimetres of cosmetic reach reserve avoids the terminal
		# sphere tangency; it does not change pole length or the physical stroke.
		var lead = .25+minf(.65,.40*travel)
		for side in [-1.0,1.0]:
			var point: Vector3 = sim.position+sim.support_basis()*Vector3(side*.42,0.0,lead)
			var sample: Dictionary = surface.sample(point.x,point.z)
			point.y = sample.height
			pole_anchors.append(point)
			pole_normals.append(sample.normal.normalized())
	if requested and not _pole_was_loaded: pole_entry = true
	if pole_phase>=.06: pole_entry = false
	if requested:
		pole_targets = pole_anchors.duplicate(); pole_target_normals = pole_normals.duplicate()
		pole_target_stage = "plant"
		if pole_phase>.76 and (previous_pole_phase<=.76 or not _pole_was_loaded):
			pole_release_origin = sim.position
		if pole_phase>.76 and pole_phase<.90:
			# The poles have released: stop dragging a declining arm blend after
			# a world anchor the skier is already passing at ~10 m/s.
			pole_target_stage = "release"
			for i in pole_targets.size():
				pole_targets[i] += (sim.position-pole_release_origin).slide(pole_target_normals[i])
		elif pole_phase>=.90 and surface!=null:
			# Preview the next reachable plant in the completed support frame.
			# This target may move while unloaded; the next actual plant is fixed
			# by the existing tick seed above. No future state or render history.
			pole_target_stage = "approach"
			var speed: float = sim.velocity.slide(sim.surface_normal).length()
			var fast = smoothstep(2.0,40.0/3.6,speed)
			var duration = lerpf(.76,.26,fast)/maxf(sim.pole_push.cadence_hz,.5)
			var lead = .25+minf(.65,.40*speed*minf(.55,maxf(0.0,duration-dt)))
			pole_targets.clear(); pole_target_normals.clear()
			for side in [-1.0,1.0]:
				var point: Vector3 = sim.position+sim.support_basis()*Vector3(side*.42,0.0,lead)
				var sample: Dictionary = surface.sample(point.x,point.z)
				point.y = sample.height
				pole_targets.append(point); pole_target_normals.append(sample.normal.normalized())
	else:
		pole_target_stage = "cancel"
		for i in pole_targets.size():
			pole_targets[i] += (sim.position-pole_last_position).slide(pole_target_normals[i])
	pole_plant = PolePose.contact_weight(pole_phase) if requested else move_toward(pole_plant,0.0,dt*12.0)
	if requested and pole_entry: pole_plant *= smoothstep(0.0,.06,pole_phase)
	# Carry owns the unloaded shaft lane independently of snow contact. A
	# completed-tick envelope avoids snapping into tuck when forward is released
	# exactly at the zero-contact midpoint; render/preview never advances it.
	pole_carry = move_toward(pole_carry,1.0 if requested else 0.0,dt*6.0)
	if not sim.grounded or sim.facing_backward or (pole_amount<=.000001 and pole_carry<=.000001):
		pole_plant = 0.0; pole_carry = 0.0; pole_anchors.clear(); pole_normals.clear(); pole_targets.clear(); pole_target_normals.clear()
		pole_target_stage = "inactive"
	pole_last_position = sim.position
	_pole_was_loaded = requested

func refine_authored_pose(_pose: Dictionary, _state: Dictionary, _action: Vector3) -> void:
	# Optional authoring experiment, before the shared limits and tick tracker.
	# Production has no additional layer. The final skeleton writer is unchanged.
	pass

static func supported_turn(sim) -> float:
	# Read each ski's constrained, completed edge, not the input-driven global
	# edge request. An unloaded ski must not select a committed carving pose.
	var edge = 0.0
	var load = 0.0
	for ski in sim.skis:
		if not ski.grounded: continue
		var weight = maxf(0.0,ski.load_n)
		edge -= ski.edge_angle*weight
		load += weight
	var supported_edge = edge/maxf(1.0,load)
	return clampf(supported_edge/.65,-1.0,1.0)*smoothstep(0.0,sim.tuning.rider_mass*3.0,load)

func fit_tuck_flexion(pose: Dictionary, tuck: float) -> void:
	# Retain the source's deep sagittal fold without forcing all of it through
	# two short lumbar links. Hip flexion supplies the limited spine's deficit.
	# This modifies the full time-varying source pose before tick tracking.
	if tuck<.00001: return
	var hip = library.names.find("Hips")
	var lumbar = library.names.find("Spine02")
	var middle = library.names.find("Spine01")
	var chest = library.names.find("Spine")
	var deficit = 0.0
	for i in [lumbar,middle,chest]:
		var source = Anatomy.vector(pose.q[i])
		var limited = Anatomy.vector(Anatomy.local_limit(library.names[i],Basis(pose.q[i])).get_rotation_quaternion())
		deficit += maxf(0.0,source.x-limited.x)
	var hip_vector = Anatomy.vector(pose.q[hip])
	var hip_share = minf(deficit*.75,maxf(0.0,deg_to_rad(53.0)-hip_vector.x))*tuck
	hip_vector.x += hip_share
	pose.q[hip] = Anatomy.basis(hip_vector).get_rotation_quaternion()
	var upper = Anatomy.vector(pose.q[chest])
	upper.x += minf(maxf(0.0,deficit*tuck-hip_share),maxf(0.0,deg_to_rad(18.0)-upper.x))
	pose.q[chest] = Anatomy.basis(upper).get_rotation_quaternion()

func fit_arm_carry(pose: Dictionary, tuck: float, preparation: float, weight: float) -> void:
	if weight<.00001: return
	# Correct local articulation before velocity tracking. The shoulder swing
	# places elbows beside the ribs, and humeral twist gathers the forearms;
	# neither operation translates a wrist or breaks the elbow hinge.
	var chest_frame = Basis.IDENTITY
	for bone in ["Hips","Spine02","Spine01","Spine"]:
		chest_frame *= Anatomy.local_limit(bone,Basis(pose.q[library.names.find(bone)]))
	for prefix in ["Right","Left"]:
		var arm = library.names.find(prefix+"Arm")
		var elbow = library.names.find(prefix+"ForeArm")
		var clavicle = library.names.find(prefix+"Shoulder")
		var parent = Anatomy.local_limit(prefix+"Shoulder",Basis(pose.q[clavicle]))
		var direction: Vector3 = parent*Basis(pose.q[arm])*(library.rest[elbow].origin-library.rest[arm].origin)
		var desired = direction
		var side = -1.0 if prefix=="Right" else 1.0
		var outward = lerpf(.055,.040,tuck)
		outward = lerpf(outward,minf(outward,.025),preparation)
		desired.x = side*minf(direction.x*side,outward)
		var arc = rotation_vector(Quaternion(direction.normalized(),desired.normalized()))
		pose.q[arm] = (parent.transposed()*Anatomy.basis(arc.limit_length(deg_to_rad(50.0))*weight)*parent*Basis(pose.q[arm])).get_rotation_quaternion()
		var hand = library.names.find(prefix+"Hand")
		var humerus = parent*Basis(pose.q[arm])
		var axis: Vector3 = (humerus*(library.rest[elbow].origin-library.rest[arm].origin)).normalized()
		var forearm: Vector3 = humerus*Anatomy.local_limit(prefix+"ForeArm",Basis(pose.q[elbow]))*(library.rest[hand].origin-library.rest[elbow].origin)
		var gathered = forearm
		gathered.x = side*lerpf(minf(forearm.x*side,.035),.075,tuck)
		var twist = forearm.slide(axis).signed_angle_to(gathered.slide(axis),axis)
		# Humeral rotation gathers the gloves while the elbow remains a hinge.
		pose.q[arm] = (parent.transposed()*Basis(axis,clampf(twist,-deg_to_rad(40.0),deg_to_rad(40.0))*weight)*humerus).get_rotation_quaternion()
		# The shaft belongs to the palm. Re-aim through the wrist envelope after
		# gathering the arm; otherwise that shoulder correction fans poles out.
		var forearm_frame = chest_frame*parent*Basis(pose.q[arm])*Anatomy.local_limit(prefix+"ForeArm",Basis(pose.q[elbow]))
		var palm = forearm_frame*Basis(pose.q[hand])
		var trail = Vector3(side*lerpf(.08,.24,tuck),lerpf(-.55,.03,tuck),-1.0).normalized()
		var aimed = Basis(Quaternion(-palm.z,trail))*palm
		var wrist = Anatomy.local_limit(prefix+"Hand",forearm_frame.transposed()*aimed,tuck*weight)
		pose.q[hand] = Basis(pose.q[hand]).slerp(wrist,weight).get_rotation_quaternion()

func duration(name: String) -> float:
	return library.clips[name].duration

func add(name: String, weight: float, time: float, looping: bool, mirror: bool = false) -> void:
	if weight>.00001: weights[name] = {"weight":weight,"time":time,"loop":looping,"mirror":mirror}

func scale_weights(scale_value: float) -> void:
	for name in weights: weights[name].weight *= scale_value

func sample_clip(name: String, time: float, looping: bool = false) -> Dictionary:
	var clip: Dictionary = prepared_clips[name]
	var seam = minf(.25,clip.duration*.2)
	var t: float = clampf(time,0.0,clip.duration)
	if looping: t = seam+fposmod(time,maxf(.01,clip.duration-seam))
	var pose = sample_raw(clip,t)
	if looping and t>clip.duration-seam:
		var other = sample_raw(clip,t-(clip.duration-seam))
		var alpha = smoothstep(clip.duration-seam,clip.duration,t)
		for i in pose.q.size(): pose.q[i] = pose.q[i].slerp(other.q[i],alpha)
		pose.root = pose.root.lerp(other.root,alpha)
	return pose

func sample_raw(clip: Dictionary, time: float) -> Dictionary:
	var cursor = clampf(time*60.0,0.0,clip.frames-1.0)
	var a = int(cursor)
	var b = mini(a+1,clip.frames-1)
	var f = cursor-a
	var count: int = library.names.size()
	var values: Array[Quaternion] = clip.rotations
	var roots: PackedVector3Array = clip.roots
	var qs: Array[Quaternion] = []
	qs.resize(count)
	var ai = a*count; var bi = b*count
	for i in count: qs[i] = values[ai+i].slerp(values[bi+i],f)
	return {"q":qs,"root":roots[a].lerp(roots[b],f)}

func mirror_pose(pose: Dictionary) -> Dictionary:
	var result: Array[Quaternion] = []
	for i in library.names.size():
		var name: String = library.names[i]
		var opposite = name.replace("Left","Right") if name.begins_with("Left") else name.replace("Right","Left")
		var q: Quaternion = pose.q[library.names.find(opposite)]
		result.append(Quaternion(q.x,-q.y,-q.z,q.w))
	return {"q":result,"root":Vector3(-pose.root.x,pose.root.y,pose.root.z)}

static func rotation_vector(q: Quaternion) -> Vector3:
	q = q.normalized()
	if q.w<0.0: q = -q
	var axis = Vector3(q.x,q.y,q.z)
	return axis.normalized()*2.0*atan2(axis.length(),maxf(0.0,q.w))

func sample(fraction: float) -> Dictionary:
	interpolation_microseconds = 0
	if current.is_empty(): return {}
	if amount==0.0 and previous_amount==0.0: return {}
	var start = Time.get_ticks_usec()
	var poses = {}; var rotations = {}
	for i in current.size():
		var id: String = library.names[i]
		var parent: int = library.parents[i]
		var local = Basis(previous[i].slerp(current[i],fraction))
		if parent<0:
			rotations[id] = local
			poses[id] = previous_root.lerp(root_position,fraction)
		else:
			var pid: String = library.names[parent]
			rotations[id] = rotations[pid]*local
			poses[id] = poses[pid]+rotations[pid]*(library.rest[i].origin-library.rest[parent].origin)
	interpolation_microseconds = Time.get_ticks_usec()-start
	var pushing = lerpf(previous_pole_amount,pole_amount,fraction)
	var sampled_targets = pole_targets.duplicate(); var sampled_normals = pole_target_normals.duplicate()
	if previous_pole_targets.size()==2 and sampled_targets.size()==2:
		for i in 2:
			sampled_targets[i] = previous_pole_targets[i].lerp(pole_targets[i],fraction)
			sampled_normals[i] = previous_pole_target_normals[i].lerp(pole_target_normals[i],fraction).normalized()
	return {"joints":poses,"rotations":rotations,"amount":lerpf(previous_amount,amount,fraction),"grip":lerpf(previous_grip,grip_amount,fraction),"downhill":lerpf(previous_downhill,downhill_amount,fraction)*(1.0-pushing),"action":previous_action.lerp(action_amount,fraction)*(1.0-pushing),"impact_posture":lerpf(previous_impact_posture,impact_posture,fraction),"support_response":lerpf(previous_support_response,support_response,fraction),"pole_amount":pushing,"pole_phase":fposmod(lerp_angle(previous_pole_phase*TAU,pole_phase*TAU,fraction)/TAU,1.0),"pole_plant":lerpf(previous_pole_plant,pole_plant,fraction),"pole_carry":lerpf(previous_pole_carry,pole_carry,fraction),"pole_anchors":pole_anchors.duplicate(),"pole_normals":pole_normals.duplicate(),"pole_targets":sampled_targets,"pole_target_normals":sampled_normals,"pole_target_stage":pole_target_stage}

static func upright_support(frame: Basis) -> Basis:
	# Source banking is authored about a sagittal up axis. Terrain up acquires
	# an outward roll as a skier yaws across a steep slope; inheriting that roll
	# makes a correct local carve visibly lean the other way at turn entry.
	# Retain slope pitch and heading, removing only this cross-slope roll.
	var forward = frame.z.normalized()
	var right = Vector3.UP.cross(forward)
	if right.length_squared()<.0001: return Basis.IDENTITY
	right = right.normalized()
	return (frame.orthonormalized().transposed()*Basis(right,forward.cross(right),forward)).orthonormalized()

func compose(body, joints: Dictionary, rotations: Dictionary, sampled: Dictionary, state: Dictionary, retention: float = 1.0, support_pelvis: Vector3 = Vector3.INF, support_alignment: Basis = Basis.IDENTITY) -> void:
	var start = Time.get_ticks_usec()
	var pelvis_started = frame_costs.begin()
	var weight: float = sampled.get("amount",0.0)*retention
	if state.is_empty(): state = {"grab":0.0,"air":0.0}
	var native: Dictionary = sampled.joints if sampled.has("joints") else joints.duplicate()
	var native_rot: Dictionary = sampled.rotations if sampled.has("rotations") else rotations.duplicate()
	var feet: Vector3 = (joints.RightFoot+joints.LeftFoot)*.5
	var target: Vector3 = feet+native.Hips
	var source_target = target
	# Grounded clips articulate around the physical pelvis transfer. Their
	# recovered support-relative root must not replace the rider's balance with
	# a forward-shifted or opposite-side pelvis. The physical crouch leads the
	# visible lowering: preserving the absolute source height left the hips high
	# while only the chest folded. Keep source sway and deeper source compression;
	# takeoff/flight/grabs retain their source shape.
	var support_weight = (1.0-state.get("air",0.0))*(1.0-state.get("prepare",0.0))
	if support_pelvis.is_finite():
		target.x = lerpf(target.x,support_pelvis.x+clampf(native.Hips.x,-.05,.05),support_weight*.65)
		var compression = maxf(state.get("tuck",0.0),absf(state.get("carve",0.0)))
		target.y = lerpf(target.y,minf(target.y,support_pelvis.y-.03*compression),support_weight*.95)
		var supported_back = support_pelvis.z+clampf(native.Hips.z,-.02,.01)-.05*compression
		target.z = lerpf(target.z,supported_back,support_weight*.95)
	target.y -= .08*smoothstep(.0,1.0,state.grab)*state.air
	# Full root translation is already removed offline. Reach fitting can move
	# the pelvis only; binding frames cannot follow a stored clip.
	var displacement: Vector3 = target-joints.Hips
	target = joints.Hips+displacement.limit_length(.38)
	var procedural = rotations.duplicate()
	var pelvis: Basis = Anatomy.local_limit("Hips",rotations.Hips.orthonormalized().slerp(native_rot.Hips.orthonormalized(),weight))
	# Straight downhill uses a feasible knee-forward compression curve. The
	# old support minimum could keep lowering after tuck release, and its rear
	# bias left the relaxed shins nearly vertical. Keep actual cuff frames fixed.
	var downhill: float = sampled.get("downhill",0.0)
	var action: Vector3 = sampled.get("action",Vector3.ZERO)
	var pushing: float = sampled.get("pole_amount",0.0)
	# A lingering ski edge must not bank the straight stance target after the
	# path has settled. This changes the pelvis target, never the rigid cuffs.
	var stance_up: Vector3 = (rotations.RightFoot.y+rotations.LeftFoot.y).normalized()
	stance_up.x *= sampled.get("support_response",1.0)
	stance_up = stance_up.normalized()
	if downhill>.00001 and support_pelvis.is_finite():
		var tuck: float = state.get("tuck",0.0)
		var prep = smoothstep(0,1,state.get("prepare",0.0))
		var up = stance_up
		var forward: Vector3 = (rotations.RightFoot.z+rotations.LeftFoot.z).slide(up).normalized()
		var height = lerpf(lerpf(.72,.49,tuck),.405,prep)+.004*state.get("pulse",0.0)
		var flex = deg_to_rad(lerpf(lerpf(18,23,tuck),23.5,prep))
		var shin: float = body.REST.RightLeg.distance_to(body.REST.RightFoot)
		var thigh: float = body.REST.RightUpLeg.distance_to(body.REST.RightLeg)
		var hip_offset: Vector3 = pelvis*((body.REST.RightUpLeg+body.REST.LeftUpLeg)*.5-body.REST.Hips)
		var leg_rise = height+hip_offset.dot(up)-shin*cos(flex)
		var backward = sqrt(maxf(.001,thigh*thigh-leg_rise*leg_rise))
		var fore_aft = shin*sin(flex)-backward-hip_offset.dot(forward)
		var supported = feet+up*height+forward*fore_aft
		# Retain small source sway without translating the physical support.
		supported.x += clampf(native.Hips.x,-.012,.012)
		target = target.lerp(supported,downhill)
	if action.x+action.z>.00001:
		# A bank reduces world height by inclination, not by folding both knees
		# into a seat. Build the stance along the actual cuff/support up axes;
		# the usual shared-pelvis and rigid-leg fit still closes the chain.
		var up: Vector3 = stance_up.lerp((rotations.RightFoot.y+rotations.LeftFoot.y).normalized(),action.z/maxf(action.x+action.z,.00001)).normalized()
		var forward: Vector3 = (rotations.RightFoot.z+rotations.LeftFoot.z).slide(up).normalized()
		var carved = feet+up*(.76-.04*absf(state.get("carve",0.0)))-forward*.10
		target = target.lerp(carved,action.x)
		# Absorption needs a reachable hip path, not only a lower Y target.
		# With rigid cuffs, lowering vertically makes reach fitting push the
		# pelvis up again. Solve the backward thigh travel at the same cuff flex.
		var impact: float = sampled.get("impact_posture",0.0)
		var height = .73-.24*impact
		var flex = deg_to_rad(18.0+5.5*impact)
		var shin: float = body.REST.RightLeg.distance_to(body.REST.RightFoot)
		var thigh: float = body.REST.RightUpLeg.distance_to(body.REST.RightLeg)
		var hip_offset: Vector3 = pelvis*((body.REST.RightUpLeg+body.REST.LeftUpLeg)*.5-body.REST.Hips)
		var leg_rise = height+hip_offset.dot(up)-shin*cos(flex)
		var backward = sqrt(maxf(.001,thigh*thigh-leg_rise*leg_rise))
		var fore_aft = shin*sin(flex)-backward-hip_offset.dot(forward)
		var absorbed = feet+up*height+forward*fore_aft
		target = target.lerp(absorbed,action.z)
	if pushing>.00001:
		var up: Vector3 = (rotations.RightFoot.y+rotations.LeftFoot.y).normalized()
		var forward: Vector3 = (rotations.RightFoot.z+rotations.LeftFoot.z).slide(up).normalized()
		var stroke = preload("res://scripts/core/pole_propulsion.gd").stroke_power(sampled.get("pole_phase",0.0))
		# A modest supported leg pulse accompanies the authored torso load;
		# shared pelvis/cuff fitting below retains the physical equipment.
		target = target.lerp(feet+up*(.73-.055*stroke)-forward*.12,pushing)
	# Align the connected gliding/carving body in the same unbanked support
	# frame. Boots remain in their physical frames; shared-pelvis/leg fitting
	# below closes the chain. Apply alignment outside local joint limits: it is
	# a reference-frame correction, not extra hip or spine articulation.
	var alignment = Basis.IDENTITY.slerp(support_alignment,clampf(downhill+action.x,0.0,1.0))
	target = feet+alignment*(target-feet)
	pelvis = Basis.IDENTITY.slerp(alignment,weight)*pelvis
	displacement = target-joints.Hips
	target = joints.Hips+displacement.limit_length(.38)
	var wanted_hips: Vector3 = joints.Hips.lerp(target,weight)
	var ankles: Array[Vector3] = [joints.RightFoot,joints.LeftFoot]
	var boots: Array[Basis] = [rotations.RightFoot,rotations.LeftFoot]
	var fitted: Vector3 = Anatomy.fit_pelvis(wanted_hips,pelvis,ankles,boots)
	requested_joints = native.duplicate(); requested_rotations = native_rot.duplicate()
	for id in requested_joints:
		requested_joints[id] = feet+alignment*requested_joints[id]
	# Procedural-only comparisons include toe positions without toe rotations.
	for id in requested_rotations:
		requested_rotations[id] = alignment*requested_rotations[id]
	joints.Hips = fitted; rotations.Hips = pelvis
	frame_costs.end(&"pose_pelvis",pelvis_started)
	var hierarchy_started = frame_costs.begin()
	# Blend parent-relative articulation, then rebuild the connected hierarchy.
	# Blending global orientations separately lets parent fitting alter the
	# child's local joint angle and was a source of rubbery spinal/arm motion.
	var pole_carry = maxf(state.get("tuck",0.0),state.get("prepare",0.0))*(1.0-state.air)*Downhill.straight(state)*(1.0-pushing)
	var articulated_carry = maxf(pushing,clampf(downhill+action.x+action.y+action.z,0.0,1.0))
	for i in library.names.size():
		var id: String = library.names[i]
		if id=="Hips" or id.ends_with("Foot") or id.ends_with("ToeBase"): continue
		if not body.REST.has(id): continue
		var pid: String = library.names[library.parents[i]]
		var source_local: Basis = native_rot[pid].transposed()*native_rot[id]
		var local = source_local.orthonormalized()
		if weight!=1.0:
			var old_local: Basis = procedural.get(pid,Basis.IDENTITY).transposed()*procedural.get(id,Basis.IDENTITY)
			local = old_local.orthonormalized().slerp(local,weight)
		rotations[id] = rotations[pid]*Anatomy.local_limit(id,local,pole_carry,articulated_carry)
		joints[id] = joints[pid]+rotations[pid]*(body.REST[id]-body.REST[pid])
	# The recovered safety clip reaches with the RIGHT hand. Its pole stays
	# in the fixed glove; preserve the source's opposite-arm counterbalance.
	var hand: Vector3 = joints.RightHand
	frame_costs.end(&"pose_hierarchy",hierarchy_started)
	var grip_started = frame_costs.begin()
	var foot = "LeftFoot" if active_grab_style=="mute" else "RightFoot"
	var grip: Vector3 = joints[foot]+rotations[foot]*SKI_GRIP
	var grab: float = smoothstep(.05,.95,sampled.get("grip",0.0))*weight
	var shoulder: Vector3 = joints.RightArm
	var upper: float = body.REST.RightArm.distance_to(body.REST.RightForeArm)
	var lower: float = body.REST.RightForeArm.distance_to(body.REST.RightHand)
	# A small distributed reach can use remaining spine/clavicle range. Each
	# link stays inside the same joint contract as ordinary skiing; unreachable
	# anchors cannot pull the torso or elbow through their stops.
	var reach_correction = 0.0
	if grab>.00001:
		# Hip flexion supplies most of a reach; hinging the waist is preferable
		# to folding one short spinal link. The physical boot frames stay fixed.
		var wrist_target: Vector3 = grip-rotations.RightHand*GLOVE_GRIP
		var hip_demand = smoothstep(upper+lower-.07,upper+lower+.25,shoulder.distance_to(wrist_target))*grab
		var hip_arc = rotation_vector(Quaternion((shoulder-joints.Hips).normalized(),(wrist_target-joints.Hips).normalized()))
		var hip_target = Anatomy.local_limit("Hips",Anatomy.basis(hip_arc.limit_length(deg_to_rad(32.0))*hip_demand)*rotations.Hips)
		# The arc already contains reach demand; applying it again squared the
		# available accommodation and left the calibrated glove short of reach.
		var hip_correction: Basis = rotations.Hips.orthonormalized().slerp(hip_target.orthonormalized(),grab)*rotations.Hips.transposed()
		var locked_joints = {}; var locked_rotations = {}
		for id in joints:
			if id.ends_with("Foot") or id.ends_with("ToeBase"):
				locked_joints[id] = joints[id]; locked_rotations[id] = rotations.get(id,Basis.IDENTITY)
		rotate_subtree("Hips",hip_correction,joints,rotations)
		for id in locked_joints: joints[id] = locked_joints[id]; rotations[id] = locked_rotations[id]
		var hip_fit = Anatomy.fit_pelvis(joints.Hips,rotations.Hips,ankles,boots)
		var shift: Vector3 = hip_fit-joints.Hips
		for id in joints:
			if not locked_joints.has(id): joints[id] += shift
		shoulder = joints.RightArm
		reach_correction += rotation_vector(hip_correction.get_rotation_quaternion()).length()
		for link in [["Hips","Spine02"],["Spine02","Spine01"],["Spine01","Spine"],["Spine","RightShoulder"]]:
			var pivot: Vector3 = joints[link[1]]
			wrist_target = grip-rotations.RightHand*GLOVE_GRIP
			var arc = rotation_vector(Quaternion((shoulder-pivot).normalized(),(wrist_target-pivot).normalized()))
			var demand = smoothstep(upper+lower-.07,upper+lower+.25,shoulder.distance_to(wrist_target))*grab
			var requested = Anatomy.basis(arc.limit_length(deg_to_rad(12.0))*demand)*rotations[link[1]]
			var parent: Basis = rotations[link[0]]
			var allowed = parent*Anatomy.local_limit(link[1],parent.transposed()*requested)
			var correction: Basis = rotations[link[1]].orthonormalized().slerp(allowed.orthonormalized(),grab)*rotations[link[1]].transposed()
			reach_correction += rotation_vector(correction.get_rotation_quaternion()).length()
			rotate_subtree(link[1],correction,joints,rotations)
			shoulder = joints.RightArm
		hand = joints.RightHand
	var wanted = hand.lerp(grip-rotations.RightHand*GLOVE_GRIP,grab)
	# Soft reach removes the hard branch at full arm extension.
	var delta = wanted-shoulder
	var maximum = upper+lower-.006
	var distance_value = delta.length()
	var soft = maximum-.025
	if distance_value>soft:
		distance_value = soft+.025*(1.0-exp(-(distance_value-soft)/.025))
	wanted = shoulder+delta.normalized()*distance_value
	var hint: Vector3 = joints.RightForeArm-shoulder
	if grab>.00001:
		var wrist_local: Basis = rotations.RightForeArm.transposed()*rotations.RightHand
		# Rotate the elbow plane on its reach circle towards a permitted
		# shoulder orientation. This retains the target without adding wrist
		# bend, elbow swivel, or an independent axial twist after the solve.
		for iteration in 8:
			var wrist_goal: Vector3 = hand.lerp(grip-rotations.RightHand*GLOVE_GRIP,grab)
			var reach = wrist_goal-shoulder
			var reach_distance: float = reach.length()
			if reach_distance>soft: reach_distance = soft+.025*(1.0-exp(-(reach_distance-soft)/.025))
			wanted = shoulder+reach.normalized()*reach_distance
			joints.RightHand = wanted
			joints.RightForeArm = body.joint(shoulder,wanted,upper,lower,hint)
			Anatomy.fit_hinge("Right",true,joints,rotations)
			var elbow_local: Basis = rotations.RightArm.transposed()*rotations.RightForeArm
			rotations.RightArm = rotations.RightShoulder*Anatomy.local_limit("RightArm",rotations.RightShoulder.transposed()*rotations.RightArm)
			rotations.RightForeArm = rotations.RightArm*Anatomy.local_limit("RightForeArm",elbow_local)
			joints.RightForeArm = shoulder+rotations.RightArm*(body.REST.RightForeArm-body.REST.RightArm)
			joints.RightHand = joints.RightForeArm+rotations.RightForeArm*(body.REST.RightHand-body.REST.RightForeArm)
			rotations.RightHand = rotations.RightForeArm*Anatomy.local_limit("RightHand",wrist_local)
			var glove_direction: Vector3 = rotations.RightHand*GLOVE_GRIP
			var grip_direction: Vector3 = grip-joints.RightHand
			if grip_direction.length_squared()>.000001:
				var grip_arc = rotation_vector(Quaternion(glove_direction.normalized(),grip_direction.normalized()))
				var aimed: Basis = Anatomy.basis(grip_arc*grab)*rotations.RightHand
				rotations.RightHand = rotations.RightForeArm*Anatomy.local_limit("RightHand",rotations.RightForeArm.transposed()*aimed)
			hint = joints.RightForeArm-shoulder
	var glove: Vector3 = joints.RightHand+rotations.RightHand*GLOVE_GRIP
	diagnostics.grip_required_reach_m = shoulder.distance_to(grip)
	diagnostics.grip_arm_reach_residual_m = wanted.distance_to(grip) if grab>.95 else 0.0
	diagnostics.pelvis_fit_m = wanted_hips.distance_to(fitted)
	diagnostics.pelvis_support_bias_m = source_target.distance_to(target)
	diagnostics.source_hips_forward_m = source_target.z-feet.z
	diagnostics.fitted_hips_forward_m = joints.Hips.z-feet.z
	diagnostics.source_hips_height_m = source_target.y-feet.y
	diagnostics.fitted_hips_height_m = joints.Hips.y-feet.y
	if support_pelvis.is_finite():
		diagnostics.physical_hips_forward_m = support_pelvis.z-feet.z
		diagnostics.physical_hips_height_m = support_pelvis.y-feet.y
	diagnostics.root_budget_m = displacement.length()-displacement.limit_length(.38).length()
	diagnostics.grip_reach_error_m = glove.distance_to(grip) if grab>.95 else 0.0
	diagnostics.grip_shoulder_correction_rad = reach_correction
	diagnostics.grip_contact_weight = grab*(1.0-smoothstep(.004,.04,glove.distance_to(grip)))
	diagnostics.grip_phase = grab
	diagnostics.clearance_retention = retention
	fit_microseconds = Time.get_ticks_usec()-start
	frame_costs.end(&"pose_grip",grip_started)

func rotate_subtree(root_name: String, correction: Basis, joints: Dictionary, rotations: Dictionary) -> void:
	var descendants = [root_name]
	var pivot: Vector3 = joints[root_name]
	for i in library.names.size():
		var id: String = library.names[i]
		var parent: int = library.parents[i]
		if parent>=0 and library.names[parent] in descendants: descendants.append(id)
		if id in descendants and joints.has(id):
			joints[id] = pivot+correction*(joints[id]-pivot)
			if rotations.has(id): rotations[id] = (correction*rotations[id]).orthonormalized()
