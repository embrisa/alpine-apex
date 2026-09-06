extends SceneTree
## Native, unranked scenery views and matched static frame samples.
## ./godotw --script tests/scenery_playtest.gd -- --scenery-label=after
var game
var output: String
var captures: Array = []
var profiles: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Scenery inspection requires a rendered viewport")
		quit(1)
		return
	var label = "after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenery-label="): label = arg.get_slice("=",1).validate_filename()
	output = "res://artifacts/scenery_variation/"+label
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440,900)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.start_speed_lab(120.0)
	game.active = false
	game.effects.visible = false
	game.weather_effects.visible = false
	game.hud.hide()
	game.camera.effects_enabled = false
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	for quality in [0,1,2]:
		game.set_graphics_quality(quality)
		for z in [500.0,950.0]:
			place_rider(z)
			game.camera.close_view = false
			game.camera.reset()
			for i in range(12): game._process(1.0/60.0)
			await capture("%s_chase_%d" % [game.graphics.label(),z])
			if z==500.0:
				await profile_frames(game.graphics.label())
	game.set_graphics_quality(1)
	game.camera.close_view = true
	place_rider(500.0)
	game.camera.reset()
	for frame in range(120):
		for tick in range(2):
			game.previous_position = game.sim.position
			game.sim.step(1.0/120.0,game.intent,game.field)
		game._process(1.0/60.0)
		await process_frame
		if frame in [0,60,119]: await capture("motion_%03d" % frame)
	var result = {"captures":captures,"profiles":profiles,"eligible":game.session.eligible,"course_id":game.session.course_id,"obstacles":game.field.obstacles.size(),"batches":game.world.scenery.batches.size()}
	FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SCENERY_PLAYTEST ",JSON.stringify(result))
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	quit()

func place_rider(z: float) -> void:
	game.sim.position = Vector3(0,game.field.sample(0,z).height,z)
	game.sim.surface_normal = game.field.contact_normal(0,z)
	game.sim.velocity = Vector3.DOWN.slide(game.sim.surface_normal).normalized()*120.0/3.6
	game.previous_position = game.sim.position

func capture(id: String) -> void:
	game.world.update_weather(game.weather.state,0.0,false)
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+id+".png")
	captures.append(id)

func profile_frames(label: String) -> void:
	for i in range(90): await process_frame
	var samples: Array[float] = []
	var calls: float = 0.0
	for i in range(150):
		var start = Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec()-start)/1000.0)
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var total = 0.0
	for value in samples: total += value
	samples.sort()
	profiles.append({"quality":label,"mean_frame_ms":total/samples.size(),"p95_frame_ms":samples[142],"mean_draw_calls":calls/samples.size(),"render_pixels":root.get_texture().get_image().get_size()})
