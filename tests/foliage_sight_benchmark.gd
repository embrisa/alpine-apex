extends "res://tests/performance_descent.gd"
## Capture-free production trials: 0/50/100% strength, three warmed repetitions.
## Inherits trace/source/terrain and exact endpoint validation, never teleports.
var selected_strength = 0.0
var forest_trial_index = 0
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	trial_seconds = 15
	trial_start_seconds = 90
	repetitions = 9
	output = "res://artifacts/orchestration_20260912/forest/timing_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	await super.run()
func configure_comparison() -> void:
	if game.preferences_enabled: failures.append("Personal preferences enabled")
func prepare_comparison_trial(index: int) -> void:
	# The base supports recorded/personal camera geometry; pin this comparison
	# to the current Connected defaults before every independently warmed trial.
	game.camera_settings.reset()
	if "recorded_look" in game.camera: game.camera.recorded_look = []
	selected_strength = [0.0,50.0,100.0][index%3]
	forest_trial_index = index/3+1
	game.camera_settings.shared.forest_visibility = 60.0
	game.camera_settings.shared.forest_visibility_strength = selected_strength
	game.camera.effects_enabled = true
func comparison_metadata() -> Dictionary:
	return {"forest_strength_percent":selected_strength,"forest_reach_percent":60,"strength_repetition":forest_trial_index,"foliage_parameters":game.world.assets.foliage_sight.parameters,"forest_shader_sha256":FileAccess.get_sha256("res://assets/graphics/foliage_sight.gdshaderinc")}
