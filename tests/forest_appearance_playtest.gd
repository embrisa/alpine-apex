extends SceneTree
## Actual production startup/selector/streaming, with capped visual captures only.
const OUT="res://artifacts/winter_integration"
var game
var camera:Camera3D
var checked=0
func _initialize():call_deferred("run")
func run():
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Shared")
	DirAccess.make_dir_recursive_absolute(OUT)
	var field=preload("res://tests/validation_mountain.gd").load_standard()
	assert(field!=null)
	set_meta("mountain_to_load",{"definition":preload("res://scripts/world/mountain_definition.gd").from_field(field,"Winter integration"),"field":field})
	game=load("res://main.tscn").instantiate();game.automated=true;root.add_child(game);current_scene=game
	while not game.initialized or (game.loading and game.loading.busy):await process_frame
	assert(game.forest_appearance.active,"Explicit winter launch must reach production startup")
	game.set_physics_process(false);game.set_process(false);game.effects.stop_audio()
	game.hud.hide_menu();game.hud.root.hide();game.skier.hide()
	game.weather.set_preset("clear");game.weather.set_time_of_day("day");game.world.update_weather(game.weather.state,0,true)
	game.display_settings.apply_display(root,Vector2i(3840,2160));game.display_settings.apply_viewport(root);Engine.max_fps=30
	camera=Camera3D.new();camera.far=6000;camera.fov=68;root.add_child(camera);camera.make_current()
	var views=JSON.parse_string(FileAccess.get_file_as_string("res://art_source/trees/meshy_snow_v1/game_views.json"))
	var captures=[]
	var overview_only="--overview-only" in OS.get_cmdline_user_args()
	for view in views:
		if overview_only and view.id not in ["forest_overview_snow","pine_8m_snow"]:continue
		if not view.id in ["forest_overview_snow","spruce_6m_snow","spruce_12m_snow","spruce_32m_snow","spruce_64m_snow","spruce_85m_snow","fir_8m_snow","pine_8m_snow"]:continue
		camera.transform=str_to_var(view.camera)
		await settle()
		captures.append(await capture(view.id))
		if view.id in ["forest_overview_snow","spruce_32m_snow"]:
			game._set_weather_option("forest_style",0);assert(not game.forest_appearance.active)
			await settle();captures.append(await capture(view.id.replace("_snow","_autumn")))
			game._set_weather_option("forest_style",1);assert(game.forest_appearance.active)
	# Texture tier changes reuse the same geometry and restore High for review.
	var selected=game.world.assets.mesh("forest_spruce_01_lod1")
	game.set_graphics_quality(0)
	assert(selected.surface_get_material(0).get_shader_parameter("mesh_albedo").resource_path.ends_with("_low.res"))
	game.set_graphics_quality(2)
	assert(game.world.assets.mesh("forest_spruce_01_lod1")==selected)
	assert(selected.surface_get_material(0).get_shader_parameter("mesh_albedo").resource_path.ends_with("_high.res"))
	game.weather.set_preset("cloudy");game.world.update_weather(game.weather.state,0,true)
	await settle();captures.append(await capture("winter_cloudy"))
	game.hud.root.show();game.hud.open_settings();game.hud.settings_tabs.current_tab=6;game._sync_weather_ui()
	for frame in 6:await process_frame
	captures.append(await capture("forest_settings"))
	var report={"captures":captures,"verified_batches":checked,"production_startup":true,"selector_restore":true,"quality_switch":true,"scope":"Capped production integration views; no FPS or human/controller acceptance"}
	FileAccess.open(OUT+("/overview_review.json" if overview_only else "/review.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WINTER_INTEGRATION_OK ",checked)
	game.queue_free();await process_frame;quit()
func settle():
	game.display_settings.reset_history()
	for frame in 240:
		await process_frame
		if frame>=60 and game.world.scenery.density_forest.pending.is_empty():break
	assert(game.world.scenery.density_forest.pending.is_empty())
	for node in game.world.scenery.batches:
		var lod=int(node.get_meta("art_lod",-1))
		if lod<0 or lod>2:continue
		var id=str(node.multimesh.mesh.get_meta("forest_asset",""));var key=id+"_lod"+str(lod)
		if not game.forest_appearance.replacement.has(key):continue
		assert(node.multimesh.mesh==(game.forest_appearance.replacement if game.forest_appearance.active else game.forest_appearance.original)[key])
		assert(node.get_meta("forest_tree") and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		checked+=1
	if game.world.wilderness and game.world.wilderness.props:
		for node in game.world.wilderness.props.get_children():
			var key:String=node.get_meta("forest_key","")
			if key.is_empty():continue
			var material:ShaderMaterial=node.multimesh.mesh.surface_get_material(0)
			if game.forest_appearance.active:
				assert("winter/textures" in material.get_shader_parameter("albedo_texture" if key.ends_with("lod2") else "mesh_albedo").resource_path)
func capture(label:String)->String:
	await RenderingServer.frame_post_draw
	var path=OUT+"/"+label+".webp"
	assert(root.get_texture().get_image().save_webp(path,true)==OK)
	print("WINTER_CAPTURE ",label);return path
