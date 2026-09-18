extends "res://art_source/trees/meshy_snow_v1/near_compare.gd"
## Capped close/middle game check of the branch-built spruce. No FPS evidence.
func run():
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Shared")
	var field=preload("res://tests/validation_mountain.gd").load_standard()
	if field==null:quit(2);return
	var definition=preload("res://scripts/world/mountain_definition.gd").from_field(field,"Bough spruce review")
	set_meta("mountain_to_load",{"definition":definition,"field":field})
	var game=load("res://main.tscn").instantiate();game.automated=true;root.add_child(game);current_scene=game
	while not game.initialized or (game.loading and game.loading.busy):await process_frame
	game.set_physics_process(false);game.set_process(false);game.effects.stop_audio()
	game.hud.hide_menu();game.hud.root.hide();game.skier.hide()
	game.weather.set_preset("clear");game.weather.set_time_of_day("day");game.world.update_weather(game.weather.state,0,true)
	game.display_settings.apply_display(root,Vector2i(3840,2160));game.display_settings.apply_viewport(root);Engine.max_fps=30
	camera=Camera3D.new();camera.far=6000;camera.fov=68;root.add_child(camera);camera.make_current()
	var library=preload("res://art_source/trees/meshy_snow_v1/bough_library.gd").new();library.setup(game.world)
	for key in library.original:library.replacement[key]=library.original[key]
	for lod in 2:
		var mesh=load_close(OUT+"/bough_full_assembly/tree_lod"+str(lod)+".glb")
		mesh.set_meta("authored_boughs",true)
		var source_mat:StandardMaterial3D=mesh.surface_get_material(0)
		var mat:ShaderMaterial=library.source.spruce.lods[lod].mat.duplicate()
		var shader=Shader.new();shader.code=mat.shader.code.replace("NORMAL_MAP=texture(mesh_normal,UV).rgb;","").replace("NORMAL_MAP_DEPTH=.35;","")
		mat.shader=shader;mat.set_shader_parameter("mesh_albedo",source_mat.albedo_texture)
		mat.set_shader_parameter("mesh_roughness",null)
		game.world.assets.lighting.register(mat)
		library.source.spruce.lods[lod]={"mesh":mesh,"mat":mat,"image":source_mat.albedo_texture.get_image()}
	for id in game.world.assets.tree_ids():
		var record:Dictionary=game.world.assets.tree_record(id)
		if record.family!="spruce":continue
		var box:AABB=library.original[id+"_lod0"].get_aabb();var srcbox:AABB=library.source.spruce.lods[0].mesh.get_aabb()
		var scale_m=Vector3(box.size.x/srcbox.size.x,box.size.y/12,box.size.z/srcbox.size.z)
		for lod in 2:
			var replacement=library.detail(id,record,"spruce",lod,scale_m,box.position.y)
			replacement.set_meta("forest_asset",id);library.replacement[id+"_lod"+str(lod)]=replacement
	library.select(true)
	var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/game_review/report.json"))
	var output=OUT+"/bough_game_review";DirAccess.make_dir_recursive_absolute(output)
	var receipt={"scope":"Static in-game spruce near/middle only; original other families and far cards; no FPS, moving transition or wind acceptance","captures":[]}
	for view in saved.captures:
		if not view.id in ["spruce_6m_snow","spruce_12m_snow","spruce_32m_snow"]:continue
		camera.transform=str_to_var(view.camera);game.display_settings.reset_history()
		for frame in 90:await process_frame
		assert(game.world.scenery.density_forest.pending.is_empty())
		await RenderingServer.frame_post_draw
		var path=output+"/"+view.id+".webp"
		assert(root.get_texture().get_image().save_webp(path,true)==OK)
		receipt.captures.append({"camera":view.camera,"detail_distance":view.detail_distance_m,"image":path})
		print("BOUGH_GAME_CAPTURE ",view.id)
	library.select(false);receipt.display=game.display_settings.report(root,Vector2i(3840,2160))
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	game.queue_free();await process_frame;quit()
