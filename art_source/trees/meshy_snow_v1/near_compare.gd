extends "res://art_source/trees/meshy_snow_v1/prepare.gd"
## Matched actual-game close tree comparison. Never writes runtime assets.
const Library=preload("res://art_source/trees/meshy_snow_v1/library.gd")
const CASES=[
	["current_21k","tree_detail.glb",false],
	["target_20k","tree_close_20k.glb",false],
	["target_40k","tree_close_40k.glb",false],
	["cleaned_40k","tree_finish_40k.glb",true],
	["cleaned_73k","tree_finish_80k.glb",true]]
func run():
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Shared")
	var field=preload("res://tests/validation_mountain.gd").load_standard()
	if field==null:quit(2);return
	var definition=preload("res://scripts/world/mountain_definition.gd").from_field(field,"Snowy close tree comparison")
	set_meta("mountain_to_load",{"definition":definition,"field":field})
	var game=load("res://main.tscn").instantiate();game.automated=true;root.add_child(game);current_scene=game
	while not game.initialized or (game.loading and game.loading.busy):await process_frame
	game.set_physics_process(false);game.set_process(false);game.effects.stop_audio()
	game.hud.hide_menu();game.hud.root.hide();game.skier.hide()
	game.weather.set_preset("clear");game.weather.set_time_of_day("day");game.world.update_weather(game.weather.state,0,true)
	game.display_settings.apply_display(root,Vector2i(3840,2160));game.display_settings.apply_viewport(root);Engine.max_fps=30
	camera=Camera3D.new();camera.far=6000;camera.fov=68;root.add_child(camera);camera.make_current()
	var library=Library.new();library.setup(game.world)
	var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/game_review/report.json"))
	var views=[]
	for row in saved.captures:
		if row.id in ["spruce_6m_snow","spruce_12m_snow"]:views.append(row)
	assert(views.size()==2)
	var output=OUT+"/near_compare";DirAccess.make_dir_recursive_absolute(output)
	var receipt={"scope":"Actual game close LOD comparison only; unchanged prototype middle/far meshes; no FPS claim","captures":[]}
	for entry in CASES:
		var mesh=load_close(SOURCE+"/spruce/"+entry[1])
		var source_mat:StandardMaterial3D=mesh.surface_get_material(0)
		var mat:ShaderMaterial=library.source.spruce.lods[0].mat.duplicate()
		if entry[2]:
			var shader=Shader.new();shader.code=mat.shader.code.replace("NORMAL_MAP_DEPTH=.35;","NORMAL_MAP_DEPTH=0.0;");mat.shader=shader
		mat.set_shader_parameter("mesh_albedo",source_mat.albedo_texture)
		mat.set_shader_parameter("mesh_normal",source_mat.normal_texture)
		mat.set_shader_parameter("mesh_roughness",source_mat.roughness_texture)
		mat.set_shader_parameter("roughness_channel",source_mat.roughness_texture_channel)
		var im=source_mat.albedo_texture.get_image()
		if im.is_compressed():assert(im.decompress()==OK)
		library.source.spruce.lods[0]={"mesh":mesh,"mat":mat,"image":im}
		for id in game.world.assets.tree_ids():
			var record:Dictionary=game.world.assets.tree_record(id)
			if record.family!="spruce":continue
			var key=id+"_lod0";var box:AABB=library.original[key].get_aabb();var srcbox=mesh.get_aabb()
			var scale_m=Vector3(box.size.x/srcbox.size.x,box.size.y/12.0,box.size.z/srcbox.size.z)
			var replacement=library.detail(id,record,"spruce",0,scale_m,box.position.y)
			replacement.set_meta("forest_asset",id);library.replacement[key]=replacement
		library.select(true)
		for view in views:
			camera.transform=str_to_var(view.camera);game.display_settings.reset_history()
			for frame in 90:await process_frame
			assert(game.world.scenery.density_forest.pending.is_empty())
			await RenderingServer.frame_post_draw
			var file=output+"/"+entry[0]+"_"+view.id+".webp"
			assert(root.get_texture().get_image().save_webp(file,true)==OK)
			receipt.captures.append({"variant":entry[0],"source":entry[1],"triangles":mesh.surface_get_array_index_len(0)/3,"vertices":mesh.surface_get_array_len(0),"camera":view.camera,"detail_distance":view.detail_distance_m,"image":file})
			print("MESHY_NEAR ",entry[0]," ",view.id)
	library.select(false);receipt.display=game.display_settings.report(root,Vector2i(3840,2160))
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	game.queue_free();await process_frame;quit()

func load_close(path:String)->ArrayMesh:
	var state=GLTFState.new();var document=GLTFDocument.new();assert(document.append_from_file(path,state)==OK)
	var imported=document.generate_scene(state);var parts=gather(imported);assert(parts.size()==1)
	var a:Array=parts[0].arrays;var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var box=AABB(v[0],Vector3.ZERO)
	for p in v:box=box.expand(p)
	var center=Vector2.ZERO;var count=0
	for p in v:
		if p.y<box.position.y+box.size.y*.015:center+=Vector2(p.x,p.z);count+=1
	center/=maxi(1,count)
	for i in v.size():v[i]=(v[i]-Vector3(center.x,box.position.y,center.y))*(12.0/box.size.y)
	a[Mesh.ARRAY_VERTEX]=v
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	var st=SurfaceTool.new();st.create_from(mesh,0);st.generate_tangents();st.optimize_indices_for_cache();mesh=st.commit()
	mesh.surface_set_material(0,parts[0].material);imported.free();return mesh
