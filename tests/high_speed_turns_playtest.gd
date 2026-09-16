extends SceneTree
## Native hard-turn inspection on actual laboratory snow; always unranked.
const OUTPUT = "res://artifacts/high_speed_turns/visual"
var game

func _initialize(): call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1280,900)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.start_speed_lab(160)
	game.hud.root.visible = false
	game.hud.toast_label.visible = false
	game.effects.visible = false
	game.weather_effects.visible = false
	game.speed_periphery.visible = false
	var fixtures = []
	var failures = []
	for speed in [120.0,160.0,200.0]:
		for direction in [-1.0,1.0]:
			game.sim.reset(Vector3(0,game.field.sample(0,500).height,500))
			game.sim.prime_contacts(game.field)
			game.sim.velocity = Vector3.BACK.slide(game.sim.surface_normal).normalized()*speed/3.6
			var input = RiderInput.new()
			input.steer = direction
			for frame in range(120):
				for tick in range(2): game.sim.step(1.0/120,input,game.field)
				game.skier.pose(game.sim)
				var focus = game.skier.to_global(Vector3(0,.75,0))
				game.camera.global_position = focus+game.skier.basis*Vector3(.8,.7,-3.4)
				game.camera.look_at(focus)
				await process_frame
				await RenderingServer.frame_post_draw
				if frame in [59,119]:
					root.get_texture().get_image().save_png(OUTPUT+"/turn_%d_%d_%03d.png"%[speed,direction,frame])
				if game.sim.crashed:
					failures.append("%s km/h, direction %s: %s"%[speed,direction,game.sim.crash_reason])
					break
			fixtures.append({"start_kmh":speed,"direction":direction,"crash":game.sim.crash_reason,"balance":game.sim.balance,"roll_deg":rad_to_deg(game.sim.body.roll)})
	var result = {"unranked":not game.session.eligible,"failures":failures,"fixtures":fixtures}
	preload("res://tests/test_report.gd").write(OUTPUT+"/results.json",JSON.stringify(result,"\t"))
	print("HIGH_SPEED_TURNS_VISUAL ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
