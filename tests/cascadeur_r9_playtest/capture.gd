extends "res://tests/cascadeur_r8_playtest/capture.gd"
const DeepTrial=preload("res://tests/cascadeur_r9_playtest/simulation.gd")

func _initialize():
	revision_base="res://artifacts/pose_review/revisions/cascadeur-20260911-r9-02-"
	call_deferred("run")

func make_simulations():return [TrialSim.new(),DeepTrial.new()]
func experiment_for(sim):return DeepTrial.DEEP_EXPERIMENT_ID if sim is DeepTrial else TrialSim.EXPERIMENT_ID
func hashes():
	var result=super.hashes();hash_dir("res://tests/cascadeur_r9_playtest",result);return result
