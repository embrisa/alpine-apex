extends "res://tests/massif_playtest.gd"
## Same full v13 world/pose and event sequence before/after the native change.
## Isolates audio overhead; this is not a traversal or player-feel benchmark.
func run() -> void:
	# Exercise the device callback without repeatedly sounding the stress fixture.
	AudioServer.set_bus_volume_db(0,-80)
	Engine.max_fps = 30
	await super.run()

func descent() -> void:
	Engine.max_fps = 120
	game.effects.muted = false
	game.voice.enabled = false
	game.effects.sfx.mode = 0
	game.effects.wind.mode = 0
	var baseline = "--audio-baseline" in OS.get_cmdline_user_args()
	if baseline: game.effects.sfx.bind_equipment_source(null)
	game.hud.hide_menu()
	process_frame.connect(_measure)
	var results: Array = []
	var identity = {}
	for file in ["native/wind/sfx_dsp.h","addons/alpine_wind/bin/alpine_wind.windows.x86_64.dll","scripts/core/ski_simulation.gd","config/ski_default.tres","scripts/main.gd","scripts/presentation/procedural_sfx.gd","tests/natural_audio_benchmark.gd","scripts/presentation/skier_visual.gd","scripts/presentation/skier_equipment.gd","assets/graphics/models/skier_v7.glb","assets/graphics/pc_lod.gdshaderinc"]:
		identity[file] = FileAccess.get_sha256("res://"+file)
	if baseline: identity["native/wind/sfx_dsp.h"] = FileAccess.get_sha256("res://artifacts/natural_audio/baseline/native/wind/sfx_dsp.h")
	print("NATURAL_AUDIO_BENCHMARK_READY baseline=",baseline)
	for section in [950,2170]:
		place_on_face(0,section)
		game.sim.velocity = game.sim.support_basis().z*25.0
		game.sim.effective_tuck = .35
		for ski in game.sim.skis:
			ski.velocity = game.sim.velocity
			ski.load_n = 400
			ski.grounded = true
		game.active = true
		game.weather.visual_time = 0
		await create_timer(3.0).timeout
		frames.clear(); gpu_ms.clear(); render_cpu_ms.clear(); draws.clear()
		last_frame = 0; previous_recording = false; recording = true
		var elapsed = 0.0
		var next_event = 0.0
		while elapsed<12.0:
			await process_frame
			var dt = root.get_process_delta_time()
			elapsed += dt
			game.effects.sfx.observe_tick(game.sim,field,dt)
			if elapsed>=next_event:
				next_event += .25
				for i in 8:
					game.effects.sfx.stream.push_event(1 if i<4 else 2,1 if i%2==0 else 2,12,(i-3.5)/5,.7)
		recording = false
		var result = {"section_m":section,"frame_ms":frame_timing(frames),"cpu_ms":timing(render_cpu_ms),"gpu_ms":timing(gpu_ms),"native_sfx":game.effects.sfx.diagnostics(),"native_wind":game.effects.wind.diagnostics(),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}
		results.append(result)
		print("NATURAL_AUDIO_TIMING ",JSON.stringify(result))
	process_frame.disconnect(_measure)
	var report = {"scope":"Full v13 mountain; fixed skier pose/velocity, repeated impacts and equipment events; audio overhead isolation, not traversal","actual_pixels":[actual_pixels.x,actual_pixels.y],"display":game.display_settings.report(root,actual_pixels),"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"version":version,"seed":mountain_seed,"source_sha256":identity,"passes":results,"unranked":not game.session.eligible,"capture_overhead":false}
	preload("res://tests/test_report.gd").write(OUTPUT+"/natural_audio.json",JSON.stringify(report,"\t"))
	game.effects.stop_audio()
	await create_timer(.18).timeout
	smoke = true
