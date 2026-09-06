extends SceneTree
const Definition = preload("res://scripts/world/mountain_definition.gd")
var game
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var field = Definition.generate(849205174)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field),"field":field})
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.set_graphics_quality(0)
	game.effects.muted = true
	game.automated = true
	game.weather.set_preset("clear")
	game.start_run(false)
	game.session.eligible = false
	root.size = Vector2i(1440,900)
	await capture("summit_south")
	game.sim.reset(field.spawn_point(),PI)
	game.sim.prime_contacts(field)
	game.camera.reset()
	await capture("summit_north")
	await game.mountain_library.open()
	await capture("library")
	game.mountain_library.close()
	game.workshop.open_library()
	game.workshop.panel.hide()
	game.workshop.focus_point = Vector3.ZERO
	game.workshop.survey_height = 5600
	game.workshop.survey.far = 18000
	game.workshop._update_survey()
	await capture("whole_mountain")
	for p in [Vector3(1900,0,0),Vector3(0,0,-1900)]:
		game.workshop.focus_point = p
		game.workshop.survey_height = 1200
		game.workshop._update_survey()
		await capture("east_bowls" if p.x>0 else "north_face")
	print("SUMMIT_VIEW triangles=",game.world.terrain_triangles," chunks=",game.world.terrain_chunks.size()," build_ms=",game.world.generation_ms)
	game.queue_free()
	await process_frame
	quit()
func capture(label: String) -> void:
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/summit_mountain/"+label+".png")
