extends "res://tests/alpine_v12_playtest.gd"
var sfx_capture=false
var sfx_recorder: AudioEffectRecord
var sfx_frames: Array[Dictionary]=[]
var sfx_capture_start=0.0
var sfx_last_capture=0.0
var sfx_capture_busy=false
var sfx_mode="procedural"

func run() -> void:
	# Bound upload staging during startup; steady-state timing is still 120 FPS.
	Engine.max_fps=30
	process_frame.connect(_startup_pacing)
	await super.run()

func _startup_pacing() -> void:
	if game==null or not game.initialized or (game.loading and game.loading.busy):
		Engine.max_fps=30
	else:
		Engine.max_fps=120
		process_frame.disconnect(_startup_pacing)

func descent() -> void:
	var report_path="res://artifacts/alpine_v12/survey_%d.json" % mountain_seed
	var route=JSON.parse_string(FileAccess.get_file_as_string(report_path)) if FileAccess.file_exists(report_path) else null
	if route!=null and route.height_sha256==field.height_checksum and route.obstacle_sha256==field.obstacle_checksum:
		surveyed_path=route.surveys[face_index].paths[0 if side<0 else 1]
	else:
		surveyed_path=Survey.survey(field,face_index).paths[0 if side<0 else 1].map(func(p):return [p.x,p.y])
	if surveyed_path.is_empty(): printerr("No traversable v12 route for audio test");return
	sfx_capture="--sfx-capture" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sfx-mode="): sfx_mode=arg.get_slice("=",1)
	game.effects.muted=false
	game.voice.enabled=false # Identical repeatable mix, without random dialogue.
	game.effects.sfx.change_setting("mode",1 if sfx_mode=="original" else 0)
	if sfx_capture:
		await _audition()
		smoke=true
		return
	var face=field.faces[face_index]
	game.sim.reset(field.launch_point(face.heading),face.heading)
	game.sim.prime_contacts(field)
	if start_z>0: place_on_face(face_index,start_z)
	game.previous_position=game.sim.position;game.camera.reset()
	for i in 120: await process_frame
	var initial_sfx_frames: int=game.effects.sfx.diagnostics().get("frames",0)
	process_frame.connect(_measure)
	recording=true
	var ticks=0
	for i in 100000:
		ticks=i+1
		if i%12==0: game.intent=pilot_intent()
		await physics_frame
		var begin=Time.get_ticks_usec()
		game.sim.step(MassifPilot.DT,game.intent,game.world.ski_surface)
		game.skier.step_animation(MassifPilot.DT,game.sim,game.intent,field)
		game.observe_audio_tick(MassifPilot.DT)
		physics_us.append(Time.get_ticks_usec()-begin)
		game.session.elapsed+=MassifPilot.DT
		if game.sim.crashed or field.reached_base(game.sim.position) or local_z()>=end_z: break
	recording=false
	var report={"mode":sfx_mode,"generator_version":version,"seed":mountain_seed,"face":face_index,"seconds":ticks*MassifPilot.DT,"peak_kmh":game.sim.peak_speed*3.6,"crash":game.sim.crash_reason,"section_completed":field.reached_base(game.sim.position) or local_z()>=end_z,"actual_pixels":[actual_pixels.x,actual_pixels.y],"display":game.display_settings.report(root,actual_pixels),"frame_ms":frame_timing(frames),"render_gpu_ms":timing(gpu_ms),"render_cpu_ms":timing(render_cpu_ms),"physics_step_us":timing(physics_us),"peak_video_bytes":peak_video_bytes,"native_sfx":game.effects.sfx.diagnostics(),"native_wind":game.effects.wind.diagnostics(),"unranked":not game.session.eligible,"capture_overhead_included":false,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"engine":Engine.get_version_info().string}
	FileAccess.open(OUTPUT+"/sfx.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	report["sfx_frames_during_measurement"]=int(game.effects.sfx.diagnostics().get("frames",0))-initial_sfx_frames
	report["native_sfx_paused"]=game.effects.sfx.player.stream_paused
	report["audio_audible"]=game.effects.sfx.audible
	report["startup_fps_cap"]=30
	FileAccess.open(OUTPUT+"/sfx.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SFX_DESCENT ",JSON.stringify(report))
	game.effects.stop_audio()
	await create_timer(.2).timeout

func _audition() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/sfx/capture")
	place_on_face(face_index,900,false)
	game.sim.velocity=game.sim.support_basis().z*25
	game.hud.hide_menu()
	sfx_recorder=AudioEffectRecord.new();sfx_recorder.format=AudioStreamWAV.FORMAT_16_BITS
	var effect_index=AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,sfx_recorder)
	sfx_capture_start=Time.get_ticks_usec()/1000000.0
	sfx_recorder.set_recording_active(true)
	process_frame.connect(_capture_audio_frame)
	for i in 1200:
		game.intent=pilot_intent()
		if i>400 and i<650: game.intent.brake=.6
		await physics_frame
		game.sim.step(MassifPilot.DT,game.intent,game.world.ski_surface)
		game.skier.step_animation(MassifPilot.DT,game.sim,game.intent,field)
		game.observe_audio_tick(MassifPilot.DT)
		if game.sim.crashed: break
	if not game.sim.crashed: game.sim.crash("AUDIO CRASH FIXTURE")
	game.skier.ragdoll.start(game.sim)
	game.active=false
	game.hud.show_menu("crashed","Audio crash fixture · unranked")
	await create_timer(5.0).timeout
	process_frame.disconnect(_capture_audio_frame)
	while sfx_capture_busy: await process_frame
	sfx_recorder.set_recording_active(false)
	var wav=sfx_recorder.get_recording()
	wav.save_to_wav("res://artifacts/sfx/capture/skiing_crash.wav")
	AudioServer.remove_bus_effect(0,effect_index)
	FileAccess.open("res://artifacts/sfx/capture/frames.json",FileAccess.WRITE).store_string(JSON.stringify(sfx_frames))
	var report={"native_sfx":game.effects.sfx.diagnostics(),"native_wind":game.effects.wind.diagnostics(),"audio_rate":wav.mix_rate,"audio_frames":wav.data.size()/4,"capture_frames":sfx_frames.size(),"unranked":true,"capture_overhead_included":true,"crash_fixture":true}
	FileAccess.open("res://artifacts/sfx/capture/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.effects.stop_audio()
	game.skier.ragdoll.stop()
	game.hud.weather_panel.show()
	_select_tab(game.hud.settings_tabs,"Audio")
	var audio_page = game.hud.settings_tabs.get_current_tab_control() as ScrollContainer
	var sound_group = _expand_group(audio_page,"Skiing sounds")
	for frame in 3: await process_frame
	audio_page.ensure_control_visible(sound_group)
	await capture("audio_settings")
	await create_timer(.2).timeout

func _capture_audio_frame() -> void:
	var now=Time.get_ticks_usec()/1000000.0
	if sfx_capture_busy or now-sfx_last_capture<.1: return
	sfx_last_capture=now;sfx_capture_busy=true
	await RenderingServer.frame_post_draw
	var name="frame_%04d.jpg" % sfx_frames.size()
	root.get_texture().get_image().save_jpg("res://artifacts/sfx/capture/"+name,.88)
	sfx_frames.append({"time":now-sfx_capture_start,"file":name})
	sfx_capture_busy=false

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
