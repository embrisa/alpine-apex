extends "res://tests/massif_playtest.gd"
## Isolate wind cost in one unchanged rendered scene, under the same background load.
func descent() -> void:
	game.effects.muted = false
	place_on_face(0,950)
	game.sim.velocity = game.sim.support_basis().z*25.0
	game.sim.effective_tuck = 0.35
	process_frame.connect(_measure)
	var passes: Array = []
	for mode in [1,0,0,1]:
		recording = false
		game.effects.wind.mode = mode
		game.weather.visual_time = 0.0
		await create_timer(2.0).timeout
		frames.clear(); gpu_ms.clear(); render_cpu_ms.clear(); draws.clear()
		last_frame = 0; previous_recording = false
		recording = true
		await create_timer(15.0).timeout
		recording = false
		var pass_result = {"mode":game.effects.wind.label(),"frame_ms":frame_timing(frames),
			"render_cpu_ms":timing(render_cpu_ms),"render_gpu_ms":timing(gpu_ms),
			"native":game.effects.wind.diagnostics(),"engine_video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
		passes.append(pass_result)
		print("WIND_AB_PASS ",JSON.stringify(pass_result))
	process_frame.disconnect(_measure)
	var report = {"scope":"Fixed skier pose and velocity; rendered audio-cost isolation, not a physics descent",
		"actual_pixels":[actual_pixels.x,actual_pixels.y],"display":game.display_settings.report(root,actual_pixels),
		"passes":passes,"unranked":not game.session.eligible}
	preload("res://tests/test_report.gd").write("res://artifacts/wind/ab_benchmark.json",JSON.stringify(report,"\t"))
	game.effects.stop_audio()
	await create_timer(.18).timeout
	smoke = true
