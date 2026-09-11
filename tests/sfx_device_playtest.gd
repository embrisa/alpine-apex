extends SceneTree
const Sfx = preload("res://scripts/presentation/procedural_sfx.gd")
var failures: Array[String]=[]
var checks=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2);return
	if "--quiet-audio" in OS.get_cmdline_user_args(): AudioServer.set_bus_volume_db(0,-80)
	var control=Sfx.new();root.add_child(control)
	if not control.available: quit(2);return
	var recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
	var index=AudioServer.get_bus_effect_count(0);AudioServer.add_bus_effect(0,recorder)
	recorder.set_recording_active(true)
	control.audible=true
	control.stream.set_mix(Vector4.ONE,true)
	control.stream.set_ski_controls(0,25,7,.6,400,.2,.12,0,0,true)
	await create_timer(.4).timeout
	check(control.diagnostics().frames>0,"Audio device requests SFX samples")
	control.stream.push_event(1,1,12,.3,.5)
	await create_timer(.3).timeout
	check(control.diagnostics().events_started>0,"Device callback consumes impact event")
	control.silence()
	await create_timer(.35).timeout
	control.player.stream_paused=true
	await create_timer(.1).timeout
	var frame_count=control.diagnostics().frames
	await create_timer(.2).timeout
	check(control.diagnostics().frames==frame_count,"Original mode can suspend native callback work")
	control.player.stream_paused=false
	control.audible=true;control.stream.set_mix(Vector4.ONE,true)
	await create_timer(.2).timeout
	check(control.diagnostics().frames>frame_count,"Native stream resumes after suspension")
	var retiring=control.player
	control.stop_audio();control.queue_free()
	await process_frame
	check(is_instance_valid(retiring),"Playback survives controller destruction for its fade")
	await create_timer(.25).timeout
	check(not is_instance_valid(retiring),"Retired playback is released")
	recorder.set_recording_active(false)
	DirAccess.make_dir_recursive_absolute("res://artifacts/sfx")
	var recording=recorder.get_recording()
	recording.save_to_wav("res://artifacts/sfx/device.wav")
	AudioServer.remove_bus_effect(0,index)
	var report={"checks":checks,"failures":failures,"mix_rate":AudioServer.get_mix_rate(),"device":AudioServer.get_output_device()}
	FileAccess.open("res://artifacts/sfx/device_suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SFX_DEVICE_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
