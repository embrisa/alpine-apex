extends "res://tests/technical_showcase_playtest.gd"
## Actual v9 geometry/interaction views. No screenshot timing enters benchmarks.
func inspect_views() -> void:
	game.active = false
	game.set_process(false)
	game.hud.root.hide()
	game.skier.hide()
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	game.weather.visual_time = 0
	game.world.update_weather(game.weather.state,0,false)
	game.camera.effects_enabled = false
	game.camera.close_view = false
	var observer = Camera3D.new()
	observer.fov = 70
	observer.far = 15000
	game.add_child(observer)
	observer.make_current()
	var plain = StandardMaterial3D.new()
	plain.albedo_color = Color(.45,.50,.56)
	plain.roughness = .9
	for section in [760,870,1040,2160]:
		var x = field.gully_x(section,-1) if section<1850 else field.glade_x(section,-1)
		var p = Vector3(x,field.sample(x,section).height,section)
		game.sim.reset(p,0)
		game.sim.prime_contacts(field)
		game.sim.grounded = false
		game.effects.update_effects(game.sim,field,p,0,false,game.weather.state)
		var ahead = Vector3(x,field.sample(x,section+30).height,section+30)
		observer.position = p+Vector3(0,2.3,0)
		observer.look_at(ahead+Vector3.UP*.5)
		await capture("powder_%d_skiing"%section)
		observer.position = p+Vector3(0,1.1,0)
		var across = Vector3(x+12,field.sample(x+12,section+18).height,section+18)
		observer.look_at(across+Vector3.UP*.4)
		await capture("powder_%d_bank"%section)
		game.world.snow_material.set_shader_parameter("snow_geometry_debug",true)
		game.effects.powder_surface.material.set_shader_parameter("snow_geometry_debug",true)
		await capture("powder_%d_geometry"%section)
		game.world.snow_material.set_shader_parameter("snow_geometry_debug",false)
		game.effects.powder_surface.material.set_shader_parameter("snow_geometry_debug",false)
	if version>=9:
		var chosen = {}
		var nearest = INF
		for ob in field.obstacles:
			if not ob.get("powder_cap",false): continue
			var distance_m = Vector2(ob.position.x-field.gully_x(824,-1),ob.position.z-824).length()
			if distance_m<nearest: chosen=ob; nearest=distance_m
		if not chosen.is_empty():
			var p: Vector3 = chosen.position
			observer.position = p+Vector3(-7,5,9)
			observer.look_at(p+Vector3.UP*1.6)
			await capture("buried_outcrop")
		print("POWDER_CAPS ",game.world.scenery.powder_cap_count)
	observer.queue_free()
	game.camera.make_current()
	game.skier.show()
	game.effects.powder_surface.apply_quality(game.graphics)
	# Real-solver pass through the deposit. Intent does not prescribe contact.
	var section = 760.0
	var x = field.gully_x(section,-1)
	game.sim.reset(Vector3(x,field.sample(x,section).height,section),0)
	game.sim.prime_contacts(field)
	game.sim.velocity = Vector3.BACK.slide(field.contact_normal(x,section)).normalized()*16.0
	game.active = true
	game.camera.reset()
	for frame in 330:
		for tick in 2:
			game.intent = Pilot.intent(game.sim,field,-1)
			game.sim.step(Pilot.DT,game.intent,field)
		game._process(1.0/60.0)
		await process_frame
		if frame in [60,61,150,329]: await capture("powder_skiing_%03d"%frame,0)
		if game.sim.crashed: break
	game.active = false
	for spray in game.effects.sprays: spray.speed_scale=0
	var p: Vector3 = game.sim.position
	game.camera.position = p+Vector3(3,2.0,-7)
	game.camera.position.y = field.sample(game.camera.position.x,game.camera.position.z).height+1.4
	game.camera.look_at(p-Vector3(0,.1,2))
	await capture("powder_tracks_close")
	print("POWDER_CONTACT ",JSON.stringify({"crashed":game.sim.crashed,"position":str(p),"snow_depth_m":game.sim.skis[0].snow_depth,"penetration_m":game.sim.skis[0].penetration,"budget":game.effects.snow_budget()}))
	await verify_gpu()

func verify_gpu() -> void:
	# Readbacks are confined to this test, after capture and outside timing.
	var local = game.effects.powder_surface
	var image = local.texture.get_image()
	var recess = 0.0
	var lip = 0.0
	for z in range(0,image.get_height(),2):
		for x in range(0,image.get_width(),2):
			var height_m = image.get_pixel(x,z).r
			recess = minf(recess,height_m)
			lip = maxf(lip,height_m)
	var valid = recess<-.02 and lip>.005 and recess>=-.35 and lip<=.35
	var original = field.heights.to_byte_array()
	var written = game.effects.snow_tracks.written
	game.set_graphics_quality(0)
	var low_ok = not local.is_active() and not game.world.snow_material.get_shader_parameter("powder_patch_enabled")
	game.set_graphics_quality(2)
	game._process(1.0/60.0)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var retained = game.effects.snow_tracks.written==written
	var exact = original==field.heights.to_byte_array()
	var report = {"gpu_recess_m":recess,"gpu_lip_m":lip,"bounded_signed_height":valid,"low_restores_base":low_ok,"quality_retains_tracks":retained,"physical_surface_unchanged":exact}
	preload("res://tests/test_report.gd").write(OUTPUT+"/gpu_impressions.json",JSON.stringify(report,"\t"))
	print("POWDER_GPU ",JSON.stringify(report))
	if not (valid and low_ok and retained and exact): quit(3)
