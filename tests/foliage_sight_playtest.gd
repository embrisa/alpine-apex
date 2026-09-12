extends "res://tests/foliage_playtest.gd"
## Matched production canopy strengths; chronological dense stand/LOD review.
var actor = Vector3.ZERO
var strength_percent = 100.0

func run() -> void:
	output = "res://artifacts/orchestration_20260912/forest/stand_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	await super.run()

func settle() -> void:
	for frame in 90:
		assets.update_foliage_sight(camera,actor,1.0/60,true,60,strength_percent)
		await process_frame

func place_camera(mode: String) -> void:
	camera.position = actor+Vector3(0,1.75,0) if mode=="first_person" else actor+Vector3(0,5,-6)
	camera.look_at(actor+Vector3(0,1.35,18))

func stand_views(profile) -> void:
	host = Scenery.new(); root.add_child(host); host.assets = assets; host.quality = profile; host.dense_woodlands = true
	forest = Forest.new(); host.add_child(forest)
	var rng = RandomNumberGenerator.new(); rng.seed = 917320
	for z in range(-5,9):
		for x in range(-5,6):
			var p = Vector3(x*7+rng.randf_range(-1.5,1.5),0,z*7+rng.randf_range(-1.5,1.5))
			if x==0: p.x = 2.0 if z%2==0 else -2.0
			var id = "forest_%s_01" % ["spruce","fir","pine"][posmod(x+z,3)]
			var scale_value = 10.5/float(assets.tree_record(id).height_m)*1.35
			forest.add_tree(id,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value),p),25)
	await forest.finish(host,Callable()); host.apply_quality(profile)
	Engine.max_fps = 60
	for mode in ["first_person","chase"]:
		for strength in [0.0,25.0,50.0,75.0,100.0]:
			strength_percent = strength
			var id = "%s_strength_%03d" % [mode,strength]
			assets.wind_time = 0.0
			assets.update_wind({"wind_velocity":Vector3(3,0,1),"enabled":true},0.0,true)
			actor = Vector3(0,0,-6); place_camera(mode)
			sun.rotation_degrees = Vector3(-42,-32,0)
			await settle(); await capture(id)
			results.append({"view":mode,"strength":strength,"reach":60,"parameters":assets.foliage_sight.parameters,"forest":forest.report()})
			if strength not in [0.0,50.0,100.0]: continue
			sun.rotation_degrees = Vector3(-25,145,0); await capture(id+"_backlit")
			sun.rotation_degrees = Vector3(-42,-32,0)
			# Three-second chronological presentation path, not a physics descent.
			# Long enough to cross near/mid/far distances at a fixed camera height.
			for frame in 180:
				actor = Vector3(sin(float(frame)/179*PI)*.75,0,lerpf(-6,36,float(frame)/179))
				place_camera(mode)
				assets.update_wind({"wind_velocity":Vector3(3,0,1),"enabled":true},1.0/60,true)
				assets.update_foliage_sight(camera,actor,1.0/60,true,60,strength)
				await process_frame
				if capture_enabled and frame%6==0:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_jpg(output+"/%s_motion_%03d.jpg" % [id,frame],.94)
		actor = Vector3(0,0,-6); place_camera(mode); strength_percent = 50
		for level in 3:
			host.apply_quality(Quality.preset(level)); assets.apply_quality(Quality.preset(level))
			await settle(); await capture(mode+"_strength_050_quality_%d" % level)
		host.apply_quality(profile); assets.apply_quality(profile)
		# Isolate the production teleport fallback without changing any trees.
		forest.set_process(false)
		var residency = forest.residency_image.duplicate()
		var visibility = []
		for node in host.batches:
			visibility.append(node.visible)
			if node.get_meta("art_lod") in [0,1,5]: node.hide()
		forest.residency_image.fill(Color(0,0,0,1)); forest.residency_texture.update(forest.residency_image)
		for strength in [0.0,50.0,100.0]:
			strength_percent = strength; await settle()
			await capture("%s_fallback_strength_%03d" % [mode,strength])
		for index in host.batches.size(): host.batches[index].visible = visibility[index]
		forest.residency_image = residency; forest.residency_texture.update(residency); forest.set_process(true)
	results.append({"trees":154,"reach":60,"no_solver_session":true,"capture_overhead_included":true,"motion_seconds_per_clip":3,"hardware_acceptance":false})
