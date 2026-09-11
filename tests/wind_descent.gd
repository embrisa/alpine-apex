extends "res://tests/massif_playtest.gd"
## Uses the existing unranked v11 pilot. Capture and timing are separate runs.
var wind_record: AudioEffectRecord
var wind_bus: int = -1
var wind_capture = false
var wind_capture_frames = 0
var wind_capture_clock = 0.0
var wind_capture_busy = false
var wind_clip_path = "res://artifacts/wind/descent_frames"
var wind_capture_times: Array[float] = []
var wind_capture_start: float = 0.0

func descent() -> void:
	game.effects.muted = false
	game.effects.wind.volume = 1.0
	wind_capture = "--wind-capture" in OS.get_cmdline_user_args()
	if wind_capture:
		await _capture_descent()
		return
	await super.descent()
	_write_report()
	game.effects.stop_audio()
	await create_timer(.18).timeout

func _capture_descent() -> void:
	place_on_face(0,950)
	game.sim.velocity = game.sim.support_basis().z*25.0
	for i in 120: await process_frame
	DirAccess.make_dir_recursive_absolute(wind_clip_path)
	wind_record = AudioEffectRecord.new()
	wind_record.format = AudioStreamWAV.FORMAT_16_BITS
	wind_bus = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,wind_record)
	wind_capture_start = Time.get_ticks_usec()/1000000.0
	wind_record.set_recording_active(true)
	process_frame.connect(_wind_capture_frame)
	for i in 1440:
		game.intent = MassifPilot.intent(game.sim,field,face_index,side)
		game.intent.tuck = 1.0 if i>=480 and i<960 else 0.0
		await physics_frame
		game.sim.step(MassifPilot.DT,game.intent,game.world.ski_surface)
		game.skier.step_animation(MassifPilot.DT,game.sim,game.intent,field)
		if game.sim.crashed: break
	process_frame.disconnect(_wind_capture_frame)
	while wind_capture_busy: await process_frame
	wind_record.set_recording_active(false)
	var recording_audio: AudioStreamWAV = wind_record.get_recording()
	recording_audio.save_to_wav("res://artifacts/wind/descent.wav")
	AudioServer.remove_bus_effect(0,wind_bus)
	FileAccess.open("res://artifacts/wind/descent_frames.json",FileAccess.WRITE).store_string(JSON.stringify(wind_capture_times))
	await capture("wind_skiing")
	game.active = false
	game.hud.menu.hide()
	game.hud.weather_panel.show()
	_select_tab(game.hud.settings_tabs,"Audio")
	var audio_page = game.hud.settings_tabs.get_current_tab_control() as ScrollContainer
	var wind_group = _expand_group(audio_page,"Wind")
	for frame in 3: await process_frame
	audio_page.ensure_control_visible(wind_group)
	await capture("wind_controls")
	var report = _write_report()
	report.capture_frames = wind_capture_frames
	report.audio_frames = recording_audio.data.size()/4
	report.audio_rate = recording_audio.mix_rate
	report.scope = "12 seconds of simulated unranked skiing, starting at 90 km/h; video follows wall time"
	report.crash = game.sim.crash_reason
	FileAccess.open(OUTPUT+"/wind.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.effects.stop_audio()
	await create_timer(.18).timeout
	smoke = true # The capture is an explicitly short fixture, not a full descent.

func _write_report() -> Dictionary:
	var report = {"mode":game.effects.wind.label(),"native":game.effects.wind.diagnostics(),
		"wind_volume":game.effects.wind.volume,"capture_overhead_included":wind_capture,
		"native_paused":game.effects.wind.player.stream_paused,"unranked":not game.session.eligible,
		"wind_stream_bytes":FileAccess.get_file_as_bytes("res://addons/alpine_wind/bin/alpine_wind.windows.x86_64.dll").size()}
	FileAccess.open(OUTPUT+"/wind.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WIND_DESCENT ",JSON.stringify(report))
	return report

func _wind_capture_frame() -> void:
	# Short 12-second, 15 fps preview; readback is excluded from timing acceptance.
	if wind_capture_busy or wind_capture_frames>=600: return
	var now = Time.get_ticks_usec()/1000000.0
	if now-wind_capture_clock<1.0/15.0: return
	wind_capture_clock = now
	wind_capture_times.append(now-wind_capture_start)
	wind_capture_busy = true
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	frame.resize(1920,1080,Image.INTERPOLATE_BILINEAR)
	frame.save_jpg(wind_clip_path+"/%04d.jpg" % wind_capture_frames,0.86)
	wind_capture_frames += 1
	wind_capture_busy = false

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
