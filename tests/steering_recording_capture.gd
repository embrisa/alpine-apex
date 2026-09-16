extends "res://tests/pose_reference_capture.gd"
## Exact recorded inputs on the production mountain; no session or personal data.
const Trace = preload("res://tests/performance_trace.gd")
const Metrics = preload("res://tests/carve_proportional_suite.gd")
const Fixture = preload("res://tests/steering_recording_fixture.gd")

func run():
	var path = ""
	var regression_fixture = false
	probe = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input-trace="): path = arg.trim_prefix("--input-trace=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg=="--regression-fixture": regression_fixture = true
	if regression_fixture: path = Fixture.PATH
	if path.is_empty() or not FileAccess.file_exists(path): printerr("A current --input-trace is required"); quit(2); return
	if FileAccess.file_exists(output+"/manifest.json"): printerr("Capture exists; choose a fresh output"); quit(2); return
	var trace = JSON.parse_string(FileAccess.get_file_as_string(path))
	var error = "" if regression_fixture else Trace.preflight_error(trace,Definition.CURRENT_VERSION,false)
	if not error.is_empty(): printerr(error); quit(2); return
	field = preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: quit(2); return
	if regression_fixture: trace = Fixture.load_inputs(field)
	elif not Trace.matches(field,trace.identity): printerr("Recording terrain identity differs"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	report = {"version":1,"engine":Engine.get_version_info().string,"physics":Sim.MODEL_VERSION,"capture_fps":120,"simulation_hz":120,"frame_origin":0,"unranked":true,"sources":source_hashes(),"scenarios":[],"failures":[],"input_sha256":FileAccess.get_sha256(path),"scope":"Exact recorded inputs on Standard terrain with production final poses; no session or personal data."}
	report.input_identity = trace.identity.duplicate(true)
	if regression_fixture: report.scope = "Current-model rerun of the retained historical input stimulus; newly generated endpoints, not an exact old-model replay."
	scene = Node3D.new(); root.add_child(scene)
	skier = Visual.new(); skier.preview_only = true; skier.snow_burial_enabled = true; scene.add_child(skier); await process_frame
	report.rig = {"names":[],"parents":[],"rest":[]}
	for i in skier.skeleton.get_bone_count():
		report.rig.names.append(skier.skeleton.get_bone_name(i)); report.rig.parents.append(skier.skeleton.get_bone_parent(i)); report.rig.rest.append(pack(skier.rest[i]))
	var sim = Sim.new(preload("res://config/ski_default.tres").duplicate(true))
	sim.reset(field.launch_point(trace.heading),trace.heading); sim.prime_contacts(field); skier.reset_animation(sim)
	if not regression_fixture and not Trace.Inputs.matches_state(sim,trace.initial_state): report.failures.append("Initial state differs")
	var initial = Trace.Inputs.state(sim)
	var checkpoints = []
	var rows = []; var checkpoint = 0
	for tick in int(trace.result.ticks):
		var input = Trace.Inputs.decode(trace.commands[tick/int(trace.command_ticks)])
		sim.step(DT,input,field); skier.step_animation(DT,sim,input,field)
		var physical = Trace.Inputs.state(sim)
		if sim.ticks%120==0: checkpoints.append(physical)
		var full = skier.animation.full_motion
		var intermediate = []
		for alpha in [0.0,.5,1.0]:
			skier.pose(sim,alpha)
			var lean = Metrics.silhouette(skier,sim)
			intermediate.append({"alpha":alpha,"body_deg":rad_to_deg(lean.x),"torso_deg":rad_to_deg(lean.y),"pelvis_m":Metrics.pelvis_lateral(skier,sim),"hips":pack(skier.rendered_joints.Hips),"clearance_retention":full.diagnostics.get("clearance_retention",1.0)})
		if Trace.Inputs.state(sim)!=physical: report.failures.append("Pose changed simulation at %d"%sim.ticks)
		if checkpoint<trace.checkpoints.size() and sim.ticks==int(trace.checkpoints[checkpoint][0]):
			if not regression_fixture and not Trace.Inputs.matches_state(sim,trace.checkpoints[checkpoint]): report.failures.append("Checkpoint differs at %d"%sim.ticks)
			checkpoint+=1
		var source = full.sample(1.0)
		var row = {"frame":tick,"tick":sim.ticks,"time":sim.ticks*DT,"grounded":sim.grounded,"phase":skier.animation.phase,"input":pack({"steer":input.steer,"tuck":input.tuck}),"effective_tuck":sim.effective_tuck,"state":pack(skier.animation.current),"diagnostics":pack(full.diagnostics),"intermediate":intermediate,"clips":clip_times(full),"root":pack(skier.global_transform),"joints":pack(skier.rendered_joints),"rotations":pack(skier.rendered_rotations),"requested":pack(full.requested_joints),"requested_rotations":pack(full.requested_rotations),"source":pack(source.joints),"source_rotations":pack(source.rotations),"support_response":full.support_response,"physical_position":pack(sim.position),"velocity":pack(sim.velocity),"heading_rad":sim.heading,"body_roll_rad":sim.body.roll,"body_roll_velocity":sim.body.roll_velocity,"cop":pack(sim.body.cop),"requested_cop":pack(sim.body.requested_cop),"correction_torque":pack(sim.body.correction_torque),"inertia":pack(sim.body.inertia),"normal_load":sim.normal_load,"force_acceleration":pack(sim.force_acceleration),"pressure_reserve":sim.body.pressure_reserve,"pelvis_height":sim.body.pelvis_height,"carve_blend":sim.carve_blend,"physical_hips":pack(sim.body.joints.Hips),"physical_com":pack(sim.body.com),"requested_lateral_acceleration":sim.requested_lateral_acceleration,"turn_rate_rad_s":sim.motion.turn_rate_rad_s,"speed_mps":sim.velocity.length(),"surface_normal":pack(sim.surface_normal),"requested_edge_rad":sim.edge_angle,"ski_edges_rad":[sim.skis[0].edge_angle,sim.skis[1].edge_angle],"ski_loads_n":[sim.skis[0].load_n,sim.skis[1].load_n],"ski_supported":[sim.skis[0].grounded,sim.skis[1].grounded],"downhill_weight":full.downhill_amount,"action_weights":pack(full.action_amount),"final_bones":[],"skis":[],"poles":[],"cameras":[]}
		for i in skier.skeleton.get_bone_count(): row.final_bones.append(pack(skier.skeleton.get_bone_global_pose(i)))
		for ski in skier.skis: row.skis.append(pack(ski.global_transform))
		for pole in skier.poles: row.poles.append(pack(pole.global_transform))
		rows.append(row)
		if sim.ticks%240==0: print("STEERING_CAPTURE tick=",sim.ticks)
	if not regression_fixture and not Trace.Inputs.matches_state(sim,trace.final_state): report.failures.append("Final state differs")
	report.exact_recording = not regression_fixture and report.failures.is_empty()
	report.regression_fixture = regression_fixture
	if regression_fixture:
		# Generate a NEW current-model diagnostic scenario by rerunning the frozen
		# stimulus. This never changes or accepts the old player recording.
		trace.identity = Trace.identity(field); trace.initial_state = initial
		trace.checkpoints = checkpoints; trace.final_state = Trace.Inputs.state(sim)
		trace.result = {"face":trace.face,"side":0,"ticks":sim.ticks,"seconds":sim.ticks*DT,"finished":false,"crash":sim.crash_reason,"position":pack(sim.position)}
		trace.source_recorded_utc = trace.recorded_utc; trace.termination = "stimulus_endpoint"
		trace.origin = "steering_jank_regression_stimulus"; trace.recorded_utc = Time.get_datetime_string_from_system(true)
		trace.engine = Engine.get_version_info(); trace.engine_sha256 = FileAccess.get_sha256(OS.get_executable_path())
		trace.erase("regression_fixture"); trace.erase("fixture_purpose")
		preload("res://tests/test_report.gd").write(output+"/current-input.json",JSON.stringify(Trace.Inputs.storage(trace),"",true,true))
	report.sources_after = source_hashes(); report.stable_sources = report.sources==report.sources_after
	if not report.stable_sources: report.failures.append("Capture source changed")
	preload("res://tests/test_report.gd").write(output+"/recording.json",JSON.stringify({"name":"recording","fixture":{"heading":trace.heading},"events":[],"frames":rows}))
	report.scenarios.append({"name":"recording","frames":rows.size()})
	preload("res://tests/test_report.gd").write(output+"/manifest.json",JSON.stringify(report,"\t"))
	print("STEERING_CAPTURE_RESULT ",JSON.stringify({"frames":rows.size(),"failures":report.failures,"output":output}))
	scene.queue_free(); await process_frame; quit(0 if report.failures.is_empty() else 1)

func source_hashes() -> Dictionary:
	var result = super.source_hashes()
	result["res://tests/steering_recording_capture.gd"] = FileAccess.get_sha256("res://tests/steering_recording_capture.gd")
	return result
