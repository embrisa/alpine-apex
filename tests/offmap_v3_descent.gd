extends "res://tests/performance_descent.gd"
## Complete ordinary-input descents; only the apron/panorama presentation swaps.
var fixture
var baseline = true
var trial_weather = "clear"
var render_sources: Dictionary
func configure_comparison() -> void:
	fixture = preload("res://tests/offmap_v2_fixture.gd").new()
	await fixture.build(game.world)
	repetitions=4
	render_sources=game.world.wilderness.source_hashes()
func prepare_comparison_trial(index: int) -> void:
	game.camera_settings.reset() # Pin Connected/default foliage aid in memory; never save preferences.
	baseline=index%2==1 # Current Clear first, also shared with the camera acceptance report.
	trial_weather="clear" if index<2 else "snowfall"
	game.weather.set_preset(trial_weather); game.weather.set_time_of_day("day")
	fixture.select(game.world,baseline)
func comparison_metadata() -> Dictionary:
	return {"offmap_version":2 if baseline else 3,"trial_weather":trial_weather,"offmap":game.world.wilderness.report(),"stable_render_sources":render_sources==game.world.wilderness.source_hashes()}
func dispose_comparison() -> void:
	fixture.select(game.world,false); fixture.dispose()
