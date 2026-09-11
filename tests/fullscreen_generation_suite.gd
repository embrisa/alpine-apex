extends SceneTree
## Native output/FG transitions; never saves display preferences.
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/fps_second")
	set_meta("test_lab_fixture",true)
	var game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game); await process_frame
	game.set_process(false); game.set_physics_process(false); game.start_speed_lab(60)
	game.preferences_enabled = false
	var settings = game.display_settings
	settings.upscaler = "fsr4"; settings.render_scale = .75; settings.fps_limit = 90
	settings.terrain_gi = true; game.set_graphics_quality(2)
	var rows = []
	for phase in ["fullscreen_on","fullscreen_off","windowed_on","fullscreen_return"]:
		game.set_display_setting("display_mode","windowed" if phase=="windowed_on" else "fullscreen")
		game.set_display_setting("frame_generation",phase!="fullscreen_off")
		var saved = settings.snapshot()
		for i in 120: game._process(1.0/90); await process_frame
		var begin = settings.fsr_status()
		for i in 120: game._process(1.0/90); await process_frame
		await RenderingServer.frame_post_draw
		var end = settings.fsr_status(); var actual = root.get_texture().get_image().get_size()
		var generated = int(end.generated_frames)-int(begin.generated_frames)
		var rendered = int(end.rendered_present_calls)-int(begin.rendered_present_calls)
		if settings.frame_generation and (not end.frame_generation_active or generated<rendered-3): failures.append(phase+": generation inactive or missing frames")
		if not settings.frame_generation and (end.frame_generation_active or generated!=0): failures.append(phase+": generation did not disable")
		if settings.display_mode=="fullscreen" and actual!=DisplayServer.screen_get_size(root.current_screen): failures.append(phase+": screen output mismatch")
		if actual!=root.size: failures.append(phase+": pixel mismatch")
		if saved!=settings.snapshot(): failures.append(phase+": preferences changed")
		var row = {"phase":phase,"pixels":[actual.x,actual.y],"position":str(root.position),"window_mode":root.mode,"borderless":root.borderless,"rendered":rendered,"generated":generated,"begin":begin,"end":end}
		rows.append(row); print("FULLSCREEN_GENERATION ",JSON.stringify(row))
		if phase in ["fullscreen_on","fullscreen_return"]: root.get_texture().get_image().save_png("res://artifacts/fps_second/"+phase+".png")
	FileAccess.open("res://artifacts/fps_second/fullscreen_generation.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"failures":failures},"\t"))
	settings.frame_generation = false; settings.apply_viewport(root)
	game.effects.stop_audio(); game.queue_free(); await process_frame
	print("FULLSCREEN_GENERATION_RESULT failures=",failures); quit(0 if failures.is_empty() else 1)
