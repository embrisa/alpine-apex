extends SceneTree
## Bounded steering transitions on the shared 4 m uneven-snow surface.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const Snow = preload("res://tests/planted_snow_probe.gd").SnowRipple
const Metrics = preload("res://tests/carve_proportional_suite.gd")
const DT = 1.0/120.0
var checks = 0
var failures: Array[String] = []
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks+=1
	if not ok: failures.append(label)
func steering(t: float, transitions: bool) -> float:
	if t<2.0 or t>=13.0: return 0.0
	if not transitions: return .4
	if t<5.0: return .4
	if t<6.0: return 0.0
	if t<6.15: return .6
	if t<7.0: return 0.0
	if t<10.0: return -.5
	return .5
func run():
	var output="artifacts/steering_jank/snow.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var visual=Visual.new(); visual.preview_only=true; visual.snow_burial_enabled=true; root.add_child(visual); await process_frame
	var cases=[]
	for direction in [-1.0,1.0]:
		for transitions in [false,true]:
			var field=Snow.new(.15,32.0,.16,direction*.35)
			var sim=Sim.new(); sim.reset(Vector3(0,field.sample(0,0).height,0)); sim.prime_contacts(field); sim.velocity=sim.support_basis().z*25
			var input=RiderInput.new(); input.tuck=1.0; sim.effective_tuck=1.0; visual.reset_animation(sim)
			var previous={}; var previous_pelvis=0.0; var previous_body=0.0; var have_previous=false
			var peak_pelvis={}; var joint_step=0.0; var pelvis_step=0.0; var body_step=0.0; var wrong_body=0.0; var wrong_torso=0.0; var wrong_pelvis=0.0; var trace=[]
			for tick in 1800:
				var t=tick*DT; input.steer=direction*steering(t,transitions)
				# Hold forward through automatic tuck release, then let go before
				# the sustained arc climbs uphill into a separate pole-push action.
				input.tuck=1.0 if t<5.0 else 0.0
				sim.step(DT,input,field); visual.step_animation(DT,sim,input,field)
				for alpha in [0.0,.5,1.0]:
					visual.pose(sim,alpha)
					# Travel heading flips by PI on switch entry; rendered facing does
					# not. Read facing at the SAME interpolated render time as the pose.
					var facing={"heading":atan2(visual.global_basis.z.x,visual.global_basis.z.z)}
					var lean=Metrics.silhouette(visual,facing); var pelvis=Metrics.pelvis_lateral(visual,facing)
					if have_previous:
						if absf(pelvis-previous_pelvis)>pelvis_step: peak_pelvis={"s":t,"alpha":alpha,"from":previous_pelvis,"to":pelvis,"grounded":sim.grounded,"facing_backward":sim.facing_backward}
						pelvis_step=maxf(pelvis_step,absf(pelvis-previous_pelvis)); body_step=maxf(body_step,absf(rad_to_deg(lean.x)-previous_body))
					previous_pelvis=pelvis; previous_body=rad_to_deg(lean.x); have_previous=true
					# Judge direction after entry settles, away from intentional reversals.
					if t>=2.5 and t<5.0:
						wrong_body=maxf(wrong_body,-direction*rad_to_deg(lean.x)); wrong_torso=maxf(wrong_torso,-direction*rad_to_deg(lean.y)); wrong_pelvis=maxf(wrong_pelvis,-direction*pelvis)
					if alpha==1.0:
						for bone in previous: joint_step=maxf(joint_step,visual.rendered_joints[bone].distance_to(previous[bone]))
						previous=visual.rendered_joints.duplicate()
				if tick%6==0: trace.append({"s":t,"input":input.steer,"tuck":sim.effective_tuck,"body_deg":previous_body,"pelvis_m":previous_pelvis,"bank_rad":sim.body.roll,"path_rad_s":sim.motion.turn_rate_rad_s})
			var name=("right" if direction>0 else "left")+(" transitions" if transitions else " sustained")
			check(not sim.crashed,name+": completes 15 seconds of uneven snow")
			check(wrong_body<=2.0 and wrong_torso<=2.0 and wrong_pelvis<=.04,name+": tuck release enters the requested direction")
			# Half-tick pelvis budget is half the existing 8 cm/tick joint envelope.
			# The recorded defect separately keeps its stricter 4 cm/tick joint gate.
			check(pelvis_step<.04 and body_step<5.0,name+": intermediate pelvis and body remain continuous")
			check(joint_step<.08,name+": connected joints stay continuous through hold, taps, reversals and release")
			cases.append({"name":name,"peak_pelvis":peak_pelvis,"opposite_body_deg":wrong_body,"opposite_torso_deg":wrong_torso,"opposite_pelvis_m":wrong_pelvis,"pelvis_step_m":pelvis_step,"body_step_deg":body_step,"joint_step_m":joint_step,"crash":sim.crash_reason,"trace":trace})
	DirAccess.make_dir_recursive_absolute(output.get_base_dir()); preload("res://tests/test_report.gd").write(output,JSON.stringify({"checks":checks,"failures":failures,"model":Sim.MODEL_VERSION,"cases":cases},"\t"))
	print("STEERING_SNOW_SUITE ",checks," checks; failures=",JSON.stringify(failures))
	visual.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
