extends "res://tests/performance_descent.gd"
## One excluded route traversal, one current control, one candidate.
## The retained older forest route is generator 17 and cannot qualify v18.
var snow=preload("res://art_source/trees/meshy_snow_v1/library.gd").new()
var snow_trial=0
func configure_comparison():
	assert(repetitions==3 and trial_seconds==15 and scenario_replay)
	snow.setup(game.world)
	for arm in [true,false]:
		snow.select(arm)
		for i in 30:await process_frame
func prepare_comparison_trial(index:int):
	snow_trial=index;snow.select(index==2);game.display_settings.reset_history()
func comparison_metadata()->Dictionary:
	return {"candidate":snow.active,"excluded_route_warmup":snow_trial==0,"inventory":snow.inventory,"production_assets_changed":false,"representation":"Matched near, local simplified mid, eight-view two-triangle far cards"}
func dispose_comparison():snow.select(false)
