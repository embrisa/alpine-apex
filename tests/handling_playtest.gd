extends SceneTree
## Native rendered handling captures; every fixture is unranked.
var game
const OUTPUT = "res://artifacts/handling/visual"
func _initialize(): call_deferred("run")
func run():
	if DisplayServer.get_name()=="headless": quit(1); return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1280,900)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.start_speed_lab(120)
	game.hud.root.visible = false
	game.hud.toast_label.visible = false
	game.effects.visible = false
	game.weather_effects.visible = false
	game.speed_periphery.visible = false
	var failures = []
	for direction in [-1.0,1.0]:
		for mode in ["hold","reverse"]:
			game.sim.reset(Vector3(0,game.field.sample(0,500).height,500))
			game.sim.prime_contacts(game.field)
			game.sim.velocity = Vector3.BACK.slide(game.sim.surface_normal).normalized()*120/3.6
			var intent = RiderInput.new()
			for frame in range(120):
				intent.steer = direction if mode=="hold" or frame<60 else -direction
				for tick in range(2): game.sim.step(1.0/120,intent,game.field)
				game.skier.pose(game.sim)
				var focus = game.skier.to_global(Vector3(0,.75,0))
				game.camera.global_position = focus+game.skier.basis*Vector3(.8,.7,-3.4)
				game.camera.look_at(focus)
				await process_frame
				await RenderingServer.frame_post_draw
				if frame in [29,59,119]:
					root.get_texture().get_image().save_png(OUTPUT+"/%s_%s_%s.png"%[mode,int(direction),frame])
				if game.sim.crashed:
					failures.append("%s %s: %s"%[mode,direction,game.sim.crash_reason])
					break
	print("HANDLING_VISUAL ",JSON.stringify({"unranked":not game.session.eligible,"failures":failures}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
