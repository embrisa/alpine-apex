extends SceneTree
## Explicit agent entry point; never writes personal records or changes source cases.
const Store = preload("res://scripts/diagnostics/case_store.gd")
const Recorder = preload("res://scripts/diagnostics/case_recorder.gd")
const Sim = preload("res://scripts/diagnostics/case_simulation.gd")
const Surface = preload("res://scripts/diagnostics/case_surface.gd")
const Pose = preload("res://scripts/diagnostics/case_pose.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
var case_path = ""
var output = ""
var mode = "Inspect"
var data
var game
var exit_status = 0

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
	if case_path.is_empty() or output.is_empty() or mode not in ["Inspect","Capture","Rerun"]: fail("Supply --case, --case-output and --case-mode=Inspect|Capture|Rerun."); return
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
	for i in 8:
		var time = lerpf(start,end,i/7.0)
		game.test_cases.seek(time)
		label.text = "%s · original %.3f s · tick %d"%[data.metadata.title,time,roundi(time*120)]
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		var picture = root.get_texture().get_image()
		var path = output+"/frame_%02d.png"%i
		if picture.save_png(path)!=OK: fail("Cannot write capture image."); return
		report.captures.append({"path":path,"requested_time":time,"captured_frame_time":game.test_cases.last_frame.get("t",-1)})
		picture.resize(640,400,Image.INTERPOLATE_LANCZOS); images.append(picture)
	var sheet = Image.create(1280,1600,false,Image.FORMAT_RGBA8); sheet.fill(Color(.02,.04,.06))
	for i in images.size():
		images[i].convert(Image.FORMAT_RGBA8); sheet.blit_rect(images[i],Rect2i(0,0,640,400),Vector2i((i%2)*640,(i/2)*400))
	if sheet.save_png(output+"/contact_sheet.png")!=OK: fail("Cannot write contact sheet."); return
	report.evidence = "Captured pose/camera reconstruction; current rendering, no original audio/video."
	write_json("result.json",report); print("TEST_CASE_CAPTURE ",output)

func rerun(report: Dictionary, ticks: Array) -> void:
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
	sim.reset(game.field.launch_point(initial.state.heading),initial.state.heading); sim.prime_contacts(game.field); game.skier.reset_animation(sim)
	var same_sources: bool = data.metadata.get("stable_sources",false) and data.metadata.identity.sources==Recorder.sources() and data.metadata.identity.engine_sha256==FileAccess.get_sha256(OS.get_executable_path())
	report.comparison = "matching_source_verification" if same_sources else "changed_code_comparison"
	report.current_model = sim.MODEL_VERSION; report.current_sources = Recorder.sources(); report.current_engine = Engine.get_version_info()
	report.tuning = "recorded"; report.differences = []; report.maximum_position_difference_m = 0.0; report.first_divergence_tick = -1
	report.fresh_ragdoll = []; report.exact_skiing = true
	report.termination = "Completed retained coverage."
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
	write_json("result.json",report); print("TEST_CASE_RERUN_RESULT ",JSON.stringify({"output":output,"comparison":report.comparison,"exact_skiing":report.exact_skiing,"first_divergence_tick":report.first_divergence_tick}))

func write_json(name_value: String, value: Variant) -> void:
	var file = FileAccess.open(output+"/"+name_value,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(json_value(value),"\t",true,true)); file.flush()
		if file.get_error()==OK: return
	exit_status = 2; printerr("TEST_CASE_ERROR Cannot write ",output+"/"+name_value)

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
