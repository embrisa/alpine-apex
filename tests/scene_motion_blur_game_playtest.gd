extends SceneTree
## Full-resolution production-component review on the authored mixed fixture.
## Short matched ordinary-input poses; capped capture is never FPS evidence.
var game
var failures: Array[String] = []
var checks = 0
var phases: Array = []
var output = "res://artifacts/scene_motion_blur/game"
var scenario = "fast"
var reference_states: Dictionary = {}
var transitions_only = false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures.append(caption); printerr("FAIL: ",caption)

func input_at(tick: int) -> RiderInput:
	var value = RiderInput.new()
	if scenario!="fast": return value
	value.tuck = 1.0 if tick<120 else 0.0
	value.steer = 0.08 if tick in range(65,145) else -0.08 if tick in range(200,260) else 0.0
	value.jump_held = tick in range(125,150)
	value.jump = tick==150
	value.brake = 0.65 if tick>=260 else 0.0
	return value

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--blur-output="): output="res://"+arg.get_slice("=",1)
		if arg=="--transitions-only": transitions_only=true
	set_meta("test_map_fixture","perf-mixed")
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	game = load("res://main.tscn").instantiate()
	game.automated = true; root.add_child(game)
	while not game.initialized or game.loading.busy: await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.preferences_enabled = false; game.effects.muted = true
	game.hud.feedback.muted = true; game.hud.feedback.reduced_motion = false
	game.display_settings.upscaler = "auto"; game.display_settings.frame_generation = false
	game.display_settings.fps_limit = 30; game.display_settings.display_mode = "fullscreen"
	game.display_settings.apply_display(root,Vector2i(3840,2160)); game.display_settings.apply_viewport(root)
	game.weather.set_automatic(false); game.weather.set_time_cycle(false)
	game.weather.set_preset("snowfall"); game.weather.set_time_of_day("day")
	game.benchmark_input = input_at
	for i in 4: await process_frame
	check(root.size==Vector2i(3840,2160),"Production-component review renders actual 4K output: "+str(root.size))
	for z in [125.0,245.0]:
		var gate=load("res://assets/graphics/flavor_v1/scenes/start_gate.tscn").instantiate()
		game.world.add_child(gate)
		gate.position=Vector3(0,game.field.sample(0,z).height,z)
	check(game.world.wilderness==null and game.world.preparation==null,"Authored mixed fixture avoids full mountain construction")
	for view in ["chase","first_person"]:
		for strength in ([0.0,100.0] if transitions_only else [0.0,50.0,100.0]): await phase(view,strength,false)
	if not transitions_only:
		await phase("chase",100.0,true)
		for kind in ["low","still"]:
			scenario=kind
			for view in ["chase","first_person"]:
				for strength in [0.0,100.0]: await phase(view,strength,false)
	game.active = false; game.hud.show_menu("paused")
	game.hud.open_settings(); game.hud.settings_tabs.current_tab = 1
	var ui = game.hud.camera_options
	for i in game.hud.settings_tabs.get_tab_count():
		if game.hud.settings_tabs.get_tab_title(i)=="Camera": game.hud.settings_tabs.current_tab = i
	ui.groups["Motion effects"].button.button_pressed = true
	ui.groups["Motion effects"].content.show()
	game._process(1.0/30.0)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/camera_controls.png")
	check(not game.scene_motion_blur.enabled,"Paused settings suppress compositor")
	check(not game.preferences_enabled and not game.session.eligible,"No personal preferences or ranked records")
	var report = {"checks":checks,"failures":failures,"phases":phases,"engine":Engine.get_version_info(),"output_pixels":root.size,"display":game.display_settings.report(root,root.size),"graphics":game.graphics.snapshot(),"map":game.field.fixture_descriptor(),"fps_cap":30,"performance_acceptance":false,"scenario":"3 s ordinary-input sequences at initial 200 and 8 km/h plus stationary, both views; gates, mixed trees/rocks, crest/compression, snow, manual look and combined effects. Scripted captured poses, not controller acceptance."}
	preload("res://tests/test_report.gd").write(output+"/report.json",JSON.stringify(report,"\t"))
	print("SCENE_BLUR_GAME_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"output":output}))
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func phase(view: String, strength: float, combined: bool) -> void:
	game.camera.close_view = view=="first_person"
	game.camera_settings.reset()
	game.camera_settings.update_profile(view,{"motion_blur_enabled":true,"motion_blur_strength":strength,"blur_strength":50.0 if combined else 0.0,"streak_strength":50.0 if combined else 0.0})
	game.start_speed_lab(200 if scenario=="fast" else 8 if scenario=="low" else 0)
	var z=160.0 if scenario=="fast" else 64.0
	var velocity: Vector3=game.sim.velocity
	game.sim.reset(Vector3(0,game.field.sample(0,z).height,z),0.0)
	game.sim.prime_contacts(game.field); game.sim.velocity=velocity
	game.previous_position=game.sim.position; game.skier.reset_animation(game.sim)
	game.camera.reset(); game.camera.make_current(); game.hud.hide_menu()
	game.weather.visual_time=0.0; game.weather_effects.reset()
	game.camera.effects_enabled = true
	game.application_focused = true # Isolated scripted presentation, no window focus.
	for i in 12:
		game._process(1.0/30.0)
		await process_frame
	var before: int = game.scene_motion_blur.status().dispatches
	var name = "%s_%s_%d%s" % [scenario,view,int(strength),"_combined" if combined else ""]
	var samples: Array = []
	var airborne = false
	var was_grounded: bool=game.sim.grounded
	for frame in 90:
		if scenario!="still":
			for tick in 4: game._physics_process(1.0/120.0)
		if scenario=="fast" and frame>66: game.camera.add_mouse_look(Vector2(8,0))
		game._process(1.0/30.0)
		airborne = airborne or not game.sim.grounded
		var transition: bool=was_grounded!=game.sim.grounded
		if transition or (not transitions_only and frame in [0,33,48,69,86]):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_webp(output+"/%s_%02d.webp" % [name,frame],true,.95)
			samples.append({"frame":frame,"tick":game.sim.ticks,"speed_kmh":game.sim.velocity.length()*3.6,"position":game.sim.position,"airborne":not game.sim.grounded,"transition":transition,"crashed":game.sim.crashed,"blur":game.scene_motion_blur.status()})
		was_grounded=game.sim.grounded
		await process_frame
	var status = game.scene_motion_blur.status()
	check(status.unavailable.is_empty(),name+" supported on production game buffers")
	check((status.dispatches>before)==(strength>0.0),name+" real game dispatch matches strength")
	check(not game.sim.crashed,name+" completes bounded sequence without crash")
	var end_state=[game.sim.position,game.sim.velocity,game.sim.ticks]
	if not reference_states.has(scenario): reference_states[scenario]=end_state
	check(reference_states[scenario]==end_state,name+" matches ordinary simulation across views and strengths")
	phases.append({"name":name,"samples":samples,"airborne_observed":airborne,"final_tick":game.sim.ticks,"blur":status})
	print("SCENE_BLUR_GAME_PHASE ",name," ",JSON.stringify(status))
