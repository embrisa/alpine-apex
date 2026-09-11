extends RefCounted
## Fixed-tick presentation state. Reads completed simulation; never writes it.
const Profiles = preload("res://assets/animation/apex_ski_motion.gd").PROFILES
const Tuning = preload("res://scripts/presentation/skier_animation_tuning.gd")
var tuning = Tuning.new()
var current: Dictionary = {}
var previous: Dictionary = {}
var initialized = false
var last_tick = -1
var last_position = Vector3.ZERO
var was_grounded = true
var takeoff_age = 60.0
var takeoff_power = 0.0
var landing_age = 60.0
var landing_speed = 0.0
var landing_side = 0.0
var landing_duration = .25
var landing_depth = 0.0
var landing_events = 0
var phase = "ride"
var prediction_samples = 0
var collision_age = 60.0
var collision_speed = 0.0
var collision_direction = Vector3.ZERO
var collision_events = 0
var clearance_surface
var full_motion = preload("res://scripts/presentation/skier_full_motion.gd").new()

func reset(sim) -> void:
	current = {"tuck":sim.effective_tuck,"prepare":0.0,"extension":0.0,
		"air":0.0 if sim.grounded else 1.0,"steer":0.0,"brake":0.0,"carve":0.0,
		"ready":0.0,"impact":0.0,"impact_drop":0.0,"impact_side":0.0,"transfer":0.0,
		"compact":0.0,"absorbed":0.0,"skid":0.0,"load_bias":0.0,"impairment":0.0,"grab":0.0,"pulse":0.0,"turn_follow":0.0,"recoil":0.0,"recoil_x":0.0,"recoil_z":0.0,
		"spine_flex":deg_to_rad(lerpf(tuning.spine_relaxed_degrees,tuning.spine_tuck_degrees,sim.effective_tuck))}
	previous = current.duplicate()
	last_tick = sim.ticks
	last_position = sim.position
	was_grounded = sim.grounded
	takeoff_age = 60.0
	takeoff_power = 0.0
	landing_age = 60.0
	landing_speed = 0.0
	landing_side = 0.0
	landing_duration = tuning.landing_recovery_seconds.x
	landing_depth = 0.0
	landing_events = 0
	prediction_samples = 0
	collision_age = 60.0
	collision_speed = 0.0
	collision_direction = Vector3.ZERO
	collision_events = 0
	clearance_surface = null
	phase = "ride" if sim.grounded else "air"
	initialized = true
	full_motion.reset(sim)

func hold() -> void:
	# Pause freezes the visible pose. Preparation decays after resume, but the
	# input lifecycle has already cancelled any pending jump command.
	previous = current.duplicate()
	full_motion.hold()

func sample(fraction: float = 1.0) -> Dictionary:
	var result: Dictionary = {}
	for key in current:
		result[key] = lerpf(previous.get(key,current[key]),current[key],clampf(fraction,0.0,1.0))
	return result

func step(dt: float, sim, intent, surface) -> void:
	if not initialized or sim.ticks<last_tick or sim.position.distance_to(last_position)>maxf(5.0,sim.velocity.length()*dt*4.0):
		reset(sim)
	clearance_surface = surface
	if sim.ticks==last_tick: return
	last_tick = sim.ticks
	last_position = sim.position
	previous = current.duplicate()
	if sim.crashed:
		# The ragdoll receives the last composed expression, not a neutral pose.
		phase = "crash"
		return
	takeoff_age += dt
	landing_age += dt
	collision_age += dt
	var signals = sim.motion
	var contact: Dictionary = signals.obstacle_contact
	if not contact.is_empty() and contact.closing_speed_mps>=tuning.collision_min_speed_mps:
		if collision_age>=tuning.collision_group_seconds:
			collision_age = 0.0
			collision_speed = 0.0
			collision_events += 1
		if contact.closing_speed_mps>collision_speed:
			collision_speed = contact.closing_speed_mps
			collision_direction = contact.normal
	var recoil: float = smoothstep(0.0,.08,collision_age)*(1.0-smoothstep(.08,tuning.collision_recovery_seconds,collision_age))
	recoil *= clampf(collision_speed/tuning.collision_reference_mps,0.0,1.0)
	var local_collision: Vector3 = sim.support_basis().transposed()*collision_direction
	current.recoil = recoil
	current.recoil_x = local_collision.x*recoil
	current.recoil_z = local_collision.z*recoil
	if sim.jump_executed or (was_grounded and not sim.grounded):
		takeoff_age = 0.0
		takeoff_power = 1.0 if signals.jump_executed else Profiles.natural_departure.power
	# Per-ski telemetry includes asymmetric support regain; the root impact
	# also catches a landing which releases again within the same tick.
	var right: float = signals.skis[0].get("landing_speed_mps",0.0)
	var left: float = signals.skis[1].get("landing_speed_mps",0.0)
	var impact: float = maxf(right,left)
	if sim.time_since_landing<dt*.5: impact = maxf(impact,sim.landing_force)
	if impact>=tuning.landing_min_speed_mps:
		var new_event: bool = landing_age>=tuning.landing_group_seconds
		if new_event:
			landing_age = 0.0
			landing_speed = 0.0
			landing_events += 1
		if impact>landing_speed:
			landing_speed = impact
			landing_side = (left-right)/maxf(left+right,.001)
			var profile = landing_profile(impact)
			landing_duration = profile.x
			landing_depth = profile.y
		# Impact can interrupt even a very short hop immediately.
		takeoff_age = tuning.takeoff_seconds
	var response: float = 1.0-exp(-tuning.response_hz*dt)
	current.tuck = lerpf(current.tuck,sim.effective_tuck,response)
	current.brake = lerpf(current.brake,intent.brake,response)
	current.steer = lerpf(current.steer,intent.steer,response)
	current.prepare = move_toward(current.prepare,1.0 if intent.jump_held and sim.grounded else 0.0,dt/tuning.preparation_seconds)
	var flight: float = 0.0 if sim.grounded else 1.0
	current.air = lerpf(current.air,flight,1.0-exp(-18.0*dt))
	var load: float = sim.skis[0].load_n+sim.skis[1].load_n
	current.load_bias = lerpf(current.load_bias,(sim.skis[1].load_n-sim.skis[0].load_n)/maxf(load,1.0),response)
	current.skid = lerpf(current.skid,smoothstep(deg_to_rad(8),deg_to_rad(20),absf(signals.slip_rad))*(1.0-current.air),response)
	current.turn_follow = lerpf(current.turn_follow,clampf(signals.turn_rate_rad_s,-1.0,1.0),1.0-exp(-6.0*dt))
	current.impairment = lerpf(current.impairment,(1.0-signals.reserve_01)*smoothstep(0.0,.12,signals.time_since_damage_s),1.0-exp(-3.0*dt))
	var grab_target = 1.0 if intent.grab and not sim.grounded else 0.0
	current.grab = move_toward(current.grab,grab_target,dt/(Profiles.safety_grab.blend_in_s if grab_target>current.grab else Profiles.safety_grab.blend_out_s))
	current.pulse = sin(sim.ticks*dt*TAU*.70)*smoothstep(2.0,12.0,signals.speed_mps)*(1.0-current.air)*(1.0-absf(current.carve))
	var load_bias: float = (sim.skis[1].load_n-sim.skis[0].load_n)/maxf(load,1.0)
	var carve: float = clampf(sim.body.roll/.85,-1.0,1.0)*smoothstep(.02,.35,absf(sim.edge_angle))
	carve *= smoothstep(0.0,sim.tuning.rider_mass*6.0,load)
	carve = carve*.8-load_bias*.2 if sim.grounded else 0.0
	current.carve = lerpf(current.carve,carve,response)
	var transfer: float = 1.0 if sim.grounded and sim.body.roll*intent.steer<-.025 else 0.0
	current.transfer = lerpf(current.transfer,transfer,response)
	var extension: float = sin(clampf(takeoff_age/tuning.takeoff_seconds,0.0,1.0)*PI)*takeoff_power
	current.extension = extension if not sim.grounded else 0.0
	var ready: float = landing_readiness(sim,surface) if not sim.grounded else 0.0
	current.ready = lerpf(current.ready,ready,response)
	# Small natural gaps do not play a full knee-gather. Readiness opens the
	# legs before contact while held tuck adds compactness without changing drag.
	current.compact = smoothstep(tuning.air_gather_start_seconds,tuning.air_gather_seconds,takeoff_age)*current.air*(1.0-current.ready*.75)
	var physical_drop: float = maxf(0.0,.94-sim.effective_tuck*.22-sim.body.pelvis_height)
	current.absorbed = lerpf(current.absorbed,physical_drop,response)
	# Budget the physical leg compression first. The cosmetic layer fills the
	# remaining absorption rather than adding a second full impact crouch.
	var progress: float = landing_age/maxf(landing_duration,.001)
	var envelope: float = smoothstep(0.0,.16,progress)*(1.0-smoothstep(.16,1.0,progress))
	current.impact = envelope
	current.impact_drop = maxf(0.0,landing_depth-current.absorbed)*envelope
	current.impact_side = landing_side*envelope
	# The back follows compression with a short delay, then opens on extension.
	# This history belongs to fixed ticks, just like the other pose envelopes.
	var flex: float = maxf(lerpf(tuning.spine_relaxed_degrees,tuning.spine_tuck_degrees,current.tuck),
		lerpf(tuning.spine_relaxed_degrees,tuning.spine_preparation_degrees,smoothstep(0.0,1.0,current.prepare)))
	flex += current.compact*10.0-current.extension*8.0
	flex += tuning.spine_landing_degrees*maxf(0.0,current.impact_drop)/tuning.landing_drop_m.z
	current.spine_flex = lerpf(current.spine_flex,deg_to_rad(clampf(flex,2.0,tuning.spine_max_degrees)),1.0-exp(-tuning.spine_response_hz*dt))
	phase = "ride"
	if current.prepare>.01: phase = "prepare"
	if not sim.grounded: phase = "takeoff" if takeoff_age<tuning.takeoff_seconds else ("landing_ready" if ready>.05 else "air")
	if envelope>.01: phase = "landing" if progress<.30 else "recovery"
	if recoil>.01 and envelope<=.01: phase = "collision"
	if current.grab>.05 and not sim.grounded: phase = "grab"
	was_grounded = sim.grounded
	full_motion.step(dt,sim,intent,current,landing_events)

func landing_profile(speed: float) -> Vector2:
	# Continuous strength across the named small/medium/large bands.
	var strength: float = clampf(speed/tuning.landing_medium_mps,0.0,1.0)
	if speed<tuning.landing_medium_mps:
		return Vector2(tuning.landing_recovery_seconds.x,lerpf(.02,tuning.landing_drop_m.x,strength))
	if speed<tuning.landing_large_mps:
		strength = smoothstep(tuning.landing_medium_mps,tuning.landing_large_mps,speed)
		return Vector2(lerpf(tuning.landing_recovery_seconds.x,tuning.landing_recovery_seconds.y,strength),lerpf(tuning.landing_drop_m.x,tuning.landing_drop_m.y,strength))
	strength = smoothstep(tuning.landing_large_mps,tuning.landing_large_mps+4.0,speed)
	return Vector2(lerpf(tuning.landing_recovery_seconds.y,tuning.landing_recovery_seconds.z,strength),lerpf(tuning.landing_drop_m.y,tuning.landing_drop_m.z,strength))

func landing_readiness(sim, surface) -> float:
	prediction_samples = 0
	# Physics owns the shared, longer-horizon footprint prediction. Animation
	# remains read-only and uses its final 0.40 seconds for readiness.
	if sim.predicted_landing_time>=0.0:
		return clampf(1.0-sim.predicted_landing_time/tuning.landing_lookahead_seconds,0.0,1.0)
	# No second trajectory loop: invalid shared prediction means no readiness.
	return 0.0

func compose(body, joints: Dictionary, rotations: Dictionary, state: Dictionary) -> void:
	if state.is_empty(): return
	var tuck: float = lerpf(state.tuck,clampf(state.tuck*.55+state.compact*.55,0.0,1.0),state.air)
	var prep: float = smoothstep(0.0,1.0,state.prepare)
	var air: float = state.air
	var ready: float = state.ready
	var impact: float = state.impact
	var carve: float = state.carve
	var fold: float = maxf(tuck,prep*.75)
	var carve_profile: Dictionary = Profiles.carve_right if carve>=0.0 else Profiles.carve_left
	var drop: float = tuning.tuck_drop_m*tuck+tuning.preparation_drop_m*prep*(1.0-tuck*.6)
	drop += state.compact*tuning.air_gather_drop_m-state.extension*tuning.takeoff_extension_m+state.impact_drop
	drop += state.transfer*Profiles.edge_transfer.hip_drop_m+state.grab*Profiles.safety_grab.hip_drop_m
	drop += state.pulse*Profiles.neutral.hip_drop_m-state.ready*state.air*Profiles.landing_open.hip_extension_m
	# Deep banking already lowers the physical hips. Do not stack an extra
	# carve crouch on that stance; share its available clearance with all phases.
	var ankle_height: float = maxf(joints.RightFoot.y,joints.LeftFoot.y)
	var clearance: float = maxf(0.0,joints.Hips.y-ankle_height-tuning.minimum_hip_above_ankles_m)
	drop = minf(drop,clearance*.80)
	var hips: Vector3 = joints.Hips+Vector3(-carve*.020+state.impact_side*.018-state.recoil_x*.025,-drop,-.075*fold*(1.0-air*.5)-state.recoil_z*.025)
	# Knee gathering is not the ground tuck's full pelvis hinge. Retain hip
	# articulation room while the physical airborne body carries roll/pitch.
	var pelvis: Basis = rotations.Hips*Basis(Vector3.UP,absf(carve)*carve_profile.pelvis_yaw_rad)*Basis(Vector3.RIGHT,Profiles.tuck.pelvis_pitch_rad*fold*(1.0-air*.70)+impact*.07)
	var extra_pitch: float = (deg_to_rad(90.0-tuning.tuck_back_degrees)-.52)*tuck
	extra_pitch = maxf(extra_pitch,prep*deg_to_rad(tuning.preparation_forward_degrees))+impact*.16+air*(Profiles.compact_flight.chest_pitch_rad+ready*Profiles.landing_open.chest_pitch_rad)+state.extension*Profiles.powered_takeoff.chest_pitch_rad
	extra_pitch += state.grab*Profiles.safety_grab.chest_pitch_rad
	extra_pitch += state.transfer*Profiles.edge_transfer.chest_pitch_rad+state.skid*Profiles.skid.chest_pitch_rad+state.impairment*Profiles.recovery.chest_pitch_rad+state.pulse*Profiles.neutral.chest_pitch_rad
	var counter_yaw: float = absf(carve)*carve_profile.chest_yaw_rad+state.steer*state.skid*Profiles.skid.chest_yaw_rad+state.grab*Profiles.safety_grab.chest_yaw_rad
	var torso: Basis = Basis(Vector3.BACK,-carve*.32+state.recoil_x*.18)*rotations.Spine*Basis(Vector3.UP,counter_yaw-state.steer*air*.16)*Basis(Vector3.RIGHT,extra_pitch-state.recoil_z*.18)
	var bank: float = atan2(-torso.y.x,torso.y.y)
	var bank_limit: float = deg_to_rad(tuning.turn_chest_bank_degrees)
	var bank_correction: float = bank-clampf(bank,-bank_limit,bank_limit)
	torso = Basis(Vector3.BACK,-bank_correction*(1.0-air))*torso
	# Constrain the aggregate pose, not just each additive animation layer.
	# A deep tuck remains possible; an upright ski frame cannot get an inverted
	# spine from overlapping pitch, preparation, steering and impact envelopes.
	var tilt: float = acos(clampf(torso.y.dot(Vector3.UP),-1.0,1.0))
	# Reserve space for the remaining curved-spine rotations below.
	var limit: float = deg_to_rad(tuning.maximum_torso_tilt_degrees)-maxf(0.0,state.spine_flex*.65)
	if tilt>limit:
		var axis: Vector3 = torso.y.cross(Vector3.UP).normalized()
		if axis.length_squared()<.0001: axis = Vector3.RIGHT
		torso = Basis(axis,tilt-limit)*torso
	# Bound the final chest after authored yaw AND the curved spine. Clamping
	# only the pre-flex torso let yaw turn spinal flexion into excess chest bank.
	var final_chest: Basis = torso*Basis(Vector3.RIGHT,state.spine_flex*.65)
	var final_bank: float = atan2(-final_chest.y.x,final_chest.y.y)
	torso = Basis(Vector3.BACK,-(final_bank-clampf(final_bank,-bank_limit,bank_limit))*(1.0-air))*torso
	# Reduce offset magnitude if the shared pelvis cannot reach the requested
	# pose within the existing leg/cuff envelope. Never stretch or move a ski.
	var ankles: Array[Vector3] = [joints.RightFoot,joints.LeftFoot]
	var boots: Array[Basis] = [rotations.RightFoot,rotations.LeftFoot]
	var base_hips: Vector3 = joints.Hips
	var base_pelvis: Basis = rotations.Hips
	var fitted: Vector3 = body.fit_hips(hips,pelvis,ankles,boots)
	# A hard 7 cm accept/retry branch can suddenly select a different crouch
	# as the cuff constraint crosses its threshold. Continuously retain the
	# fitted expression, then close the blended pelvis once more.
	var fit_error: float = fitted.distance_to(hips)/.07
	var retention: float = 1.0/sqrt(1.0+fit_error*fit_error)
	pelvis = base_pelvis.slerp(pelvis,retention)
	hips = body.fit_hips(base_hips.lerp(fitted,retention),pelvis,ankles,boots)
	joints.Hips = hips
	rotations.Hips = pelvis
	# Articulate each rest-length link instead of rotating the whole back as a
	# rigid bar. Symmetric lumbar/chest pitches retain the requested overall
	# tuck angle while letting the jacket follow an actual forward curve.
	var flex: float = state.spine_flex
	var lumbar: Basis = torso*Basis(Vector3.RIGHT,-flex*.5)
	rotations.Spine02 = torso
	rotations.Spine01 = torso*Basis(Vector3.RIGHT,flex*.5)
	rotations.Spine = torso*Basis(Vector3.RIGHT,flex*.65)
	joints.Spine02 = hips+lumbar*(body.REST.Spine02-body.REST.Hips)
	joints.Spine01 = joints.Spine02+rotations.Spine02*(body.REST.Spine01-body.REST.Spine02)
	joints.Spine = joints.Spine01+rotations.Spine01*(body.REST.Spine-body.REST.Spine01)
	joints.neck = joints.Spine+rotations.Spine*(body.REST.neck-body.REST.Spine)
	# Share gaze compensation between neck and head; neither floats off the
	# chest nor inherits its full downward pitch. Head orientation stays ahead.
	if air>.01:
		var gaze_angle: float = rotations.Spine.get_rotation_quaternion().angle_to(rotations.Head.get_rotation_quaternion())
		if gaze_angle>PI*.5:
			rotations.Head = rotations.Spine.slerp(rotations.Head,(PI*.5)/gaze_angle)
	rotations.neck = rotations.Spine.slerp(rotations.Head,.60)
	joints.Head = joints.neck+rotations.neck*(body.REST.Head-body.REST.neck)
	for index in range(2):
		var side = -1.0 if index==0 else 1.0
		var prefix = "Right" if index==0 else "Left"
		for suffix in ["Shoulder","Arm"]:
			joints[prefix+suffix] = joints.Spine+rotations.Spine*(body.REST[prefix+suffix]-body.REST.Spine)
		var width: float = lerpf(.29,Profiles.tuck.hand_width_m,tuck)+air*(Profiles.compact_flight.hand_width_m+state.brake*.13)*(1.0-tuck*.65)+impact*.15+state.recoil*.09
		width += state.skid*Profiles.skid.hand_width_m+state.transfer*Profiles.edge_transfer.hand_width_m+state.impairment*Profiles.recovery.hand_width_m
		var chest: Vector3 = joints.Spine
		var hand = chest+Vector3(side*width-state.steer*air*.065-state.recoil_x*.08,-.20+.13*fold+impact*.08+side*absf(carve)*carve_profile.hand_height_m+state.recoil*.05,.23+.08*fold+side*state.steer*air*.07-state.recoil_z*.08)
		hand += Vector3(0,state.impairment*Profiles.recovery.hand_height_m+state.pulse*Profiles.neutral.hand_height_m,ready*air*Profiles.landing_open.hand_forward_m+side*absf(carve)*carve_profile.hand_forward_m)
		# Safety-style left-hand reach toward the inside ski above the binding.
		# The closed glove keeps its pole; this is a pole-in-hand reach, with no
		# finger grasp/binding release claim. Arm reach is constrained below.
		if index==1:
			var reach: Dictionary = Profiles.safety_grab
			var grab_target: Vector3 = joints.LeftFoot+rotations.LeftFoot*Vector3(reach.hand_boot_x_m,reach.hand_boot_y_m,reach.hand_boot_z_m)
			hand = hand.lerp(grab_target,state.grab)
		var arm: Vector3 = joints[prefix+"Arm"]
		var upper: float = body.REST[prefix+"Arm"].distance_to(body.REST[prefix+"ForeArm"])
		var lower: float = body.REST[prefix+"ForeArm"].distance_to(body.REST[prefix+"Hand"])
		hand = arm+(hand-arm).limit_length(upper+lower-.008)
		joints[prefix+"Hand"] = hand
		joints[prefix+"ForeArm"] = body.joint(arm,hand,upper,lower,Vector3(side*lerpf(.65,.16,tuck),-.65,-.35))

func pole_direction(side: float, state: Dictionary) -> Vector3:
	var compact: float = maxf(state.tuck,state.compact*.65)
	return Vector3(side*(.08+state.air*.06+state.impact*.15+state.recoil*.08),lerpf(-.65,-.18,compact)+state.extension*.20,-.75-compact*.30).normalized()

func clearance_margin(joints: Dictionary, frame: Transform3D) -> float:
	# Called after render leg closure, including rigid boot snow burial. Five
	# exact height queries, no prediction or fixed-tick state advancement.
	if clearance_surface==null: return INF
	var margin = INF
	for id in ["Hips","Spine","Head","RightHand","LeftHand"]:
		var p: Vector3 = frame*joints[id]
		if clearance_surface.has_method("bounds") and not clearance_surface.bounds().has_point(Vector2(p.x,p.z)): continue
		var height: float = clearance_surface.sample(p.x,p.z).height
		var required: float = .18 if id=="Hips" else (.30 if id=="Head" else (.24 if id=="Spine" else .06))
		margin = minf(margin,p.y-height-required)
	return margin
