extends SceneTree
## Headless lifecycle checks and native chronological review from one isolated
## laboratory setup. At most 19 s of riding per attempt; no personal writes.
const DT = 1.0/120.0
const Session = preload("res://scripts/core/run_session.gd")
const Race = preload("res://scripts/racing/race_definition.gd")
const Records = preload("res://scripts/racing/competitive_record.gd")
const Replay = preload("res://scripts/racing/run_replay.gd")
const Ghost = preload("res://scripts/presentation/personal_best_ghost.gd")
const Flavor = preload("res://scripts/world/flavor_layout.gd")
const FocusFixture = preload("res://tests/crash_recovery_focus_fixture.gd")
const RenderSubmission = preload("res://tests/crash_render_submission.gd")
var checks = 0
var failures: Array[String] = []
var chronology: Array = []
var game
var output: String
var sequence = 0
var trace: Array = []
var fixture: Dictionary = {}
var focus_fixture: Dictionary = {}
var rendered_ragdoll_bones: Array[Transform3D] = []
var rendered_ragdoll_frame = -1
var rendered_ragdoll_updates = 0
var equipment_submissions: Array = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func run() -> void:
	set_meta("test_lab_fixture",true)
	output = "res://artifacts/orchestration_20260912/crash/lifecycle-%s-%d-%d" % ["headless" if DisplayServer.get_name()=="headless" else "native",OS.get_process_id(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(960,540) if "--small" in OS.get_cmdline_user_args() else Vector2i(1440,900)
	game = load("res://main.tscn").instantiate()
	focus_fixture = FocusFixture.install(game)
	check(not focus_fixture.has("error"),"Native focus seam compiles from the actual live Main script")
	if focus_fixture.has("error"):
		FileAccess.open(output.path_join("focus-setup-error.json"),FileAccess.WRITE).store_string(JSON.stringify(focus_fixture))
		game.free(); quit(1); return
	FileAccess.open(output.path_join("controlled-main.gd"),FileAccess.WRITE).store_string(game.get_script().source_code)
	game.automated = true
	root.add_child(game)
	current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_physics_process(false); game.set_process(false)
	game.effects.haptic_hardware_enabled = false
	game.preferences_enabled = false
	game.voice.persist = false; game.effects.wind.persist = false; game.effects.sfx.persist = false
	game.session.record_directory = output.path_join("records")
	game.session.benchmark_path = output.path_join("benchmark.json")
	game.automated = false
	game.crash_fixture_apply_focus(true,"fixture-initial-focus")
	game.skier.skeleton.skeleton_updated.connect(_observe_ragdoll_skin)
	_trace("focus-fixture-installed",focus_fixture)
	_probe_external_focus("fixture-start",true)
	game.effects.muted = true # listening is an explicit separate review
	var submission_error: String = _install_submission_observers()
	check(submission_error.is_empty(),"Actual ski, boot, binding and pole meshes expose read-only renderer submission receipts")
	if not submission_error.is_empty():
		_trace("render-observer-setup-error",{"error":submission_error})
		game.effects.stop_audio(); game.queue_free(); quit(1); return
	# Keep only the solver/session on manual ticks. Actual Main presentation must
	# run in the engine's normal process phase, before transform notifications
	# are flushed to the renderer and before the final skeleton is drawn.
	game.set_process(true)
	await _free_ski_choices()
	await _timed_attempt()
	check(load("res://scripts/main.gd").source_code.sha256_text()==focus_fixture.source_sha256,"Focus fixture leaves the cached production Main script unchanged")
	var report = {"focus_fixture":focus_fixture,"focus_events":game.crash_fixture_focus_events,"checks":checks,"failures":failures,"chronology":chronology,"trace":trace,"fixture":fixture,"rendered":DisplayServer.get_name()!="headless","human_controller":"pending","listening":"not exercised; muted fixture"}
	FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t",true,true))
	game.active = false; game.effects.stop_audio(); game.queue_free()
	await process_frame
	print("CRASH_RECOVERY_LIFECYCLE_RESULTS ",JSON.stringify(report,"",true,true))
	quit(0 if failures.is_empty() else 1)

func _ticks(count: int) -> void:
	for i in count: game._physics_process(DT)

func _crash(reason: String = "RECOVERY LIFECYCLE FIXTURE") -> void:
	game.sim.crash(reason)
	game._physics_process(DT)
	_trace("crash",{"requested_reason":reason})
	check(game.session.recovering and not game.active and game.hud.menu_mode=="crashed","Crash owns inactive clock/menu")

func _free_ski_choices() -> void:
	game.start_run(false)
	_ticks(30)
	_crash()
	await _capture("free-crash")
	check(game.hud.primary.text=="Stand Up" and game.hud.crash_restart.text=="Try again","Both free-ski choices are explicit")
	await _keyboard_confirm(game.hud.primary)
	check(game.active and not game.sim.crashed and game.session.recovery_count==1,"Keyboard confirms free-ski local recovery")
	_ticks(30)
	_crash()
	var mouse_attempt: int = game.session.attempt_id
	await _mouse_confirm(game.hud.crash_restart)
	_trace("mouse-restart-result",{"original_start":_v3(game.field.spawn_point()),"previous_attempt":mouse_attempt})
	check(game.active and not game.sim.crashed and game.session.attempt_id==mouse_attempt+1 and game.session.elapsed==0.0 and game.sim.position.distance_to(game.field.spawn_point())<.01,"Mouse Try Again returns to original start with fresh attempt")
	_ticks(30)
	_crash()
	var button = InputEventJoypadButton.new(); button.device=17; button.button_index=JOY_BUTTON_A; button.pressed=true
	game.navigation.route(button)
	button.pressed=false; game.navigation.route(button)
	await process_frame
	check(game.active and not game.sim.crashed,"Simulated controller confirms local recovery through menu navigation")
	_ticks(30)
	_crash()
	button.button_index = JOY_BUTTON_Y # Dedicated Try again bind; no focus selection on crash overlay.
	button.pressed=true; game.navigation.route(button)
	button.pressed=false; game.navigation.route(button)
	await process_frame
	check(game.active and game.session.elapsed==0,"Simulated controller retains full restart choice")
	var attempt: int = game.session.attempt_id
	game.respawn_here()
	check(game.session.attempt_id==attempt and not game.session.recovering,"Non-crash recovery action is ignored")
	# Exercise an actual solver impact against the production active-prop adapter.
	var start: Vector3 = game.sim.position
	var gate_id = 908612
	game.world.ski_surface.register_props(gate_id,[{"transform":Transform3D(Basis.IDENTITY,start+Vector3(0,.7,2)),"size":Vector3(1.0,2.0,.35),"reason":"RECOVERY TEST GATE"}])
	game.sim.velocity = Vector3.BACK.slide(game.sim.surface_normal).normalized()*80.0
	game.sim.impacts.reserve = .001
	for i in 12:
		game._physics_process(DT)
		if game.sim.crashed: break
	check(game.sim.crashed and "GATE" in game.sim.crash_reason,"Actual active-prop impact enters crash recovery")
	await _capture("actual-gate-impact")
	await _mouse_confirm(game.hud.primary)
	check(game.active and not game.sim.crashed,"Mouse confirms recovery around the active prop")
	game.world.ski_surface.unregister_props(gate_id)
	_crash()
	await _keyboard_confirm(game.hud.crash_restart)
	check(game.active and game.session.elapsed==0,"Keyboard confirms full restart")

func _timed_attempt() -> void:
	var race = Race.new()
	race.title="Bounded crash recovery"
	# Pin the actual loaded physical/scenery identity. This fixture must never
	# reload the world or silently continue Free Ski after a rejected course.
	race.mountain=Race.mountain_reference(game.field,game.world.mountain.seed_value)
	race.start=game.field.spawn_point()
	# The old z=105 gate failed the production gate-seat check. This fixed gate
	# stays on the gentle starting apron, 45 m downhill and inside the ordinary
	# neutral-input descent. Gate dimensions, validity and finish sweep are intact.
	race.finish=Vector3(-3,game.field.sample(-3,70).height,70)
	race.heading=0.0; race.finish_heading=0.0
	var original_finish = Vector3(0,game.field.sample(0,105).height,105)
	fixture = {"source":"fixed laboratory apron; ordinary neutral gameplay input",
		"original_start":_gate_diagnostics(race.start,0.0),
		"rejected_finish":_gate_diagnostics(original_finish,0.0),
		"proposed_finish":_gate_diagnostics(race.finish,0.0),
		"definition":race.to_data(),"identity":race.record_identity()}
	var decoded: Dictionary = Race.decode(race.share_text())
	var same_world: bool = game.workshop.matches_world(race)
	var surface_error: String = race.validate_surface(game.field)
	fixture["surface_error"] = surface_error
	fixture["same_world"] = same_world
	fixture["decode_error"] = decoded.get("error","")
	_trace("timed-preflight",fixture)
	check(same_world and decoded.has("race") and surface_error.is_empty(),"Short course passes portable identity, endpoint and full gate-seat validation")
	if not same_world or not decoded.has("race") or not surface_error.is_empty(): return
	var field_id: int = game.field.get_instance_id()
	await game.play_custom_race(race)
	_trace("timed-start",{"requested_identity":race.record_identity(),"requested_start":_v3(race.start),"requested_finish":_v3(race.finish)})
	var started: bool = game.session.race==race and game.timed and game.active and game.session.eligible and game.session.recording!=null
	check(started and game.session.course_id==race.record_identity() and game.session.elapsed==0.0,"Disposable timed fixture starts eligible with current recovery identity")
	check(game.field.get_instance_id()==field_id and game.sim.position.distance_to(race.start)<.01,"Timed fixture uses the loaded field and original stationary race start")
	if not started: return
	_ticks(180)
	game.camera.close_view = true
	var attempt: int = game.session.attempt_id
	var recorder = game.session.recording
	var before_time: float = game.session.elapsed
	var peak: float = game.sim.peak_speed
	_crash()
	var onset: Vector3 = game.crash_recovery.anchor.position
	check(absf(game.session.elapsed-before_time-DT)<.000000001,"Onset tick is consumed once")
	await _capture("timed-crash-onset")
	for frame in 4:
		_clock_ticks(60,60,"crash-menu-%d" % frame)
		await _capture("timed-crash-%d" % frame)
	check("CLOCK RUNNING" in game.hud.crash_clock.text and absf(game.session.elapsed-before_time-241*DT)<.00000001,"Crash menu visibly advances on exact fixed ticks")
	game.hud.open_settings()
	var time: float = game.session.elapsed
	_clock_ticks(120,120,"incidental-settings")
	check(absf(game.session.elapsed-time-1.0)<.00000001,"Incidental settings page cannot stop recovery clock")
	game.hud.close_weather(); game.hud.menu_tabs.current_tab=0
	game.toggle_crash_pause(); time=game.session.elapsed
	_clock_ticks(120,0,"explicit-pause")
	check(game.session.elapsed==time and game.skier.ragdoll.frozen,"Explicit pause freezes clock and ragdoll")
	game.respawn_here(); check(game.sim.crashed,"Recovery cannot advance while explicitly paused")
	await _capture("timed-paused")
	game.toggle_crash_pause()
	game.crash_fixture_apply_focus(false,"explicit-focus-out")
	await process_frame # Allow real OS notifications while controlled focus stays OUT.
	_probe_external_focus("explicit-focus-out",false)
	check(not game.application_focused and game.skier.ragdoll.frozen and not game.session.recovery_paused,"Explicit focus OUT routes through production and freezes the unpaused ragdoll")
	game.respawn_here()
	check(game.sim.crashed and game.session.recovering and not game.active,"Unfocused recovery remains rejected by actual production policy")
	_clock_ticks(60,0,"explicit-focus-out")
	check(game.session.elapsed==time,"Focus loss preserves existing crash pause policy")
	game.crash_fixture_apply_focus(true,"explicit-focus-in")
	await process_frame
	_probe_external_focus("explicit-focus-in",true)
	_clock_ticks(60,60,"explicit-focus-in")
	check(absf(game.session.elapsed-time-.5)<.00000001,"Focus return resumes unpaused crash clock")
	game.skier.ragdoll.elapsed=15.1; game.skier.ragdoll._physics_process(DT)
	time=game.session.elapsed; _clock_ticks(60,60,"ragdoll-settle-cap")
	check(game.skier.ragdoll.frozen and absf(game.session.elapsed-time-.5)<.00000001,"Ragdoll settle cap is independent of race clock")
	_trace("recovery-clock-budget",{"expected_inactive_ticks":480,"inactive_ticks":recorder.tick_kinds.count(1),
		"recorded_ticks":recorder.ticks,"input_values":recorder.inputs.size(),"input_width":Replay.INPUT_WIDTH})
	check(recorder.tick_kinds.count(1)==480 and recorder.ticks==661 and recorder.inputs.size()==661*Replay.INPUT_WIDTH and absf(game.session.elapsed-before_time-481*DT)<.00000001,"Recovery budget has exactly 480 inactive ticks and no pause/focus input rows")
	# Deliberately move the presentation body: placement must remain onset-owned.
	game.skier.ragdoll.bodies.Hips.global_position += Vector3(14,0,14)
	for action in ["jump","steer_right","grab","flip_forward"]: Input.action_press(action)
	var button = InputEventJoypadButton.new(); button.device=17; button.button_index=JOY_BUTTON_A; button.pressed=true
	game.navigation.route(button)
	button.pressed=false; game.navigation.route(button)
	await process_frame
	check(game.active and game.sim.position.distance_to(onset)<=8.3 and not game.skier.ragdoll.running,"Local recovery ignores traveled ragdoll and detaches equipment")
	check(game.sim.velocity==Vector3.ZERO and game.sim.air_control.angular_velocity==Vector3.ZERO and game.sim.impacts.reserve==1 and game.sim.contact_count==2,"Zero speed, full reserve and supported pose at actual lifecycle boundary")
	check(game.session.attempt_id==attempt and recorder!=null and game.session.recording==recorder and game.sim.peak_speed>=peak and game.session.eligible,"Attempt/recorder/totals/eligibility survive native recovery")
	check(game.camera.close_view and game.previous_position==game.sim.position and game.session.previous_elapsed==game.session.elapsed,"Selected view and interpolation origins restore without a race sweep")
	await _capture("respawn-zero-first-person")
	game.camera.close_view=false; game.camera.reset()
	await _capture("respawn-zero-chase")
	game.camera.close_view=true; game.camera.reset()
	var count: int = game.session.recovery_count
	game.respawn_here(); check(game.session.recovery_count==count,"Double activation is harmless")
	_ticks(12)
	check(game.intent.steer==0 and not game.intent.grab and game.intent.air_pitch==0 and not game.sim.jump_executed,"Held controls remain gated across confirm/recovery")
	for action in ["jump","steer_right","grab","flip_forward"]: Input.action_release(action)
	_ticks(2)
	check(not game.sim.jump_executed and game.sim.jump_buffer_remaining==0,"Releasing a pre-recovery jump cannot fire a delayed hop")
	for frame in 4:
		_ticks(30)
		await _capture("resumed-first-person-%d" % frame)
	game.camera.close_view=false; game.camera.reset()
	for frame in 4:
		_ticks(30)
		await _capture("resumed-chase-%d" % frame)
	var riding_ticks = 0
	var finish_sweep: Dictionary = {}
	while not game.session.finished and not game.sim.crashed and riding_ticks<1800:
		var before: Vector3 = game.sim.position
		var before_elapsed: float = game.session.elapsed
		game._physics_process(DT); riding_ticks += 1
		var after: Vector3 = game.sim.position
		var inverse = Basis(Vector3.UP,race.finish_heading).transposed()
		var a: Vector3 = inverse*(before-race.finish)
		var b: Vector3 = inverse*(after-race.finish)
		if a.z*b.z<=0.0 and absf(b.z-a.z)>.000001:
			var fraction: float = race.finish_fraction(before,after)
			finish_sweep = {"before":_v3(before),"after":_v3(after),"before_local":_v3(a),"after_local":_v3(b),
				"fraction":fraction,"expected_elapsed":before_elapsed+DT*fraction,"before_elapsed":before_elapsed}
			_trace("finish-plane-crossing",finish_sweep)
	_trace("timed-descent-result",{"riding_ticks":riding_ticks,"finish_sweep":finish_sweep})
	check(game.session.finished and game.session.new_best and game.session.eligible,"Recovered eligible run reaches real short-course finish and PB")
	check(not finish_sweep.is_empty() and finish_sweep.fraction>=0.0 and game.session.elapsed==finish_sweep.expected_elapsed,"Real finite gate sweep owns the exact fractional finish clock")
	check(game.session.save_error.is_empty() and FileAccess.file_exists(Records.path_for(game.session.record_path())),"PB/archive saved in disposable store")
	var saved = Records.load_record(game.session.record_path(),Replay.key(game.session.course_id))
	var selected = Records.selected(game.session.record_path(),Replay.key(game.session.course_id),saved.runs,Records.default_selection())
	_trace("archive-reload",{"manifest":Records.path_for(game.session.record_path()),"saved_best":saved.best,
		"saved_splits":saved.splits,"saved_runs":saved.runs.size(),"selected_runs":selected.runs.size(),
		"load_warning":saved.warning,"unavailable_payloads":selected.unavailable,
		"session_time_f64":_f64(game.session.elapsed),"saved_time_f64":_f64(saved.best),
		"session_splits_f64":_f64_array(game.session.split_times),"saved_splits_f64":_f64_array(saved.splits)})
	if not selected.runs.is_empty():
		var loaded = selected.runs[0].replay
		check(loaded!=null and loaded.has_presentation() and saved.best==game.session.elapsed and saved.splits==game.session.split_times,"Atomic store reload matches PB, splits and recovery production-pose timeline")
		if loaded!=null:
			check(loaded.duration==game.session.elapsed and loaded.crash_intervals==recorder.crash_intervals and loaded.crash_intervals.size()==1 and loaded.tick_kinds.count(1)==480,"Recovered PB reload retains exact duration, crash interval and inactive ticks")
			check(not loaded.sample_times.is_empty() and not loaded.pose_times.is_empty() and loaded.sample_times[-1]==game.session.elapsed and loaded.pose_times[-1]==game.session.elapsed,"Recovered PB final sample and production pose retain exact fractional finish")
			_trace("recovered-replay",{"duration_f64":_f64(loaded.duration),"final_sample_f64":_f64(loaded.sample_times[-1]),"final_pose_f64":_f64(loaded.pose_times[-1]),"duration":loaded.duration,"intervals":loaded.crash_intervals,"inactive_ticks":loaded.tick_kinds.count(1),"samples":loaded.sample_times.size(),"poses":loaded.pose_times.size()})
			await _ghost_review(loaded)
	else:
		check(false,"Recovered PB has a replay for review")
	await _capture("timed-finished" if game.session.finished else "timed-unfinished")
	game.restart()
	check(game.session.elapsed==0 and game.session.recovery_count==0 and game.sim.peak_speed==0,"Try Again still clears whole attempt")
	game.session.mark_practice("recovery lifecycle automation")
	_crash(); game.respawn_here()
	check(not game.session.eligible and game.session.practice_reason=="recovery lifecycle automation","Lifecycle recovery never upgrades an ineligible run")

func _ghost_review(replay) -> void:
	# The replay inspection owns an explicit camera and timestamp. Pause Main's
	# automatic presentation only for this bounded observer, then restore it.
	var main_processing: bool = game.is_processing()
	game.set_process(false)
	var menu_visible: bool = game.hud.menu.visible
	game.hud.menu.hide() # Inspect the actual replay equipment without the result overlay.
	var ghost = Ghost.new()
	ghost.source_assets=game.skier.assets; ghost.player_history=game.effects.snow_tracks
	ghost.profile=game.graphics; ghost.field=game.field; ghost.replay=replay
	game.add_child(ghost)
	for interval in replay.crash_intervals:
		for time in [maxf(0,interval[0]-.04),interval[0],(interval[0]+interval[1])*.5,interval[1],interval[1]+.04]:
			ghost.update_ghost(time,Vector3(10000,0,0),true)
			check(ghost.visual.visible==(not replay.in_crash(time)),"Ghost visibility follows recorded crash boundary %.5f" % time)
			if ghost.visual.visible:
				game.camera.close_view=false
				game.camera.position=ghost.visual.global_position+Vector3(6,4,-7)
				game.camera.look_at(ghost.visual.global_position+Vector3.UP)
			await _capture("ghost-%.5f" % time,false)
	ghost.queue_free()
	await process_frame
	game.hud.menu.visible = menu_visible
	game.set_process(main_processing)

func _keyboard_confirm(control: Control) -> void:
	var code = KEY_R if control==game.hud.crash_restart else KEY_ENTER
	for pressed in [true,false]:
		var event = InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		root.push_input(event)
		await process_frame

func _mouse_confirm(control: Button) -> void:
	# Actual Main presentation runs on each native frame. Let its ordinary mouse
	# mode and deferred HFlow layout settle before the one-point click.
	var initial_rect: Rect2 = control.get_global_rect()
	for i in 3: await process_frame
	var point: Vector2 = control.get_global_transform_with_canvas()*(control.size*.5)
	var motion = InputEventMouseMotion.new(); motion.position=point
	root.push_input(motion,true)
	for i in 2: await process_frame
	point = control.get_global_transform_with_canvas()*(control.size*.5)
	motion = InputEventMouseMotion.new(); motion.position=point
	root.push_input(motion,true)
	await process_frame
	var signals = {"target":0,"restart":0,"respawn":0}
	var target_signal = func(): signals.target += 1
	var restart_signal = func(): signals.restart += 1
	var respawn_signal = func(): signals.respawn += 1
	control.pressed.connect(target_signal)
	game.hud.restart_requested.connect(restart_signal)
	game.hud.respawn_requested.connect(respawn_signal)
	_trace("mouse-before",{"target":str(control.get_path()),"initial_rect":str(initial_rect),"settled_rect":str(control.get_global_rect()),
		"point":[point.x,point.y],"hovered":control.is_hovered(),"mouse_mode":Input.mouse_mode})
	check(control.is_visible_in_tree() and not control.disabled and control.is_hovered() and root.get_visible_rect().has_point(point),"Mouse target is visible, enabled and hit-tested after menu layout")
	await _capture("mouse-before-"+control.text.to_lower().replace(" ","-"))
	for pressed in [true,false]:
		var event = InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT
		event.position=point; event.pressed=pressed; event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true)
		await process_frame
	_trace("mouse-after",{"target":str(control.get_path()),"signals":signals.duplicate(),"point":[point.x,point.y]})
	control.pressed.disconnect(target_signal)
	game.hud.restart_requested.disconnect(restart_signal)
	game.hud.respawn_requested.disconnect(respawn_signal)
	check(signals.target==1 and signals.restart==int(control==game.hud.crash_restart) and signals.respawn==int(control==game.hud.primary),"Mouse dispatches exactly the selected crash action once")

func _capture(label: String, update: bool = true) -> void:
	var before_elapsed: float = game.session.elapsed
	var before_render_frames: int = game.render_frames
	for i in 3: await process_frame
	var file = "%03d-%s.png" % [sequence,label]; sequence += 1
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_pre_draw
	# Read-only draw boundary: writing Node3D transforms here is AFTER the scene
	# flush. CPU gear/skin can match while the submitted meshes remain stale.
	var frame_state = _state()
	frame_state["frame"] = file
	frame_state["main_render_frames"] = game.render_frames-before_render_frames
	chronology.append(frame_state)
	check(game.is_processing()==update and game.session.elapsed==before_elapsed and (game.render_frames-before_render_frames>=2 if update else game.render_frames==before_render_frames),"Chronological capture uses the actual presentation phase without advancing the race: "+label)
	if DisplayServer.get_name()=="headless": return
	var equipment_sync: Dictionary = {}
	if game.skier.ragdoll.running:
		equipment_sync["physical_target_gap_m"] = _ragdoll_equipment_gap()
		equipment_sync["rendered_skin"] = _rendered_skin_gaps()
		equipment_sync["submitted_meshes"] = _submitted_skin_gaps()
		var submitted: Dictionary = equipment_sync.submitted_meshes
		check(submitted.available and submitted.fresh and submitted.max_node_gap_m<=.001 and submitted.max_skin_gap_m<=.001,"Rendered ski, boot, binding and pole submissions match final skin in the same frame: "+label)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(file))
	if not equipment_sync.is_empty(): _trace("capture-equipment-sync",{"frame":file,"gaps":equipment_sync})

static func _v3(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func _state() -> Dictionary:
	var race = game.session.race
	return {"elapsed":game.session.elapsed,"previous_elapsed":game.session.previous_elapsed,
		"controlled_application_focus":game.application_focused,"actual_window_focus":root.has_focus(),
		"focus_event_count":game.crash_fixture_focus_events.size(),"recovery_paused":game.session.recovery_paused,
		"ragdoll_frozen":game.skier.ragdoll.frozen,"process_frame":Engine.get_process_frames(),
		"position":_v3(game.sim.position),"heading":game.sim.heading,"speed_mps":game.sim.velocity.length(),
		"reserve":game.sim.impacts.reserve,"crashed":game.sim.crashed,"crash_reason":game.sim.crash_reason,
		"recovering":game.session.recovering,"recovery_count":game.session.recovery_count,
		"attempt":game.session.attempt_id,"first_person":game.camera.close_view,
		"active":game.active,"timed":game.timed,"finished":game.session.finished,"new_best":game.session.new_best,
		"eligible":game.session.eligible,"practice_reason":game.session.practice_reason,
		"recording":game.session.recording!=null,"record_path":game.session.record_path(),"save_error":game.session.save_error,
		"record_warning":game.session.record_warning,"replay_warning":game.session.replay_warning,
		"splits":game.session.split_times.duplicate(),"course_id":game.session.course_id,
		"race_identity":race.record_identity() if race!=null else "", "race":race.to_data() if race!=null else {},
		"field_id":game.field.get_instance_id(),"field_reference":Race.mountain_reference(game.field,game.world.mountain.seed_value),
		"output_size":[root.size.x,root.size.y],"viewport_rect":str(root.get_visible_rect()),
		"spawn":_v3(game.field.spawn_point()),"spawn_heading":game.field.spawn_heading(),
		"menu_mode":game.hud.menu_mode,"workshop_status":game.workshop.status.text,
		"eligibility_inputs":{"automated":game.automated,"physics_modified":game.physics_modified,
			"test_lab_argument":"--test-lab" in OS.get_cmdline_user_args(),"weather_quality":game.graphics.weather_quality,
			"controller_weather_quality":game.weather.quality,"automatic_weather":game.weather.automatic,
			"automatic_daylight":game.weather.daylight.automatic,"weather":game.weather.selected_preset,"hour":game.weather.daylight.hour}}

func _trace(label: String, details: Dictionary = {}) -> void:
	var row = {"event":label,"state":_state(),"details":details.duplicate(true)}
	trace.append(row)
	print("CRASH_LIFECYCLE_TRACE ",JSON.stringify(row,"",true,true))

func _gate_diagnostics(point: Vector3, yaw: float) -> Dictionary:
	var low = INF; var high = -INF
	var corners: Array = []
	var basis = Basis(Vector3.UP,yaw)
	for side in [-5.6,5.6]:
		for x in [-.6,.6]:
			for z in [-.9,.9]:
				var p: Vector3 = point+basis*Vector3(side+x,0,z)
				var height: float = game.field.sample(p.x,p.z).height
				low=minf(low,height); high=maxf(high,height); corners.append({"xz":[p.x,p.z],"height":height})
	return {"position":_v3(point),"heading":yaw,"corners":corners,"height_spread_m":high-low,"high_above_endpoint_m":high-point.y,
		"point_error":Race.point_error(point,game.field),"gate_error":Race.gate_error(point,yaw,game.field),
		"seated":not Flavor.gate_seat(game.field,point,yaw).is_empty()}

func _ragdoll_equipment_gap() -> float:
	var result = 0.0
	var ragdoll = game.skier.ragdoll
	for i in 2:
		var prefix = "Right" if i==0 else "Left"
		var ski: Transform3D = ragdoll.bone_world(prefix+"Foot")*ragdoll.equipment_offsets[i*2]
		var pole: Transform3D = ragdoll.bone_world(prefix+"Hand")*ragdoll.equipment_offsets[i*2+1]
		result = maxf(result,game.skier.skis[i].global_position.distance_to(ski.origin))
		result = maxf(result,game.skier.poles[i].global_position.distance_to(pole.origin))
	return result

func _probe_external_focus(stage: String, expected_focused: bool) -> void:
	var before = [game.application_focused,game.active,game.session.elapsed,game.skier.ragdoll.frozen]
	game.crash_fixture_probe_external(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.crash_fixture_probe_external(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var after = [game.application_focused,game.active,game.session.elapsed,game.skier.ragdoll.frozen]
	_trace("external-focus-probe",{"stage":stage,"before":before,"after":after})
	check(before==after and game.application_focused==expected_focused,"External focus dispatch cannot overwrite controlled state: "+stage)

func _clock_ticks(count: int, expected_advance: int, stage: String) -> void:
	var recorder = game.session.recording
	var before: float = game.session.elapsed
	var before_ticks: int = recorder.ticks
	var before_inactive: int = recorder.tick_kinds.count(1)
	var expected: float = before
	for i in expected_advance: expected += DT
	_ticks(count)
	_trace("clock-stage",{"stage":stage,"requested_ticks":count,"expected_advance_ticks":expected_advance,
		"before_elapsed":before,"expected_elapsed":expected,"before_ticks":before_ticks,"after_ticks":recorder.ticks,
		"before_inactive":before_inactive,"after_inactive":recorder.tick_kinds.count(1),"input_values":recorder.inputs.size()})
	check(game.session.elapsed==expected and recorder.ticks-before_ticks==expected_advance and recorder.tick_kinds.count(1)-before_inactive==expected_advance and recorder.inputs.size()==recorder.ticks*Replay.INPUT_WIDTH,"Exact clock and input-row budget: "+stage)

static func _f64(value: float) -> String:
	var bytes = PackedByteArray(); bytes.resize(8); bytes.encode_double(0,value)
	return bytes.hex_encode()

static func _f64_array(values: Array) -> Array:
	var result: Array = []
	for value in values: result.append(_f64(value))
	return result

func _observe_ragdoll_skin() -> void:
	# Read the final modifier result destined for the skin, not the restored
	# procedural pose or PhysicalBone target used by update_equipment itself.
	if not game.skier.ragdoll.running: return
	rendered_ragdoll_bones.clear()
	for id in ["RightFoot","RightHand","LeftFoot","LeftHand"]:
		rendered_ragdoll_bones.append(game.skier.skeleton.global_transform*game.skier.skeleton.get_bone_global_pose(game.skier.bone_ids[id]))
	rendered_ragdoll_frame = Engine.get_process_frames()
	rendered_ragdoll_updates += 1

func _rendered_skin_gaps() -> Dictionary:
	var result = {"sample_frame":rendered_ragdoll_frame,"capture_frame":Engine.get_process_frames(),
		"observed_updates":rendered_ragdoll_updates,"available":rendered_ragdoll_bones.size()==4,"limbs":[]}
	if rendered_ragdoll_bones.size()!=4: return result
	var nodes = [game.skier.skis[0],game.skier.poles[0],game.skier.skis[1],game.skier.poles[1]]
	var names = ["RightFoot","RightHand","LeftFoot","LeftHand"]
	for i in 4:
		var skin: Transform3D = rendered_ragdoll_bones[i]
		var target: Transform3D = skin*game.skier.ragdoll.equipment_offsets[i]
		result.limbs.append({"bone":names[i],"rendered_bone":_v3(skin.origin),
			"physical_bone":_v3(game.skier.ragdoll.bone_world(names[i]).origin),
			"skin_physical_gap_m":skin.origin.distance_to(game.skier.ragdoll.bone_world(names[i]).origin),
			"skin_equipment_gap_m":target.origin.distance_to(nodes[i].global_position),
			"rendered_target":_v3(target.origin),"equipment_origin":_v3(nodes[i].global_position)})
	return result

func _install_submission_observers() -> String:
	# The receipt corresponds to VisualInstance3D's non-interpolated submission
	# path. Alpine does its own completed-state interpolation in SkierVisual.
	if is_physics_interpolation_enabled(): return "Renderer receipt requires the existing non-interpolated SceneTree setting."
	var roots = [game.skier.skis[0],game.skier.poles[0],game.skier.skis[1],game.skier.poles[1]]
	for i in roots.size(): _collect_equipment_meshes(roots[i],Transform3D.IDENTITY,i)
	if equipment_submissions.size()!=8: return "Expected two ski, boot, binding and pole meshes."
	for entry in equipment_submissions:
		if entry.node.get_script()!=null or not entry.node.is_transform_notification_enabled():
			return "Equipment already has a script or disabled transform notifications; review the read-only receipt."
	for entry in equipment_submissions: entry.node.set_script(RenderSubmission)
	return ""

func _collect_equipment_meshes(node: Node3D, relative: Transform3D, limb: int) -> void:
	if node is MeshInstance3D:
		equipment_submissions.append({"node":node,"relative":relative,"limb":limb})
	for child in node.get_children():
		if child is Node3D: _collect_equipment_meshes(child,relative*child.transform,limb)

static func _transform_point_gap(a: Transform3D, b: Transform3D) -> float:
	# Origin alone cannot catch a detached shaft caused by stale rotation. Unit
	# axis endpoints bound the submitted rigid frame as well as its translation.
	var result = 0.0
	for point in [Vector3.ZERO,Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
		result = maxf(result,(a*point).distance_to(b*point))
	return result

func _submitted_skin_gaps() -> Dictionary:
	var frame = Engine.get_process_frames()
	var available = rendered_ragdoll_bones.size()==4 and equipment_submissions.size()==8
	var result = {"available":available,"fresh":available and rendered_ragdoll_frame==frame,
		"max_node_gap_m":0.0,"max_skin_gap_m":0.0,"capture_frame":frame,
		"skin_frame":rendered_ragdoll_frame,"engine_interpolation":is_physics_interpolation_enabled(),"meshes":[]}
	if not available: return result
	for entry in equipment_submissions:
		var mesh = entry.node
		var submitted: Transform3D = mesh.submitted_transform
		var skin: Transform3D = rendered_ragdoll_bones[entry.limb]*game.skier.ragdoll.equipment_offsets[entry.limb]*entry.relative
		var node_gap = _transform_point_gap(submitted,mesh.global_transform)
		var skin_gap = _transform_point_gap(submitted,skin)
		result.max_node_gap_m = maxf(result.max_node_gap_m,node_gap)
		result.max_skin_gap_m = maxf(result.max_skin_gap_m,skin_gap)
		result.fresh = result.fresh and mesh.is_visible_in_tree() and game.skier.body_pivot.is_visible_in_tree() and mesh.submission_count>0 and mesh.submitted_process_frame==frame
		result.meshes.append({"path":str(mesh.get_path()),"mesh":mesh.mesh.resource_path,"limb":entry.limb,
			"submitted_frame":mesh.submitted_process_frame,"submissions":mesh.submission_count,"visible":mesh.is_visible_in_tree(),
			"submitted_origin":_v3(submitted.origin),"skin_target":_v3(skin.origin),
			"node_gap_m":node_gap,"skin_gap_m":skin_gap})
	return result
