extends "res://tests/cascadeur_r8_playtest/physics_suite.gd"
const DeepTrial=preload("res://tests/cascadeur_r9_playtest/simulation.gd")

func _initialize():
	sink_limit_m=.177;experiment=DeepTrial.DEEP_EXPERIMENT_ID
	output_folder="res://artifacts/cascadeur_r9_contact"
	call_deferred("run")

func make_sim(field,trial:bool,enabled:bool=true,speed:float=18.0):
	if not trial:return super.make_sim(field,false,enabled,speed)
	var sim=DeepTrial.new();sim.pressure_enabled=enabled
	sim.reset(Vector3.ZERO);sim.prime_contacts(field);sim.velocity=sim.support_basis().z*speed;sim.reset_pose_history()
	return sim
