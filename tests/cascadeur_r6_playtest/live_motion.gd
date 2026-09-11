extends "res://scripts/presentation/skier_full_motion.gd"
## Opt-in sample substitution. Inherited posture, limits, tracking and fitting remain.
var candidate:Dictionary={}
var candidate_enabled=true
var candidate_amount=0.0
var candidate_time=2.0
var tuck_was_down=false
var pending_replay=false
func reset(sim) -> void:
	candidate_amount=0.0;candidate_time=2.0;tuck_was_down=false;pending_replay=false
	super.reset(sim)
func replay() -> void:
	pending_replay=true
func step(dt:float,sim,intent,state:Dictionary,landing_event:int) -> void:
	if sim.ticks==last_tick:return
	var tuck_down:bool=intent.tuck>.15
	if candidate_enabled and sim.grounded and not sim.facing_backward and not sim.crashed:
		if pending_replay or (tuck_down and not tuck_was_down and candidate_time>=2.0):
			candidate_time=0.0;pending_replay=false
		else:candidate_time=minf(2.0,candidate_time+dt)
	else:pending_replay=false
	tuck_was_down=tuck_down
	candidate_amount=move_toward(candidate_amount,float(candidate_enabled),dt*4.0)
	super.step(dt,sim,intent,state,landing_event)
func sample_clip(name:String,time:float,looping:bool=false) -> Dictionary:
	var base=super.sample_clip(name,time,looping)
	if candidate.is_empty() or candidate_amount<=0.0 or name not in ["NAV_SLOW_FWD","NAV_MED_FWD","NAV_FAST_FWD","NAV_FAST_FWD_SPEED"]:return base
	var authored=sample_raw(candidate,candidate_time)
	for i in base.q.size():base.q[i]=base.q[i].slerp(authored.q[i],candidate_amount).normalized()
	base.root=base.root.lerp(authored.root,candidate_amount)
	return base
