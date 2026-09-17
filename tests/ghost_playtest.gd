extends SceneTree
## Native production comparison. All recordings/stores are isolated fixtures.
## --profile: matched 20 s cases (0/1/10, then 10 without tracks), no captures.
## Otherwise: chronological 15 s playback, lifecycle and Records input probes.
const Replay = preload("res://scripts/racing/run_replay.gd")
const Pose = preload("res://scripts/presentation/ghost_pose.gd")
const Records = preload("res://scripts/racing/competitive_record.gd")
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const Sim = preload("res://scripts/core/ski_simulation.gd")
const DT = 1.0/120.0
const PIXELS = Vector2i(3840,2160)
const STARTUP_TIMEOUT_MS = 600000
var game
var checks = 0
var failures: Array = []
var rows: Array = []
var metrics: Array = []
var output = "res://artifacts/ghost/native"
var profiling = false
var fixture_store = ""
var expected_pixels = PIXELS
var actual_pixels = Vector2i.ZERO
var framebuffer_checks: Array = []
var capture_us = 0
var review_only = false
var selector_only = false
var production_coverage: Array = []
var profile_ghost_count = -1
var profile_seconds = 20.0
var pose_cpu_ms_per_ten = 0.0

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> bool:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
	return value

func run() -> void:
	set_meta("test_lab_fixture",true)
	profiling = "--profile" in OS.get_cmdline_user_args()
	review_only = "--review-only" in OS.get_cmdline_user_args()
	selector_only = "--selector-only" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile-ghosts="): profile_ghost_count=clampi(arg.trim_prefix("--profile-ghosts=").to_int(),0,10)
		if arg.begins_with("--profile-seconds="): profile_seconds=clampf(arg.trim_prefix("--profile-seconds=").to_float(),5.0,20.0)
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
			if not output.begins_with("res://"): output = "res://"+output
	if DisplayServer.get_name()=="headless":
		push_error("Ghost native harness requires a rendered engine; run ghost_archive_suite headlessly.")
		quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	for arg in OS.get_cmdline_user_args():
		if arg in ["--autoplay","--capture-menu"]:
			check(false,"Main's independent runner cannot share this fixture: "+arg)
	if not failures.is_empty(): await _finish(); return
	fixture_store = "user://ghost_native_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	root.size = PIXELS
	game = load("res://main.tscn").instantiate()
	# _ready can yield while constructing effects/session. Automation must already
	# be set when it first decides whether to read personal appearance/preferences.
	game.automated = true
	game.physics_modified = true # Any UI-triggered retry remains ineligible too.
	game.active = false
	game.benchmark_input = _input_for.bind(0)
	game.set_physics_process(false); game.set_process(false)
	root.add_child(game); current_scene = game
	var startup_deadline = Time.get_ticks_msec()+STARTUP_TIMEOUT_MS
	while not game.initialized or (game.loading and game.loading.busy):
		if Time.get_ticks_msec()>startup_deadline:
			check(false,"Main initialization/loading exceeded 600 seconds")
			await _finish(); return
		await process_frame
	check(game.session!=null and game.effects!=null and game.ghost!=null,"Main initialized effects, session and bound ghost field before fixture access")
	if not failures.is_empty(): await _finish(); return
	game.active = false
	game.set_physics_process(false); game.set_process(false)
	game.benchmark_no_captures = true
	game.preferences_enabled = false
	game.hud.feedback.persist = false
	game.voice.persist = false; game.effects.wind.persist = false; game.effects.sfx.persist = false
	game.effects.haptic_hardware_enabled = false
	game.effects.muted = true
	game.session.record_directory = fixture_store.path_join("records")
	game.session.benchmark_path = fixture_store.path_join("benchmark.json")
	game.session.mark_practice("Isolated ghost native startup")
	check(game.field.GENERATOR_ID=="laboratory" and game.field.seed_value==849205174,"Native fixture uses the requested laboratory without scene reload")
	if not failures.is_empty(): await _finish(); return
	game.start_run(true)
	game.session.mark_practice("Isolated ghost native fixture")
	if not _check_isolation("startup"): await _finish(); return
	check(game.ghost.powder_surface==game.effects.powder_surface and game.ghost.track_stack.player==game.effects.snow_tracks,"Ghost field retains bound powder receiver and player history")
	if not failures.is_empty(): await _finish(); return
	# Keep the requested quality/reconstruction settings, but measure rendered
	# frames only. The output image, not the window request, proves actual 4K.
	game.display_settings.frame_generation = false
	if not await _set_output(PIXELS,"startup"): await _finish(); return
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for i in 10:
		var replay = preload("res://tests/ghost_replay_fixture.gd").replay(1.0,Replay.key(game.session.course_id)) if selector_only else _capture_production(i)
		check(replay.has_presentation(),("Synthetic selector-only recording %d" if selector_only else "Completed production pose recording %d") % i)
		rows.append({"id":Records.run_id(),"time":replay.duration,"date":1700000000+i,"peak_kmh":100.0,"splits":[-1.0,-1.0,-1.0],"replay":replay})
	if not failures.is_empty(): await _finish(); return
	rows.sort_custom(Records.ordered)
	if selector_only:
		await _selector()
	elif profiling:
		_pose_cpu_probe()
		var configurations = [[profile_ghost_count,"--profile-no-tracks" not in OS.get_cmdline_user_args()]] if profile_ghost_count>=0 else [[0,true],[1,true],[10,true],[10,false]]
		for config in configurations:
			await _scenario(config[0],config[1],profile_seconds)
			if not failures.is_empty(): break
	else:
		if not review_only: await _scenario(10,true,15.0)
		# Independent probes still run if screenshot I/O exhausts chronology time.
		await _lifecycle_and_opacity()
		await _animation_views()
		await _selector()
	_check_isolation("finish")
	await _finish()

func _finish() -> void:
	for evidence in production_coverage:
		if evidence.pose_comparisons>0:
			check(evidence.max_joint_error_m<.001 and evidence.max_equipment_error_m<.001 and evidence.max_basis_error<.002,"Recorded endpoint pose/equipment matches completed production writer")
	if is_instance_valid(game):
		game.active = false
		if game.effects: game.effects.stop_audio()
	var sources: Dictionary = {}
	for path in ["tests/ghost_playtest.gd","scripts/presentation/ghost_pose.gd","scripts/presentation/personal_best_ghost.gd","scripts/presentation/skier_visual.gd","scripts/presentation/skier_full_motion.gd","scripts/presentation/snow_tracks.gd","assets/graphics/ghost_skier.gdshader"]:
		sources[path] = _source_metadata(path)
	var report = {"source_metadata":sources,"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"profiles":metrics,"pose_cpu_ms_per_ten":pose_cpu_ms_per_ten,"profile_mode":profiling,"selector_only":selector_only,"production_coverage":production_coverage,"capture_wall_ms":capture_us/1000.0,"device":RenderingServer.get_video_adapter_name(),"pixels":[actual_pixels.x,actual_pixels.y],"framebuffers":framebuffer_checks,"isolated_store":fixture_store,"human_acceptance":"pending","production_capture":"Synthetic UI fixture only" if selector_only else "Session-owned sample cadence after actual fixed animation step"}
	var file = preload("res://tests/test_report.gd").open_write(output.path_join("profile_results.json" if profiling else "visual_results.json"))
	if file: file.store_string(JSON.stringify(report,"\t")); file.close()
	else: check(false,"Native report could not be written")
	print("GHOST_NATIVE_RESULTS ",JSON.stringify(report))
	if is_instance_valid(game): game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

static func _source_metadata(path: String) -> Dictionary:
	var file = FileAccess.open("res://"+path,FileAccess.READ)
	return {"bytes":file.get_length() if file else -1,"modified":FileAccess.get_modified_time("res://"+path)}

func _check_isolation(label: String) -> bool:
	return check(game.physics_modified and not game.session.eligible and game.session.recording==null and not game.preferences_enabled and game.session.record_directory==fixture_store.path_join("records") and game.session.benchmark_path==fixture_store.path_join("benchmark.json"),label+": ineligible playback, no recorder, isolated record/selection writes")

func _set_output(size: Vector2i, label: String) -> bool:
	expected_pixels = size
	game.display_settings.display_mode = "windowed"
	# Explicit exact-output mode also handles Windows' borderless/fullscreen inference.
	game.display_settings.display.apply(root,size,true)
	game.display_settings.apply_viewport(root)
	for frame in 12: await process_frame
	return await _verify_framebuffer(label)

func _framebuffer_matches(image: Image, label: String) -> bool:
	actual_pixels = image.get_size() if image!=null else Vector2i.ZERO
	framebuffer_checks.append({"stage":label,"requested":[expected_pixels.x,expected_pixels.y],"actual":[actual_pixels.x,actual_pixels.y]})
	return check(actual_pixels==expected_pixels,label+": actual framebuffer "+str(actual_pixels)+" matches "+str(expected_pixels))

func _verify_framebuffer(label: String) -> bool:
	await RenderingServer.frame_post_draw
	return _framebuffer_matches(root.get_texture().get_image(),label)

func _input_for(tick: int, variant: int) -> RiderInput:
	var time = tick*DT
	var input = RiderInput.new()
	input.tuck = .8 if fmod(time+variant*.3,8.0)<4 else .15
	input.steer = sin(time*.65+variant*.15)*(.035+variant*.002)
	# Variant clips include actual takeoff/grab/rotation requests; report/captures
	# show which actions the solver accepted, rather than labelling intent as pose.
	input.jump = tick==600+variant*4
	input.jump_held = tick>=560+variant*4 and tick<600+variant*4
	input.air_yaw = .3 if time>5.0 and time<5.35 else 0.0
	input.grab = time>5.15 and time<5.6
	return input

func _capture_production(variant: int):
	var sim = Sim.new(preload("res://config/ski_default.tres").duplicate(true))
	sim.reset(game.field.spawn_point(),game.field.spawn_heading())
	sim.surface_normal = game.field.contact_normal(sim.position.x,sim.position.z); sim.prime_contacts(game.field)
	var visual = Visual.new(); visual.preview_only = true
	# Independent production pose state; immutable meshes are provided by the world.
	# A private assets wrapper is unnecessary for a hidden capture actor because
	# appearance defaults are already the fixture defaults and no preference loads.
	visual.visible = false
	root.add_child(visual); visual.reset_animation(sim)
	var mirror = null
	if variant==0 and not profiling:
		mirror = Visual.new(); mirror.preview_only = true; mirror.visible = false
		root.add_child(mirror)
	var observed = {"variant":variant,"phases":{},"switch_samples":0,"turn_left_samples":0,"turn_right_samples":0,"hard_turn_samples":0,"air_rotation_samples":0,"takeoffs":0,"landings":0,"was_grounded":true,"previous_heading":sim.heading,"snow_samples":[0,0],"unsupported_samples":[0,0],"one_ski_samples":0,"rock_samples":0,"pose_comparisons":0,"max_joint_error_m":0.0,"max_equipment_error_m":0.0,"max_basis_error":0.0}
	var replay = Replay.new(); replay.begin(sim,Replay.key(game.session.course_id))
	visual.pose(sim,1.0); replay.capture_presentation(0.0,Pose.capture(visual,sim,game.field))
	var limit = 2400-variant*24
	var crash_until = -1
	for tick in range(1,limit+1):
		var time = tick*DT
		if crash_until>=0:
			replay.record_crash(DT,time)
			if tick>=crash_until:
				sim.reset(game.field.spawn_point(),game.field.spawn_heading()); sim.prime_contacts(game.field)
				visual.reset_animation(sim); replay.record_recovery(time,sim)
				visual.pose(sim,1.0); replay.capture_presentation(time,Pose.capture(visual,sim,game.field))
				crash_until = -1
			continue
		var intent = _input_for(tick,variant)
		sim.step(DT,intent,game.field); visual.step_animation(DT,sim,intent,game.field)
		replay.record(DT,time,sim,intent,1.0 if tick==limit else -1.0)
		if replay.wants_presentation_sample():
			visual.pose(sim,1.0)
			var completed = Pose.capture(visual,sim,game.field)
			replay.capture_presentation(time,completed)
			_observe_production(visual,mirror,sim,completed,time,observed)
		if sim.crashed and tick<limit:
			replay.begin_crash(time,sim)
			visual.pose(sim,1.0); replay.capture_presentation(time,Pose.capture(visual,sim,game.field))
			crash_until = mini(tick+24,limit-1)
	# Exact finish may lie in a crash interval; close at the last valid endpoint
	# and retain the actual independent duration instead of inventing a pose.
	if not replay.complete:
		replay.complete = true
		replay.duration = replay.pose_times[-1]
		replay.ticks = ceili(replay.duration/DT-.000001)
		replay.inputs.resize(replay.ticks*Replay.INPUT_WIDTH); replay.tick_kinds.resize(replay.ticks)
	if mirror: mirror.free()
	production_coverage.append(observed)
	visual.free()
	return replay

func _install(count: int) -> void:
	game.session.ghost_runs = rows.duplicate()
	game.session.reference_ghosts = rows.slice(0,count)
	game.session.attempt_id += 1
	game.ghost.sync_attempt(game.session)
	game.hud.ghost_colors = game.ghost.colors
	for ghost in game.ghost.ghosts:
		check(ghost.snow_tracks.material in game.effects.powder_surface.receivers,"Ghost ribbon registered with bound powder surface")

func _scenario(count: int, tracks: bool, seconds: float) -> void:
	game.restart(); game.session.mark_practice("Isolated bounded ghost comparison")
	if not _check_isolation("scenario %d/%s" % [count,tracks]): return
	game.ghost.set_enabled(true); game.ghost.tracks_enabled = tracks
	_install(count)
	# Readback is outside the timed sample, including the no-capture profiles.
	if not await _verify_framebuffer("scenario %d/%s start" % [count,tracks]): return
	var samples: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var unfocused_frames = 0
	var last = Time.get_ticks_usec()
	var accumulator = 0.0
	var next_capture = 1.0
	var wall_start = last
	var prior_capture_us = capture_us
	# Full 4K PNG readback/encoding is outside gameplay time. Leave enough wall
	# time for the 30 chronology captures without shortening the 15-second ride.
	var wall_budget_us = 60000000 if profiling else 180000000
	while game.session.elapsed<seconds and Time.get_ticks_usec()-wall_start<wall_budget_us:
		await process_frame
		var now = Time.get_ticks_usec()
		var measured = (now-last)/1000000.0
		var delta = minf(measured,.1); last = now
		accumulator += delta
		while accumulator>=DT:
			game._physics_process(DT); accumulator -= DT
		var started = Time.get_ticks_usec()
		game._process(delta)
		if profiling and game.session.elapsed>2.0:
			if not game.application_focused: unfocused_frames+=1
			samples.append(measured*1000.0); cpu.append((Time.get_ticks_usec()-started)/1000.0)
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		if not profiling and game.session.elapsed>=next_capture:
			await _capture("chronology_%05d" % roundi(game.session.elapsed*1000))
			next_capture += .5
			last = Time.get_ticks_usec() # PNG stalls do not advance simulated riding.
		if game.session.recovering:
			game.respawn_here()
	check(game.session.elapsed>=seconds,"Bounded %d ghost / tracks=%s scenario reached %.1f s" % [count,tracks,seconds])
	var stamps = 0
	for ghost in game.ghost.ghosts: stamps += ghost.snow_tracks.written
	check(stamps<=count*320,"Ghost retained track total stays within %d" % (count*320))
	if not tracks: check(stamps==0,"Disabling track_emission retains zero ghost stamps")
	if profiling: check(unfocused_frames==0,"Timed playback remained focused")
	metrics.append({"quality_preset":game.graphics.preset_id,"render_scale":game.display_settings.render_scale,"upscaler":game.display_settings.upscaler,"fps_limit":game.display_settings.fps_limit,"display":game.display_settings.report(root,actual_pixels),"ghosts":count,"tracks":tracks,"seconds":game.session.elapsed,"frame_ms":_distribution(samples),"presentation_cpu_ms":_distribution(cpu),"renderer_gpu_ms":_distribution(gpu),"static_memory":Performance.get_monitor(Performance.MEMORY_STATIC),"retained_ghost_stamps":stamps,"gpu_stroke_capacity":game.ghost.track_stack.capacity+2,"captures_affect_timing":not profiling,"performance_eligible":profiling and unfocused_frames==0,"unfocused_frames":unfocused_frames,"capture_wall_ms":(capture_us-prior_capture_us)/1000.0})
	game.active = false
	await _verify_framebuffer("scenario %d/%s end" % [count,tracks])

func _pose_cpu_probe() -> void:
	# Separate CPU attribution, outside rendered frame measurements. Use actual
	# production recordings, changing interpolation weights within each sample.
	_install(10)
	var started=Time.get_ticks_usec()
	var steps=240
	for step in steps:
		for ghost in game.ghost.ghosts:
			var data: Dictionary=ghost.replay.presentation_at(1.0+step/120.0)
			if not data.is_empty(): Pose.apply(ghost.visual,data.a,data.b,data.weight,ghost.responses)
	pose_cpu_ms_per_ten=(Time.get_ticks_usec()-started)/1000.0/steps

func _lifecycle_and_opacity() -> void:
	_install(10)
	var ghost = game.ghost.ghosts[0]
	var time = 2.0
	var point: Vector3 = Pose.transform_at(ghost.replay.presentation_at(time).a,0).origin
	for distance in [0.0,1.19,1.21,3.99,4.01,749.9,750.1]:
		ghost.update_ghost(time,point+Vector3.RIGHT*distance,true)
		check(ghost.visual.visible and ghost.opacity>=.15,"Distance %.2f never hides active model/equipment" % distance)
		game.camera.global_position = point+Vector3(3,2,-4); game.camera.look_at(point+Vector3.UP)
		# Fixed camera isolates rider-distance opacity, including old far thresholds.
		await _capture("opacity_%07.2f" % distance)
	var saved_fov: float = game.camera.fov
	var saved_far: float = game.camera.far
	game.camera.far = maxf(saved_far,1600.0); game.camera.fov = 3.0
	game.camera.global_position = point+Vector3(0,350,-700); game.camera.look_at(point+Vector3.UP)
	ghost.update_ghost(time,game.camera.global_position,true)
	await _capture("far_camera_telephoto_782m")
	game.camera.fov = saved_fov; game.camera.far = saved_far
	var count: int = ghost.snow_tracks.written
	var paused_pose: Transform3D = ghost.visual.global_transform
	ghost.update_ghost(time+1.0,point,true,true)
	check(ghost.snow_tracks.written==count and ghost.visual.global_transform.is_equal_approx(paused_pose) and ghost.last_time==time,"Pause ignores an advancing requested time and freezes pose/emission")
	game.ghost.set_enabled(false)
	check(ghost.snow_tracks.written==0,"Global off clears history and emission")
	game.ghost.set_enabled(true); ghost.update_ghost(8.0,point,true)
	check(ghost.snow_tracks.written==0,"Re-enable starts at current time without catch-up stamps")
	ghost.update_ghost(1.0,point,true)
	check(ghost.snow_tracks.written==0,"Time reversal clears origins/history")
	var other = game.ghost.ghosts[1]
	other.update_ghost(2.0,point,true)
	ghost.update_ghost(ghost.replay.duration+.01,point,true)
	check(not ghost.visual.visible and other.visual.visible,"Independent finish leaves another ghost playing")
	var replaced = ghost.replay
	var other_count: int = other.snow_tracks.written
	ghost.replay = other.replay
	check(ghost.last_time<0 and ghost.snow_tracks.written==0 and other.snow_tracks.written==other_count,"Replay replacement resets only that ghost")
	ghost.replay = replaced
	# Outfit shots must actually return camera, rider and all ghosts to overlap.
	game.restart(); game.session.mark_practice("Isolated overlap review"); game.active = false
	_install(10); game.skier.pose(game.sim,1.0)
	var original: Color = game.skier.appearance.values.Clothing.tint
	for tint in [Color.WHITE,Color("22252b"),Color("edf6ff"),Color("22c6de")]:
		game.skier.appearance.change("Clothing","tint",tint,false)
		game.ghost.refresh_colors(game.session.ghost_runs)
		game.hud.ghost_colors = game.ghost.colors
		for item in game.ghost.ghosts: item.update_ghost(0.0,game.sim.position,true)
		game.camera.global_position = game.sim.position+Vector3(3,2,-4); game.camera.look_at(game.sim.position+Vector3.UP)
		await _capture("overlap_outfit_"+tint.to_html())
		game.camera.close_view = true; game.camera.reset(); game._process(0.0)
		for item in game.ghost.ghosts:
			item.update_ghost(0.0,game.sim.position,true)
			for mat in item.ghost_assets.materials.values(): check(float(mat.get_shader_parameter("ghost_opacity"))>=.15,"First-person body/equipment material alpha floor")
		await _capture("first_person_overlap_"+tint.to_html())
		game.camera.close_view = false; game.camera.reset(); game._process(0.0)
	game.skier.appearance.change("Clothing","tint",original,false)
	game.ghost.refresh_colors(game.session.ghost_runs)
	for item in game.ghost.ghosts:
		check(item.visual.ragdoll==null and item.visual.motion_comparison==null and not item.visual.is_processing_unhandled_input(),"Ghost has no ragdoll/input/UI side effects")
	check(game.ghost.ghosts[0].ghost_assets.materials.values()[0]!=game.ghost.ghosts[1].ghost_assets.materials.values()[0],"Materials are instance-local")

func _selector() -> void:
	game.active = false
	game.session.mark_practice("Isolated native Records input")
	if not _check_isolation("selector entry"): return
	_install(10)
	game.automated = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for size in [Vector2i(1024,720),PIXELS]:
		game.session.choose_ghosts("manual",[],10)
		game.hud.open_competition(game.session)
		game.hud.competition.tabs.current_tab = 3
		var selector = game.hud.competition.selector
		if not await _set_output(size,"selector resize"):
			game.automated = true; return
		check(root.get_visible_rect().encloses(game.hud.competition.panel.get_global_rect()),"Ghost selector fits "+str(size))
		var frozen = game.session.reference_ghosts.duplicate()
		var first = selector.choices[selector.ids[0]]
		first.grab_focus(); await process_frame
		await _key(KEY_ENTER)
		check(game.session.ghost_selection.ids.size()==1 and game.session.reference_ghosts==frozen,"Keyboard toggle/frozen attempt at "+str(size))
		# Real focus navigation must scroll the tenth row into view at each size.
		for step in 9: await _pad(JOY_BUTTON_DPAD_DOWN)
		var last = selector.choices[selector.ids[-1]]
		await process_frame; await process_frame
		var scroll = game.hud.competition.tabs.get_tab_control(3)
		check(root.gui_get_focus_owner()==last and scroll.get_global_rect().encloses(last.get_global_rect()),"Controller reaches and scrolls tenth row at "+str(size))
		await _pad(JOY_BUTTON_A)
		check(game.session.ghost_selection.ids.size()==2,"Controller toggles final row at "+str(size))
		for id in selector.ids: check(selector.swatches[id].color==game.ghost.colors[id],"Selector swatch matches rendered ghost "+id.left(8))
		await _capture("selector_last_%dx%d" % [size.x,size.y])
		for step in 9: await _pad(JOY_BUTTON_DPAD_UP)
		await process_frame; await process_frame
		check(root.gui_get_focus_owner()==first and scroll.get_global_rect().encloses(first.get_global_rect()),"Controller returns to visible first row at "+str(size))
		for pressed in [true,false]:
			var mouse = InputEventMouseButton.new(); mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.position = root.get_final_transform()*first.get_global_rect().get_center(); mouse.pressed = pressed
			Input.parse_input_event(mouse); await process_frame
		check(game.session.ghost_selection.ids.size()==1,"Mouse toggles selected row at "+str(size))
		last.grab_focus(); await process_frame; await _key(KEY_ENTER)
		check(game.session.ghost_selection.ids.is_empty(),"Keyboard can restore empty manual set at "+str(size))
		await _capture("selector_empty_%dx%d" % [size.x,size.y])
		selector.mode.grab_focus(); await process_frame; await process_frame
		await _key(KEY_ENTER)
		await _key(KEY_UP); await _key(KEY_ENTER)
		check(game.session.ghost_selection.mode=="automatic" and selector.count_choice.visible,"Keyboard opens automatic count at "+str(size))
		selector.count_choice.grab_focus(); await process_frame; await _key(KEY_ENTER)
		for step in 7: await _key(KEY_UP)
		await _key(KEY_ENTER)
		check(game.session.ghost_selection.automatic_count==3 and game.session.reference_ghosts==frozen,"Keyboard count three preserves current roster at "+str(size))
		check(Records.load_record(game.session.record_path(),Replay.key(game.session.course_id)).selection.automatic_count==3,"Automatic count persists from native UI at "+str(size))
		check(selector.choices.values().filter(func(choice): return choice.button_pressed).size()==3,"Automatic checkmarks match selected count at "+str(size))
		await _capture("selector_automatic_three_%dx%d" % [size.x,size.y])
		selector.count_choice.grab_focus(); await _pad(JOY_BUTTON_A)
		for step in 7: await _pad(JOY_BUTTON_DPAD_DOWN)
		await _pad(JOY_BUTTON_A)
		check(game.session.ghost_selection.automatic_count==10 and game.session.reference_ghosts==frozen,"Controller selects count ten without changing active attempt at "+str(size))
		await _mouse_first_option(selector.count_choice)
		check(game.session.ghost_selection.automatic_count==1 and game.session.reference_ghosts==frozen,"Mouse selects count one without changing active attempt at "+str(size))
		await _pad(JOY_BUTTON_B)
		check(not game.hud.competition.panel.visible,"Controller Back closes Records at "+str(size))
	game.automated = true
	_check_isolation("selector exit")

func _pad(button: int) -> void:
	for pressed in [true,false]:
		var event = InputEventJoypadButton.new(); event.device = 0; event.button_index = button; event.pressed = pressed
		Input.parse_input_event(event); await process_frame

func _key(code: int) -> void:
	for pressed in [true,false]:
		var event = InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed
		# PopupMenu handles keys in Window's input callback, before Viewport input.
		# Dispatch through its host window, which also routes embedded popups.
		var popup = game.navigation.top_popup()
		if popup: event.window_id = popup.get_window_id()
		Input.parse_input_event(event)
		await process_frame

func _mouse_first_option(option: OptionButton) -> void:
	for pressed in [true,false]:
		var event = InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		event.position = root.get_final_transform()*option.get_global_rect().get_center()
		Input.parse_input_event(event); await process_frame
	var popup = option.get_popup()
	check(popup.visible,"Mouse opens automatic count dropdown")
	if not popup.visible: return
	await process_frame; await process_frame
	# The popup's panel starts inside its window shadow. Include that measured
	# offset instead of treating the window edge as the first item's top edge.
	var panel: Control = popup.get_child(0,true)
	var y = panel.get_global_rect().position.y+popup.get_theme_stylebox("panel").get_content_margin(SIDE_TOP)+popup.get_theme_font("font").get_height(popup.get_theme_font_size("font_size"))*.5+popup.get_theme_constant("v_separation")*.5
	for pressed in [true,false]:
		var event = InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		event.window_id = popup.get_window_id()
		event.position = Vector2(panel.position.x+30,y)*popup.content_scale_factor
		if popup.is_embedded(): event.position = root.get_final_transform()*(Vector2(popup.position)+event.position)
		Input.parse_input_event(event); await process_frame

func _animation_views() -> void:
	_install(1)
	var ghost = game.ghost.ghosts[0]
	var saved_fov: float = game.camera.fov
	game.camera.fov = 42.0
	for time in [2.0,4.3,5.0,5.35,5.7,6.2,8.3]:
		var data = ghost.replay.presentation_at(time)
		if data.is_empty(): continue # A real crash hides its own ghost; see coverage.
		var point: Vector3 = Pose.transform_at(data.a,0).origin
		ghost.update_ghost(time,point+Vector3.RIGHT*18.0,true,false,false)
		game.camera.global_position = point+Vector3(3,1.8,-3); game.camera.look_at(point+Vector3.UP*.85)
		await _capture("isolated_recorded_pose_%05d" % roundi(time*1000))
	game.camera.fov = saved_fov
	var materials: Array = []
	for item in game.ghost.ghosts: materials.append(item.snow_tracks.material)
	_install(0); await process_frame
	check(materials.all(func(mat): return mat not in game.effects.powder_surface.receivers),"Roster teardown unregisters its powder receivers")

func _observe_production(source, mirror, sim, data: PackedFloat32Array, time: float, observed: Dictionary) -> void:
	var phase: String = source.animation.full_motion.phase
	if not observed.phases.has(phase): observed.phases[phase] = {"first":time,"last":time,"samples":0}
	observed.phases[phase].last = time; observed.phases[phase].samples += 1
	if sim.facing_backward: observed.switch_samples += 1
	if sim.grounded and sim.steering_applied_yaw<-.01: observed.turn_left_samples += 1
	if sim.grounded and sim.steering_applied_yaw>.01: observed.turn_right_samples += 1
	if sim.grounded and sim.carve_blend>.5: observed.hard_turn_samples += 1
	if not sim.grounded and absf(wrapf(sim.heading-observed.previous_heading,-PI,PI))>.0001: observed.air_rotation_samples += 1
	if observed.was_grounded and not sim.grounded: observed.takeoffs += 1
	if not observed.was_grounded and sim.grounded: observed.landings += 1
	observed.was_grounded = sim.grounded; observed.previous_heading = sim.heading
	var support_count = 0
	for side in 2:
		var start = Pose.CONTACT_START+side*Pose.CONTACT_WIDTH
		if data[start+1]>.5: observed.snow_samples[side] += 1
		if data[start]>.5: support_count += 1
		else: observed.unsupported_samples[side] += 1
		var ski = source.skis[side].global_position
		if preload("res://scripts/core/terrain_material.gd").at(game.field,ski.x,ski.z)==1: observed.rock_samples += 1
	if support_count==1: observed.one_ski_samples += 1
	if mirror==null: return
	Pose.apply(mirror,data,data,0.0,[preload("res://scripts/presentation/snow_response.gd").new(),preload("res://scripts/presentation/snow_response.gd").new()])
	for bone in source.skeleton.get_bone_count():
		var a: Transform3D = source.skeleton.global_transform*source.skeleton.get_bone_global_pose(bone)
		var b: Transform3D = mirror.skeleton.global_transform*mirror.skeleton.get_bone_global_pose(bone)
		observed.max_joint_error_m = maxf(observed.max_joint_error_m,a.origin.distance_to(b.origin))
		for axis in 3: observed.max_basis_error = maxf(observed.max_basis_error,a.basis[axis].distance_to(b.basis[axis]))
	for pair in [[source.skis,mirror.skis],[source.poles,mirror.poles]]:
		for side in 2:
			var a: Transform3D = pair[0][side].global_transform
			var b: Transform3D = pair[1][side].global_transform
			observed.max_equipment_error_m = maxf(observed.max_equipment_error_m,a.origin.distance_to(b.origin))
			for axis in 3: observed.max_basis_error = maxf(observed.max_basis_error,a.basis[axis].distance_to(b.basis[axis]))
	observed.pose_comparisons += 1

func _capture(label: String) -> void:
	var started = Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	if _framebuffer_matches(image,label):
		check(image.save_png(output.path_join(label+".png"))==OK,"Saved "+label)
		framebuffer_checks[-1].camera_position = str(game.camera.global_position)
		framebuffer_checks[-1].camera_fov = game.camera.fov
		framebuffer_checks[-1].ghosts = []
		for ghost in game.ghost.ghosts:
			framebuffer_checks[-1].ghosts.append({"id":ghost.run_id,"time":ghost.last_time,"visible":ghost.visual.is_visible_in_tree(),"color":ghost.color.to_html(),"opacity":ghost.opacity,"live_skis":ghost.snow_tracks.live_active.duplicate(),"retained_stamps":ghost.snow_tracks.written})
	capture_us += Time.get_ticks_usec()-started

static func _distribution(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var sorted = values.duplicate(); sorted.sort()
	var total = 0.0
	for value in values: total += value
	return {"count":values.size(),"mean":total/values.size(),"p95":sorted[mini(sorted.size()-1,int(sorted.size()*.95))],"p99":sorted[mini(sorted.size()-1,int(sorted.size()*.99))]}
