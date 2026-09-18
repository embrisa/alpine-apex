extends "res://art_source/trees/meshy_snow_v1/bough_game_review.gd"
## Matched cameras and a moving pass across both production transitions.
func run():
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Shared")
	var field=preload("res://tests/validation_mountain.gd").load_standard()
	if field==null:quit(2);return
	var definition=preload("res://scripts/world/mountain_definition.gd").from_field(field,"Winter family review")
	set_meta("mountain_to_load",{"definition":definition,"field":field})
	var game=load("res://main.tscn").instantiate();game.automated=true;root.add_child(game);current_scene=game
	while not game.initialized or (game.loading and game.loading.busy):await process_frame
	game.set_physics_process(false);game.set_process(false);game.effects.stop_audio()
	game.hud.hide_menu();game.hud.root.hide();game.skier.hide()
	game.weather.set_preset("clear");game.weather.set_time_of_day("day");game.world.update_weather(game.weather.state,0,true)
	game.display_settings.apply_display(root,Vector2i(3840,2160));game.display_settings.apply_viewport(root);Engine.max_fps=30
	camera=Camera3D.new();camera.far=6000;camera.fov=68;root.add_child(camera);camera.make_current()
	var library=preload("res://art_source/trees/meshy_snow_v1/family_library.gd").new();library.setup(game.world);library.select(true)
	var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/game_review/report.json"))
	var output=OUT+"/winter_family/game_round_mid";DirAccess.make_dir_recursive_absolute(output)
	var receipt={"scope":"Complete winter family in actual game; capped static/moving visual review, no FPS","captures":[],"moving_frames":[],"inventory":library.inventory}
	var views={}
	for view in saved.captures:
		if not view.id.ends_with("_snow"):continue
		views[view.id]=view
		camera.transform=str_to_var(view.camera);game.display_settings.reset_history()
		for frame in 240:
			await process_frame
			if frame>=60 and game.world.scenery.density_forest.pending.is_empty():break
		assert(game.world.scenery.density_forest.pending.is_empty());library.validate_batches()
		await RenderingServer.frame_post_draw
		var path=output+"/"+view.id+".webp";assert(root.get_texture().get_image().save_webp(path,true)==OK)
		receipt.captures.append({"id":view.id,"camera":view.camera,"image":path});print("FAMILY_GAME ",view.id)
	# Continue the camera smoothly across near/middle and middle/card; fixed wind
	# remains active throughout. Readback frames are visual evidence only.
	var near_pose:Transform3D=str_to_var(views.spruce_6m_snow.camera)
	var far_pose:Transform3D=str_to_var(views.spruce_85m_snow.camera)
	for step in 240:
		camera.transform=near_pose.interpolate_with(far_pose,float(step)/239.0)
		game.world.assets.update_wind({"wind_velocity":Vector3(4,0,2),"enabled":true},1.0/30.0,true)
		await process_frame
		if step%6==0:
			await RenderingServer.frame_post_draw
			var image=root.get_texture().get_image();image.resize(1920,1080)
			var path=output+"/move_%03d.webp"%step;assert(image.save_webp(path,true)==OK)
			receipt.moving_frames.append(path)
	# Bounded contact excursion on the same spruce; uses the real publisher and
	# authored pivots, without changing collision or driving the skiing solver.
	camera.transform=near_pose;game.display_settings.reset_history()
	var stand=FileAccess.open("res://artifacts/far_stand_mesh_20260917/stand.bin",FileAccess.READ).get_var()
	var anchor=Vector3.ZERO;var nearest=INF
	for tree in stand.trees:
		if not tree.id.begins_with("forest_spruce"):continue
		var d=tree.pose.origin.distance_squared_to(stand.center)
		if d<nearest:nearest=d;anchor=tree.pose.origin
	var motion=game.world.scenery.tree_motion
	motion.anchors[0]=Vector4(anchor.x,anchor.y,anchor.z,1)
	for sample in 3:
		for branch in 12:motion.angles[branch]=Vector4(.22 if sample==1 else 0,0,-.16 if sample==1 else 0,0)
		motion._upload()
		for frame in 45:await process_frame
		await RenderingServer.frame_post_draw
		var path=output+"/contact_"+str(sample)+".webp"
		assert(root.get_texture().get_image().save_webp(path,true)==OK)
		receipt.captures.append({"id":"contact_"+str(sample),"image":path})
	receipt.verified_forest_batches=library.validate_batches()
	motion.reset();library.select(false);receipt.display=game.display_settings.report(root,Vector2i(3840,2160))
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	game.queue_free();await process_frame;quit()
