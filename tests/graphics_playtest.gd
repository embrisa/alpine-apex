extends SceneTree
var game
var captures: Array = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Graphics inspection requires a rendered viewport")
		quit(1)
		return
	root.size = Vector2i(1440,900)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.start_speed_lab(120)
	game.sim.position = Vector3(0,game.field.sample(0,500).height,500)
	game.sim.surface_normal = game.field.contact_normal(0,500)
	game.previous_position = game.sim.position
	game.effects.visible = false
	game.weather_effects.visible = false
	game.hud.root.visible = false
	game.hud.toast_time = 0.0
	game.hud.toast_label.visible = false
	for setting in [["upright",0.0,0.0],["tuck",1.0,0.0],["carve",.45,.60],["compression",1.0,-.4]]:
		game.sim.effective_tuck = setting[1]
		game.sim.edge_angle = setting[2]
		game.sim.landing_force = 5.0 if setting[0]=="compression" else 0.0
		for i in range(10): game._process(.016)
		var center: Vector3 = game.skier.pose_probe("chest")
		game.camera.global_position = center+Vector3(2.25,1.0,2.8)
		game.camera.look_at(center)
		await capture("skier_"+setting[0])
	game.sim.effective_tuck = .0
	game.sim.edge_angle = 0.0
	game.sim.landing_force = 0.0
	for quality in [0,1,2]:
		game.set_graphics_quality(quality)
		game.camera.close_view = false
		game.camera.reset()
		for i in range(15): game._process(.016)
		await capture("quality_"+game.graphics.label())
	game.hud.root.visible = true
	game.hud.fps_label.text = "GRAPHICS INSPECTION / UNRANKED"
	game.active = false
	game.hud.show_menu("paused")
	game.hud.menu.visible = false
	game.hud.weather_panel.visible = true
	await capture("settings")
	FileAccess.open("res://artifacts/graphics_presentation.json",FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"eligible":game.session.eligible},"\t"))
	game.queue_free()
	await process_frame
	quit()
func capture(id: String) -> void:
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/graphics_%s.png" % id)
	captures.append(id)
