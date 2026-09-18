extends "res://tests/performance_descent.gd"
## One excluded traversal then the packaged winter forest, without captures.
var winter_trial=0
func configure_comparison():
	assert(repetitions==2 and trial_seconds==15 and scenario_replay)
	assert(game.forest_appearance.active)
func prepare_comparison_trial(index:int):
	winter_trial=index;game.display_settings.reset_history()
func comparison_metadata()->Dictionary:
	return {"forest_style":"winter","excluded_route_warmup":winter_trial==0,"packaged_production_assets":true,"winter_background":game.world.wilderness.winter_forest}
