extends "res://scripts/core/ski_simulation.gd"
## Explicit opt-in experimental contact model; never eligible for records.
const EXPERIMENT_ID="cascadeur-r8-pressure-snow-v1"
const PressureSupport=preload("res://tests/cascadeur_r8_playtest/snow_support.gd")
var pressure_enabled=true

func _init(values:SkiTuning=null) -> void:
	super._init(values)
	for ski in skis:ski.crush=PressureSupport.new(ski)

func step(dt:float,intent,surface) -> void:
	for ski in skis:
		ski.crush.tick_dt=dt
		ski.crush.trial_enabled=pressure_enabled
	super.step(dt,intent,surface)
