extends "res://tests/targeted_performance.gd"
## Small production-component weather cost, using the normal solver and telemetry.
## Day/night deliberately look up so the measured frame contains the sky.
var weather_case="day"
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--weather-case="):weather_case=arg.get_slice("=",1)
	assert(weather_case in ["day","night","storm"])
	super._initialize()

func prepare_start()->void:
	super.prepare_start()
	game.weather.set_preset("snowstorm" if weather_case=="storm" else "clear")
	game.weather.set_time_of_day("night" if weather_case=="night" else "day")
	if weather_case!="storm":
		game.camera_settings.update_profile("chase",{"rest_tilt":20.0,"fast_tilt":20.0,"slope_follow":0.0})
		game.camera.reset()
	game.world.update_weather(game.weather.state,0,true)

func capture_source_metadata(phase:String)->Dictionary:
	return metadata_command(["capture","--root",ProjectSettings.globalize_path("res://"),
		"--scope",ProjectSettings.globalize_path("res://config/benchmark_metadata_scope.json"),
		"--producer","tests/weather_presentation_cost.gd","--extra-path","tests/targeted_performance.gd",
		"--engine",OS.get_executable_path()],output.path_join("inputs_"+phase+".json"))

func finish()->void:
	report.weather_case=weather_case
	if game and game.initialized:
		report.weather_preset=game.weather.selected_preset
		report.time_of_day=game.weather.daylight.hour
		report.particle_budget=game.weather_effects.particle_budget()
		report.cloud_offset=str(game.weather.cloud_offset)
	await super.finish()
