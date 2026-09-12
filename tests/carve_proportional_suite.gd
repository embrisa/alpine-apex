extends SceneTree
## Full final-pose response matrix. No sessions, records or solver changes.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const Replay = preload("res://scripts/racing/run_replay.gd")
const Slope = preload("res://tests/carve_direction_capture.gd").DirectionSlope
const DT = 1.0/120.0
var checks = 0
var failures: Array[String] = []

func _initialize():call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if not ok:failures.append(message)

func run():
	var output="artifacts/carve_proportional/matrix.json"
	var baseline=""
	var measure_only=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--baseline-motion="):baseline=arg.trim_prefix("--baseline-motion=")
		if arg=="--measure-only":measure_only=true
	var visual=Visual.new();visual.preview_only=true;root.add_child(visual);await process_frame
	if not baseline.is_empty():visual.animation.full_motion=load(baseline).new()
	var specs=[]
	for speed in [12.0,25.0]:
		for warmup in [.5,2.0]:
			for direction in [-1.0,1.0]:
				for magnitude in [0.0,.05,.10,.20,.55,1.0]:
					for mode in ["hold","tap"]:
						specs.append({"speed":speed,"warmup":warmup,"direction":direction,"magnitude":magnitude,"mode":mode,"cross":0.0,"tuck":0.0})
	for cross in [-.22,0.0,.22]:
		for direction in [-1.0,1.0]:
			for mode in ["hold","reversal","tuck"]:
				specs.append({"speed":25.0,"warmup":2.0,"direction":direction,"magnitude":.1 if mode=="hold" else .55,"mode":mode,"cross":cross,"tuck":1.0 if mode=="tuck" else 0.0})
	var results=[]
	for spec in specs:
		var sim=Sim.new();var control=Sim.new();var field=Slope.new();field.cross_gradient=spec.cross
		for s in [sim,control]:s.reset(Vector3.ZERO);s.prime_contacts(field);s.velocity=s.support_basis().z*spec.speed
		visual.reset_animation(sim)
		var input=RiderInput.new();input.tuck=spec.tuck
		for tick in int(spec.warmup/DT):
			sim.step(DT,input,field);control.step(DT,input,field);visual.step_animation(DT,sim,input,field)
		visual.pose(sim)
		var initial=silhouette(visual,sim)
		var last=visual.rendered_joints.duplicate()
		var trace=[];var same=true;var peak_step=0.0;var peak_body=0.0;var peak_action=0.0;var peak_path=0.0
		var wrong=Vector2.ZERO;var step_us=0;var fit_us=0
		var duration=180 if spec.mode!="tap" else (6 if spec.warmup<1 else 18)
		for tick in 420:
			input.steer=spec.direction*spec.magnitude if tick<duration else 0.0
			if spec.mode=="reversal" and tick>=90 and tick<duration:input.steer*=-1
			sim.step(DT,input,field);control.step(DT,input,field)
			visual.step_animation(DT,sim,input,field);visual.pose(sim)
			var full=visual.animation.full_motion
			same=same and Replay.snapshot(sim.ticks*DT,sim)==Replay.snapshot(control.ticks*DT,control) and sim.body.com==control.body.com
			var lean=silhouette(visual,sim)
			for bone in last:peak_step=maxf(peak_step,visual.rendered_joints[bone].distance_to(last[bone]))
			last=visual.rendered_joints.duplicate()
			peak_body=maxf(peak_body,absf(lean.x));peak_action=maxf(peak_action,full.action_amount.x)
			peak_path=maxf(peak_path,absf(sim.motion.turn_rate_rad_s)*sim.velocity.length())
			if tick<mini(duration,90) and spec.magnitude>0:
				wrong.x=maxf(wrong.x,-spec.direction*(lean.x-initial.x));wrong.y=maxf(wrong.y,-spec.direction*(lean.y-initial.y))
			step_us+=full.step_microseconds;fit_us+=full.fit_microseconds
			if tick%2==1:
				trace.append({"tick":tick,"input":input.steer,"body_deg":rad_to_deg(lean.x),"torso_deg":rad_to_deg(lean.y),"turn_acceleration":-sim.motion.turn_rate_rad_s*sim.velocity.length(),"bank":sim.body.roll,"edge":full.supported_turn(sim),"action":full.action_amount.x,"pelvis_lateral_m":pelvis_lateral(visual,sim)})
		var name=JSON.stringify(spec)
		check(same and not sim.crashed,name+": exact physical/replay/COM equality")
		check(peak_step<.08,name+": continuous final joints")
		# Relaxing an initial lean toward the requested side is not all wrong-way
		# lean. Allow that initial offset, but at most two degrees beyond neutral;
		# an already opposite initial pose gets no additional allowance.
		check(wrong.x<deg_to_rad(2.0)+maxf(spec.direction*initial.x,0.0) and wrong.y<deg_to_rad(2.0)+maxf(spec.direction*initial.y,0.0),name+": bounded entry counter-sway")
		if spec.magnitude<=.1 and peak_path<2.5:
			check(peak_action<.25,name+": mild correction cannot fully commit posture")
			check(peak_body<deg_to_rad(12),name+": mild final lean envelope")
		if spec.mode=="hold" and spec.magnitude>=.55 and peak_path>8:
			check(peak_body>deg_to_rad(25),name+": strong loaded turn retains deep lean")
		var settled=true
		var residual_support_frames=0
		for row in trace:
			if row.tick>duration+60 and absf(row.turn_acceleration)<.5:
				settled=settled and absf(row.torso_deg)<4
				# Rigid boots can remain deeply edged even after the path settles.
				# Preserve those samples as a physical residual, not a pose all-clear.
				if absf(row.edge)<.22: settled=settled and absf(row.body_deg)<12
				elif absf(row.body_deg)>=12: residual_support_frames+=1
		check(settled,name+": torso settles with path; whole body settles with support")
		results.append({"spec":spec,"initial_body_deg":rad_to_deg(initial.x),"initial_torso_deg":rad_to_deg(initial.y),"peak_body_deg":rad_to_deg(peak_body),"opposite_body_deg":rad_to_deg(wrong.x),"opposite_torso_deg":rad_to_deg(wrong.y),"peak_joint_step_m":peak_step,"peak_action":peak_action,"peak_turn_acceleration":peak_path,"step_us_mean":step_us/420.0,"fit_us_mean":fit_us/420.0,"residual_support_frames":residual_support_frames,"trace":trace})
		if results.size()%12==0:print("CARVE_MATRIX_PROGRESS ",results.size(),"/",specs.size())
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":results,"model":Sim.MODEL_VERSION,"engine":Engine.get_version_info().string},"\t"))
	if not measure_only:
		for failure in failures:printerr("FAIL: ",failure)
	print("CARVE_PROPORTIONAL ",checks," checks, ",failures.size()," failures; measure_only=",measure_only)
	visual.queue_free();await process_frame;quit(0 if failures.is_empty() or measure_only else 1)

static func silhouette(visual,sim) -> Vector2:
	var j=visual.rendered_joints
	var frame=Basis(Vector3.UP,sim.heading).transposed()*visual.global_basis
	var body: Vector3=frame*(j.Spine-(j.LeftFoot+j.RightFoot)*.5)
	var torso: Vector3=frame*visual.rendered_rotations.Spine.y
	return Vector2(asin(clampf(-body.normalized().x,-1,1)),asin(clampf(-torso.normalized().x,-1,1)))

static func pelvis_lateral(visual,sim) -> float:
	var j=visual.rendered_joints
	var offset: Vector3=Basis(Vector3.UP,sim.heading).transposed()*visual.global_basis*(j.Hips-(j.LeftFoot+j.RightFoot)*.5)
	return -offset.x
