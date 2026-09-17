extends "res://tests/performance_descent.gd"
## One startup and one excluded traversal, then one arm per optional quality.
var shadow_trial=0
var atlas_loads: Array=[]
func configure_comparison() -> void:
	assert(repetitions==4 and trial_seconds>0 and scenario_replay,"Use warmup, Off, Low, High with one matched bounded route")
	for quality in [0,1,2]:
		await select_quality(quality)
		atlas_loads.append(game.world.wilderness.horizon.report())
		for i in 30: await process_frame

func select_quality(quality: int) -> void:
	var profile=game.graphics.duplicate(); profile.offmap_shadow_quality=quality
	await game.world.wilderness.apply_quality(profile)
	game.world.update_weather(game.weather.state,0.0,false)
	game.display_settings.reset_history()

func prepare_comparison_trial(index: int) -> void:
	shadow_trial=index
	await select_quality([0,0,1,2][index])

func comparison_metadata() -> Dictionary:
	var wilderness=game.world.wilderness
	var materials=[wilderness.material,wilderness.apron_material]+wilderness.props.materials
	var bound=true
	for material in materials:
		bound=bound and material.get_shader_parameter("offmap_horizon_enabled")==bool([0,0,1,2][shadow_trial])
	return {"excluded_route_warmup":shadow_trial==0,"shadow_quality":[0,0,1,2][shadow_trial],"horizon":wilderness.horizon.report(),"initial_atlas_loads":atlas_loads,"all_shadow_receivers_bound":bound,"shadow_receiver_count":materials.size()}
