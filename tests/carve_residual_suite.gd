extends SceneTree
## Reject residual whole-body stance independently of torso and edge saturation.
## 12 retained cases plus weak exits, neutral, loaded holds and short-tap controls. No records.
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
	var output="artifacts/pelvis_residual/regression.json"
	var compact=false
	var measure_only=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg=="--compact":compact=true
		if arg=="--measure-only":measure_only=true
	var visual=Visual.new();visual.preview_only=true;root.add_child(visual);await process_frame
	var specs=[]
	for speed in [25.0,40.0]:
		for direction in [-1.0,1.0]:
			for magnitude in [.05,.10,.55]:
				specs.append({"speed":speed,"warmup":2.0,"direction":direction,"magnitude":magnitude,"mode":"reversal" if magnitude==.55 else "hold","cross":0.0,"tuck":0.0})
	if not compact:
		for speed in [12.0,25.0,40.0]:
			for direction in [-1.0,1.0]:
				for mode in ["neutral","strong55","strong100","tap50","tap150"]:
					specs.append({"speed":speed,"warmup":2.0,"direction":direction,"magnitude":0.0 if mode=="neutral" else .55 if mode=="strong55" else 1.0 if mode=="strong100" else .1,"mode":mode,"cross":0.0,"tuck":0.0})
		for speed in [25.0,40.0]:
			for direction in [-1.0,1.0]:
				for post_steer in [.05,.10]:
					specs.append({"speed":speed,"warmup":2.0,"direction":direction,"magnitude":.55,"mode":"reversal","post_steer":post_steer,"cross":0.0,"tuck":0.0})
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
		var initial_pelvis=pelvis_lateral(visual,sim)
		var last=visual.rendered_joints.duplicate()
		var trace=[];var same=true;var peak_step=0.0;var peak_body=0.0;var peak_action=0.0;var peak_path=0.0
		var wrong=Vector2.ZERO;var step_us=0;var fit_us=0
		var duration=6 if spec.mode=="tap50" else 18 if spec.mode=="tap150" else 180
		for tick in 420:
			input.steer=spec.direction*spec.magnitude if tick<duration else -spec.direction*spec.get("post_steer",0.0)
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
				trace.append({"tick":tick,"input":input.steer,"body_deg":rad_to_deg(lean.x),"torso_deg":rad_to_deg(lean.y),"turn_acceleration":-sim.motion.turn_rate_rad_s*sim.velocity.length(),"bank":sim.body.roll,"edge":full.supported_turn(sim),"action":full.action_amount.x,
					"pelvis_lateral_m":pelvis_lateral(visual,sim),"roll_velocity":sim.body.roll_velocity,"requested_cop":pack2(sim.body.requested_cop),"cop":pack2(sim.body.cop),"torque_nm":pack2(sim.body.correction_torque),"com_m":pack3(sim.body.com),
					"support_n":sim.normal_load*sim.tuning.rider_mass,"ski_edges_rad":[sim.skis[0].edge_angle,sim.skis[1].edge_angle],"ski_loads_n":[sim.skis[0].load_n,sim.skis[1].load_n],
					"steering_yaw_rad_s":sim.steering_applied_yaw,"requested_lateral_m_s2":sim.requested_lateral_acceleration,"applied_lateral_m_s2":sim.lateral_acceleration,
					"speed_m_s":sim.velocity.length(),"slip_rad":sim.slip_angle,"position_m":pack3(sim.position),"heading_rad":sim.heading,
					"posture_root_m":pack3(full.root_position),"requested_posture_hips_m":pack3(full.requested_joints.get("Hips",Vector3.ZERO)),"pelvis_fit_m":full.diagnostics.get("pelvis_fit_m",0.0)})
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
		if spec.mode.begins_with("strong") and peak_path>8:
			check(peak_body>deg_to_rad(25),name+": strong loaded turn retains deep lean")
		# Start with the existing 12-degree mild body envelope. The 15 cm
		# neutral-relative pelvis allowance covers the 10-degree cuff side range
		# over both ~36 cm leg segments plus 2 cm sway. It rejects the retained
		# 36-41 cm failure without narrowing the anatomical constraints.
		# Require both a half-second since release and 250 ms of low curvature.
		# A full loaded carve must unwind its supported reaction first; its
		# continuous return is different from the retained outward overshoot.
		# A high edge is NEVER an exemption. At <=2 m/s the motion observer can
		# report zero path rate during uphill switch, so that is a separate case.
		var residual_frames=0;var peak_residual=0.0;var peak_pelvis=0.0
		var last_outside=duration-1;var low_curve_samples=0;var low_curve_age=0.0
		for row in trace:
			if row.tick<duration:continue
			low_curve_age=low_curve_age+2.0*DT if absf(row.turn_acceleration)<.5 and row.speed_m_s>2.0 else 0.0
			var outside=absf(row.body_deg-rad_to_deg(initial.x))>12.0 or absf(row.pelvis_lateral_m-initial_pelvis)>.15
			if outside:last_outside=row.tick
			if row.tick>duration+60 and low_curve_age>=.25:
				low_curve_samples+=1
				peak_residual=maxf(peak_residual,absf(row.body_deg-rad_to_deg(initial.x)))
				peak_pelvis=maxf(peak_pelvis,absf(row.pelvis_lateral_m-initial_pelvis))
				if outside:residual_frames+=1
		check(residual_frames==0,name+": released body <=12 degrees and pelvis <=0.15 m from neutral, regardless of edge")
		if spec.mode=="reversal" and spec.get("post_steer",0.0)==0.0:
			check(low_curve_samples>30,name+": regression exercises sustained low-curvature release")
			check((last_outside+1-duration)*DT<=.5,name+": reversal stance settles within half a second of release")
		if spec.get("post_steer",0.0)>0.0:
			# A held correction retains real curvature; compare with the absolute
			# mild-stance envelope, not the former opposite neutral-bank offset.
			var weak_exit_ok=true
			for row in trace:
				if row.tick>duration+60:
					weak_exit_ok=weak_exit_ok and absf(row.body_deg)<12.0 and absf(row.pelvis_lateral_m)<.15 and row.action<.25
			check(weak_exit_ok,name+": weak correction after reversal stays within mild body/pelvis/action bounds")
		results.append({"spec":spec,"initial_body_deg":rad_to_deg(initial.x),"initial_torso_deg":rad_to_deg(initial.y),"peak_body_deg":rad_to_deg(peak_body),"opposite_body_deg":rad_to_deg(wrong.x),"opposite_torso_deg":rad_to_deg(wrong.y),"peak_joint_step_m":peak_step,"peak_action":peak_action,"peak_turn_acceleration":peak_path,"step_us_mean":step_us/420.0,"fit_us_mean":fit_us/420.0,"initial_pelvis_m":initial_pelvis,"low_curvature_samples":low_curve_samples,"residual_frames":residual_frames,"residual_duration_s":residual_frames/60.0,"peak_residual_deg":peak_residual,"peak_residual_pelvis_m":peak_pelvis,"settling_after_release_s":(last_outside+1-duration)*DT,"trace":trace})
		if results.size()%12==0:print("CARVE_RESIDUAL_PROGRESS ",results.size(),"/",specs.size())
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	preload("res://tests/test_report.gd").write(output,JSON.stringify({"checks":checks,"failures":failures,"cases":results,"model":Sim.MODEL_VERSION,"engine":Engine.get_version_info().string},"\t"))
	if not measure_only:
		for failure in failures:printerr("FAIL: ",failure)
	print("CARVE_RESIDUAL ",JSON.stringify({"checks":checks,"failures":failures,"measure_only":measure_only}))
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

static func pack2(v: Vector2) -> Array:return [v.x,v.y]
static func pack3(v: Vector3) -> Array:return [v.x,v.y,v.z]
