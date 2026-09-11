extends "res://tests/cascadeur_r8_playtest/simulation.gd"
const DEEP_EXPERIMENT_ID="cascadeur-r9-deep-pressure-v1"

func _init(values:SkiTuning=null) -> void:
	super._init(values)
	for ski in skis:
		# Calibrated to about 17 cm boot world-Y separation in the strong-turn fixture.
		ski.crush.max_sink_m=.177
		ski.crush.penetration_scale=1.4
