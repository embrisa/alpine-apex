extends SceneTree
const Race = preload("res://scripts/racing/race_definition.gd")
var game
var checks = 0
var failures = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func fixture():
	var race = Race.new(); race.title = "Storm lifecycle"
	race.mountain = Race.mountain_reference(game.field,game.world.mountain.seed_value)
	race.start = Vector3(0,game.field.sample(0,25).height,25)
	race.finish = Vector3(0,game.field.sample(0,240).height,240)
	race.finish_heading = Race.Flavor.downhill_heading(game.field,race.finish)
	race.weather_preset = "thunderstorm"; race.time_band = "dusk"
	return race
func run() -> void:
	set_meta("test_map_fixture","short-course")
	game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game)
	while not game.initialized: await process_frame
	game.benchmark_no_captures = true
	game.set_process(false); game.set_physics_process(false)
	game.session.record_directory = "res://artifacts/weather_upgrade/records"
	game.session.benchmark_path = "res://artifacts/weather_upgrade/benchmark.json"
	game.weather.set_preset("snowfall"); game.weather.set_automatic(true); game.weather.set_time_cycle(true)
	game.weather.update_weather(game.weather.duration+13,true)
	var free_state: Dictionary = game.weather.snapshot()
	var manual: Dictionary = game.weather_preferences.snapshot()
	var race = Race.decode(fixture().share_text()).race
	check(race.validate_surface(game.field).is_empty(),"Storm fixture uses valid production gates")
	game.play_custom_race(race)
	check(game.session.race==race and game.weather.selected_preset=="thunderstorm" and game.weather.daylight.hour==17.5 and game.weather.active_seconds==0,"Starting a storm race publishes authored conditions at elapsed zero")
	check(game.free_weather_snapshot==free_state,"Initial free-ski blend is suspended intact")
	await capture("race_start")
	game.session.elapsed = 15; game._process(.2)
	check(game.weather.active_seconds==15 and game.weather.daylight.hour==17.5 and game.weather.free_seconds==free_state.free_seconds,"Race sampling uses elapsed race time and suspends free clocks")
	game.active = false; var race_state: Dictionary = game.weather.snapshot(); game._process(25)
	check(game.weather.snapshot()==race_state,"Pause consumes no race schedule or free progression")
	for option in [["manual_weather","rain"],["manual_time","night"],["automatic",true],["time_cycle",true],["quality",0]]:
		game.restart(); game.session.eligible = true # Disposable store exercises the production eligibility latch.
		match option[0]:
			"manual_weather": game.weather.set_preset(option[1])
			"manual_time": game.weather.set_time_of_day(option[1])
			"automatic": game.weather.set_automatic(option[1])
			"time_cycle": game.weather.set_time_cycle(option[1])
			"quality": game.set_display_setting("weather_quality",option[1])
		check(not game.session.eligible and not game.session.practice_reason.is_empty(),"Practice latches immediately on "+option[0])
		game.weather.set_preset("thunderstorm"); game.weather.set_time_of_day("dusk"); game.weather.set_automatic(false); game.weather.set_time_cycle(false); game.set_display_setting("weather_quality",2)
		check(not game.session.eligible,"Restoring controls cannot undo practice before retry: "+option[0])
		game.session.step(.1,race.finish+Vector3.FORWARD*2,race.finish+Vector3.BACK*2)
		check(game.session.finished and game.session.personal_best<0 and game.session.history.is_empty() and game.session.ghost_runs.is_empty(),"Practice finish cannot write PB/history/ghost: "+option[0])
		if option[0]=="manual_weather":
			game.hud.show_result(game.session,80)
			await capture("practice_finish")
	game.restart(); game.session.eligible = true
	game.set_display_setting("weather_quality",1); game._set_weather_option("lightning",0)
	check(game.session.eligible and game.session.practice_reason.is_empty(),"Low FX and disabled lightning retain eligibility")
	game.set_display_setting("weather_quality",0); game.restart()
	check(not game.session.practice_reason.is_empty(),"Retry with FX Off remains practice")
	game.set_display_setting("weather_quality",2); game.restart()
	check(game.session.practice_reason.is_empty() and game.weather.active_seconds==0 and game.weather.cloud_offset==Vector2.ZERO,"Valid retry clears the condition latch and resets weather schedule")
	var other = fixture(); other.title = "Snowstorm alternate"; other.weather_preset = "snowstorm"; other.time_band = "night"
	game.play_custom_race(other)
	check(game.free_weather_snapshot==free_state and game.weather.selected_preset=="snowstorm","Race switching retains the original free snapshot")
	game._remember_world_settings()
	var remembered: Dictionary = get_meta("weather_application")
	check(remembered.free==free_state and remembered.live.selected_preset=="snowstorm","World-rebuild handoff carries live race and initial free-ski state separately")
	game.start_run(false)
	check(game.weather.snapshot().selected_preset==free_state.selected_preset and game.weather.phase_seconds==free_state.phase_seconds and game.weather.rng.state==free_state.rng_state and game.weather.cloud_offset==free_state.cloud_offset and game.free_weather_snapshot.is_empty(),"Leaving restores blend/RNG/cloud continuity")
	check(game.weather_preferences.values.manual_weather==manual.choices.manual_weather and game.weather_preferences.values.manual_time==manual.choices.manual_time and game.weather_preferences.values.automatic==manual.choices.automatic,"Race controls never overwrite personal weather/time fallbacks")
	game.play_custom_race(race)
	var invalid = fixture(); invalid.start.y += 40
	game.play_custom_race(invalid)
	check(game.session.race==null and game.free_weather_snapshot.is_empty() and game.weather.selected_preset==free_state.selected_preset,"Failed race validation restores free ski even during a race switch")
	var before_preferences: Dictionary = game.weather_preferences.snapshot()
	game.weather.update_weather(900,true)
	check(game.weather_preferences.snapshot()==before_preferences,"Routine front/daylight updates do not mutate preference storage")
	game.weather.set_preset("cloudy"); game.weather.pending_storm = "thunderstorm"
	game.play_custom_race(race); game._set_weather_option("rare_storms",false); game.start_run(false)
	game.weather._next_phase(true)
	check(game.weather.pending_storm.is_empty() and game.weather.target_preset in game.weather.Rules.ORDINARY,"Disabling Rare storms during a race cancels a suspended planned storm")
	await capture("free_ski_restored")
	var before_launch: Dictionary = game.weather_preferences.snapshot()
	game._remember_world_settings()
	var old_weather = game.weather
	game.weather_preferences = preload("res://scripts/presentation/weather_preferences.gd").new()
	game._initialize_weather(); old_weather.queue_free()
	check(game.weather_preferences.last_weather==before_launch.last_weather and game.weather_preferences.last_band==before_launch.last_band,"Application reload reuses launch history without drawing again")
	check(not game.preferences_enabled,"Script fixture keeps personal stores isolated")
	var report = {"checks":checks,"failures":failures}
	FileAccess.open("res://artifacts/weather_upgrade/lifecycle.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WEATHER_LIFECYCLE_RESULTS ",JSON.stringify(report))
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for frame in 3: game._process(0.0); await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/weather_upgrade/lifecycle_native")
	root.get_texture().get_image().save_png("res://artifacts/weather_upgrade/lifecycle_native/"+label+".png")
