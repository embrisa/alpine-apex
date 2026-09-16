extends SceneTree
const Session = preload("res://scripts/core/run_session.gd")
const Replay = preload("res://scripts/racing/run_replay.gd")
const Records = preload("res://scripts/racing/competitive_record.gd")
const Race = preload("res://scripts/racing/race_definition.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const DT = 1.0/120.0
var checks: int = 0
var failures: Array = []
var metrics: Dictionary = {}
var captures: Array = []
var test_dir: String
var field
var race
var game

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("PASS: ",label)
	else:
		failures.append(label)
		printerr("FAIL: ",label)

func fixture():
	var result = Race.new()
	result.title = "Ravine Rush"
	result.mountain = Race.mountain_reference(field,field.seed_value+4187)
	result.start = field.spawn_point()
	result.finish = Vector3(0,field.sample(0,240).height,240)
	result.finish_heading=Race.Flavor.downhill_heading(field,result.finish)
	return result

func run() -> void:
	set_meta("test_lab_fixture",true) # Explicit laboratory regression fixture.
	test_dir = "user://competitive_test_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(test_dir)
	field = Race.Terrain.new()
	race = fixture()
	var benchmark_snapshot = _benchmark_files()
	_split_checks()
	var session = Session.new()
	session.record_directory = test_dir.path_join("records")
	session.configure(race)
	var sim = Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
	_drive(session,sim,0.0)
	var first_best: float = session.personal_best
	var first_replay = _best(session)
	check(session.finished and session.new_best and _best(session)!=null,"First ranked finish creates a PB and recorded ghost")
	check(session.save_error.is_empty() and FileAccess.file_exists(Records.path_for(session.record_path())),"PB, splits, history and ghost save together")
	check(session.split_times.all(func(t): return t>0) and session.split_times[0]<session.split_times[1] and session.split_times[1]<session.split_times[2],"Real ski run produces three ordered cumulative approach splits")
	check(absf(first_replay.duration-session.elapsed)<0.000001 and first_replay.inputs.size()==first_replay.ticks*Replay.INPUT_WIDTH,"Replay retains exact finish time and every 120 Hz tick input")
	check(first_replay.samples.size()<=first_replay.ticks/Replay.SAMPLE_EVERY+2,"Snapshot storage is bounded to the capture cadence plus start and exact finish")
	var last_position: Vector3 = first_replay.pose_at(first_replay.duration).position
	check(absf((Basis(Vector3.UP,race.finish_heading).transposed()*(last_position-race.finish)).z)<0.01,"Final ghost sample ends on the sub-tick gate-plane intersection")
	var loaded = Session.new()
	loaded.record_directory = session.record_directory
	loaded.configure(race)
	check(absf(loaded.personal_best-first_best)<0.000000001 and _best(loaded)!=null and range(3).all(func(i): return absf(loaded.best_splits[i]-session.best_splits[i])<0.000000001),"A fresh session restores the PB, matching splits and ghost")
	check(loaded.history.size()==1 and loaded.history[0].date>0 and loaded.history[0].peak_kmh>0,"Visible history retains timestamp, time, splits and peak speed")
	_drive(session,sim,1.0)
	check(session.personal_best<first_best and session.new_best and session.previous_best==first_best,"A faster line beats the prior personal best")
	check(_reference(session).duration==first_replay.duration and _best(session).duration!=first_replay.duration,"Beating a PB retains the old ghost until the next restart")
	check(session.split_delta(2)<0 and "−" in session.result_text(sim.peak_speed*3.6),"Split and finish differences compare against the PB at run start")
	var winning_replay = _best(session)
	var winning_time: float = session.personal_best
	_drive(session,sim,0.0)
	check(not session.new_best and _best(session).duration==winning_replay.duration and session.personal_best==winning_time,"A slower finish enters history and archive while preserving the PB")
	var count: int = session.history.size()
	_drive(session,sim,1.0,false)
	check(session.history.size()==count and _best(session).duration==winning_replay.duration,"Unranked completion changes neither PB, ghost nor history")
	session.reset()
	check(_reference(session).duration==winning_replay.duration and session.elapsed==0 and session.split_times==[-1.0,-1.0,-1.0],"Instant restart resets the clock/splits and selects the latest PB ghost")
	_replay_checks(winning_replay,session)
	_incompatible_storage_checks()
	_history_and_benchmark_checks()
	_failure_checks(session)
	await _runtime_checks(winning_time)
	check(_benchmark_files()==benchmark_snapshot,"Competitive checks leave both legacy and current user benchmark files untouched")
	game.active = false
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	_cleanup(test_dir)
	var output = {"checks":checks,"failures":failures,"metrics":metrics,"captures":captures}
	preload("res://tests/test_report.gd").write("res://artifacts/competitive_results%s.json" % ("_rendered" if DisplayServer.get_name()!="headless" else ""),JSON.stringify(output,"\t"))
	print("COMPETITIVE_RESULTS ",JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)

func _drive(session, sim, tuck: float, ranked: bool = true) -> void:
	sim.reset(race.start,race.heading)
	sim.surface_normal = field.contact_normal(sim.position.x,sim.position.z)
	sim.prime_contacts(field)
	var visual = preload("res://scripts/presentation/skier_visual.gd").new()
	visual.preview_only = true
	root.add_child(visual)
	visual.reset_animation(sim)
	session.reset()
	session.eligible = ranked
	session.begin_capture(sim)
	visual.pose(sim,1.0)
	session.capture_presentation(preload("res://scripts/presentation/ghost_pose.gd").capture(visual,sim,field))
	var intent = RiderInput.new()
	intent.tuck = tuck
	var begin = Time.get_ticks_usec()
	for i in range(7200):
		var before: Vector3 = sim.position
		sim.step(DT,intent,field)
		visual.step_animation(DT,sim,intent,field)
		if sim.crashed: break
		var finished: bool = session.step(DT,before,sim.position,sim,intent)
		if session.recording and session.recording.wants_presentation_sample():
			visual.pose(sim,(session.elapsed-session.previous_elapsed)/DT if finished else 1.0)
			session.capture_presentation(preload("res://scripts/presentation/ghost_pose.gd").capture(visual,sim,field))
		if finished: break
	visual.free()
	metrics.recorded_run_cpu_ms = float(Time.get_ticks_usec()-begin)/1000.0
	check(session.finished and not sim.crashed,"Complete physical route at tuck %.1f, ranked=%s" % [tuck,ranked])

func _split_checks() -> void:
	var direct = Session.new()
	direct.record_directory = test_dir
	direct.configure(race)
	direct.eligible = false
	direct.step(1.0,race.start,race.finish)
	var wide = Session.new()
	wide.record_directory = test_dir
	wide.configure(race)
	wide.eligible = false
	wide.step(1.0,race.start+Vector3.RIGHT*200,race.finish)
	check(direct.split_times==wide.split_times and wide.finished,"Unlimited split planes allow a different lateral route and never gate finishing")
	check(absf(direct.split_times[0]-.25)<0.000001,"Split time interpolates within a tick")
	direct.reset()
	direct.eligible = false
	var middle: Vector3 = race.start.lerp(race.finish,0.6)
	direct.step(1,race.start,middle)
	var initial: Array = direct.split_times.duplicate()
	direct.step(1,middle,race.start)
	direct.step(1,race.start,middle)
	check(initial==direct.split_times,"Backtracking and recrossing cannot replace first-passage split times")
	# Reverse azimuth demonstrates splits do not assume world +Z downhill.
	var reverse = fixture()
	reverse.start = race.finish
	reverse.finish = race.start
	direct.configure(reverse)
	direct.eligible = false
	direct.step(1,reverse.start,reverse.finish)
	check(direct.finished and direct.split_times.all(func(t): return t>0),"Splits follow a race's start-to-finish axis in either direction")

func _best(session):
	var selected = Records.selected(session.record_path(),Replay.key(session.course_id),session.ghost_runs,Records.default_selection())
	return selected.runs[0].replay if not selected.runs.is_empty() else null

func _reference(session):
	return session.reference_ghosts[0].replay if not session.reference_ghosts.is_empty() else null

func _replay_checks(replay, session) -> void:
	var decoded = Replay.decode(JSON.parse_string(JSON.stringify(replay.to_data())),Replay.key(session.course_id),replay.duration)
	check(decoded!=null and decoded.has_presentation(),"Complete production replay survives binary/JSON round trip")
	check(decoded.pose_at(5.123).position.distance_to(replay.pose_at(5.123).position)<.00001,"Playback interpolates independently of render cadence")
	var input = RiderInput.new(); input.jump_held = true
	var sim = Simulation.new(); sim.reset(race.start); sim.prime_contacts(field)
	var held = Replay.new(); held.begin(sim,Replay.key(session.course_id)); held.record(DT,DT,sim,input)
	check(held.input_at(0).jump_held,"Recorded held jump preserves pole-force cancellation")
	var limited = Replay.new(); limited.begin(sim,Replay.key(session.course_id)); limited.record(DT,601,sim,input)
	check(limited.overflow and limited.samples.is_empty() and limited.inputs.is_empty(),"Ten-minute overflow frees recorder without changing race time")

func _incompatible_storage_checks() -> void:
	var path = test_dir.path_join("incompatible.json")
	preload("res://tests/test_report.gd").write(path,JSON.stringify({"version":1,"best":18.0}))
	check(Records.load_record(path,Replay.key("other")).runs.is_empty(),"Superseded storage is not migrated into invented ghosts")

func _history_and_benchmark_checks() -> void:
	var recent = Session.new()
	recent.record_directory = test_dir.path_join("history_cap")
	recent.configure(race)
	for i in range(25):
		recent.reset()
		recent.step(float(i+1),race.finish+Vector3.LEFT*20,race.finish+Vector3.RIGHT*20)
	var loaded = Session.new()
	loaded.record_directory = recent.record_directory
	loaded.configure(race)
	check(loaded.history.size()==20 and absf(loaded.history[0].time-12.5)<0.000001 and absf(loaded.history[-1].time-3.0)<0.000001,"History keeps the newest 20 completions across reloads")
	var benchmark = Session.new()
	benchmark.benchmark_path = test_dir.path_join("original_benchmark.json")
	benchmark.configure()
	_drive(benchmark,Simulation.new(preload("res://config/ski_default.tres").duplicate(true)),1.0)
	var fresh = Session.new()
	fresh.benchmark_path = benchmark.benchmark_path
	fresh.configure()
	check(benchmark.finished and benchmark.personal_best>0 and absf(fresh.personal_best-benchmark.elapsed)<.000001 and _best(fresh)!=null and fresh.best_splits.all(func(t): return t>0),"Current benchmark restores its measured reference time, ghost and splits")

func _failure_checks(session) -> void:
	var path = Records.path_for(session.record_path())
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	data.runs[0].sha256 = "0".repeat(64)
	preload("res://tests/test_report.gd").write(path,JSON.stringify(data,"",true,true))
	var restored = Records.load_record(session.record_path(),Replay.key(session.course_id))
	check(restored.best==session.personal_best and not restored.warning.is_empty(),"Missing payload retains valid best time with explanation")
	session.save_record()
	preload("res://tests/test_report.gd").write(test_dir.path_join("not_a_folder"),"fixture")
	var error = Records.save(test_dir.path_join("not_a_folder/record.json"),Replay.key(session.course_id),session.personal_best,session.best_splits,session.history,session.ghost_runs,session.ghost_selection)
	check(not error.is_empty(),"Visible persistence failure never claims success")

func _runtime_checks(winning_time: float) -> void:
	root.size = Vector2i(1440,900)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_physics_process(false)
	game.preferences_enabled = false
	game.hud.feedback.persist = false
	game.voice.persist = false; game.effects.wind.persist = false; game.effects.sfx.persist = false
	game.effects.haptic_hardware_enabled = false
	game.automated = false
	game.effects.muted = true
	game.set_graphics_quality(0)
	game.session.record_directory = test_dir.path_join("records")
	game.session.benchmark_path = test_dir.path_join("benchmark.json")
	await process_frame
	await _capture("title")
	check(root.get_visible_rect().encloses(game.hud.menu.get_global_rect()),"Title menu with race/history actions fits the viewport")
	game.play_custom_race(race)
	check(absf(game.session.personal_best-winning_time)<0.000000001 and _reference(game.session)!=null and game.session.recording!=null,"Selecting a saved race starts capture and restores its PB ghost")
	for i in range(20): game._physics_process(DT)
	var ticks: int = game.session.recording.ticks
	key(KEY_F6)
	var elapsed: float = game.session.elapsed
	for i in range(4): game._physics_process(DT)
	game._process(0.2)
	check(not game.active and game.hud.competition.panel.visible and game.session.elapsed==elapsed and game.session.recording.ticks==ticks,"Run history pauses the clock, recording and ghost timeline")
	check("BEST" in game.hud.competition.history.text and "CUMULATIVE" not in game.hud.competition.history.text,"History lists timed runs and identifies the current personal best")
	await _capture("history")
	check(root.get_visible_rect().encloses(game.hud.competition.panel.get_global_rect()),"History and split panel stays inside the viewport")
	key(KEY_ESCAPE)
	check(game.hud.menu.visible and game.hud.menu_mode=="paused" and not game.active,"Closing history returns to pause without advancing the run")
	key(KEY_ESCAPE)
	check(game.active and game.session.previous_elapsed==game.session.elapsed,"Resume aligns player and ghost interpolation clocks")
	key(KEY_F2)
	key(KEY_F6)
	key(KEY_ESCAPE)
	check(not game.active and game.hud.menu_mode=="paused" and game.session.race==race,"Opening history from the workbench retains the paused custom race")
	key(KEY_ESCAPE)
	key(KEY_F2)
	key(KEY_F4)
	game.workshop.back_pressed()
	check(not game.active and game.hud.menu_mode=="paused" and game.session.race==race,"Opening the race library from the workbench retains the paused custom race")
	key(KEY_ESCAPE)
	var new_recording = game.session.recording
	key(KEY_R)
	check(game.session.elapsed==0 and game.session.recording!=new_recording and game.session.recording.ticks==0,"One-key restart clears the in-progress recording as well as rider state")
	key(KEY_G)
	game._process(0.016)
	check(not game.ghost.enabled and not game.ghost.visible,"Ghost can be switched off independently")
	key(KEY_G)
	var reference = _reference(game.session)
	var pose: Dictionary = reference.pose_at(10.0)
	game.sim.position = pose.position+Vector3(4,0,-4)
	game.sim.position.y = field.sample(game.sim.position.x,game.sim.position.z).height
	game.sim.surface_normal = field.contact_normal(game.sim.position.x,game.sim.position.z)
	game.sim.velocity = Vector3.BACK*20
	game.previous_position = game.sim.position
	game.session.elapsed = 10.0
	game.session.previous_elapsed = 10.0
	var snapshot = [game.sim.position,game.sim.velocity,game.sim.heading,game.sim.balance,game.session.elapsed]
	for i in range(20): game._process(0.016)
	check(game.ghost.ghosts[0].visual.visible and snapshot==[game.sim.position,game.sim.velocity,game.sim.heading,game.sim.balance,game.session.elapsed],"Visible ghost playback cannot alter rider physics or race time")
	await _capture("ghost_chase")
	game.camera.close_view = true
	game.camera.reset()
	for i in range(10): game._process(0.016)
	await _capture("ghost_first_person")
	game.ghost.ghosts[0].update_ghost(10.0,pose.position,true)
	check(game.ghost.ghosts[0].visual.visible and game.ghost.ghosts[0].opacity>=.15,"Exact overlap remains visible at the 15 percent opacity floor")
	game.ghost.ghosts[0].update_ghost(reference.duration+1.0,Vector3.ZERO,true)
	check(not game.ghost.ghosts[0].visual.visible,"Ghost stops independently at its recorded finish")
	game.camera.close_view = false
	game.start_speed_lab(120)
	for i in range(3): game._physics_process(DT)
	check(not game.session.eligible and game.session.recording==null,"Speed lab discards its recording and cannot replace the PB")
	game.physics_modified = true
	game.restart()
	check(game.session.recording==null and not game.session.eligible,"Modified physics does not begin a ranked recording")
	game.physics_modified = false
	game.restart()
	game.sim.crash("TEST CRASH")
	game._physics_process(DT)
	check(not game.active and not game.session.finished and _best(game.session).duration==reference.duration,"Crash cannot promote a partial ghost to personal best")
	var practice = Session.new()
	practice.record_directory = test_dir.path_join("celebration")
	practice.configure(race)
	_drive(practice,Simulation.new(preload("res://config/ski_default.tres").duplicate(true)),0.0)
	game.session.record_directory = practice.record_directory
	game.play_custom_race(race)
	game.automated = true
	for i in range(6000):
		# Exercise the same session recorder path without invoking autoplay's quit hook.
		var input = RiderInput.new()
		input.tuck = 1.0
		game.previous_position = game.sim.position
		game.sim.step(DT,input,field)
		game.skier.step_animation(DT,game.sim,input,field)
		var complete: bool = game.session.step(DT,game.previous_position,game.sim.position,game.sim,input)
		game._capture_ghost_pose((game.session.elapsed-game.session.previous_elapsed)/DT if complete else 1.0)
		if complete: break
	game.automated = false
	game.active = false
	game.hud.toast_time = 0
	game.hud.show_result(game.session,game.sim.peak_speed*3.6)
	check(game.session.new_best and game.hud.menu_title.text=="PERSONAL\nBEST.","A faster completed run celebrates the new PB with the previous-best delta")
	game._process(0.016)
	await _capture("finish")
	game.open_competition()
	await _capture("finish_splits")
	check("BEHIND" in game.hud.split_label.text or "AHEAD" in game.hud.split_label.text or "LEVEL" in game.hud.split_label.text,"Completed race exposes its split comparison in the HUD")

func key(code: Key) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_input(event)

func _capture(label: String) -> void:
	# Container layout is deferred in headless runs too. Keep the layout wait
	# before assertions, even when there is no framebuffer to capture.
	for i in range(5): await process_frame
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/competitive_%s.png" % label)
	captures.append(label)

func _benchmark_files() -> Array:
	var result: Array = []
	for path in ["user://benchmark_v1.json",Records.path_for("user://benchmark_v1.json")]:
		result.append(FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing")
	return result

func _cleanup(path: String) -> void:
	for child in DirAccess.get_directories_at(path): _cleanup(path.path_join(child))
	for name in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
