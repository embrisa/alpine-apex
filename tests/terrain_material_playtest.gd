extends SceneTree
## Matched native terrain views, including both renderers and all quality levels.
## ./godotw --script tests/terrain_material_playtest.gd -- --terrain-label=after
var game
var output: String
var captures: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Terrain material inspection requires a rendered viewport")
		quit(1)
		return
	var label = "after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--terrain-label="): label = arg.get_slice("=",1).validate_filename()
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
	output = "res://artifacts/terrain_variation/%s_%s" % [label,game.world.terrain_renderer]
	DirAccess.make_dir_recursive_absolute(output)
	for quality in [0,1,2]:
		game.set_graphics_quality(quality)
		place_rider(500.0)
		game.camera.close_view = false
		game.camera.reset()
		for i in range(12): game._process(1.0/60.0)
		await capture("%s_chase" % game.graphics.label())
		game.camera.close_view = true
		game.camera.reset()
		for i in range(12): game._process(1.0/60.0)
		await capture("%s_pov" % game.graphics.label())
		game.skier.hide()
		var ground = Vector3(65,game.field.sample(65,640).height,640)
		game.camera.position = ground+Vector3(0,34,-16)
		game.camera.look_at(ground+Vector3(0,0,16))
		await capture("%s_snow" % game.graphics.label())
		var mountain = game.world.mountain
		var face = Vector3(1050,mountain.sample_height(Vector2(1050,700)),700)
		game.camera.position = face+Vector3(-220,110,-180)
		game.camera.look_at(face)
		await capture("%s_rock" % game.graphics.label())
		game.camera.position = Vector3(0,game.field.sample(0,500).height+160,500)
		game.camera.look_at(Vector3(1600,mountain.sample_height(Vector2(1600,1600)),1600))
		await capture("%s_vista" % game.graphics.label())
		game.skier.show()
	# Fixed-step motion at racing speed makes filtering and tile transitions visible.
	game.set_graphics_quality(1)
	game.camera.close_view = true
	place_rider(500.0)
	game.camera.reset()
	for frame in range(180):
		for tick in range(2):
			game.previous_position = game.sim.position
			game.sim.step(1.0/120.0,game.intent,game.field)
		game._process(1.0/60.0)
		await process_frame
		if frame in [0,30,60,90,120,179]: await capture("motion_%03d" % frame)
	var result = {"captures":captures,"eligible":game.session.eligible,"renderer":game.world.terrain_renderer}
	preload("res://tests/test_report.gd").write(output+"/results.json",JSON.stringify(result,"\t"))
	print("TERRAIN_MATERIAL_VIEWS ",JSON.stringify(result))
	game.effects.stop_audio()
	await create_timer(.1).timeout
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
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	img.save_png(output+"/"+id+".png")
	captures.append(id)
