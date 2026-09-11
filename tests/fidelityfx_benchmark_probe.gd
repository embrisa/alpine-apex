extends SceneTree
## Diagnose requested versus actual generation without modifying engine/settings.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	set_meta("test_lab_fixture",true)
	var game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game); await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.start_speed_lab(60)
	var rows = []
	for mode in ["1080p","4k_fullscreen","4k_borderless"]:
		var pixels = Vector2i(1920,1080) if mode=="1080p" else Vector2i(3840,2160)
		game.display_settings.upscaler = "fsr4"; game.display_settings.render_scale = .75
		game.display_settings.frame_generation = true; game.display_settings.fps_limit = 90
		game.display_settings.display_mode = "windowed"
		game.display_settings.terrain_gi = true; game.set_graphics_quality(2)
		game.display_settings.apply_display(root,pixels); game.display_settings.apply_viewport(root)
		if mode=="4k_borderless": root.mode = Window.MODE_WINDOWED; root.borderless = true; root.size = pixels
		for i in 120: game._process(1.0/90); await process_frame
		var begin = game.display_settings.fsr_status()
		for i in 120: game._process(1.0/90); await process_frame
		await RenderingServer.frame_post_draw
		var before_readback = game.display_settings.fsr_status()
		var actual = root.get_texture().get_image().get_size()
		for i in 120: game._process(1.0/90); await process_frame
		var row = {"mode":mode,"requested":str(pixels),"viewport":str(root.size),"window":str(DisplayServer.window_get_size()),"screen":str(DisplayServer.screen_get_size()),"actual":str(actual),"begin":begin,"before_readback":before_readback,"end":game.display_settings.fsr_status()}
		rows.append(row); print("FIDELITYFX_BENCHMARK_PROBE ",JSON.stringify(row))
	FileAccess.open("res://artifacts/fps_optimization/fidelityfx_benchmark_probe.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	game.display_settings.frame_generation = false; game.display_settings.apply_viewport(root)
	game.effects.stop_audio(); game.queue_free(); await process_frame; quit(0)
