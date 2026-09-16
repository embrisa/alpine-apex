extends SceneTree
## Matched asset inspection. All runs are automated and unranked.
var game
var output_dir = "res://artifacts/skier_v7/after"
var captures: Array[String] = []
var include_motion = false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--skier-motion": include_motion = true
		if arg.begins_with("--skier-label="):
			output_dir = "res://artifacts/skier_v7/"+arg.trim_prefix("--skier-label=").validate_filename()
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Skier inspection requires a rendered viewport")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1100,1100)
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
		game.sim.prime_contacts(game.field)
		game.sim.body.roll = -setting[2]*.65
		game.sim.body.pelvis_height = .94-setting[1]*.22
		for i in range(180): game.sim.body._pose(game.sim,1.0/120.0)
		game.sim.body.previous_joints = game.sim.body.joints.duplicate()
		game.sim.body.previous_rotations = game.sim.body.rotations.duplicate()
		for i in range(15): game._process(.016)
		var center: Vector3 = game.skier.to_global(Vector3(0,.85,0))
		for view in [["front",Vector3(1.6,.75,2.4)],["rear",Vector3(-1.6,.6,-2.4)],["side",Vector3(2.7,.35,0)]]:
			game.camera.global_position = center+game.skier.basis*view[1]
			game.camera.look_at(center)
			await capture(setting[0]+"_"+view[0])
	game.camera.reset()
	for i in range(15): game._process(.016)
	await capture("chase")
	game.camera.close_view = true
	for i in range(15): game._process(.016)
	await capture("first_person")
	if include_motion:
		await capture_motion()
	preload("res://tests/test_report.gd").write(output_dir+"/report.json",JSON.stringify({"captures":captures,"eligible":game.session.eligible,"bones":game.skier.skeleton.get_bone_count()},"\t"))
	assert(not game.session.eligible)
	game.queue_free()
	await process_frame
	quit()

func capture(id: String) -> void:
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir+"/"+id+".png")
	captures.append(id)

func capture_motion() -> void:
	# Controlled visual sequence, not a physical descent or performance benchmark.
	game.camera.close_view = false
	root.size = Vector2i(960,720)
	DirAccess.make_dir_recursive_absolute(output_dir+"/motion_frames")
	for frame in range(240):
		var t = frame/30.0
		game.sim.ticks += 4
		game.sim.effective_tuck = .5-.5*cos(t*TAU/4.0)
		game.sim.edge_angle = .6*sin(t*TAU/3.0)
		game.sim.normal_load = 9.81+3.5*sin(t*TAU*1.2)
		game.sim.landing_force = maxf(0.0,1.0-absf(t-5.5)*4.0)*4.0
		game.sim.body.roll = -game.sim.edge_angle*.65
		for i in range(4): game.sim.body._pose(game.sim,1.0/120.0)
		game.sim.body.previous_joints = game.sim.body.joints.duplicate()
		game.sim.body.previous_rotations = game.sim.body.rotations.duplicate()
		game._process(1.0/30.0)
		var center: Vector3 = game.skier.to_global(Vector3(0,.90,0))
		game.camera.global_position = center+Vector3(1.55,.75,2.0)
		game.camera.look_at(center)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_dir+"/motion_frames/%04d.png" % frame)
