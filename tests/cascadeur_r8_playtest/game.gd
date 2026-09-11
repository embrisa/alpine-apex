extends "res://tests/cascadeur_r7_playtest/game.gd"
const TrialSimulation=preload("res://tests/cascadeur_r8_playtest/simulation.gd")
var snow_trial_label="R8"
var snow_trial_experiment=TrialSimulation.EXPERIMENT_ID
var snow_trial_output="res://artifacts/cascadeur_r8_live_playtest"

func create_simulation(values:SkiTuning):
	return TrialSimulation.new(values)

func _ready() -> void:
	await super._ready()
	if not initialized:return
	get_window().title="Alpine Apex | Cascadeur %s snow and leg comparison"%snow_trial_label
	trial_button.text="Compare with current snow contacts"
	for child in trial_status.get_parent().get_children():
		if child is Label and child!=trial_status:
			child.text="F9 compare snow contacts · R7 hands in both modes\nA/D or left stick to carve · C changes camera · Unranked"
	if "--cascadeur-snow-ui-check" in OS.get_cmdline_user_args():
		var key=InputEventKey.new();key.physical_keycode=KEY_F9;key.pressed=true
		_input(key);assert(not sim.pressure_enabled and trial_motion.candidate_enabled)
		_input(key);assert(sim.pressure_enabled and trial_motion.candidate_enabled)
		restart();assert(not session.eligible and session.recording==null)
		controls_checked=true
	hud.toast("SNOW / LEG COMPARISON · F9 SWITCHES CONTACTS")

func _toggle_trial() -> void:
	if not trial_ready:return
	sim.pressure_enabled=not sim.pressure_enabled
	trial_button.text="Compare with current snow contacts" if sim.pressure_enabled else "Use pressure-dependent snow"

func _process(dt:float) -> void:
	super._process(dt)
	if not trial_ready:return
	trial_status.text=snow_trial_label+" · PRESSURE IN SOFT SNOW" if sim.pressure_enabled else "CURRENT SNOW CONTACTS"
	var right=sim.skis[0].crush.effective_pressure_m*100.0
	var left=sim.skis[1].crush.effective_pressure_m*100.0
	trial_status.text+="\nSinking: R %.1f cm / L %.1f cm"%[right,left]

func _capture_ready() -> void:
	for frame in 3:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output=snow_trial_output
	DirAccess.make_dir_recursive_absolute(output)
	get_viewport().get_texture().get_image().save_png(output+"/ready.png")
	var report={"ready":trial_ready,"manual_input":not automated,"base_model":sim.MODEL_VERSION,"experiment":snow_trial_experiment,"pressure_enabled":sim.pressure_enabled,"R7_hands_enabled":trial_motion.candidate_enabled,"unranked":not session.eligible,"scene":scene_file_path,"F9_and_restart_checked":controls_checked,"laboratory":"--test-lab" in OS.get_cmdline_user_args()}
	FileAccess.open(output+"/ready.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CASCADEUR_SNOW_CARVING_READY ",JSON.stringify(report))
