extends "res://scripts/main.gd"
const CandidateAsset=preload("res://tests/cascadeur_r7_playtest/candidate_asset.gd")
const CandidateMotion=preload("res://tests/cascadeur_r7_playtest/live_motion.gd")
var trial_motion
var trial_status:Label
var trial_button:Button
var trial_ready=false
var controls_checked=false
func _ready() -> void:
	await super._ready()
	if not initialized:return
	trial_motion=CandidateMotion.new();trial_motion.candidate=CandidateAsset.load_for(skier)
	skier.animation.full_motion=trial_motion;skier.reset_animation(sim)
	session.eligible=false;session.recording=null
	_build_trial_controls();trial_ready=true
	get_window().title="Alpine Apex | Cascadeur R7 carving comparison"
	if "--cascadeur-ui-check" in OS.get_cmdline_user_args():
		var key=InputEventKey.new();key.physical_keycode=KEY_F9;key.pressed=true
		_input(key);assert(not trial_motion.candidate_enabled)
		_input(key);assert(trial_motion.candidate_enabled)
		restart();assert(not session.eligible and session.recording==null)
		controls_checked=true
	start_run(false)
	if not summit_ready:active=false;hud.show_menu("paused")
	hud.toast("CARVING COMPARISON · F9 SWITCHES ANIMATIONS")
	_capture_ready.call_deferred()
func restart(preserve_return:bool=false) -> void:
	super.restart(preserve_return)
	session.eligible=false;session.recording=null
func _build_trial_controls() -> void:
	var layer=CanvasLayer.new();layer.layer=25;add_child(layer)
	var panel=PanelContainer.new();layer.add_child(panel);panel.position=Vector2(18,150)
	var style=StyleBoxFlat.new();style.bg_color=Color(.035,.05,.07,.86);style.set_content_margin_all(12);style.set_corner_radius_all(6);panel.add_theme_stylebox_override("panel",style)
	var box=VBoxContainer.new();panel.add_child(box)
	trial_status=Label.new();trial_status.add_theme_font_size_override("font_size",18);box.add_child(trial_status)
	var help=Label.new();help.text="F9 compare  ·  A/D or left stick to carve\nTry linked turns and release  ·  C changes camera  ·  Unranked";box.add_child(help)
	trial_button=Button.new();trial_button.text="Compare with current carving";trial_button.pressed.connect(_toggle_trial);box.add_child(trial_button)
func _toggle_trial() -> void:
	if not trial_ready:return
	trial_motion.candidate_enabled=not trial_motion.candidate_enabled
	trial_button.text="Compare with current carving" if trial_motion.candidate_enabled else "Use Cascadeur carving"
func _input(event:InputEvent) -> void:
	if not trial_ready or not event is InputEventKey or not event.pressed or event.echo:return
	if event.physical_keycode==KEY_F9:_toggle_trial();get_viewport().set_input_as_handled()
func _process(dt:float) -> void:
	super._process(dt)
	if not trial_ready:return
	trial_status.text="CASCADEUR R7 CARVING" if trial_motion.candidate_enabled else "CURRENT CARVING"
	if trial_motion.candidate_enabled:trial_status.text+="  /  "+("TURNING" if trial_motion.applied_amount>.05 else "READY")
	if not trial_motion.enabled:trial_status.text+="  ·  F8: skeletal motion disabled"
	trial_button.visible=not active or hud.menu.visible or summit_ready
func _capture_ready() -> void:
	for frame in 3:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output="res://artifacts/cascadeur_r7_live_playtest"
	DirAccess.make_dir_recursive_absolute(output)
	get_viewport().get_texture().get_image().save_png(output+"/ready.png")
	var report={"ready":trial_ready,"manual_input":not automated,"generator":field.GENERATOR_ID,"model":sim.MODEL_VERSION,"candidate_sha256":CandidateAsset.SOURCE_SHA,"unranked":not session.eligible,"summit_ready":summit_ready,"scene":scene_file_path,"F9_and_restart_checked":controls_checked}
	FileAccess.open(output+"/ready.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CASCADEUR_CARVING_READY ",JSON.stringify(report))
