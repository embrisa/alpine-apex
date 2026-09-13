extends SceneTree
const Store = preload("res://scripts/diagnostics/case_store.gd")
var game
var failures: Array[String] = []
var output = "res://artifacts/test_cases/playtest"
var checks = 0
var performance: Array = []
class QuietRecorder extends "res://scripts/diagnostics/case_recorder.gd":
	func observe_tick(_sim, _intent, skiing: bool, _changes: Array) -> void:
		tick += 1
		if skiing: input_ticks += 1
	func observe_frame(_game, _dt: float, _fraction: float) -> void: pass
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("FAIL ",label)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if not output.is_absolute_path(): output=ProjectSettings.globalize_path("res://"+output)
	DirAccess.make_dir_recursive_absolute(output)
	var field = preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: printerr("Missing warm mountain."); quit(2); return
	set_meta("mountain_to_load",{"definition":preload("res://scripts/world/mountain_definition.gd").from_field(field,"Test Cases validation"),"field":field})
	game = load("res://main.tscn").instantiate(); game.automated = true; root.add_child(game); current_scene = game
	while game.test_cases==null: await process_frame
	game.active = false
	var cases = game.test_cases
	cases.directory = output+"/library"
	cases.open_library(); await capture("library")
	cases.setup_recording(); await capture("setup")
	cases.ui.immortal.button_pressed = true; cases.ui.speed.value = 40
	cases.queue_controls(true)
	cases.start_recording()
	game.sim.reset(field.spawn_point(),field.faces[3].heading)
	game.drop_from_summit()
	game.benchmark_input = func(_tick):
		var input = RiderInput.new(); input.tuck = .7; input.steer = .3*sin(_tick*.03); return input
	while game.sim.ticks<240: await physics_frame
	cases.open_controls()
	check(cases.recorder.data.rows("ticks")[1].events.any(func(event): return event.kind=="speed" and event.value==40),"Explicit setup speed survives summit launch exactly once")
	var ticks: int = cases.recorder.tick
	for i in 12: await physics_frame
	check(cases.recorder.tick==ticks,"Paused controls freeze recording clock")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	for i in 12: await physics_frame
	check(cases.recorder.tick==ticks and not game.application_focused,"Focus loss freezes the recording clock")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	cases.ui.speed.value = 80; cases.ui.trees.button_pressed = false; cases.ui.rocks.button_pressed = false
	cases.queue_controls(true,true)
	while game.sim.ticks<480: await physics_frame
	cases.open_controls(); await capture("controls")
	check(not game.session.eligible and not game.preferences_enabled,"Diagnostic take cannot save personal records/preferences")
	var real_directory: String = cases.directory
	var impossible = output+"/not-a-directory"
	FileAccess.open(impossible,FileAccess.WRITE).store_string("Save failure fixture")
	cases.directory = impossible
	check(not cases.save_recording("save_failure") and cases.recorder!=null and not game.active,"Failed publication preserves the paused recording for retry")
	cases.directory = real_directory
	check(cases.save_recording("validation",false),"Recording publishes")
	var path: String = cases.case_path
	await cases.open_case(path)
	check(cases.reviewing,"Saved recording opens in review")
	if not cases.reviewing: printerr(cases.ui.status.text); quit(2); return
	await controller_checks(cases)
	cases.seek(2.5); await capture("review")
	var pose_before = preload("res://scripts/diagnostics/case_pose.gd").capture(game.skier)
	cases.seek(1); cases.seek(2.5)
	var pose_after = preload("res://scripts/diagnostics/case_pose.gd").capture(game.skier)
	var pose_error = 0.0
	for i in pose_after.size(): pose_error = maxf(pose_error,absf(pose_after[i]-pose_before[i]))
	check(pose_error<.0001,"Seeking back then forward restores recorded pose")
	cases.toggle_camera(); await capture("free-camera")
	cases.in_tick = 240; cases.out_tick = 360
	var clip = cases.case_data.trim(240,360,"Controller speed test","Speed changed mid-recording","Saved settings must rerun at the same tick")
	var clip_path = output+"/case-"+str(Time.get_ticks_usec())+".apexcase"
	check(clip.save(clip_path).is_empty(),"Trimmed selection publishes")
	var opened = Store.open_case(clip_path)
	check(opened.error.is_empty() and opened.rows("ticks").size()==361,"Clip retains launch-to-end input history")
	var changed = false
	for row in opened.rows("ticks"):
		for event in row.events:
			if event.kind=="speed" and event.value==80: changed = true
	check(changed,"Trim retains exact speed-control event")
	cases.open_library(); cases.leave_mode()
	check(not cases.recording_mode and game.world.ski_surface==cases.original_surface,"Leaving restores ordinary surface and simulator")
	if "--recording-only" not in OS.get_cmdline_user_args(): await crash_case(cases,field)
	if "--case-performance" in OS.get_cmdline_user_args(): await measure_capture(cases,field)
	var report = {"checks":checks,"failures":failures,"recording":ProjectSettings.globalize_path(path),"clip":ProjectSettings.globalize_path(clip_path),"performance":performance,"scope":"Automated rendered lifecycle, not physical-controller acceptance"}
	if "--recording-only" in OS.get_cmdline_user_args(): report.scope="Bounded recording/export fixture; crash lifecycle and human acceptance not exercised"
	FileAccess.open(output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TEST_CASE_PLAYTEST ",JSON.stringify(report))
	game.effects.stop_audio(); game.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)

func capture(name_value: String) -> void:
	await process_frame; await process_frame
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name_value+".png")

func crash_case(cases, field) -> void:
	cases.policy.values.immortal = false
	cases.start_recording()
	# A recorded tuning fixture makes a normal jump/landing fatal without an
	# unrecorded teleport, forced crash call, or an alternate terrain surface.
	game.sim.tuning.landing_tolerance = .01
	game.sim.tuning.impact_reference_damage = 2.0
	game.sim.tuning.impact_max_damage = 2.0
	game.sim.tuning.impact_soft_ratio = 0.0
	game.sim.tuning.landing_clean_damage_scale = 1.0
	game.sim.reset(field.spawn_point(),field.faces[3].heading)
	game.drop_from_summit()
	game.benchmark_input = func(tick):
		var input = RiderInput.new(); input.tuck = .7; input.jump_held = tick>=10 and tick<50; input.jump = tick==50; return input
	while game.sim.ticks<720 and not game.sim.crashed: await physics_frame
	check(game.sim.crashed,"Recorded jump fixture enters a physical crash")
	if not game.sim.crashed: cases.save_recording("fixture_no_crash"); cases.leave_mode(); return
	var onset: int = cases.recorder.tick
	check(not cases.recorder.data.rows("frames").filter(func(frame): return not frame.crashed and frame.contacts.size()==21 and frame.contacts[0]==0 and frame.contacts[10]==0).is_empty(),"Take captures an airborne pose before impact")
	while cases.recorder!=null and cases.recorder.tick<onset+1900: await physics_frame
	for i in 4: await process_frame
	check(cases.reviewing and cases.case_data.metadata.termination=="crash_aftermath","Crash aftermath automatically saves and opens review")
	if cases.reviewing:
		cases.seek((onset+300)/120.0); await capture("crash_review")
		cases.ui.panel.hide(); await capture("crash_pose"); cases.ui.panel.show()
		check(cases.last_frame.crashed,"Review shows captured crash poses instead of hiding the rider")
		var early = cases.last_frame.pose
		cases.seek((onset+900)/120.0)
		check(cases.last_frame.pose!=early,"Captured ragdoll advances independently of frozen skiing state")
		cases.step_frame(-1); cases.step_frame(1)
		cases.leave_mode()

func measure_capture(cases, field) -> void:
	game.display_settings.apply_display(root,Vector2i(3840,2160))
	game.display_settings.apply_viewport(root)
	root.grab_focus()
	var weather = game.weather.snapshot()
	var reference = Vector3.INF
	for repetition in 3:
		for capture_enabled in [false,true]:
			game.weather.restore(weather)
			cases.policy.values = {"immortal":true,"hold_speed":true,"speed_kmh":120.0,"trees":false,"rocks":false}
			cases.start_recording()
			game.sim.reset(field.spawn_point(),field.faces[3].heading)
			game.drop_from_summit()
			game.benchmark_input = func(_tick):
				var input = RiderInput.new(); input.tuck = .7; return input
			if not capture_enabled:
				cases.recorder = QuietRecorder.new(); cases.recorder.begin(game)
			while game.sim.ticks<240: await physics_frame
			var samples: Array = []; var invalid: Array = []; var previous: Array = [Time.get_ticks_usec()]
			var sample = func():
				var now = Time.get_ticks_usec()
				if game.sim.ticks>=240 and game.sim.ticks<2040:
					samples.append((now-previous[0])/1000.0)
					if not root.has_focus() or root.mode==Window.MODE_MINIMIZED: invalid.append("unfocused")
				previous[0] = now
			process_frame.connect(sample)
			while game.sim.ticks<2040: await physics_frame
			process_frame.disconnect(sample)
			var endpoint: Vector3 = game.sim.position
			if reference==Vector3.INF: reference = endpoint
			check(endpoint==reference,"Matched capture overhead trial retains exact endpoint")
			check(invalid.is_empty(),"Performance trial remains focused and visible")
			samples.sort()
			var total = 0.0
			for value in samples: total += value
			var row = {"repetition":repetition+1,"capture":capture_enabled,"samples":samples.size(),"mean_ms":total/maxi(1,samples.size()),"p95_ms":samples[mini(samples.size()-1,floori(samples.size()*.95))],"p99_ms":samples[mini(samples.size()-1,floori(samples.size()*.99))],"raw_bytes":cases.recorder.data.raw_bytes,"actual_pixels":[root.size.x,root.size.y],"unfocused_frames":invalid.size(),"scope":"15-second diagnostic capture overhead after 2-second warmup; fixed 120 km/h, immortal, trees/rocks disabled"}
			performance.append(row); print("CASE_CAPTURE_OVERHEAD ",JSON.stringify(row))
			# Quiet fixtures are intentionally unsaved; only the measured timings are evidence.
			cases.recorder = null; cases.leave_mode()

func controller_checks(cases) -> void:
	var pad = InputEventJoypadButton.new(); pad.device = 15; pad.pressed = true
	check(game.navigation.scope()==cases.ui.panel,"Test review owns controller navigation scope")
	cases.seek(1); pad.button_index = JOY_BUTTON_RIGHT_SHOULDER
	check(cases.route(pad) and cases.playhead==2,"Controller shoulder scrubs recorded time")
	cases.ui.notes(); await process_frame
	pad.button_index = JOY_BUTTON_A; game.navigation.route(pad); await process_frame
	check(game.navigation.virtual_keyboard.dialog.visible,"Controller opens existing text keyboard for case title")
	game.navigation.virtual_keyboard.field.text = "Controller case title"
	game.navigation.virtual_keyboard.apply(); game.navigation.virtual_keyboard.dialog.hide(); await process_frame
	check(cases.ui.title_edit.text=="Controller case title","Controller text entry returns edited case title")
	cases.ui.review(); cases.capture_camera(); pad.button_index = JOY_BUTTON_B
	check(cases.route(pad) and not cases.camera_active and cases.ui.panel.visible,"Controller B returns from free camera to review")
	cases.toggle_camera()
	var tick: int = game.sim.ticks
	for i in 12: await physics_frame
	check(game.sim.ticks==tick and not game.active,"Review and controller camera input never advance skiing")
