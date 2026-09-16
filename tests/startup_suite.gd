extends SceneTree
## Compact startup-to-real-menu integration. Captures and timing are separate runs.
const State = preload("res://scripts/ui/startup_state.gd")
const Sequence = preload("res://scripts/ui/startup_sequence.gd")
var checks = 0
var failures: Array[String] = []
var output = "res://artifacts/startup_20260914/functional"
var capture_mode = false
var reduced = false
var skip_kind = ""
var fullscreen = false
var timing_mode = false
var evidence: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func check(value: bool, caption: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ",caption)
	if not value: failures.append(caption)

func key_event(code: Key) -> InputEventKey:
	var e = InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = true; return e

func run() -> void:
	timing_mode = "--startup-timing" in OS.get_cmdline_user_args()
	if not (timing_mode and "--startup-fullscreen" in OS.get_cmdline_user_args()):
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1920,1080)
	Engine.max_fps = 120
	for arg in OS.get_cmdline_user_args():
		if arg=="--startup-capture": capture_mode = true
		elif arg=="--startup-reduced": reduced = true
		elif arg=="--startup-fullscreen": fullscreen = true
		elif arg.begins_with("--startup-skip="): skip_kind = arg.get_slice("=",1)
		elif arg.begins_with("--startup-output="): output = "res://"+arg.get_slice("=",1)
		elif arg.begins_with("--startup-size="):
			var dimensions = arg.get_slice("=",1).split("x"); root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	DirAccess.make_dir_recursive_absolute(output)
	if not timing_mode:
		unit_checks()
		await optional_checks()
	set_meta("test_map_fixture","short-course")
	set_meta("startup_preferences",{"reduced_motion":reduced,"muted":true})
	if fullscreen: set_meta("startup_display_preferences",{"display_mode":"fullscreen"})
	var boot = load("res://startup.tscn").instantiate()
	var start = Time.get_ticks_usec()
	root.add_child(boot); current_scene = boot
	var display_setup_ms: float = (boot.display_ready_usec-boot.started_usec)/1000.0
	var chosen_photo: int = boot.sequence.photo_index
	check(chosen_photo>=0 and boot.sequence.photo_texture!=null,"Startup selects an imported user photograph")
	check(boot.loading.startup_photo.texture==boot.sequence.photo_texture,"The same chosen photograph underlies startup and actual loading")
	check(boot.sequence.weather!=null and boot.loading.startup_weather!=null,"Snow and icy gusts cover both opening and photographic loading")
	boot.sequence._paint()
	check(boot.sequence.weather.motion_enabled==not reduced,"Reduced motion disables every snow and wind layer")
	if fullscreen and DisplayServer.get_name()!="headless": check(root.mode==Window.MODE_FULLSCREEN,"Fullscreen is established before main resources and initialization")
	var frames = 0
	var frame_times: Array[float] = []
	var last = Time.get_ticks_usec()
	var capture_index = 0
	var capture_times = [.12,.55,1.05,1.7,2.3]
	var sent_skip = false
	var actual_game
	var menu_at = 0
	var finished_at = 0
	while Time.get_ticks_usec()-start<90000000:
		await process_frame
		frames += 1
		var now = Time.get_ticks_usec()
		frame_times.append((now-last)/1000.0); last = now
		if is_instance_valid(boot):
			if is_instance_valid(boot.game): actual_game = boot.game
			if not skip_kind.is_empty() and not sent_skip and boot.sequence.state.elapsed>.60:
				var event: InputEvent = key_event(KEY_SPACE)
				if skip_kind=="mouse":
					event = InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
				elif skip_kind=="controller":
					event = InputEventJoypadButton.new(); event.button_index = JOY_BUTTON_A; event.pressed = true
				Input.parse_input_event(event); sent_skip = true
			if boot.sequence.complete and finished_at==0: finished_at = now
			if capture_mode and capture_index<capture_times.size() and boot.sequence.state.elapsed>=capture_times[capture_index]:
				await capture("%02d_reveal"%capture_index); capture_index += 1
		if is_instance_valid(actual_game) and actual_game.initialized and not actual_game.loading.busy:
			menu_at = Time.get_ticks_usec(); break
	check(menu_at>0,"Startup reaches the real interactive menu before the failure backstop")
	if menu_at==0: finish(); return
	var game = actual_game
	game.automated = false; game.set_physics_process(false)
	game.effects.muted = true; game.hud.feedback.muted = true; game.hud.feedback.persist = false
	check(game.get_tree().current_scene==game,"Scene reloads target the main scene, never replay the boot sequence")
	check(game.hud.menu.visible and not game.active,"Menu is visibly available without starting skiing")
	check(game.sim.ticks==0 and game.session.elapsed==0,"Boot has not advanced solver or race time")
	check(game.hud.feedback.reduced_motion==reduced,"Startup accessibility preference reaches the real interface")
	check(not game.loading.busy and not game.loading.overlay.visible,"Loading relinquishes its input shield when ready")
	check(game.world.defer_startup_cosmetics and game.world.grass==null,"Interactive menu precedes optional grass admission")
	game.navigation.ensure_focus()
	check(root.gui_get_focus_owner()!=null,"Keyboard/controller focus is restored on readiness")
	game.hud.primary.grab_focus()
	var focus_before = root.gui_get_focus_owner()
	var input_at = Time.get_ticks_usec()
	root.push_input(key_event(KEY_RIGHT))
	await process_frame; await process_frame
	var keyboard_latency = (Time.get_ticks_usec()-input_at)/1000.0
	check(root.gui_get_focus_owner()!=focus_before,"Keyboard changes real menu focus immediately")
	var pad = InputEventJoypadButton.new(); pad.button_index = JOY_BUTTON_DPAD_LEFT; pad.pressed = true
	focus_before = root.gui_get_focus_owner(); input_at = Time.get_ticks_usec()
	root.push_input(pad)
	await process_frame; await process_frame
	var controller_latency = (Time.get_ticks_usec()-input_at)/1000.0
	check(root.gui_get_focus_owner()!=focus_before,"Controller changes real menu focus immediately")
	game.hud.menu_tabs.current_tab = 2
	await process_frame
	var mouse = InputEventMouseButton.new(); mouse.button_index = MOUSE_BUTTON_LEFT; mouse.pressed = true
	mouse.position = game.hud.weather_button.get_global_rect().get_center()
	root.push_input(mouse,true)
	await process_frame
	mouse = mouse.duplicate(); mouse.pressed = false; root.push_input(mouse,true)
	await process_frame
	check(game.hud.weather_panel.visible,"Pointer opens the existing Settings action from the ready menu")
	for i in 30:
		if not game.world.startup_cosmetics_pending and not game.world.startup_cosmetics_running: break
		await process_frame
	check(game.world.grass!=null and not game.world.startup_cosmetics_running,"Optional grass completes while ready menu actions remain available")
	game.hud.close_weather(); game.hud.menu_tabs.current_tab = 0
	while is_instance_valid(boot) and not boot.sequence.complete: await process_frame
	if finished_at==0: finished_at = Time.get_ticks_usec()
	if capture_mode:
		for i in 24: await process_frame
		await capture("menu_ready")
	var stable_frames: Array[float] = []
	last = Time.get_ticks_usec()
	for i in 120:
		await process_frame
		var now = Time.get_ticks_usec(); stable_frames.append((now-last)/1000.0); last = now
	evidence = {"fixture":"short-course","dimensions":root.size,"photo_index":chosen_photo,"display_setup_ms":display_setup_ms,"fullscreen":fullscreen,"map_m":[256,512],"objects":0,"rendered":DisplayServer.get_name()!="headless","capture_run":capture_mode,"reduced_motion":reduced,"skip":skip_kind,
		"startup_to_menu_ms":(menu_at-start)/1000.0,"engine_to_menu_ms":menu_at/1000.0,"sequence_dismissed_ms":(finished_at-start)/1000.0,"startup_frames":frames,"startup_frame_ms":stats(frame_times),"menu_frame_ms":stats(stable_frames),"keyboard_observed_ms":keyboard_latency,"controller_observed_ms":controller_latency,"engine":Engine.get_version_info(),"graphics":game.display_settings.snapshot(),"build":preload("res://scripts/diagnostics/build_identity.gd").current()}
	game.queue_free(); await process_frame
	if not timing_mode: await failure_checks()
	finish()

func failure_checks() -> void:
	var failed = load("res://startup.tscn").instantiate()
	failed.scene_path = "res://absent_main_scene.tscn"
	root.add_child(failed)
	failed.sequence.set_process(false)
	failed.sequence.advance_visual(.01); failed.sequence.advance_visual(.3)
	check(not failed.failure.is_empty() and failed.loading.title.text=="Unable to start","Missing main scene exposes a factual error instead of an empty screen")
	check(failed.loading.retry_button.visible and failed.loading.quit_button.visible,"Failed startup exposes existing Retry and Quit controls")
	check(failed.sequence.complete and not failed.sequence.player.playing,"Failure releases the startup input/audio cover")
	var recovery_pad = InputEventJoypadButton.new(); recovery_pad.button_index = JOY_BUTTON_DPAD_RIGHT; recovery_pad.pressed = true
	root.push_input(recovery_pad); await process_frame
	check(root.gui_get_focus_owner()==failed.loading.quit_button,"Controller can navigate failure recovery before a main menu exists")
	var cancelled_job = preload("res://scripts/world/generation_job.gd").new()
	failed.loading.attach_job(cancelled_job); failed.loading.cancel_button.grab_focus()
	recovery_pad = InputEventJoypadButton.new(); recovery_pad.button_index = JOY_BUTTON_A; recovery_pad.pressed = true
	root.push_input(recovery_pad); await process_frame
	check(cancelled_job.is_cancelled(),"Controller can activate startup loading controls without gameplay input")
	failed.queue_free(); await process_frame
	check(not has_meta("startup_sequence") and not has_meta("startup_loading"),"Failed-start exit clears startup metadata for a clean retry")

func unit_checks() -> void:
	var state = State.new()
	check(not state.skip(key_event(KEY_SPACE)),"Input before legibility cannot skip")
	state.advance(.46,false)
	var echo = key_event(KEY_SPACE); echo.echo = true
	check(not state.skip(echo),"Key repeats cannot skip")
	check(not state.skip(InputEventMouseMotion.new()) and not state.skip(InputEventJoypadMotion.new()),"Pointer drift and stick noise cannot skip")
	check(state.skip(key_event(KEY_ESCAPE)),"Keyboard skip is admitted after legibility")
	state.advance(.3,false)
	check(not state.fading,"Skip never reveals an absent loading screen or menu")
	state.advance(.01,true)
	check(state.fading,"Queued skip starts the dissolve as soon as a destination exists")
	state.advance(.3,true)
	check(state.finished and is_zero_approx(state.opacity()),"Dissolve has a bounded finished state")
	for mode in ["mouse","controller"]:
		state = State.new(); state.advance(.5,false)
		var event: InputEvent
		if mode=="mouse": event = InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
		else: event = InputEventJoypadButton.new(); event.button_index = JOY_BUTTON_A; event.pressed = true
		check(state.skip(event),mode+" can skip after legibility")
	state = State.new(); state.advance(.02,true,true)
	check(state.fading,"Early menu readiness imposes no minimum logo display time")
	state = State.new(); state.advance(1.86,true)
	check(state.fading,"Ordinary reveal hands off within its two-second budget")
	state = State.new(); state.reduced_motion = true; state.advance(1.0,true)
	check(state.motion_time()==0 and not state.finished,"Reduced motion keeps effects static without removing the brand")
	state.advance(100.0,true)
	state.advance(.3,true)
	check(state.finished,"A stalled frame cannot trap the startup state")
	check(ProjectSettings.get_setting("application/boot_splash/show_image")==false,"Supported project configuration disables the stock Godot image")
	check(ProjectSettings.get_setting("display/window/size/mode")==Window.MODE_FULLSCREEN,"Project starts fullscreen before scene code runs")
	var clock_test = Sequence.new()
	root.add_child(clock_test); clock_test.set_process(false)
	clock_test.destination_ready = true
	clock_test.last_frame_usec = Time.get_ticks_usec()-2000000
	clock_test._process(.001)
	check(clock_test.state.fading,"A clamped engine delta cannot prolong the real-time reveal")
	clock_test.queue_free()
	var photos = Sequence.Photos.catalog()
	check(photos.size()==6,"All six supplied mountain photographs are packaged")
	var rng = RandomNumberGenerator.new(); rng.seed = 4149
	var selected = {}
	for i in 120: selected[Sequence.Photos.choose(photos,rng)] = true
	check(selected.size()==6 and not selected.has(-1),"Private random selection reaches every imported photograph")
	check(Sequence.Photos.choose([],rng)==-1,"Missing optional photo catalog falls back without a load error")

func optional_checks() -> void:
	for kind in ["missing","muted","zero","ambience_off","enabled"]:
		var opening = Sequence.new(); opening.optional_effects = false
		opening.audio_allowed = true
		opening.preferences = {"volume":0.0 if kind=="zero" else .55,"muted":kind=="muted","loading_ambience":kind!="ambience_off"}
		if kind=="missing": opening.cue_path = "res://assets/audio/interface/absent_optional.wav"
		root.add_child(opening); opening.set_process(false)
		opening.advance_visual(.01); opening.advance_visual(.01)
		check(opening.audio_dispatches==(1 if kind=="enabled" else 0),"Audio admission once only: "+kind)
		check(opening.panel.material==null and opening.logo.texture!=null,"Missing optional effect retains the approved logo and solid background: "+kind)
		opening.apply_preferences({"muted":true})
		check(not opening.player.playing,"Live mute stops startup audio: "+kind)
		opening.destination_ready = true; opening.menu_ready = true; opening.advance_visual(.01); opening.advance_visual(.3)
		check(opening.complete and not opening.player.playing,"Dismissal releases panel and sound: "+kind)
		opening.queue_free(); await process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label+".png")

func stats(values: Array[float]) -> Dictionary:
	values.sort()
	var total = 0.0
	for value in values: total += value
	return {"mean":total/maxi(1,values.size()),"p95":values[mini(values.size()-1,int(values.size()*.95))],"p99":values[mini(values.size()-1,int(values.size()*.99))],"max":values.back()}

func finish() -> void:
	evidence.timing_mode = timing_mode
	evidence.checks = checks; evidence.failures = failures
	preload("res://tests/test_report.gd").write(output+"/results.json",JSON.stringify(evidence,"\t"))
	print("STARTUP_SUITE ",checks," checks, ",failures.size()," failures ",JSON.stringify(evidence))
	quit(0 if failures.is_empty() else 1)
