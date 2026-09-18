extends "res://tests/performance_descent.gd"
## Reuse the matching saved control; one excluded warm traversal and candidate.
var winter=preload("res://art_source/trees/meshy_snow_v1/family_library.gd").new()
var winter_trial=0
func configure_comparison():
	assert(repetitions==2 and trial_seconds==15 and scenario_replay)
	winter.setup(game.world);winter.select(true)
	for i in 30:await process_frame
func prepare_comparison_trial(index:int):
	winter_trial=index;game.display_settings.reset_history()
func comparison_metadata()->Dictionary:
	return {"candidate":true,"excluded_route_warmup":winter_trial==0,"verified_forest_batches":winter.validate_batches(),"inventory":winter.inventory,"representation":"Branch-built snowy conifers, existing bare birches, matching far cards; original transforms and shadows"}
func dispose_comparison():winter.select(false)
