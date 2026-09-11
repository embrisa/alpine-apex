extends SceneTree
## Production input, simulation and rendering on the explicit laboratory fixture.
const Pad = preload("res://tests/controller_input_suite.gd")
const DT = 1.0/120.0
const OUT = "res://artifacts/controller_input_v1/visual"
var game
var observer: Camera3D
var caption: Label
var rows: Array = []
var failures: Array = []

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	set_meta("test_lab_fixture",true)
	DirAccess.make_dir_recursive_absolute(OUT)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized: await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.effects.haptic_hardware_enabled = false
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "native"
	game.display_settings.render_scale = 1.0
	game.display_settings.fps_limit = 60
	game.display_settings.apply_display(root,Vector2i(1920,1080))
	game.display_settings.apply_viewport(root)
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.start_speed_lab(65)
	game.effects.muted = true; game.voice.set_muted(true)
	game.automated = false # Production router must receive our synthetic pad events.
	game.session.eligible = false
	Pad.axis(JOY_AXIS_TRIGGER_LEFT,0.0)
	Pad.button(JOY_BUTTON_LEFT_SHOULDER,false)
	game.camera.effects_enabled = false
	game.hud.hide()
	observer = Camera3D.new(); observer.fov = 50; observer.near = .05
	game.add_child(observer)
	var layer = CanvasLayer.new(); root.add_child(layer)
	caption = Label.new(); caption.position = Vector2(28,24)
	caption.add_theme_font_size_override("font_size",24)
	layer.add_child(caption)
	for frame in 30: await process_frame
	await ride("Left stick forward: tuck",0.0,-1.0,90)
	await capture("01_forward_tuck")
	if game.sim.effective_tuck<.95: failures.append("Forward did not tuck")
	await ride("Diagonal steering: automatic open stance",.7071,-.7071,30)
	await capture("02_diagonal_turn")
	if game.sim.effective_tuck>.04: failures.append("Steering did not open tuck")
	await ride("Return forward: tuck resumes",0.0,-1.0,90)
	await capture("03_tuck_resumes")
	if game.sim.effective_tuck<.95: failures.append("Forward did not resume tuck")
	Pad.axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	await ride("Hold R2: prepare",0.0,0.0,30)
	await capture("04_r2_prepare")
	if not game.intent.jump_held or not game.sim.grounded: failures.append("R2 hold did not prepare on snow")
	Pad.axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	await ride("Release R2: hop",0.0,0.0,5)
	await capture("05_r2_hop")
	if game.sim.grounded: failures.append("R2 release did not hop")
	await ride("Landing: small contacts stay quiet",0.0,0.0,60)
	await capture("06_landing")
	game.active = false
	game.hud.show(); game.hud.show_menu("paused"); game.hud.open_settings()
	_select_tab(game.hud.settings_tabs,"Controls")
	var help_page = game.hud.settings_tabs.get_current_tab_control() as ScrollContainer
	var skiing_help = _expand_group(help_page,"Skiing")
	_expand_group(help_page,"Air control")
	for frame in 3: await process_frame
	help_page.ensure_control_visible(skiing_help)
	caption.hide()
	game._process(1.0/60.0)
	await capture("07_controller_guide")
	var result = {"model":game.sim.MODEL_VERSION,"fixture":"laboratory","unranked":not game.session.eligible,"hardware_output":false,"cases":rows,"failures":failures}
	FileAccess.open(OUT+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CONTROLLER_VISUAL_RESULTS ",JSON.stringify(result))
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func ride(label: String, x: float, y: float, frames: int) -> void:
	caption.text = label
	for frame in frames:
		# Reapply the synthetic sample immediately before stepping: native SDL
		# device polling between frames may replace a one-shot injected axis.
		Pad.axis(JOY_AXIS_LEFT_X,x); Pad.axis(JOY_AXIS_LEFT_Y,y)
		for tick in 2: game._physics_process(DT)
		game._process(1.0/60.0)
		var center: Vector3 = game.sim.position+Vector3.UP*.85
		var basis: Basis = game.sim.support_basis()
		observer.global_position = center+basis.x*4.5+basis.z*2.0+Vector3.UP*.65
		observer.look_at(center)
		observer.make_current()
		await process_frame

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var picture = root.get_texture().get_image()
	picture.save_png(OUT+"/"+name+".png")
	rows.append({"name":name,"pixels":[picture.get_width(),picture.get_height()],"tuck":game.sim.effective_tuck,"input_tuck":game.intent.tuck,"input_steer":game.intent.steer,"input_brake":game.intent.brake,"jump_held":game.intent.jump_held,"grounded":game.sim.grounded,"crashed":game.sim.crashed,"haptic_output":str(game.effects.haptic_output)})
	if game.sim.crashed: failures.append(name+": unexpected crash")

func _select_tab(tabs: TabContainer, caption: String) -> void:
	for index in tabs.get_tab_count():
		if tabs.get_tab_title(index)==caption:
			tabs.current_tab = index
			return
	assert(false,"Missing tab: "+caption)

func _expand_group(page: Control, caption: String) -> Control:
	for button in page.find_children("*","Button",true,false):
		if button.has_meta("group_body") and button.text.ends_with(caption):
			button.button_pressed = true
			return button.get_meta("group_body")
	assert(false,"Missing settings group: "+caption)
	return null
