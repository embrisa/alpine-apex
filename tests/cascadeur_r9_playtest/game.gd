extends "res://tests/cascadeur_r8_playtest/game.gd"
const DeepSimulation=preload("res://tests/cascadeur_r9_playtest/simulation.gd")

func create_simulation(values:SkiTuning):return DeepSimulation.new(values)

func _ready() -> void:
	snow_trial_label="R9"
	snow_trial_experiment=DeepSimulation.DEEP_EXPERIMENT_ID
	snow_trial_output="res://artifacts/cascadeur_r9_live_playtest"
	await super._ready()

func _capture_ready() -> void:
	await super._capture_ready()
	if "--trial-smoke-exit" in OS.get_cmdline_user_args():get_tree().quit()
