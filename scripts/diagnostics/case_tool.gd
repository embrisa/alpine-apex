extends SceneTree
## Explicit agent entry point; never writes personal records or changes source cases.
const Store = preload("res://scripts/diagnostics/case_store.gd")
const Recorder = preload("res://scripts/diagnostics/case_recorder.gd")
const Sim = preload("res://scripts/diagnostics/case_simulation.gd")
const Surface = preload("res://scripts/diagnostics/case_surface.gd")
const Pose = preload("res://scripts/diagnostics/case_pose.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Evidence = preload("res://scripts/diagnostics/scenario_evidence.gd")
var case_path = ""
var output = ""
var mode = "Inspect"
var data
var game
var exit_status = 0
var capture_frames = 8
var rerun_caption: Label

func _initialize() -> void: call_deferred("run")

func fail(message: String) -> void:
	exit_status = 2
	printerr("TEST_CASE_ERROR ",message)
	if not output.is_empty(): write_json("error.json",{"error":message,"mode":mode})
	quit(2)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): case_path = arg.trim_prefix("--case=")
		if arg.begins_with("--case-output="): output = arg.trim_prefix("--case-output=")
		if arg.begins_with("--case-mode="): mode = arg.trim_prefix("--case-mode=")
		if arg.begins_with("--case-capture-frames="): capture_frames = arg.trim_prefix("--case-capture-frames=").to_int()
	if case_path.is_empty() or output.is_empty() or mode not in ["Inspect","Capture","Rerun","RerunCapture"] or capture_frames<2 or capture_frames>120: fail("Supply a case/output, Inspect|Capture|Rerun|RerunCapture mode and 2-120 capture frames."); return
	if FileAccess.file_exists(output+"/result.json"): fail("Choose a fresh output folder; prior results are preserved."); return
	if DirAccess.make_dir_recursive_absolute(output)!=OK: fail("Cannot create output folder."); return
	data = Store.open_case(case_path)
	if not data.error.is_empty(): fail(data.error); return
	var ticks: Array = data.rows("ticks")
	if not data.error.is_empty() or ticks.size()!=int(data.metadata.duration_ticks)+1:
		fail(data.error if not data.error.is_empty() else "Incomplete tick coverage."); return
	for i in ticks.size():
		if ticks[i].tick!=i or ticks[i].input.size()!=(9 if i>0 and i<=data.metadata.input_ticks else 0): fail("Input/tick coverage mismatch."); return
	var selected: Array = []; var events: Array = []
	for tick in ticks:
		events.append_array(tick.events)
		if tick.tick>=data.metadata.start_tick and tick.tick<=data.metadata.end_tick: selected.append(tick)
	var report = {"mode":mode,"case_sha256":FileAccess.get_sha256(case_path),"metadata":data.metadata,
		"selected_ticks":selected,"control_events":events,"scope":"diagnostic_case","personal_records":false}
	if mode=="Inspect": write_json("result.json",report); print("TEST_CASE_INSPECT ",output); quit(exit_status); return
	report.source_identity = Evidence.identity()
	var reference = data.metadata.identity.get("mountain")
	var error = Definition.reference_error(reference)
	if not error.is_empty(): fail(error); return
	var decoded = Definition.decode(JSON.stringify({"format":"alpine-apex-mountain","schema":2,"name":"Case mountain","mountain":reference}))
	if not decoded.error.is_empty(): fail(decoded.error); return
	print("TEST_CASE_LOADING recorded mountain")
	var restored = decoded.mountain.reconstruct()
	if not restored.error.is_empty(): fail(restored.error); return
	set_meta("mountain_to_load",{"definition":decoded.mountain,"field":restored.field})
	game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized: await process_frame
	while game.test_cases==null: await process_frame
	if not Pose.compatible(data.metadata.rig,game.skier): fail("Unsupported recorded skier rig or asset."); return
	game.active = false; game.session.eligible = false; game.session.recording = null; game.preferences_enabled = false
	if mode=="Capture": await capture(report)
	else: await rerun(report,ticks)
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(exit_status)

func capture(report: Dictionary) -> void:
	await game.test_cases.open_case(case_path)
	if not game.test_cases.reviewing: fail(game.test_cases.ui.status.text); return
	game.test_cases.ui.panel.hide()
	var label = Label.new(); label.position = Vector2(24,24); label.add_theme_font_size_override("font_size",22); game.hud.root.add_child(label)
	var images: Array[Image] = []; report.captures = []
	var start: float = data.metadata.start_tick/120.0; var end: float = data.metadata.end_tick/120.0
	for i in capture_frames:
		var time = lerpf(start,end,float(i)/(capture_frames-1))
		game.test_cases.seek(time)
		hide_capture_hud(label)
		label.text = "%s | original %.3f s | tick %d"%[data.metadata.title,time,roundi(time*120)]
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		var picture = root.get_texture().get_image()
		var path = output+"/frame_%02d.png"%i
		if picture.save_png(path)!=OK: fail("Cannot write capture image."); return
		report.captures.append({"path":path,"tick":roundi(time*120),"time":time,"requested_time":time,"captured_frame_time":game.test_cases.last_frame.get("t",-1),"captured_tick":game.test_cases.last_frame.tick,"camera":Pose.camera_capture(game.presentation_camera),"pose":game.test_cases.last_frame.pose,"state_origin":"recorded_pose"})
		picture.resize(640,400,Image.INTERPOLATE_LANCZOS); images.append(picture)
	var sheet = Image.create(1280,400*ceili(images.size()/2.0),false,Image.FORMAT_RGBA8); sheet.fill(Color(.02,.04,.06))
	for i in images.size():
		images[i].convert(Image.FORMAT_RGBA8); sheet.blit_rect(images[i],Rect2i(0,0,640,400),Vector2i((i%2)*640,(i/2)*400))
	if sheet.save_png(output+"/contact_sheet.png")!=OK: fail("Cannot write contact sheet."); return
	report.evidence = "Captured pose/camera reconstruction; current rendering, no original audio/video."
	publish_evidence(report,recorded_rows(report.selected_ticks),"recorded_pose")
	write_json("result.json",report); print("TEST_CASE_CAPTURE ",output)

func rerun(report: Dictionary, ticks: Array) -> void:
	if mode=="RerunCapture":
		if DisplayServer.get_name()=="headless": fail("RerunCapture requires rendering"); return
		await game.test_cases.open_case(case_path)
		if not game.test_cases.reviewing: fail(game.test_cases.ui.status.text); return
		# The tool owns completed simulation and camera state during capture.
		game.set_process(false); game.test_cases.ui.panel.hide()
		rerun_caption=Label.new(); rerun_caption.position=Vector2(24,24); rerun_caption.add_theme_font_size_override("font_size",22); game.hud.root.add_child(rerun_caption)
	var initial: Dictionary = ticks[0]
	if not initial.has("tuning"): fail("Missing recorded tuning."); return
	var tuning = preload("res://config/ski_default.tres").duplicate(true)
	var current_keys = Recorder.tuning_data(tuning)
	if initial.tuning.keys()!=current_keys.keys(): fail("Recorded tuning layout is incompatible."); return
	for key in initial.tuning:
		if typeof(initial.tuning[key])!=typeof(current_keys[key]): fail("Recorded tuning type is incompatible: "+key); return
		tuning.set(key,initial.tuning[key])
	var sim = Sim.new(tuning); sim.policy.values = data.metadata.initial_settings.duplicate()
	var surface = Surface.new(game.field,game.world.ski_surface,sim.policy)
	game.sim = sim; game.world.ski_surface = surface
	sim.reset(game.field.launch_point(initial.state.heading),initial.state.heading); sim.prime_contacts(game.field); game.skier.reset_animation(sim); game.skier.pose(sim,1.0)
	var same_sources: bool = data.metadata.get("stable_sources",false) and data.metadata.identity.sources==Recorder.sources() and data.metadata.identity.engine_sha256==FileAccess.get_sha256(OS.get_executable_path())
	report.comparison = "matching_source_verification" if same_sources else "changed_code_comparison"
	report.current_model = sim.MODEL_VERSION; report.current_sources = Recorder.sources(); report.current_engine = Engine.get_version_info()
	report.tuning = "recorded"; report.differences = []; report.maximum_position_difference_m = 0.0; report.first_divergence_tick = -1
	report.fresh_ragdoll = []; report.exact_skiing = true
	report.termination = "Completed retained coverage."
	report.captures = []
	var evidence_rows: Array = []
	var sample_ticks: Dictionary = {}
	for i in capture_frames: sample_ticks[roundi(lerpf(data.metadata.start_tick,data.metadata.end_tick,float(i)/(capture_frames-1)))]=true
	var previous = Recorder.state(sim)
	if int(data.metadata.start_tick)==0:
		evidence_rows.append(Evidence.sample(sim,0,null,surface))
		if mode=="RerunCapture": await capture_rerun_frame(report,0)
	if sim.position!=initial.state.position: report.exact_skiing = false; report.first_divergence_tick = 0
	for i in range(1,ticks.size()):
		var recorded: Dictionary = ticks[i]
		if recorded.input.is_empty() and not sim.crashed:
			report.termination = "Original input coverage ended; original crash did not occur."; report.exact_skiing = false; report.first_divergence_tick = i if report.first_divergence_tick<0 else report.first_divergence_tick; break
		if sim.crashed and not recorded.input.is_empty():
			report.termination = "Current code crashed earlier than the original."; report.exact_skiing = false; report.first_divergence_tick = i if report.first_divergence_tick<0 else report.first_divergence_tick; break
		sim.policy.pending = recorded.events.map(func(event): return {"kind":event.kind,"value":event.value})
		sim.policy.before_tick(sim,surface,i)
		game.crash_collision.set_diagnostic_filter(sim.policy.values.trees,sim.policy.values.rocks)
		if not sim.policy.error.is_empty(): report.differences.append({"tick":i,"control_error":sim.policy.error})
		if not recorded.input.is_empty():
			var intent = Recorder.input_from(recorded.input)
			sim.step(1.0/120,intent,surface); game.skier.step_animation(1.0/120,sim,intent,game.field)
			game.skier.pose(sim,1.0)
			if sim.crashed:
				game.crash_collision.prepare(sim.position); game.skier.ragdoll.start(sim)
		else:
			await physics_frame
			game.skier.ragdoll.update_equipment()
			if i>=int(data.metadata.start_tick): report.fresh_ragdoll.append({"tick":i,"pose":Pose.capture(game.skier)})
		var actual: Dictionary = Recorder.state(sim)
		if i>=int(data.metadata.start_tick):
			var row = Evidence.sample(sim,i,Recorder.input_from(recorded.input) if not recorded.input.is_empty() else null,surface)
			row.events=Evidence.events(previous,actual)
			evidence_rows.append(row)
			if mode=="RerunCapture" and (sample_ticks.has(i) or not row.events.is_empty()): await capture_rerun_frame(report,i)
		previous=actual
		var distance: float = sim.position.distance_to(recorded.state.position)
		report.maximum_position_difference_m = maxf(report.maximum_position_difference_m,distance)
		var equal: bool = actual==recorded.state and sim.policy.error.is_empty()
		if not equal:
			report.exact_skiing = false
			if report.first_divergence_tick<0: report.first_divergence_tick = i
		if i>=int(data.metadata.start_tick): report.differences.append({"tick":i,"position_difference_m":distance,"equal":equal,"actual":actual})
		if i%1200==0: print("TEST_CASE_RERUN tick=",i)
	report.final_state = Recorder.state(sim)
	report.ragdoll_scope = "Fresh Jolt observations, not deterministic original crash reproduction."
	report.bug_fixed = "Not automatically assessed. Compare the user's notes and captured evidence."
	if same_sources and not report.exact_skiing:
		report.validation_error = "Matching-source skiing reproduction diverged."; exit_status = 1
	publish_evidence(report,evidence_rows,"current_solver")
	write_json("result.json",report); print("TEST_CASE_RERUN_RESULT ",JSON.stringify({"output":output,"comparison":report.comparison,"exact_skiing":report.exact_skiing,"first_divergence_tick":report.first_divergence_tick}))

func write_json(name_value: String, value: Variant) -> void:
	var file = FileAccess.open(output+"/"+name_value,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(json_value(value),"\t",true,true)); file.flush()
		if file.get_error()==OK: return
	exit_status = 2; printerr("TEST_CASE_ERROR Cannot write ",output+"/"+name_value)

func capture_rerun_frame(report: Dictionary,tick: int) -> void:
	hide_capture_hud(rerun_caption)
	var frame: Dictionary = data.frame_at(tick/120.0)
	if frame.is_empty(): fail("No recorded camera for candidate capture"); return
	Pose.camera_apply(game.test_cases.view_camera,frame.camera); game.test_cases.view_camera.make_current()
	game.presentation_camera=game.test_cases.view_camera
	game.weather.restore(frame.weather); game.world.update_weather(game.weather.state,0,false)
	rerun_caption.text="Current solver | original %.3f s | tick %d"%[tick/120.0,tick]
	# Save the actual new final pose, not the package's recorded pose.
	await process_frame; await RenderingServer.frame_post_draw
	var pose=Pose.capture(game.skier)
	var name="rerun_%06d.png"%tick
	if root.get_texture().get_image().save_png(output+"/"+name)!=OK: fail("Cannot save rerun frame"); return
	report.captures.append({"path":name,"tick":tick,"time":tick/120.0,"captured_tick":tick,"captured_frame_time":tick/120.0,"camera_source_time":frame.t,"pose":pose,"camera":Pose.camera_capture(game.presentation_camera),"state_origin":"current_solver"})

func hide_capture_hud(caption: Label) -> void:
	# A candidate must not display the last sought recording's speed/FPS labels.
	# The synchronized review supplies telemetry from the correct state origin.
	for child in game.hud.root.get_children():
		if child is CanvasItem and child!=caption: child.hide()

func recorded_rows(ticks: Array) -> Array:
	var rows: Array=[]
	var previous: Dictionary={}
	for row in ticks:
		var state: Dictionary=row.state
		rows.append({"tick":row.tick,"time":row.t,"input":row.input,"state":state,"events":Evidence.events(previous,state),
			"metrics":{"speed_mps":state.velocity.length(),"load_n":state.ski_loads[0]+state.ski_loads[1],"slip_rad":state.slip,"edge_rad":state.edge,"grounded":1 if state.grounded else 0,"impact_speed_mps":state.impact_speed}})
		previous=state
	return rows

func publish_evidence(report: Dictionary,rows: Array,origin: String) -> void:
	var manifest=Evidence.envelope("case:"+report.case_sha256,{"case_sha256":report.case_sha256,"start_tick":data.metadata.start_tick,"end_tick":data.metadata.end_tick},report.source_identity)
	manifest.scope="diagnostic_case"; manifest.state_origin=origin; manifest.recorded_identity=data.metadata.identity
	manifest.recorded_stable_sources=data.metadata.get("stable_sources",false)
	manifest.notes={"title":data.metadata.title,"observed":data.metadata.what,"expected":data.metadata.expected,"settings":data.metadata.initial_settings,"controls":report.control_events}
	manifest.tuning=data.rows("ticks")[0].tuning
	manifest.camera={"view":"recorded","resolution":[root.size.x,root.size.y]}
	manifest.captures=report.get("captures",[]).duplicate(true); manifest.comparison=report.get("comparison","recorded_state_current_rendering")
	for frame in manifest.captures: frame.path=frame.path.get_file()
	manifest.actual_ticks=rows[-1].tick-rows[0].tick if not rows.is_empty() else 0
	manifest.actual_seconds=manifest.actual_ticks/120.0
	manifest.stop_reason=report.get("termination","selected_recording")
	manifest.stable_sources=report.source_identity.sources==Evidence.identity().sources
	if not manifest.stable_sources: manifest.failures.append("Source changed during evidence production")
	if report.has("validation_error"): manifest.failures.append(report.validation_error)
	if rows.is_empty(): manifest.failures.append("No selected rerun coverage")
	manifest.status="complete" if manifest.failures.is_empty() else "failed"
	for row in rows:
		for event in row.events: manifest.events.append({"tick":row.tick,"name":event})
	write_json("telemetry.json",rows); write_json("manifest.json",manifest)
	if not manifest.failures.is_empty(): exit_status=1

static func json_value(value: Variant) -> Variant:
	if value is Vector2: return [value.x,value.y]
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Dictionary:
		var result = {}
		for key in value: result[str(key)] = json_value(value[key])
		return result
	if value is Array or value is PackedFloat64Array or value is PackedFloat32Array or value is PackedInt32Array:
		var result: Array = []
		for item in value: result.append(json_value(item))
		return result
	return value
