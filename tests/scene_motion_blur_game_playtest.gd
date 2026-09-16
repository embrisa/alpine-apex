extends SceneTree
## 18 s total ordinary-input skiing plus a 3 s combined-effects check, capped
## at 30 rendered FPS. Isolated lab; no PB writes, input capture or fullscreen.
var game
var failures: Array[String] = []
var checks = 0
var phases: Array = []
var output = "res://artifacts/scene_motion_blur/game"

func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures.append(caption); printerr("FAIL: ",caption)

func input_at(tick: int) -> RiderInput:
	var value = RiderInput.new()
	value.tuck = 1.0 if tick<120 else 0.0
	value.steer = 0.35 if tick in range(65,145) else -0.3 if tick in range(200,260) else 0.0
	value.jump_held = tick in range(125,150)
	value.jump = tick==150
	value.brake = 0.65 if tick>=260 else 0.0
	return value

func run() -> void:
	set_meta("test_lab_fixture",true)
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	game = load("res://main.tscn").instantiate()
	game.automated = true; root.add_child(game)
	while not game.initialized or game.loading.busy: await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.preferences_enabled = false; game.effects.muted = true
	game.hud.feedback.muted = true; game.hud.feedback.reduced_motion = false
	game.display_settings.upscaler = "auto"; game.display_settings.frame_generation = false
	game.display_settings.fps_limit = 30; game.display_settings.display_mode = "windowed"
	game.display_settings.apply_display(root,Vector2i(960,540)); game.display_settings.apply_viewport(root)
	game.weather.set_automatic(false); game.weather.set_time_cycle(false)
	game.weather.set_preset("snowfall"); game.weather.set_time_of_day("noon")
	game.benchmark_input = input_at
	for view in ["chase","first_person"]:
		for strength in [0.0,50.0,100.0]: await phase(view,strength,false)
	await phase("chase",100.0,true)
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
	var report = {"checks":checks,"failures":failures,"phases":phases,"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"output_pixels":root.size,"fps_cap":30,"performance_acceptance":false,"scenario":"3 s lab at 160 km/h: straight, carve, jump release, reverse carve, brake/manual look; repeat per view/strength"}
	preload("res://tests/test_report.gd").write(output+"/report.json",JSON.stringify(report,"\t"))
	print("SCENE_BLUR_GAME_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"output":output}))
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func phase(view: String, strength: float, combined: bool) -> void:
	game.camera.close_view = view=="first_person"
	game.camera_settings.reset()
	game.camera_settings.update_profile(view,{"motion_blur_enabled":true,"motion_blur_strength":strength,"blur_strength":50.0 if combined else 0.0,"streak_strength":50.0 if combined else 0.0})
	game.start_speed_lab(160)
	game.camera.effects_enabled = true
	game.application_focused = true # Isolated scripted presentation, no window focus.
	game._process(1.0/30.0)
	var before: int = game.scene_motion_blur.status().dispatches
	var name = "%s_%d%s" % [view,int(strength),"_combined" if combined else ""]
	var samples: Array = []
	var airborne = false
	for frame in 90:
		for tick in 4: game._physics_process(1.0/120.0)
		if frame>66: game.camera.add_mouse_look(Vector2(8,0))
		game._process(1.0/30.0)
		airborne = airborne or not game.sim.grounded
		if frame in [15,33,48,69,86]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"/%s_%02d.png" % [name,frame])
			samples.append({"frame":frame,"tick":game.sim.ticks,"speed_kmh":game.sim.velocity.length()*3.6,"position":game.sim.position,"airborne":not game.sim.grounded,"crashed":game.sim.crashed,"blur":game.scene_motion_blur.status()})
		await process_frame
	var status = game.scene_motion_blur.status()
	check(status.unavailable.is_empty(),name+" supported on production game buffers")
	check((status.dispatches>before)==(strength>0.0),name+" real game dispatch matches strength")
	check(not game.sim.crashed,name+" completes bounded sequence without crash")
	phases.append({"name":name,"samples":samples,"airborne_observed":airborne,"final_tick":game.sim.ticks,"blur":status})
	print("SCENE_BLUR_GAME_PHASE ",name," ",JSON.stringify(status))
