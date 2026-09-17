extends "res://tests/performance_descent.gd"
## One shared startup and one excluded traversal before three warmed material arms.
var snow_modes = preload("res://tests/scenery_snow_modes.gd").new()
var snow_trial = 0
var shader_setup_ms = 0.0

func configure_comparison() -> void:
	assert(repetitions==4 and trial_seconds>0 and scenario_replay,"Use four bounded scenario trials: warmup, baseline, cheap, enhanced")
	var path = "res://artifacts/scenery_snow_cost/baseline"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--snow-baseline="): path = "res://"+arg.get_slice("=",1)
	var started = Time.get_ticks_usec()
	snow_modes.setup(game,path)
	# Compile all modes outside measurement. The complete first traversal also
	# warms the route's residency/collision path, not just its starting position.
	for mode in ["baseline","cheap","enhanced"]:
		snow_modes.select(mode)
		for i in 30: await process_frame
	shader_setup_ms = (Time.get_ticks_usec()-started)/1000.0

func prepare_comparison_trial(index: int) -> void:
	snow_trial = index
	snow_modes.select(["baseline","baseline","cheap","enhanced"][index])
	game.display_settings.reset_history()

func comparison_metadata() -> Dictionary:
	var result = snow_modes.report()
	result.excluded_route_warmup = snow_trial==0
	result.shared_shader_setup_ms = shader_setup_ms
	return result

func dispose_comparison() -> void: snow_modes.restore()
