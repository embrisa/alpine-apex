extends SceneTree
## Isolated SDFGI comparison; existing sky lighting and SSAO stay fixed.
## Manual simulation steps keep paired views identical and out of records.
var game
var captures: Array = []
var failures: Array[String] = []
const OUTPUT = "res://artifacts/sdfgi_lighting"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("SDFGI inspection requires a rendered viewport")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1440,900)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sdfgi-benchmark="):
			if not "--autoplay" in OS.get_cmdline_user_args():
				printerr("SDFGI benchmark requires --autoplay")
				quit(1)
				return
			game.world.environment.sdfgi_enabled = arg.get_slice("=",1)=="on"
			print("SDFGI_BENCHMARK enabled=",game.world.environment.sdfgi_enabled)
			return
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.start_speed_lab(120.0)
	game.sim.position = Vector3(0,game.field.sample(0,500).height,500)
	game.sim.surface_normal = game.field.contact_normal(0,500)
	game.previous_position = game.sim.position
	game.hud.root.hide()
	game.hud.toast_label.hide()
	game.camera.effects_enabled = false
	game.set_graphics_quality(2)
	for preset in ["clear","snowfall"]:
		game.weather.set_preset(preset)
		game.weather.set_time_of_day("day")
		for view in [false,true]:
			game.camera.close_view = view
			game.camera.reset()
			for i in range(8): game._process(1.0/60.0)
			await pair("%s_%s_%s" % [game.graphics.label(),preset,"pov" if view else "chase"])
	game.set_graphics_quality(2)
	game.weather.set_preset("clear")
	for period in ["dawn","dusk","night"]:
		game.weather.set_time_of_day(period)
		game._process(0.0)
		await pair("high_"+period)
	game.weather.set_time_of_day("day")
	game.weather.set_preset("clear")
	game._process(0.0)
	# Inspect real shoulder rocks at close range, without synthetic lighting props.
	var nearest: Dictionary = {}
	var distance = INF
	for obstacle in game.field.obstacles:
		var d: float = obstacle.position.distance_to(game.sim.position)
		if not obstacle.tree and d<distance:
			nearest = obstacle
			distance = d
	var target: Vector3 = nearest.position + Vector3.UP*nearest.height*0.4
	var eye = target + Vector3(4,3,-6)
	eye.y = maxf(eye.y,game.field.sample(eye.x,eye.z).height+2.0)
	game.camera.global_position = eye
	game.camera.look_at(target)
	await pair("high_rock_contact")
	game.weather.set_preset("snowfall")
	game.camera.close_view = false
	game.camera.reset()
	for frame in range(240):
		for tick in range(2):
			game.previous_position = game.sim.position
			game.sim.step(1.0/120.0,game.intent,game.field)
		game._process(1.0/60.0)
		await process_frame
		if frame in [1,2,30,60,120,180,239]: await capture("moving_%03d" % frame,0)
	for level in [0,1,2,0]:
		game.set_graphics_quality(level)
		game.world.update_weather(game.weather.state,0.0,false)
		if game.world.environment.sdfgi_enabled != game.display_settings.terrain_gi:
			failures.append("SDFGI quality switching failed for tier %d" % level)
	if game.session.eligible: failures.append("Lighting QA must remain unranked")
	FileAccess.open(OUTPUT+"/results.json",FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"failures":failures},"\t"))
	print("SDFGI_LIGHTING_RESULTS ",JSON.stringify({"captures":captures.size(),"failures":failures}))
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func pair(label: String) -> void:
	var env: Environment = game.world.environment
	env.sdfgi_enabled = false
	await capture(label+"_before")
	env.sdfgi_enabled = true
	await capture(label+"_after")

func capture(label: String, settle_frames: int = 90) -> void:
	for i in range(settle_frames): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png")
	captures.append({"label":label,"speed_kmh":game.sim.speed_kmh(),"eligible":game.session.eligible,"sdfgi":game.world.environment.sdfgi_enabled})
