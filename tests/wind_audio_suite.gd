extends SceneTree
const Wind = preload("res://scripts/presentation/procedural_wind.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Weather = preload("res://scripts/presentation/weather_state.gd")
var failures: Array[String] = []
var checks = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func energy(buffer: PackedVector2Array) -> float:
	var total = 0.0
	for f in buffer: total += f.length_squared()*.5
	return total / maxi(buffer.size(),1)
func run() -> void:
	var original = AudioStreamPlayer.new()
	root.add_child(original)
	var wind = Wind.new()
	root.add_child(wind)
	wind.setup(original)
	check(not wind.persist,"Automated audition does not persist preferences")
	check(wind.mode==0 and wind.volume==1.0,"Procedural is the default at calibrated volume")
	var sim = Simulation.new(preload("res://config/ski_default.tres").duplicate())
	sim.heading = 0.0
	sim.velocity = Vector3(0,0,25)
	var weather = Weather.new()
	weather.wind_velocity = Vector3(0,0,-10)
	wind.sample(sim,weather,true,-25.0)
	check(is_equal_approx(wind.airflow.length(),35.0),"Headwind adds to relative airspeed")
	weather.wind_velocity = Vector3(0,0,10)
	wind.sample(sim,weather,true,-25.0)
	check(is_equal_approx(wind.airflow.length(),15.0),"Tailwind subtracts from relative airspeed")
	weather.enabled = false
	wind.sample(sim,weather,true,-25.0)
	check(is_equal_approx(wind.airflow.length(),25.0) and wind.gust==0,"Weather off retains motion-generated wind")
	var forward_air: Vector3 = wind.airflow
	sim.facing_backward = true
	wind.sample(sim,weather,true,-25.0)
	check(is_equal_approx(wind.airflow.z,-forward_air.z),"Backward facing changes head-relative airflow")
	sim.grounded = false
	wind.sample(sim,weather,true,-25.0)
	check(wind.audible,"Airborne skiing keeps wind")
	wind.restore({"mode":100,"volume":NAN})
	check(wind.mode==0 and wind.volume==1.0,"Invalid saved settings restore defaults")
	wind.restore({"mode":1,"volume":.4})
	check(wind.mode==1 and wind.volume==.4,"Comparison and volume round-trip")
	wind.advance(.2)
	check(wind.blend==0.0,"Comparison fades fully to Original")
	wind.restore({"mode":0,"volume":1.0})
	wind.available = false
	wind.advance(.2)
	check(wind.blend==0.0 and wind.label().contains("unavailable"),"Missing native stream falls back with an explanation")
	wind.available = wind.stream != null
	if "--wind-disable-native" in OS.get_cmdline_user_args():
		check(not wind.available,"Forced-unavailable path has no native stream")
	else:
		check(wind.available,"Installed Godot loads native wind extension")
		if wind.available:
			wind.stream.set_controls(Vector3(0,0,-25),0.0,0.5,1.0,true)
			var playback: AudioStreamPlayback = wind.stream.instantiate_playback()
			var second: AudioStreamPlayback = wind.stream.instantiate_playback()
			playback.start()
			second.start()
			var first = playback.mix_audio(1.0,48000)
			var another = second.mix_audio(1.0,48000)
			check(first.size()==48000 and energy(first)>0.00001,"Native callback produces audible stereo PCM")
			check(first!=another,"Two native playbacks have independent DSP histories")
			var finite = true
			var peak = 0.0
			for f in first:
				finite = finite and f.is_finite()
				peak = maxf(peak,maxf(absf(f.x),absf(f.y)))
			check(finite and peak<=0.501188,"Native PCM respects -6 dBFS ceiling")
			wind.stream.set_controls(Vector3(0,0,-25),1.0,1.0,0.0,false)
			playback.mix_audio(1.0,48000)
			check(energy(playback.mix_audio(1.0,512))<1e-12,"Native disable fades to silence")
			playback.stop()
			second.stop()
			check(not playback.is_playing() and playback.mix_audio(1.0,512).is_empty(),"Stopped playback returns no active audio frames")
			check(wind.diagnostics().blocks>0,"Native callback reports measured timing")
	wind.silence()
	check(not wind.audible,"Pause/mute gate silences immediately at the control boundary")
	wind.stop_audio()
	wind.queue_free()
	original.queue_free()
	await process_frame
	var result = {"checks":checks,"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://artifacts/wind")
	var label = "fallback" if "--wind-disable-native" in OS.get_cmdline_user_args() else "native"
	preload("res://tests/test_report.gd").write("res://artifacts/wind/"+label+"_suite.json",JSON.stringify(result,"\t"))
	print("WIND_AUDIO_RESULT ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
