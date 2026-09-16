extends SceneTree
## Native mixer evidence for deterministic delayed positional thunder and lifecycle gates.
const Weather = preload("res://scripts/presentation/weather_controller.gd")
const Storm = preload("res://scripts/presentation/storm_effects.gd")
var capture: AudioEffectCapture
var samples = PackedVector2Array()
var weather
var storm
var timeline = []
func _initialize() -> void: call_deferred("run")
func collect(seconds: float, active = true, muted = false, volume = 1.0) -> void:
	var until = Time.get_ticks_msec()+int(seconds*1000)
	var previous = Time.get_ticks_usec()
	while Time.get_ticks_msec()<until:
		await process_frame
		var now = Time.get_ticks_usec()
		weather.update_weather((now-previous)/1000000.0,active); previous = now
		storm.update_storm(weather.state,active,0,false,muted,volume)
		var available = capture.get_frames_available()
		if available>0: samples.append_array(capture.get_buffer(available))
func mark(label: String) -> void:
	timeline.append({"label":label,"sample":samples.size(),"weather_seconds":weather.active_seconds,"voices_played":storm.played_count})
func run() -> void:
	if DisplayServer.get_name()=="headless": printerr("Native mixer required"); quit(2); return
	Engine.max_fps = 120
	capture = AudioEffectCapture.new(); capture.buffer_length = 2.0
	var effect_index = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,capture,effect_index)
	var scene = Node3D.new(); root.add_child(scene)
	var camera = Camera3D.new(); scene.add_child(camera); camera.current = true
	weather = Weather.new(); scene.add_child(weather); weather.set_preset("thunderstorm")
	storm = Storm.new(); scene.add_child(storm); storm.layer_height = 600
	var event = Storm.event(weather.variation_seed,0)
	weather.active_seconds = event.at-.1
	weather.update_weather(0.001,true); storm.update_storm(weather.state,true,0,false,false,1)
	mark("before invisible lightning; thunder remains enabled")
	await collect(8.0)
	mark("mute active thunder")
	await collect(0.6,true,true)
	var mute_start = samples.size(); await collect(.4,true,true)
	var mute_peak = 0.0
	for i in range(mute_start,samples.size()): mute_peak = maxf(mute_peak,maxf(absf(samples[i].x),absf(samples[i].y)))
	mark("pause drops pending event")
	var next = Storm.event(weather.variation_seed,1)
	weather.active_seconds = next.at-.1; storm.clear_transients(weather.active_seconds)
	await collect(.3); await collect(.2,false)
	weather.active_seconds = next.thunder_at-.1
	var count = storm.played_count
	await collect(.5)
	mark("resume has no obsolete thunder")
	var pcm = PackedByteArray(); pcm.resize(samples.size()*4)
	var peak = 0.0
	for i in samples.size():
		peak = maxf(peak,maxf(absf(samples[i].x),absf(samples[i].y)))
		pcm.encode_s16(i*4,roundi(clampf(samples[i].x,-1,1)*32767)); pcm.encode_s16(i*4+2,roundi(clampf(samples[i].y,-1,1)*32767))
	var wav = AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true; wav.mix_rate = roundi(AudioServer.get_mix_rate()); wav.data = pcm
	var folder = "res://artifacts/weather_upgrade/audio"; DirAccess.make_dir_recursive_absolute(folder)
	wav.save_to_wav(folder+"/native_thunder.wav")
	var failures = []
	if peak<.0001: failures.append("No thunder captured")
	if peak>=1.0: failures.append("Mixer clipping")
	if mute_peak>.00001: failures.append("Muted thunder leaked")
	if count!=storm.played_count: failures.append("Paused thunder leaked after resume")
	var report = {"timeline":timeline,"peak":peak,"mute_peak":mute_peak,"voices":storm.players.size(),"events_played":storm.played_count,"frames":samples.size(),"sample_rate":wav.mix_rate,"failures":failures,"listening":"user equipment acceptance pending"}
	preload("res://tests/test_report.gd").write(folder+"/native_thunder.json",JSON.stringify(report,"\t"))
	print("STORM_AUDIO_RESULTS ",JSON.stringify(report))
	AudioServer.remove_bus_effect(0,effect_index)
	storm.clear_transients(); scene.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
