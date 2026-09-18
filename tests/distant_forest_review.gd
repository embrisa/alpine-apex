extends "res://tests/aerial_perspective_review.gd"
## Bounded current-Meshy far-band attribution. Captures are never FPS evidence.
var preset=7
var reconstruction="auto"
var style=1
var condition="clear"
var hour="day"
var variant="reference,production"
var footprints=[]
var variants=[]
var selected_sites=["ride","forest"]
var acceptance=false
var cases=[]
var case_reports=[]
var a2c_shader:Shader
func run():
	assert(DisplayServer.get_name()!="headless")
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Exclusive")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=ProjectSettings.globalize_path(arg.trim_prefix("--output="))
		if arg.begins_with("--forest-preset="):preset=int(arg.get_slice("=",1))
		if arg.begins_with("--forest-upscaler="):reconstruction=arg.get_slice("=",1)
		if arg.begins_with("--forest-style="):style=int(arg.get_slice("=",1))
		if arg.begins_with("--forest-weather="):condition=arg.get_slice("=",1)
		if arg.begins_with("--forest-hour="):hour=arg.get_slice("=",1)
		if arg.begins_with("--forest-variant="):variant=arg.get_slice("=",1)
		if arg.begins_with("--forest-sites="):selected_sites=arg.get_slice("=",1).split(",")
		if arg=="--acceptance":acceptance=true
	assert(preset in [7,10] and reconstruction in ["auto","native"] and style in [0,1,2])
	variants=variant.split(",")
	for selected in variants:assert(selected in ["reference","production","no_background","a2c"])
	assert(not output.is_empty() and not DirAccess.dir_exists_absolute(output))
	DirAccess.make_dir_recursive_absolute(output);metadata("before")
	field=preload("res://tests/validation_mountain.gd").load_standard()
	if field==null:quit(2);return
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Distant forest"),"field":field})
	game=load("res://main.tscn").instantiate();game.automated=true;game.benchmark_no_captures=true
	root.add_child(game);current_scene=game
	while not game.initialized or (game.loading and game.loading.busy):await process_frame
	game.set_process(false);game.set_physics_process(false);game.set_audio_muted(true)
	game.start_run(false);game.summit_ready=false;game.session.eligible=false
	game.set_graphics_preset(preset);game.display_settings.upscaler=reconstruction
	game.display_settings.frame_generation=false;game.display_settings.terrain_gi=false
	game.display_settings.display.apply(root,pixels,true);game.display_settings.apply_viewport(root);Engine.max_fps=30
	game.forest_appearance.select(style)
	game.weather.set_automatic(false);game.weather.set_time_cycle(false)
	game.weather.set_preset(condition);game.weather.set_time_of_day(hour)
	game.world.update_weather(game.weather.state,0,false)
	game.hud.hide_menu();game.hud.root.hide();game.skier.hide()
	for particle in game.effects.sprays+game.weather_effects.volumes+game.weather_effects.drifts:particle.speed_scale=0
	camera=Camera3D.new();camera.fov=68;camera.far=32000;game.add_child(camera);camera.make_current()
	if acceptance:
		for quality in [7,10]:
			for mode in ["auto","native"]:
				for weather in ["clear","cloudy"]:cases.append([quality,mode,1,weather,"day"])
		cases.append_array([[7,"auto",0,"clear","dusk"],[10,"native",2,"clear","night"]])
	else:cases.append([preset,reconstruction,style,condition,hour])
	for spec in cases:
		preset=spec[0];reconstruction=spec[1];style=spec[2];condition=spec[3];hour=spec[4]
		await capture_case()
	metadata("after")
	var differences=metadata_command(["compare","--before",output+"/inputs_before.json","--after",output+"/inputs_after.json"],output+"/input_changes.json")
	assert(differences.get("stable_inputs",false))
	preload("res://tests/test_report.gd").write(output+"/results.json",JSON.stringify({"views":views,"footprints":footprints,"cases":case_reports,"variant":variant,"preset":preset,"style":style,"weather":condition,"hour":hour,"display":game.display_settings.report(root,pixels),"stable_sources":true,"scope":"30 FPS capped Standard far-band captures; not performance or human acceptance"},"\t"))
	print("DISTANT_FOREST_REVIEW_COMPLETE ",variant)
	game.effects.stop_audio();game.queue_free();await process_frame;quit()
func capture_case():
	game.set_graphics_preset(preset);game.display_settings.upscaler=reconstruction
	game.display_settings.frame_generation=false;game.display_settings.terrain_gi=false
	game.display_settings.apply_viewport(root);Engine.max_fps=30
	game.forest_appearance.select(style)
	game.weather.set_preset(condition);game.weather.set_time_of_day(hour)
	game.world.update_weather(game.weather.state,0,false)
	var label="p%d_%s_%s_%s_%s"%[preset,reconstruction,game.forest_appearance.STYLES[style],condition,hour]
	for site in (["ride"] if acceptance else selected_sites):
		if site=="forest":camera.transform=str_to_var(JSON.parse_string(FileAccess.get_file_as_string("res://art_source/trees/meshy_snow_v1/game_views.json"))[0].camera)
		else:place(site)
		game.world.scenery.density_forest.update_residency(camera.position)
		for frame in 90:await process_frame
		footprint(label+"_"+site)
		var origin=camera.position
		for selected in variants:
			variant=selected;apply_variant();camera.position=origin
			game.display_settings.reset_history()
			for frame in 30:await process_frame
			await picture(label+"_"+site+"_"+variant+"_still")
			for frame in (16 if acceptance else 31):
				camera.position=origin+camera.basis.x*float(frame)*(.4 if acceptance else .2)
				await process_frame;await RenderingServer.frame_post_draw
				# Original-resolution crops preserve the actual subpixel pattern.
				var path="%s_%s_%s_move_%02d.png"%[label,site,variant,frame]
				assert(root.get_texture().get_image().get_region(Rect2i(800,1000,2240,700)).save_png(output+"/"+path)==OK)
				views.append({"image":path,"camera":str(camera.global_transform),"frame":frame,"crop":[800,1000,2240,700]})
	case_reports.append({"label":label,"preset":preset,"style":style,"weather":condition,"hour":hour,"display":game.display_settings.report(root,pixels)})
func apply_variant():
	for node in game.world.wilderness.props.get_children():
		if node.get_meta("kind","")!="tree":continue
		node.visible=variant!="no_background"
		var mat:ShaderMaterial=node.multimesh.mesh.surface_get_material(0)
		if variant=="production":
			mat.shader=load("res://assets/graphics/offmap_tree.gdshader")
			preload("res://scripts/world/wilderness_props.gd").configure_card(mat,node.multimesh.mesh)
		elif variant in ["no_background","reference"]:mat.shader=load("res://tests/fixtures/distant_forest_reference.gdshader")
		else:
			if a2c_shader==null:
				a2c_shader=Shader.new()
				a2c_shader.code=FileAccess.get_file_as_string("res://tests/fixtures/distant_forest_reference.gdshader").replace("shadows_disabled;","shadows_disabled,alpha_to_coverage;").replace("ALPHA_SCISSOR_THRESHOLD=.35;","ALPHA_SCISSOR_THRESHOLD=.35; ALPHA_ANTIALIASING_EDGE=.35; ALPHA_TEXTURE_COORDINATE=UV*vec2(textureSize(albedo_texture,0));")
			mat.shader=a2c_shader
		var base:AABB=node.get_meta("card_filter_base_bound")
		node.multimesh.custom_aabb=base.grow(preload("res://scripts/world/wilderness_props.gd").CARD_FILTER_PADDING_M if variant=="production" else 0.0)
func footprint(site:String):
	var records={"playable":[],"background":[]}
	var examples=[]
	for owner in records:
		var nodes=game.world.scenery.batches if owner=="playable" else game.world.wilderness.props.get_children()
		for node in nodes:
			if not node is MultiMeshInstance3D:continue
			if owner=="playable" and int(node.get_meta("art_lod",-1))!=2:continue
			if owner=="background" and node.get_meta("kind","")!="tree":continue
			var mesh=node.multimesh.mesh
			var mat:ShaderMaterial=mesh.surface_get_material(0)
			var width=mesh.get_aabb().size.x*float(mat.get_shader_parameter("card_crop"))
			var count=node.multimesh.instance_count if node.multimesh.visible_instance_count<0 else node.multimesh.visible_instance_count
			for index in count:
				var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(index)
				var distance_m=camera.position.distance_to(pose.origin)
				if distance_m>(game.graphics.tree_far_m if owner=="playable" else game.graphics.offmap_tree_distance_m):continue
				if camera.is_position_behind(pose.origin):continue
				var point=camera.unproject_position(pose.origin)
				if not Rect2(Vector2.ZERO,Vector2(pixels)).has_point(point):continue
				var right=Vector3(camera.position.z-pose.origin.z,0,pose.origin.x-camera.position.x).normalized()
				var projected=camera.unproject_position(pose.origin+right*width*pose.basis.x.length()*.5).distance_to(camera.unproject_position(pose.origin-right*width*pose.basis.x.length()*.5))*root.scaling_3d_scale
				records[owner].append(projected)
				if examples.size()<20 and owner=="background" and projected<1.2:examples.append({"screen":str(point),"world":str(pose.origin),"distance_m":distance_m,"width_internal_px":projected,"source_width_m":width*pose.basis.x.length()})
	var stats={}
	for owner in records:
		var widths:Array=records[owner];widths.sort()
		stats[owner]={"count":widths.size(),"below_one":widths.filter(func(v):return v<1).size(),"below_two":widths.filter(func(v):return v<2).size(),"min":widths[0] if widths.size() else 0,"median":widths[widths.size()/2] if widths.size() else 0,"max":widths[-1] if widths.size() else 0}
	footprints.append({"site":site,"stats":stats,"examples":examples,"scope":"Anchor in view and distance range; terrain occlusion and shader near-fade not tested","scale":root.scaling_3d_scale})
	preload("res://tests/test_report.gd").write(output+"/footprints.json",JSON.stringify(footprints,"\t"))
func metadata(phase:String):
	var arguments=["capture","--root",ProjectSettings.globalize_path("res://"),"--scope",ProjectSettings.globalize_path("res://config/benchmark_metadata_scope.json"),"--producer","tests/distant_forest_review.gd","--engine",OS.get_executable_path()]
	return metadata_command(arguments,output+"/inputs_"+phase+".json")
