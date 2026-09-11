extends "res://scripts/main.gd"
## Separate playable scene. Normal main.tscn and its production motion stay unchanged.
const CandidateAsset=preload("res://tests/cascadeur_r6_playtest/candidate_asset.gd")
const CandidateMotion=preload("res://tests/cascadeur_r6_playtest/live_motion.gd")
var trial_motion
var trial_status:Label
var trial_buttons:HBoxContainer
var trial_toggle:Button
var trial_ready=false
func _ready() -> void:
	await super._ready()
	if not initialized:return
	trial_motion=CandidateMotion.new();trial_motion.candidate=CandidateAsset.load_for(skier)
	skier.animation.full_motion=trial_motion;skier.reset_animation(sim)
	session.eligible=false;session.recording=null
	_build_trial_controls();trial_ready=true
	get_window().title="Alpine Apex | Cascadeur R6 playtest"
	print("CASCADEUR_PLAYTEST_READY ",JSON.stringify({"candidate":CandidateAsset.SOURCE_SHA,"manual_input":not automated,"generator":field.GENERATOR_ID,"model":sim.MODEL_VERSION,"unranked":not session.eligible}))
	if "--cascadeur-smoke" in OS.get_cmdline_user_args():_smoke.call_deferred()
	else:
		start_run(false)
		if not summit_ready:
			active=false;hud.show_menu("paused")
		hud.toast("CASCADEUR R6 · F9 COMPARE · F10 REPLAY SEQUENCE")
		if "--cascadeur-ready-capture" in OS.get_cmdline_user_args():_capture_ready.call_deferred()
func _capture_ready() -> void:
	for frame in 3:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output="res://artifacts/cascadeur_r6_live_playtest"
	DirAccess.make_dir_recursive_absolute(output)
	get_viewport().get_texture().get_image().save_png(output+"/ready.png")
	FileAccess.open(output+"/ready.json",FileAccess.WRITE).store_string(JSON.stringify({"ready":trial_ready,"manual_input":not automated,"generator":field.GENERATOR_ID,"model":sim.MODEL_VERSION,"candidate_sha256":CandidateAsset.SOURCE_SHA,"unranked":not session.eligible,"summit_ready":summit_ready,"scene":scene_file_path},"\t"))
func restart(preserve_return:bool=false) -> void:
	super.restart(preserve_return)
	# super may prepare a recording; no tick or result save occurs before this.
	session.eligible=false;session.recording=null
func _build_trial_controls() -> void:
	var layer=CanvasLayer.new();layer.layer=25;add_child(layer)
	var panel=PanelContainer.new();layer.add_child(panel)
	panel.position=Vector2(18,150)
	var style=StyleBoxFlat.new();style.bg_color=Color(.035,.05,.07,.86);style.set_content_margin_all(12);style.set_corner_radius_all(6);panel.add_theme_stylebox_override("panel",style)
	var box=VBoxContainer.new();panel.add_child(box)
	trial_status=Label.new();trial_status.add_theme_font_size_override("font_size",18);box.add_child(trial_status)
	var help=Label.new();help.text="F9 compare  ·  F10 replay  ·  Tuck starts the 2-second sequence\nNormal ski controls  ·  R6 grounded motion  ·  Unranked playtest";box.add_child(help)
	trial_buttons=HBoxContainer.new();box.add_child(trial_buttons)
	trial_toggle=Button.new();trial_toggle.text="Compare with production";trial_toggle.pressed.connect(_toggle_trial);trial_buttons.add_child(trial_toggle)
	var replay_button=Button.new();replay_button.text="Replay R6 sequence";replay_button.pressed.connect(func():trial_motion.replay());trial_buttons.add_child(replay_button)
func _toggle_trial() -> void:
	if not trial_ready:return
	trial_motion.candidate_enabled=not trial_motion.candidate_enabled
	trial_toggle.text="Compare with production" if trial_motion.candidate_enabled else "Use Cascadeur R6"
func _input(event:InputEvent) -> void:
	if not trial_ready or not event is InputEventKey or not event.pressed or event.echo:return
	if event.physical_keycode==KEY_F9:
		_toggle_trial();get_viewport().set_input_as_handled()
	elif event.physical_keycode==KEY_F10:
		trial_motion.replay();get_viewport().set_input_as_handled()
func _process(dt:float) -> void:
	super._process(dt)
	if not trial_ready:return
	trial_status.text=("CASCADEUR R6" if trial_motion.candidate_enabled else "PRODUCTION ANIMATIONS")+"  /  "+("READY" if trial_motion.candidate_time>=2.0 else "SEQUENCE %.1f / 2.0 s"%trial_motion.candidate_time)
	trial_buttons.visible=not active or hud.menu.visible or summit_ready
	# Existing F8 comparison can disable skeletal motion; make that state explicit.
	if not trial_motion.enabled:trial_status.text+="  ·  F8: skeletal motion disabled"
func _smoke() -> void:
	var output="res://artifacts/cascadeur_r6_live_smoke"
	DirAccess.make_dir_recursive_absolute(output)
	automated=true;benchmark_input=func(_tick):
		var result=RiderInput.new();result.tuck=.65 if sim.ticks>30 and sim.ticks<210 else 0.0;result.steer=.12 if sim.ticks>100 and sim.ticks<180 else 0.0;return result
	start_run(false);summit_ready=false;effects.muted=true
	var start_tick:int=sim.ticks
	while sim.ticks<start_tick+300 and not sim.crashed:await get_tree().process_frame
	assert(not sim.crashed and sim.ticks>=start_tick+300 and not session.eligible and session.recording==null)
	active=false;skier.pose(sim,1.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/candidate.png")
	var event=InputEventKey.new();event.physical_keycode=KEY_F9;event.pressed=true;_input(event)
	assert(not trial_motion.candidate_enabled)
	_input(event);assert(trial_motion.candidate_enabled)
	event.physical_keycode=KEY_F10;_input(event);assert(trial_motion.pending_replay)
	restart();assert(not session.eligible and session.recording==null)
	var report={"passed":true,"model":sim.MODEL_VERSION,"candidate_sha256":CandidateAsset.SOURCE_SHA,"simulated_ticks":300,"F9_toggle":true,"F10_replay":true,"restart_unranked":true,"manual_controller_acceptance":false}
	FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CASCADEUR_PLAYTEST_SMOKE ",JSON.stringify(report));get_tree().quit()
