extends SceneTree
## Native rendering of the reproduced tiny-turn failures and a banking crash.
const OUTPUT = "res://artifacts/high_speed_balance/visual"
var game
var failures: Array[String] = []
func _initialize(): call_deferred("run")
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png")
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
	game.start_speed_lab(200)
	game.hud.root.visible = false
	game.hud.toast_label.visible = false
	game.effects.visible = false
	game.weather_effects.visible = false
	game.speed_periphery.visible = false
	for fixture in [[120.0,-1.0,"release"],[200.0,1.0,"release"],[200.0,-1.0,"wave"]]:
		game.sim.reset(Vector3(0,game.field.sample(0,500).height,500))
		game.sim.prime_contacts(game.field)
		game.sim.velocity = Vector3.BACK.slide(game.sim.surface_normal).normalized()*fixture[0]/3.6
		var input = RiderInput.new()
		input.tuck = 1.0
		# The longer wave reaches a real tree beyond this open terrain segment.
		# Keep impacts separate from the handling reproduction.
		var frames = 360 if fixture[2]=="wave" else 480
		for frame in range(frames):
			for tick in range(2):
				var time = (frame*2+tick)/120.0
				input.steer = fixture[1]*.04 if time<=2.0 else 0.0
				if fixture[2]=="wave": input.steer = fixture[1]*.25*sin(time*1.6)
				game.sim.step(1.0/120.0,input,game.field)
			game.skier.pose(game.sim)
			var focus = game.skier.to_global(Vector3(0,.75,0))
			game.camera.global_position = focus+game.skier.basis*Vector3(.8 if frame<300 else 2.5,.7,-3.4 if frame<300 else .7)
			game.camera.look_at(focus)
			await process_frame
			if frame in [119,239,359,479]: await capture("%s_%d_%03d"%[fixture[2],fixture[0],frame])
			if game.sim.crashed:
				failures.append("%s %s: %s"%[fixture[2],fixture[0],game.sim.crash_reason])
				break
	# Deliberate crash, separate from the no-crash handling fixtures.
	game.sim.velocity = game.sim.velocity.normalized()*150.0/3.6
	game.sim.body.roll_velocity = .7
	game.sim.crash("PLAYTEST")
	game.crash_collision.prepare(game.sim.position)
	game.skier.ragdoll.start(game.sim)
	for frame in range(180):
		for tick in range(2): await physics_frame
		game.skier.ragdoll.update_equipment()
		var focus = game.skier.ragdoll.focus()
		game.crash_collision.prepare(focus)
		game.camera.global_position = focus+Vector3(3.0,1.8,-3.5)
		game.camera.global_position.y = maxf(game.camera.global_position.y,game.field.sample(game.camera.global_position.x,game.camera.global_position.z).height+1.0)
		game.camera.look_at(focus)
		await process_frame
		if frame in [0,29,59,119,179]: await capture("crash_%03d"%frame)
	var result = {"unranked":not game.session.eligible,"failures":failures,"rendered_handling_seconds":22,"crash_seconds":3}
	preload("res://tests/test_report.gd").write(OUTPUT+"/results.json",JSON.stringify(result,"\t"))
	print("HIGH_SPEED_BALANCE_VISUAL ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
