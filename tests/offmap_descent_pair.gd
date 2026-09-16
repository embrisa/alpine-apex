extends "res://tests/massif_playtest.gd"
## Four complete descents share one loaded simulation, terrain and tuning.
## This prevents concurrent physics edits from changing the comparison halfway.
func descent() -> void:
	var output_root = OUTPUT
	var fixture = preload("res://tests/offmap_fixture.gd").new()
	fixture.build(game.world)
	var trials: Array = []
	var loaded_simulation_sha256: String = game.sim.get_script().source_code.sha256_text()
	for condition in ["clear","snowfall"]:
		for baseline in [true,false]:
			weather = condition
			game.weather.set_preset(condition)
			game.weather.set_time_of_day("day")
			game.start_run(false); game.summit_ready = false
			game.session.eligible = false
			fixture.select(game.world,baseline)
			OUTPUT = output_root+"/"+("baseline_" if baseline else "upgraded_")+condition
			DirAccess.make_dir_recursive_absolute(OUTPUT)
			frames.clear(); forest_frames.clear(); gpu_ms.clear(); render_cpu_ms.clear()
			draws.clear(); physics_us.clear(); segment_frames.clear()
			last_frame = 0; previous_recording = false; recording = false; peak_video_bytes = 0
			for i in 300: await process_frame
			await super.descent()
			if process_frame.is_connected(_measure): process_frame.disconnect(_measure)
			var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"/native_%d_%s.json" % [side,weather]))
			result.baseline = baseline
			result.loaded_simulation_sha256 = loaded_simulation_sha256
			result.loaded_model_version = game.sim.MODEL_VERSION
			result.both_scenery_versions_resident = true
			result.scenery_sha256 = game.world.wilderness.source_hashes()
			trials.append(result)
			preload("res://tests/test_report.gd").write(output_root+"/paired.json",JSON.stringify({"trials":trials,"same_process":true,"unranked":true},"\t"))
	fixture.select(game.world,false); fixture.dispose()
	OUTPUT = output_root
