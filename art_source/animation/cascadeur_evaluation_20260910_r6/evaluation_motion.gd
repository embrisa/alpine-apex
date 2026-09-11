extends "res://scripts/presentation/skier_full_motion.gd"
## Test-only source selection. All composition/tracking/fitting stays inherited.
var candidate: Dictionary = {}
var evaluation_time = -1.0
var use_candidate = false
var ready_only = false
var stages: Dictionary = {}
var substituted: Dictionary = {}
var carry_weight = 0.0

func clip_time() -> float:
	return 0.0 if ready_only else clampf(evaluation_time-.7,0.0,2.0)

func edit_weight() -> float:
	return smoothstep(.2,.7,evaluation_time)*(1.0-smoothstep(2.7,3.2,evaluation_time)) if use_candidate else 0.0

func sample_clip(name: String, time: float, looping: bool = false) -> Dictionary:
	var base = super.sample_clip(name,time,looping)
	# Only forward navigation slots. Turns, flight, preparation and landing keep
	# their production sources. Tuck overlap is deliberately tested here.
	if name not in ["NAV_SLOW_FWD","NAV_MED_FWD","NAV_FAST_FWD","NAV_FAST_FWD_SPEED"] or candidate.is_empty(): return base
	var weight = edit_weight()
	if weight<=0.0: return base
	var authored = sample_raw(candidate,clip_time())
	for i in base.q.size(): base.q[i]=base.q[i].slerp(authored.q[i],weight).normalized()
	base.root=base.root.lerp(authored.root,weight)
	substituted[name]={"source_time":clip_time(),"source_frame":clip_time()*30,"weight":weight}
	return base

func fit_tuck_flexion(pose: Dictionary, tuck: float) -> void:
	stages.raw_mix=pose.duplicate(true)
	super.fit_tuck_flexion(pose,tuck)
	stages.after_tuck=pose.duplicate(true)

func fit_arm_carry(pose: Dictionary, tuck: float, preparation: float, weight: float) -> void:
	carry_weight=weight
	super.fit_arm_carry(pose,tuck,preparation,weight)
	stages.after_carry=pose.duplicate(true)

func step(dt: float, sim, intent, state: Dictionary, landing_event: int) -> void:
	substituted.clear()
	super.step(dt,sim,intent,state,landing_event)
	if not stages.has("after_carry"): return
	# Diagnostic reconstruction of the two static correction stages using this
	# tick's actual smoothed weights. These copies never feed the live solve.
	var physical_state=state.duplicate(); physical_state.steer=supported_turn(sim); physical_state.carve=physical_state.steer
	var probe: Dictionary=stages.after_carry.duplicate(true)
	Downhill.apply(probe,library,physical_state,downhill_amount)
	stages.after_downhill=probe.duplicate(true)
	Action.apply(probe,library,physical_state,action_amount,air_age)
	stages.after_action=probe.duplicate(true)
	stages.downhill_weight=downhill_amount; stages.action_weights=action_amount
	stages.candidate_weight=edit_weight(); stages.candidate_time=clip_time()

func landmarks(pose: Dictionary) -> Dictionary:
	var joints={};var rotations={}
	for i in library.names.size():
		var name: String=library.names[i]; var parent: int=library.parents[i]
		if parent<0:
			joints[name]=pose.root;rotations[name]=Basis(pose.q[i])
		else:
			var pname: String=library.names[parent]
			joints[name]=joints[pname]+rotations[pname]*(library.rest[i].origin-library.rest[parent].origin)
			rotations[name]=rotations[pname]*Basis(pose.q[i])
	return {"joints":joints,"rotations":rotations}
