extends SceneTree
## Interactive, unranked entry straight into the new powder section. Normal
## controls remain live; this is not a prescribed-input benchmark or PB run.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	var definition = preload("res://scripts/world/mountain_definition.gd")
	var field = definition.generate(849205174,9)
	set_meta("mountain_to_load",{"definition":definition.from_field(field,"Technical Showcase"),"field":field})
	var game = load("res://main.tscn").instantiate()
	# Suppress preference writes during setup, then enable normal player input.
	game.automated = true
	root.add_child(game)
	current_scene = game
	await process_frame
	game.automated = false
	game.set_graphics_quality(2)
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	game.start_run(false)
	game.session.eligible = false
	game.summit_ready = false
	var z = 760.0
	var x = field.gully_x(z,-1)
	game.sim.reset(Vector3(x,field.sample(x,z).height,z),0)
	game.sim.prime_contacts(field)
	game.previous_position = game.sim.position
	game.camera.reset()
	game.active = false
	game.hud.show_menu("paused","Powder Garden\nResume to ski the fresh banks and buried outcrops.")
	print("POWDER_GARDEN_READY version=9 unranked=true physics_hz=120")
