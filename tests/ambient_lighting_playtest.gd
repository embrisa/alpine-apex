extends SceneTree
## Matched native captures for the incremental ambient/contact-lighting pass.
## Manual simulation steps keep paired views identical and out of records.
var game
var captures: Array = []
var failures: Array[String] = []
const OUTPUT = "res://artifacts/ambient_lighting"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Ambient lighting inspection requires a rendered viewport")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1440,900)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
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
	for level in [0,1,2]:
		game.set_graphics_quality(level)
		for preset in ["clear","snowfall"]:
			game.weather.set_preset(preset)
			game.weather.set_time_of_day("day")
			for view in [false,true]:
				game.camera.close_view = view
				game.camera.reset()
				for i in range(8): game._process(1.0/60.0)
				await pair("%s_%s_%s" % [game.graphics.label(),preset,"pov" if view else "chase"])
	game.set_graphics_quality(1)
	game.weather.set_preset("clear")
	for period in ["dawn","dusk","night"]:
		game.weather.set_time_of_day(period)
		game._process(0.0)
		await pair("balanced_"+period)
	game.weather.set_time_of_day("day")
	game.weather.set_preset("snowfall")
	game.camera.close_view = false
	game.camera.reset()
	for frame in range(120):
		for tick in range(2):
			game.previous_position = game.sim.position
			game.sim.step(1.0/120.0,game.intent,game.field)
		game._process(1.0/60.0)
		await process_frame
		if frame in [30,60,90,119]: await capture("moving_%03d" % frame)
	if game.session.eligible: failures.append("Lighting QA must remain unranked")
	FileAccess.open(OUTPUT+"/results.json",FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"failures":failures},"\t"))
	print("AMBIENT_LIGHTING_RESULTS ",JSON.stringify({"captures":captures.size(),"failures":failures}))
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func pair(label: String) -> void:
	var env: Environment = game.world.environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ssao_enabled = false
	await capture(label+"_before")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ssao_enabled = game.graphics.contact_shading
	await capture(label+"_after")

func capture(label: String) -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png")
	captures.append({"label":label,"speed_kmh":game.sim.speed_kmh(),"eligible":game.session.eligible})
