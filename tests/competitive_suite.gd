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
	var first_replay = session.best_replay
	check(session.finished and session.new_best and session.best_replay!=null,"First ranked finish creates a PB and recorded ghost")
	check(session.save_error.is_empty() and FileAccess.file_exists(Records.path_for(session.record_path())),"PB, splits, history and ghost save together")
	check(session.split_times.all(func(t): return t>0) and session.split_times[0]<session.split_times[1] and session.split_times[1]<session.split_times[2],"Real ski run produces three ordered cumulative approach splits")
	check(absf(first_replay.duration-session.elapsed)<0.000001 and first_replay.inputs.size()==first_replay.ticks*Replay.INPUT_WIDTH,"Replay retains exact finish time and every 120 Hz tick input")
	check(first_replay.samples.size()<first_replay.ticks/3+3,"Snapshot storage is bounded to 30 Hz plus the exact finish")
	var last_position: Vector3 = first_replay.pose_at(first_replay.duration).position
	check(absf((Basis(Vector3.UP,race.finish_heading).transposed()*(last_position-race.finish)).z)<0.01,"Final ghost sample ends on the sub-tick gate-plane intersection")
	var loaded = Session.new()
	loaded.record_directory = session.record_directory
	loaded.configure(race)
	check(absf(loaded.personal_best-first_best)<0.000000001 and loaded.best_replay!=null and range(3).all(func(i): return absf(loaded.best_splits[i]-session.best_splits[i])<0.000000001),"A fresh session restores the PB, matching splits and ghost")
	check(loaded.history.size()==1 and loaded.history[0].date>0 and loaded.history[0].peak_kmh>0,"Visible history retains timestamp, time, splits and peak speed")
	_drive(session,sim,1.0)
	check(session.personal_best<first_best and session.new_best and session.previous_best==first_best,"A faster line beats the prior personal best")
	check(session.reference_replay==first_replay and session.best_replay!=first_replay,"Beating a PB retains the old ghost until the next restart")
	check(session.split_delta(2)<0 and "−" in session.result_text(sim.peak_speed*3.6),"Split and finish differences compare against the PB at run start")
	var winning_replay = session.best_replay
	var winning_time: float = session.personal_best
	_drive(session,sim,0.0)
	check(not session.new_best and session.best_replay==winning_replay and session.personal_best==winning_time,"A slower finish enters history without replacing the best ghost")
	var count: int = session.history.size()
	_drive(session,sim,1.0,false)
	check(session.history.size()==count and session.best_replay==winning_replay,"Unranked completion changes neither PB, ghost nor history")
	session.reset()
	check(session.reference_replay==winning_replay and session.elapsed==0 and session.split_times==[-1.0,-1.0,-1.0],"Instant restart resets the clock/splits and selects the latest PB ghost")
	_replay_checks(winning_replay,session)
	_migration_checks()
	_history_and_benchmark_checks()
	_failure_checks(session)
	await _runtime_checks(winning_time)
	if DisplayServer.get_name()!="headless" and ("--profile-competition" in OS.get_cmdline_user_args() or "--profile-full-competition" in OS.get_cmdline_user_args()):
		if "--profile-full-competition" in OS.get_cmdline_user_args():
			game.session.benchmark_path = test_dir.path_join("original_benchmark.json")
			game.start_run(true)
			game.weather.set_preset("snowfall")
			game.weather.set_quality(2)
		metrics.profiles = []
		for ghost_enabled in [false,true]:
			metrics.profiles.append(await _profile(ghost_enabled))
	if metrics.has("profiles"):
		FileAccess.open("res://artifacts/competitive_profile.json",FileAccess.WRITE).store_string(JSON.stringify(metrics.profiles,"\t"))
	check(_benchmark_files()==benchmark_snapshot,"Competitive checks leave both legacy and current user benchmark files untouched")
	game.active = false
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	_cleanup(test_dir)
	var output = {"checks":checks,"failures":failures,"metrics":metrics,"captures":captures}
	FileAccess.open("res://artifacts/competitive_results%s.json" % ("_rendered" if DisplayServer.get_name()!="headless" else ""),FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("COMPETITIVE_RESULTS ",JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)

func _drive(session, sim, tuck: float, ranked: bool = true) -> void:
	sim.reset(race.start,race.heading)
	sim.surface_normal = field.contact_normal(sim.position.x,sim.position.z)
	session.reset()
	session.eligible = ranked
	session.begin_capture(sim)
	var intent = RiderInput.new()
	intent.tuck = tuck
	var begin = Time.get_ticks_usec()
	for i in range(7200):
		var before: Vector3 = sim.position
		sim.step(DT,intent,field)
		if sim.crashed: break
		if session.step(DT,before,sim.position,sim,intent): break
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

func _replay_checks(replay, session) -> void:
	var data: Dictionary = replay.to_data()
	var decoded = Replay.decode(data,Replay.key(session.course_id),session.personal_best)
	check(decoded!=null and decoded.pose_at(5.123).position.distance_to(replay.pose_at(5.123).position)<0.00001,"Saved snapshot playback round-trips at arbitrary times")
	check(Replay.decode(JSON.parse_string(JSON.stringify(data,"",true,true)),Replay.key(session.course_id),session.personal_best)!=null,"Replay metadata survives JSON numeric type conversion")
	var sample = replay.samples[10]
	var next = replay.samples[11]
	var t: float = (sample[0]+next[0])*0.5
	var expected = Vector3(sample[1],sample[2],sample[3]).lerp(Vector3(next[1],next[2],next[3]),0.5)
	check(replay.pose_at(t).position.distance_to(expected)<0.00001,"Playback interpolates between samples independently of render rate")
	var wrapped = Replay.new()
	wrapped.samples = [[0,0,0,0,deg_to_rad(179),0,0,0,1,0,1],[1,1,0,0,deg_to_rad(-179),0,1,0,1,0,1]]
	for frame in wrapped.samples: frame.append_array(replay.samples[0].slice(11))
	check(absf(absf(wrapped.pose_at(0.5).heading)-PI)<0.001,"Ghost heading interpolation takes the short arc across ±pi")
	for variant in ["version","physics","course","engine","tuning","order","finite","input","duration"]:
		var bad: Dictionary = data.duplicate(true)
		match variant:
			"version": bad.version = 99
			"physics": bad.compatibility.physics = 19
			"course": bad.compatibility.course = "other-race"
			"engine": bad.compatibility.engine = "other-engine"
			"tuning": bad.compatibility.tuning = "different-tuning"
			"order": bad.samples[1][0] = 0.0
			"finite": bad.samples[1][1] = NAN
			"input": bad.inputs_f32 = "AAAA"
			"duration": bad.duration = 999999
		check(Replay.decode(bad,Replay.key(session.course_id),session.personal_best)==null,"Reject incompatible or malformed ghost: "+variant)
	var simulator = Simulation.new()
	simulator.reset(race.start)
	var limited = Replay.new()
	limited.begin(simulator,Replay.key(session.course_id))
	limited.record(DT,601,simulator,RiderInput.new())
	check(limited.overflow and limited.samples.is_empty() and limited.inputs.is_empty(),"Ten-minute cap releases the recording buffer without ending the race")
	var query_start = Time.get_ticks_usec()
	for i in range(10000): replay.pose_at(float(i%1900)*0.01)
	metrics.ghost_query_mean_us = float(Time.get_ticks_usec()-query_start)/10000.0

func _migration_checks() -> void:
	var legacy = Session.new()
	legacy.record_directory = test_dir.path_join("legacy")
	legacy.configure(race)
	DirAccess.make_dir_recursive_absolute(legacy.record_directory)
	var old = {"version":1,"course":legacy.course_id,"best":18.0,"history":[19.0,18.0,"bad",-4]}
	FileAccess.open(legacy.record_path(),FileAccess.WRITE).store_string(JSON.stringify(old))
	legacy.configure(race)
	check(legacy.personal_best==18.0 and legacy.history.size()==2 and legacy.best_replay==null,"Legacy PB and valid history migrate without inventing a ghost or splits")
	legacy.save_record()
	legacy.configure(race)
	check(legacy.personal_best==18.0 and legacy.history.size()==2 and legacy.history[0].date==0,"Migrated records persist with unknown dates explicitly preserved")
	var changed = fixture()
	changed.title = "A different race"
	legacy.configure(changed)
	check(legacy.personal_best<0 and legacy.best_replay==null and legacy.reference_splits==[-1.0,-1.0,-1.0],"Changing race clears the previous race's best, splits and ghost")

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
	check(benchmark.finished and benchmark.personal_best>0 and absf(fresh.personal_best-benchmark.elapsed)<.000001 and fresh.best_replay!=null and fresh.best_splits.all(func(t): return t>0),"Current benchmark restores its measured reference time, ghost and splits")

func _failure_checks(session) -> void:
	var path = Records.path_for(session.record_path())
	var existing = FileAccess.open_compressed(path,FileAccess.READ)
	var data = JSON.parse_string(existing.get_as_text())
	existing.close()
	data.replay.compatibility.physics = -1
	var damaged = FileAccess.open_compressed(path,FileAccess.WRITE)
	damaged.store_string(JSON.stringify(data,"",true,true))
	damaged.close()
	var restored = Session.new()
	restored.record_directory = session.record_directory
	restored.configure(race)
	check(absf(restored.personal_best-session.personal_best)<0.000000001 and restored.best_replay==null and not restored.record_warning.is_empty(),"Incompatible ghost is rejected while keeping its valid PB time")
	session.save_record()
	FileAccess.open(test_dir.path_join("not_a_folder"),FileAccess.WRITE).store_string("fixture")
	var failure = Records.save(test_dir.path_join("not_a_folder/record.json"),Replay.key(session.course_id),session.personal_best,session.best_splits,session.history,session.best_replay)
	check(not failure.is_empty(),"Persistence failure is reported instead of claiming a successful save")

func _runtime_checks(winning_time: float) -> void:
	root.size = Vector2i(1440,900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.effects.muted = true
	game.set_graphics_quality(0)
	game.session.record_directory = test_dir.path_join("records")
	game.session.benchmark_path = test_dir.path_join("benchmark.json")
	await process_frame
	await _capture("title")
	check(root.get_visible_rect().encloses(game.hud.menu.get_global_rect()),"Title menu with race/history actions fits the viewport")
	game.play_custom_race(race)
	check(absf(game.session.personal_best-winning_time)<0.000000001 and game.session.reference_replay!=null and game.session.recording!=null,"Selecting a saved race starts capture and restores its PB ghost")
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
	var reference = game.session.reference_replay
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
	check(game.ghost.visible and snapshot==[game.sim.position,game.sim.velocity,game.sim.heading,game.sim.balance,game.session.elapsed],"Visible ghost playback cannot alter rider physics or race time")
	await _capture("ghost_chase")
	game.camera.close_view = true
	game.camera.reset()
	for i in range(10): game._process(0.016)
	await _capture("ghost_first_person")
	game.ghost.update_ghost(reference,10.0,pose.position,true)
	check(not game.ghost.visible,"Overlapping ghost fades out to keep the player's view clear")
	game.ghost.update_ghost(reference,reference.duration+1.0,Vector3.ZERO,true)
	check(not game.ghost.visible,"Ghost disappears after its recorded finish")
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
	check(not game.active and not game.session.finished and game.session.best_replay==reference,"Crash cannot promote a partial ghost to personal best")
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
		if game.session.step(DT,game.previous_position,game.sim.position,game.sim,input): break
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

func _profile(ghost_enabled: bool) -> Dictionary:
	game.hud.close_competition()
	game.automated = true
	game.set_ghost_visible(ghost_enabled)
	game.restart()
	# Keep timing unranked; a discarded probe measures the same recording work.
	game.session.eligible = false
	var recording_probe = Replay.new()
	recording_probe.begin(game.sim,Replay.key(game.session.course_id))
	var times: Array[float] = []
	var draws: Array[float] = []
	var frames = 0
	var accumulator = 0.0
	var last = Time.get_ticks_usec()
	var input = RiderInput.new()
	input.tuck = 0.9 if game.session.race==null else 0.4
	while not game.session.finished and not game.sim.crashed and game.session.elapsed<90:
		await process_frame
		var now = Time.get_ticks_usec()
		var dt = float(now-last)/1000000.0
		last = now
		accumulator += minf(dt,0.2)
		while accumulator>=DT and not game.session.finished:
			game.previous_position = game.sim.position
			game.intent = input
			game.sim.step(DT,input,field)
			game.session.step(DT,game.previous_position,game.sim.position,game.sim,input)
			var finish_fraction: float = (game.session.elapsed-game.session.previous_elapsed)/DT if game.session.finished else -1.0
			recording_probe.record(DT,game.session.elapsed,game.sim,input,finish_fraction)
			accumulator -= DT
		frames += 1
		if frames>120 and not game.session.finished:
			times.append(dt*1000.0)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	game.active = false
	game.automated = false
	check(game.session.finished and not game.sim.crashed,"Native Low profile finishes with ghost %s" % ghost_enabled)
	times.sort()
	var mean = 0.0
	for ms in times: mean += ms
	mean /= maxf(1,times.size())
	var draw_mean = 0.0
	for count in draws: draw_mean += count
	draw_mean /= maxf(1,draws.size())
	var worst_count = maxi(1,ceili(times.size()*0.01))
	var worst_total = 0.0
	for ms in times.slice(times.size()-worst_count): worst_total += ms
	var report = {"ghost":ghost_enabled,"frames":times.size(),"mean_ms":mean,"average_fps":1000.0/mean,"p95_ms":times[int(times.size()*0.95)],"p99_ms":times[int(times.size()*0.99)],"slowest_one_percent_fps":1000.0/(worst_total/worst_count),"mean_draw_calls":draw_mean,"run_time":game.session.elapsed,"warmup_frames":120,"pixels":str(root.get_texture().get_image().get_size()),"device":RenderingServer.get_video_adapter_name(),"quality":"Low","recording_probe":true,"eligible":game.session.eligible,"course":game.session.course_id,"weather":game.weather.selected_preset,"weather_quality":game.weather.quality,"backend":RenderingServer.get_current_rendering_driver_name()}
	print("COMPETITIVE_PROFILE ",JSON.stringify(report))
	return report

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
