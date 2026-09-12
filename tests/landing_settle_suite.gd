extends SceneTree
## Observable small-hop recovery, contact exclusions and presentation ownership.
const Probe = preload("res://tests/small_landing_probe.gd")
const Motion = preload("res://scripts/presentation/skier_animation.gd")
var output = "res://artifacts/small_landing_20260912/contracts"
var checks = 0
var failures: Array[String] = []
var results: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = "res://"+arg.trim_prefix("--output=").trim_prefix("res://")
	DirAccess.make_dir_recursive_absolute(output)
	for fixture in [
		{"name":"flat","flat":true,"amplitude":0.0,"kmh":30.0,"depth":.03},
		{"name":"slope","amplitude":0.0,"kmh":60.0,"depth":.2},
		{"name":"rounded","amplitude":.3,"wavelength":32.0,"kmh":120.0,"depth":.2},
		{"name":"shallow","amplitude":.3,"wavelength":16.0,"kmh":120.0,"depth":.03},
		{"name":"tuck","amplitude":.3,"wavelength":32.0,"kmh":120.0,"depth":.2,"tuck":1.0,"steer":.15}]:
		var trace: Array = []; var row=Probe.measure(fixture,trace); results.append(row)
		check(row.jumps==1 and row.launches.size()==1 and row.landings.size()==1 and row.final_grounded,fixture.name+": one deliberate hop followed by sustained support")
		check(row.crash.is_empty() and row.ticks==480,fixture.name+": complete bounded scenario")
	var sharp={"amplitude":.6,"wavelength":16.0,"depth":.06,"angle":.5,"kmh":120.0,"steer":.15,"tuck":1.0,"hop":false}
	var trace: Array=[]; var row=Probe.measure(sharp,trace); results.append(row)
	check(row.jumps==0 and row.launches.size()>1,"Actual sharp terrain still releases the skier independently of deliberate jump input")
	await final_pose()
	episodes()
	FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify({"model":Probe.Sim.MODEL_VERSION,"checks":checks,"failures":failures,"results":results,"human_acceptance":false},"\t"))
	print("LANDING_SETTLE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"output":output}))
	quit(0 if failures.is_empty() else 1)
func final_pose() -> void:
	var skier=preload("res://scripts/presentation/skier_visual.gd").new(); skier.preview_only=true; root.add_child(skier)
	await process_frame
	var fixture={"amplitude":0.0,"kmh":60.0,"depth":.2}
	var field=Probe.surface(fixture); var sim=Probe.rider(field,fixture); var reference=Probe.rider(field,fixture)
	skier.reset_animation(sim)
	var landed=-1; var touchdown_height=0.0; var min_height=INF; var min_tick=-1; var max_recovery_mps=0.0; var prior_height=0.0
	var delayed_compression=0.0; var peak_cosmetic=0.0; var stable=true; var pose_rows: Array=[]
	for tick in 480:
		var intent=Probe.input(tick,fixture)
		sim.step(Probe.DT,intent,field); reference.step(Probe.DT,intent,field)
		skier.step_animation(Probe.DT,sim,intent,field); skier.pose(sim,1.0)
		stable=stable and sim.position==reference.position and sim.velocity==reference.velocity and sim.grounded==reference.grounded and sim.impacts.reserve==reference.impacts.reserve and sim.body.pelvis_height==reference.body.pelvis_height
		var feet: Vector3=(skier.rendered_joints.RightFoot+skier.rendered_joints.LeftFoot)*.5
		var height: float=(skier.rendered_joints.Hips-feet).y
		if sim.time_since_landing==0.0 and landed<0: landed=sim.ticks; touchdown_height=prior_height
		if landed>=0 and sim.ticks-landed<48:
			if height<min_height: min_height=height; min_tick=sim.ticks
			max_recovery_mps=maxf(max_recovery_mps,(height-prior_height)/Probe.DT)
			peak_cosmetic=maxf(peak_cosmetic,skier.animation.current.impact_drop)
			if sim.ticks-landed==30: delayed_compression=touchdown_height-height
		pose_rows.append({"tick":sim.ticks,"hip_height":height,"cosmetic_drop":skier.animation.current.impact_drop})
		prior_height=height
	check(stable,"Animation and final fitting leave paired solver trajectory, support, reserve and body state identical")
	check(landed>0 and touchdown_height-min_height>.05 and touchdown_height-min_height<.14,"Small landing gives readable proportional 5-14 cm compression")
	check(min_tick-landed>=8 and min_tick-landed<=24,"Small landing reaches compression in 67-200 ms, without an instantaneous dip")
	check(max_recovery_mps<.8 and delayed_compression>.025,"Small landing remains absorbed after 250 ms and avoids a fast upward pop")
	check(peak_cosmetic>.05,"Existing flight crouch cannot consume the small landing's entire procedural compression")
	check(skier.animation.landing_events==1 and skier.animation.current.impact==0.0,"Small-hop reaction completes once")
	results.append({"pose":"small_hop","touchdown_tick":landed,"drop_m":touchdown_height-min_height,"peak_tick":min_tick,"max_upward_hip_speed_mps":max_recovery_mps,"compression_at_250ms_m":delayed_compression,"peak_cosmetic_drop_m":peak_cosmetic})
	FileAccess.open(output+"/pose.json",FileAccess.WRITE).store_string(JSON.stringify(pose_rows))
	skier.queue_free(); await process_frame
func episodes() -> void:
	var field=Probe.surface({"amplitude":0.0}); var sim=Probe.rider(field,{})
	var motion=Motion.new(); motion.reset(sim)
	# Isolate completed contact telemetry from translation to test event ownership.
	for tick in 44:
		sim.ticks+=1
		for ski in sim.skis: ski.landing_speed=3.0 if tick in [0,42] else 0.0
		sim.motion.capture(sim,Probe.DT); motion.step(Probe.DT,sim,RiderInput.new(),field)
	check(motion.landing_events==1 and motion.landing_age>.35,"Brief recontact during small landing recovery does not restart compression")
	var saved=motion.current.duplicate(true); motion.hold(); motion.step(Probe.DT,sim,RiderInput.new(),field)
	check(motion.current==saved,"Pause and repeated observation hold the completed landing pose")
	sim.airtime=.12; sim.ticks+=1
	for ski in sim.skis: ski.landing_speed=0.0
	sim.motion.capture(sim,Probe.DT); motion.step(Probe.DT,sim,RiderInput.new(),field)
	sim.airtime=0.0; sim.ticks+=1
	for ski in sim.skis: ski.landing_speed=3.0
	sim.motion.capture(sim,Probe.DT); motion.step(Probe.DT,sim,RiderInput.new(),field)
	check(motion.landing_events==2,"New sustained flight rearms a genuine landing during an earlier recovery")
	motion.reset(sim)
	check(motion.current.impact==0.0 and motion.current.absorbed==0.0 and motion.landing_events==0,"Restart/contact initialization clears landing history")
