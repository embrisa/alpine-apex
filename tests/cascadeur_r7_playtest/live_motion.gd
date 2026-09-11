extends "res://scripts/presentation/skier_full_motion.gd"
## Cascadeur-solved local offsets over current carving. Solver owns direction.
var candidate:Dictionary={}
var candidate_enabled=true
var candidate_amount=0.0
var applied_amount=0.0
const BONES=["Spine02","Spine01","Spine","neck","Head","LeftShoulder","RightShoulder","LeftArm","RightArm","LeftForeArm","RightForeArm"]
func reset(sim) -> void:
	candidate_amount=0.0;applied_amount=0.0
	super.reset(sim)
func step(dt:float,sim,intent,state:Dictionary,landing_event:int) -> void:
	if sim.ticks==last_tick:return
	candidate_amount=move_toward(candidate_amount,float(candidate_enabled),dt*4.0)
	applied_amount=0.0
	super.step(dt,sim,intent,state,landing_event)
	diagnostics.cascadeur_carve_amount=applied_amount
func refine_authored_pose(pose:Dictionary,state:Dictionary,action:Vector3) -> void:
	if candidate.is_empty() or candidate_amount<=0.0:return
	applied_amount=candidate_amount*.75*action.x*smoothstep(.08,.65,absf(state.steer))*(1.0-state.tuck*.5)
	if applied_amount<=0.00001:return
	var neutral=sample_raw(candidate,0.0)
	var target=sample_raw(candidate,.5 if state.steer>0 else 1.5)
	for name in BONES:
		var i:int=library.names.find(name)
		var delta:Quaternion=neutral.q[i].inverse()*target.q[i]
		if name=="Spine02":
			# Transfer the authored body counter-rotation to the upper body only;
			# the existing supported pelvis and legs keep their gameplay targets.
			var hip:int=library.names.find("Hips")
			delta=(neutral.q[hip].inverse()*target.q[hip])*delta
		pose.q[i]=(pose.q[i]*Quaternion.IDENTITY.slerp(delta,applied_amount)).normalized()
