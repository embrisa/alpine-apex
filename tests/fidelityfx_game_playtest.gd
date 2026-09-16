extends SceneTree
## Native game/HUD inspection using the explicit lab, without preferences or records.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures.append(message)

func run() -> void:
	set_meta("test_lab_fixture",true)
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "auto"
	game.display_settings.frame_generation = true
	game.display_settings.fps_limit = 90
	game.display_settings.apply_display(root,Vector2i(1920,1080))
	game.display_settings.apply_viewport(root)
	game.start_speed_lab(120)
	for frame in 120:
		game._physics_process(1.0/120.0)
		game._process(1.0/90.0)
		await process_frame
	await RenderingServer.frame_post_draw
	var running: Dictionary = game.display_settings.report(root,root.get_texture().get_image().get_size())
	check(str(running.fidelityfx.get("active_upscaler_version","")).begins_with("4.1"),"Game automatically selects FSR 4.1 on RX 9070")
	check(running.fidelityfx.get("frame_generation_active",false),"Game scene generates frames")
	check(running.fidelityfx.get("generated_frames",0)>0,"Game interpolation dispatches are recorded")
	check(not game.preferences_enabled and not game.session.eligible,"Lab run cannot change preferences or records")
	check(root.get_texture().get_image().save_png("res://artifacts/fidelityfx/captures/gameplay-fsr4-fg.png")==OK,"Game capture saved")
	game.active = false
	game.hud.show_menu("paused")
	game.hud.menu.visible = false
	game.hud.weather_panel.visible = true
	game.hud.sync_display(game.display_settings)
	for frame in 100:
		game._process(1.0/90.0)
		await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/fidelityfx/captures/settings-fidelityfx.png")==OK,"Settings capture saved")
	check(game.display_settings.fsr_status().get("error","")=="","Game and menu have no SDK error")
	var result = {"failures":failures,"gameplay":running,"menu":game.display_settings.fsr_status()}
	preload("res://tests/test_report.gd").write("res://artifacts/fidelityfx/game-results.json",JSON.stringify(result,"\t"))
	print("FIDELITYFX_GAME_RESULTS ",JSON.stringify(result))
	game.display_settings.frame_generation = false
	game.display_settings.apply_viewport(root)
	for frame in 3: await process_frame
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
