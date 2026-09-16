extends SceneTree
## Native integration / settings / captured audio. Records use an artifact store.
var game
var checks: int = 0
var failures: Array[String] = []
var cues: Array = []
var native: bool = false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func settle() -> void:
	for i in 8: await process_frame
func capture(id: String) -> void:
	await settle()
	if native:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/voice/"+id+".png")
func run() -> void:
	native = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute("res://artifacts/voice")
	set_meta("test_lab_fixture",true)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	Engine.max_fps = 60
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.initialized: await process_frame
	game.set_physics_process(false)
	game.session.benchmark_path = "res://artifacts/voice/disposable_benchmark.json"
	game.session.record_directory = "res://artifacts/voice/disposable_records"
	game.hud.feedback.persist = false
	game.hud.feedback.muted = true
	game.effects.muted = true
	game.voice.set_muted(false)
	check(not game.voice.persist,"Scripted native run cannot change personal voice preferences")
	game.voice.cue_started.connect(func(id,event): cues.append({"id":id,"event":event,"seconds":game.voice.clock_seconds}))
	game.start_run(true)
	game.voice.silence()
	game.voice.next_riding_reaction = 0.0
	game.voice.next_reaction = 0.0 # Isolate the air hook from a probabilistic start cue.
	var cue_seed = 0
	while true:
		game.voice.rng.seed = cue_seed
		if game.voice.rng.randf()<0.5:
			game.voice.rng.seed = cue_seed
			break
		cue_seed += 1
	game.session.eligible = false
	game.sim.grounded = false
	game.sim.position.y += 80.0
	game.sim.velocity = Vector3(0,8,25)
	for tick in 370: game._physics_process(1.0/120.0)
	check(cues.any(func(c): return c.event=="big_air"),"Main's completed physics ticks trigger the real big-air hook")
	await capture("air_hook")
	game.active = false
	check(not game.voice.player.playing,"Pause stops native reaction playback")
	game.restart()
	game.session.eligible = false
	game.sim.crashed = true
	game.sim.crash_reason = "Voice integration fixture"
	game._physics_process(1.0/120.0)
	check(game.voice.current_event=="crash" and not game.active,"Crash menu transition retains the crash reaction")
	game.restart()
	game.session.eligible = true
	game.session.personal_best = 999.0
	game.session.previous_best = 999.0
	game.session.finish_z = game.sim.position.z+0.01
	game.sim.velocity = Vector3(0,0,25)
	game._physics_process(1.0/120.0)
	check(game.session.finished and game.voice.current_event=="personal_best","A saved finish through Main announces PB after the result menu opens")
	await capture("pb_hook")
	if not native:
		# Exercise the boundary finish's synchronous reduced-motion reset, where
		# session PB flags disappear before the return-completed callback.
		game.voice.reset()
		game.voice._process(3.0) # A separate result episode, beyond the result cooldown.
		game.current_mountain = preload("res://scripts/world/mountain_definition.gd").new()
		game.mountain_zone.enabled = true
		game.hud.feedback.reduced_motion = true
		game._begin_summit_return(true)
		check(not game.session.new_best and game.voice.current_event=="personal_best","Boundary finish preserves its verified PB through the summit session reset")
		game.mountain_zone.enabled = false
		game.current_mountain = null
	game.timed = true
	game.restart()
	game.session.eligible = true
	game.session.personal_best = 0.000001
	game.session.previous_best = -1.0
	game.session.finish_z = game.sim.position.z+0.01
	game.sim.velocity = Vector3(0,0,25)
	game._physics_process(1.0/120.0)
	check(game.session.finished and game.voice.current_event=="finish","Missing comparison data uses a normal finish reaction")
	game.active = false
	game.hud.open_settings()
	_select_tab(game.hud.settings_tabs,"Audio")
	var audio_page = game.hud.settings_tabs.get_current_tab_control() as ScrollContainer
	_expand_group(audio_page,"Skier voice")
	await settle()
	var panel = game.hud.voice_settings
	audio_page.ensure_control_visible(panel.selection)
	await settle()
	check(panel.volume.is_visible_in_tree() and panel.selection.is_visible_in_tree(),"Expanded Audio voice group exposes volume and auditions")
	check(root.get_visible_rect().encloses(panel.selection.get_global_rect()),"Voice audition fits 1280x720")
	var voice_column = panel.selection.get_parent()
	var play_button = voice_column.find_child("PlaySkierReaction",true,false)
	audio_page.ensure_control_visible(play_button)
	await settle()
	check(audio_page.get_global_rect().encloses(play_button.get_global_rect()),"Audition action is fully visible inside the scroll viewport at 720p")
	panel.volume.value = 0.5
	check(is_equal_approx(game.voice.volume,0.5),"Settings slider controls live voice volume")
	panel.enabled.button_pressed = false
	check(not game.voice.request("personal_best",true),"Disabled reactions cannot play through preview")
	panel.enabled.button_pressed = true
	panel.volume.value = 0.75
	game.voice.preview("breathing")
	_select_tab(game.hud.settings_tabs,"Display")
	await settle()
	check(not game.voice.audition_active and not game.voice.breath_wanted,"Leaving Audio stops its voice audition")
	_select_tab(game.hud.settings_tabs,"Audio")
	await capture("settings_720p")
	root.size = Vector2i(3840,2160)
	await capture("settings_4k")
	check(audio_page.get_global_rect().encloses(play_button.get_global_rect()),"Audition action is fully visible inside the scroll viewport at 4K")
	var record: AudioEffectRecord
	var bus = AudioServer.bus_count
	if native:
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus,"VoiceReview")
		game.voice.player.bus = "VoiceReview"
		game.voice.breath_player.bus = "VoiceReview"
		record = AudioEffectRecord.new()
		record.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(bus,record)
		record.set_recording_active(true)
		# Native playback of the automatic recovery scheduler, using a settled
		# hip-speed fixture. Ragdoll movement itself is covered by its own suite.
		game.set_process(false)
		game.voice.set_process(false)
		game.voice.silence()
		game.voice._process(61.0)
		game.voice.begin_crash()
		var recovery_start = cues.size()
		for tick in 45:
			game.voice._process(0.1)
			game.voice.observe_crash(0.1,0.0,true)
			await create_timer(0.1).timeout
		check(cues.slice(recovery_start).any(func(c): return c.event=="crash_after"),"Native settled-hip fixture plays the automatic post-crash reaction")
		game.voice.set_process(true)
		game.set_process(true)
		for event in ["big_air","air_huge","land_big","landing_bad","impact_small","impact","nearmiss","injured","terrain_cliff","terrain_tight","terrain_open","speed_high","crash","crash_after","breathing","finish","finish_good","finish_bad","personal_best","race_record"]:
			game.voice.preview(event)
			var duration: float = game.voice.breath_player.stream.get_length() if event=="breathing" else game.voice.player.stream.get_length()
			await create_timer(duration+0.6).timeout
		game.set_audio_muted(true)
		check(not game.voice.player.playing and not game.voice.breath_player.playing,"M / global mute stops both native players")
		await create_timer(0.5).timeout
		record.set_recording_active(false)
		var audio: AudioStreamWAV = record.get_recording()
		check(audio != null and audio.data.size()>48000,"Native audio bus captured the supplied voices")
		if audio: audio.save_to_wav("res://artifacts/voice/native_audition.wav")
		game.voice.player.bus = "Master"
		game.voice.breath_player.bus = "Master"
		AudioServer.remove_bus(bus)
	var result = {"checks":checks,"failures":failures,"native_audio":native,"cues":cues,"note":"Controlled integration fixture; does not establish subjective skier performance or full-mountain FPS."}
	preload("res://tests/test_report.gd").write("res://artifacts/voice/playtest.json" if native else "res://artifacts/voice/integration.json",JSON.stringify(result,"\t"))
	game.effects.stop_audio()
	game.voice.silence()
	game.queue_free()
	await settle()
	print("VOICE_PLAYTEST_RESULT ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func _select_tab(tabs: TabContainer, caption: String) -> void:
	for index in tabs.get_tab_count():
		if tabs.get_tab_title(index)==caption:
			tabs.current_tab = index
			return
	assert(false,"Missing tab: "+caption)

func _expand_group(page: Control, caption: String) -> Control:
	for button in page.find_children("*","Button",true,false):
		if button.has_meta("group_body") and button.text.ends_with(caption):
			button.button_pressed = true
			return button.get_meta("group_body")
	assert(false,"Missing settings group: "+caption)
	return null
