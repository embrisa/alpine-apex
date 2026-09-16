extends SceneTree
## Final-pose regression for the user's held-right jank, including interpolation.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const Fixture = preload("res://tests/steering_recording_fixture.gd")
const Metrics = preload("res://tests/carve_proportional_suite.gd")
const DT = 1.0/120.0
var checks = 0
var failures: Array[String] = []
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks+=1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)
func run():
	var output="res://artifacts/steering_jank/regression.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	var field=preload("res://tests/validation_mountain.gd").load_standard()
	if field==null:quit(2);return
	var data=Fixture.load_inputs(field)
	var visual=Visual.new();visual.preview_only=true;visual.snow_burial_enabled=true;root.add_child(visual);await process_frame
	var results=[]
	for direction in [1.0,-1.0]:
		var sim=Sim.new(preload("res://config/ski_default.tres").duplicate(true))
		sim.reset(field.launch_point(data.heading),data.heading);sim.prime_contacts(field);visual.reset_animation(sim)
		var wrong_body=0.0;var wrong_torso=0.0;var wrong_pelvis=0.0;var joint_step=0.0;var all_joint_step=0.0;var last={};var pose_read_only=true;var supported_grip=true
		var trace=[]
		for tick in data.commands.size():
			var input=Fixture.Inputs.decode(data.commands[tick]);input.steer*=direction
			sim.step(DT,input,field);visual.step_animation(DT,sim,input,field)
			var state=Fixture.Inputs.state(sim)
			for alpha in [0.0,.5,1.0]:
				visual.pose(sim,alpha)
				var lean=Metrics.silhouette(visual,sim);var pelvis=Metrics.pelvis_lateral(visual,sim)
				if tick>=800:
					wrong_body=maxf(wrong_body,-direction*rad_to_deg(lean.x));wrong_torso=maxf(wrong_torso,-direction*rad_to_deg(lean.y));wrong_pelvis=maxf(wrong_pelvis,-direction*pelvis)
				if alpha==1.0:
					for bone in last:
						var delta:float=visual.rendered_joints[bone].distance_to(last[bone])
						all_joint_step=maxf(all_joint_step,delta)
						# The recording starts with pole propulsion. Its retained elbow
						# issue is separate from this steering interval beginning at 6.4 s.
						if tick>=767:joint_step=maxf(joint_step,delta)
					last=visual.rendered_joints.duplicate()
					trace.append({"tick":sim.ticks,"body_deg":rad_to_deg(lean.x),"torso_deg":rad_to_deg(lean.y),"pelvis_m":pelvis})
			pose_read_only=pose_read_only and Fixture.Inputs.state(sim)==state
			for ski in sim.skis:supported_grip=supported_grip and (ski.grounded or is_zero_approx(ski.grip_n))
		var name="recorded right" if direction>0 else "mirrored input on Standard terrain"
		check(not sim.crashed and sim.ticks==1104,name+": completes the 9.2 second stimulus")
		check(wrong_body<=2.0,name+": final body does not counterbank beyond 2 degrees")
		check(wrong_torso<=2.0,name+": final torso does not counterbank beyond 2 degrees")
		check(wrong_pelvis<=.04,name+": no opposite pelvis excursion beyond 4 cm")
		check(joint_step<.04,name+": steering joints move less than 4 cm per 120 Hz tick")
		check(pose_read_only and supported_grip,name+": rendering is read-only and grip requires support")
		results.append({"name":name,"opposite_body_deg":wrong_body,"opposite_torso_deg":wrong_torso,"opposite_pelvis_m":wrong_pelvis,"steering_joint_step_m":joint_step,"all_joint_step_m":all_joint_step,"end":Fixture.Inputs.state(sim),"trace":trace})
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	preload("res://tests/test_report.gd").write(output,JSON.stringify({"checks":checks,"failures":failures,"model":Sim.MODEL_VERSION,"cases":results},"\t"))
	print("STEERING_RECORDING_SUITE ",checks," checks; failures=",JSON.stringify(failures))
	visual.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
