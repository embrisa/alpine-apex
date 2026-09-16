extends SceneTree
## Native mixer capture only: one original sting, silence gates and bus gain.
const Sequence = preload("res://scripts/ui/startup_sequence.gd")
var output = "res://artifacts/startup_20260914/audio"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Use the native mixer for startup audio evidence"); quit(2); return
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1280,720); Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(output)
	var master = AudioServer.get_bus_index("Master")
	var original_db = AudioServer.get_bus_volume_db(master)
	var original_mute = AudioServer.is_bus_mute(master)
	var recorder = AudioEffectRecord.new()
	AudioServer.add_bus_effect(master,recorder)
	var report: Array = []
	for mode in ["normal","muted","master_half","master_muted"]:
		AudioServer.set_bus_volume_db(master,-6.0206 if mode=="master_half" else 0.0)
		AudioServer.set_bus_mute(master,mode=="master_muted")
		var opening = Sequence.new()
		opening.audio_allowed = true
		opening.preferences = {"muted":mode=="muted","volume":.55,"loading_ambience":true}
		recorder.set_recording_active(true)
		root.add_child(opening)
		var start = Time.get_ticks_msec()
		var peak_db = -200.0
		while Time.get_ticks_msec()-start<2400:
			await process_frame
			# Bus meters follow effects, volume and mute in AudioServer; the WAV
			# effect tap is before bus gain and cannot prove Master attenuation.
			peak_db = maxf(peak_db,AudioServer.get_bus_peak_volume_left_db(master,0))
		recorder.set_recording_active(false)
		var recording = recorder.get_recording()
		recording.save_to_wav(output+"/"+mode+".wav")
		report.append({"mode":mode,"dispatches":opening.audio_dispatches,"bus":opening.player.bus,"master_db":AudioServer.get_bus_volume_db(master),"post_gain_peak_db":peak_db,"wav_tap":"before Master gain","stream_finished":not opening.player.playing})
		opening.queue_free(); await process_frame
	AudioServer.remove_bus_effect(master,AudioServer.get_bus_effect_count(master)-1)
	AudioServer.set_bus_volume_db(master,original_db)
	AudioServer.set_bus_mute(master,original_mute)
	preload("res://tests/test_report.gd").write(output+"/dispatch.json",JSON.stringify(report,"\t"))
	print("STARTUP_AUDIO_CAPTURE ",JSON.stringify(report))
	quit()
