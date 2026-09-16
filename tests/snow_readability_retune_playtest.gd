extends "res://tests/snow_readability_playtest.gd"
## Compare the previous balanced treatment with its slightly stronger tuning.
## The new tint is exactly 1.4 times the old displacement from white, so a
## reciprocal strength reconstructs the previous material without shader swaps.

func select_look(old: bool) -> void:
	before = old
	for material in current_shaders:
		material.set_shader_parameter("snow_hollows_strength",1.0/1.4 if old else 1.0)
	game.world.render_state.clear(); game.world.weather_values.clear()
	game.world.update_weather(game.weather.state,0,false)
	game.world.environment.ssao_light_affect = .15 if old else .20
	game.display_settings.reset_history()

func read_sources() -> Dictionary:
	var result = super.read_sources()
	for path in ["tests/snow_readability_retune_playtest.gd","tests/alpine_v13_playtest.gd"]:
		result[path] = FileAccess.get_sha256("res://"+path)
	return result

func save_report() -> void:
	super.save_report()
	var path = OUTPUT+"/report.json"
	var report = JSON.parse_string(FileAccess.get_file_as_string(path))
	report.comparison_description = "Previous balanced snow (10% hollow shading, 0.15 direct AO) versus stronger snow (14%, 0.20) on the same default v15 Standard mountain."
	report.generator_version = Definition.CURRENT_VERSION
	preload("res://tests/test_report.gd").write(path,JSON.stringify(report,"\t"))

func stills() -> void:
	for site in snow_sites:
		for condition in ["clear","cloudy","snowfall"]:
			reset_site(site,condition,false)
			game.skier.hide(); observer.make_current()
			observer.position = game.sim.position+Vector3.UP*1.8
			observer.look_at(observer.position+game.sim.ski_forward+Vector3.DOWN*.35)
			for look in [true,false]:
				select_look(look); await capture_pair(site.name+"_"+condition)
	# Additional sun angles, all track presets, and night retain the same camera.
	reset_site(snow_sites[2],"clear",false)
	game.skier.hide(); observer.make_current()
	observer.position = game.sim.position+Vector3.UP*1.8
	var sun: Vector3 = game.weather.state.sun_direction
	for angle in [0,90,180]:
		var direction = Vector3(sun.x,0,sun.z).normalized().rotated(Vector3.UP,deg_to_rad(angle))
		observer.look_at(observer.position+direction+Vector3.DOWN*.35)
		for look in [true,false]:
			select_look(look); await capture_pair("bank_sun_%d"%angle)
	for level in [0,1,2]:
		game.set_graphics_quality(level); Engine.max_fps = 30
		reset_site(snow_sites[0],"clear",false)
		for i in 90:
			step_frame(4); await process_frame
		game.active = false; game.skier.hide(); observer.make_current()
		observer.position = game.sim.position+Vector3.UP*8-game.sim.ski_forward*9
		observer.look_at(game.sim.position-game.sim.ski_forward*7)
		for look in [true,false]:
			select_look(look); await capture_pair("tracks_quality_%d"%level)
	reset_site(snow_sites[-1],"clear",false)
	game.weather.set_time_of_day("night")
	for look in [true,false]:
		select_look(look); await capture_pair("forest_night")
	for close in [false,true]:
		for look in [true,false]: await ride(snow_sites[0],"clear",close,look,false)

func timings() -> void:
	game.display_settings.fps_limit = 120; Engine.max_fps = 120
	process_frame.connect(_measure)
	for look in [true,false,false,true]:
		for site in [snow_sites[0],snow_sites[-1]]:
			await ride(site,"clear",false,look,true)
