extends SceneTree
## Captures the actual native mixer output, including the loading ambience.
const Feedback = preload("res://scripts/ui/interface_feedback.gd")
const Loading = preload("res://scripts/ui/loading_overlay.gd")
var capture: AudioEffectCapture
var samples = PackedVector2Array()
var timeline: Array = []
var failures: Array = []
func _initialize(): call_deferred("run")
func collect(seconds: float) -> void:
 var until = Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<until:
  await process_frame
  var count = capture.get_frames_available()
  if count>0: samples.append_array(capture.get_buffer(count))
func marker(label: String) -> void:
 timeline.append({"event":label,"sample":samples.size()})
func run() -> void:
 if DisplayServer.get_name()=="headless": quit(2); return
 capture = AudioEffectCapture.new()
 capture.buffer_length = 2.0
 var index = AudioServer.get_bus_effect_count(0)
 AudioServer.add_bus_effect(0,capture,index)
 var feedback = Feedback.new()
 root.add_child(feedback)
 feedback.enabled = true; feedback.persist = false
 for id in Feedback.CUE_IDS:
  marker(id)
  feedback.play(id)
  await collect(.5)
 marker("rapid held adjustment")
 for i in 50:
  feedback.play("adjust")
  await collect(.01)
 await collect(.3)
 marker("volume 25 percent")
 feedback.volume = .25
 feedback.play("press")
 await collect(.5)
 marker("muted")
 feedback.muted = true
 feedback.play("error")
 var silent_start = samples.size()
 await collect(.4)
 var mute_peak = 0.0
 for i in range(silent_start,samples.size()): mute_peak = maxf(mute_peak,maxf(absf(samples[i].x),absf(samples[i].y)))
 if mute_peak>.00001: failures.append("Muted interface produced mixer samples")
 marker("loading ambience")
 var loading = Loading.new()
 root.add_child(loading)
 loading.audio_enabled = true
 loading.apply_preferences({"volume":.55,"muted":false,"loading_ambience":true,"reduced_motion":true})
 loading.begin("Loading mountain","Reading terrain")
 await collect(1.2)
 marker("loading ambience off")
 loading.apply_preferences({"volume":.55,"muted":false,"loading_ambience":false,"reduced_motion":true})
 await collect(.4)
 loading.finish()
 var pcm = PackedByteArray()
 pcm.resize(samples.size()*4)
 var peak = 0.0
 for i in samples.size():
  peak = maxf(peak,maxf(absf(samples[i].x),absf(samples[i].y)))
  pcm.encode_s16(i*4,roundi(clampf(samples[i].x,-1,1)*32767))
  pcm.encode_s16(i*4+2,roundi(clampf(samples[i].y,-1,1)*32767))
 var wav = AudioStreamWAV.new()
 wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.stereo=true; wav.mix_rate=roundi(AudioServer.get_mix_rate()); wav.data=pcm
 DirAccess.make_dir_recursive_absolute("res://artifacts/interface_feedback")
 wav.save_to_wav("res://artifacts/interface_feedback/native_mixer_timeline.wav")
 if peak<=.0001: failures.append("No audible mixer output captured")
 var result = {"timeline":timeline,"mix_rate":wav.mix_rate,"frames":samples.size(),"peak":peak,"mute_peak":mute_peak,"failures":failures,"device_listening":"not performed"}
 preload("res://tests/test_report.gd").write("res://artifacts/interface_feedback/native_mixer.json",JSON.stringify(result,"\t"))
 print("INTERFACE_AUDIO_CAPTURE ",JSON.stringify(result))
 AudioServer.remove_bus_effect(0,index)
 feedback.queue_free(); loading.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
