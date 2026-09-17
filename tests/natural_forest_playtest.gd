extends SceneTree
## Matched production-camera review, separate from capture-free route timings.
const Definition=preload("res://scripts/world/mountain_definition.gd")
var output_root="res://artifacts/natural_forest_20260917"
var baseline=false
var seed_number=849205174
var game
var field
var output:String
var views=[]
var motion_only=false
var motion_trace={}
var motion_habitat="upper"
func _initialize()->void:run.call_deferred()
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-root="):output_root=arg.get_slice("=",1)
		if arg=="--baseline":baseline=true
		if arg=="--motion":motion_only=true
		if arg.begins_with("--motion-habitat="):
			motion_habitat=arg.get_slice("=",1)
			assert(motion_habitat in ["lower","upper","mixed"])
		if arg.begins_with("--seed="):seed_number=int(arg.get_slice("=",1))
	if Definition.CURRENT_VERSION!=16 and output_root=="res://artifacts/natural_forest_20260917":printerr("Use --output-root for current generator review; Dev94 evidence is retained.");quit(2);return
	field=Definition.Cache.generate(seed_number)
	if field==null:quit(2);return
	output=output_root+("/old_views_" if baseline else "/new_views_")+str(seed_number)
	DirAccess.make_dir_recursive_absolute(output)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Natural forest review"),"field":field})
	game=load("res://main.tscn").instantiate();game.automated=true;root.add_child(game);current_scene=game
	while not game.initialized or (game.loading and game.loading.busy):await process_frame
	game.set_physics_process(false);game.set_process(false);game.effects.stop_audio()
	game.display_settings.apply_display(root,Vector2i(3840,2160));game.display_settings.apply_viewport(root);Engine.max_fps=60
	game.weather.set_preset("clear");game.weather.set_time_of_day("day")
	game.world.update_weather(game.weather.state,0,true)
	if motion_only:
		await capture_motion()
		game.effects.stop_audio();game.queue_free();await process_frame;quit();return
	var sites=[]
	var old_views=[]
	if baseline:
		if seed_number==Definition.DEFAULT_SEED:
			for habitat in ["lower","upper","mixed"]:
				var trace=JSON.parse_string(FileAccess.get_file_as_string(output_root+"/old_traces/"+habitat+".json"))
				assert(preload("res://tests/performance_trace.gd").Inputs.expand(trace).is_empty())
				sites.append({"id":habitat,"origin":trace.scenario_origin,"heading":trace.heading})
		else:sites.append({"id":"lower","origin":[1608,1416],"heading":1.8})
		for face_id in [2,4]:
			var chosen=Vector3.ZERO;var score=INF
			for i in range(0,field.tree_data.size(),7):
				var p:Vector3=field.tree_data.positions[i]
				if p.y<3320:continue
				if field.adjacent_faces(Vector2(p.x,p.z))[0].index!=face_id:continue
				var value=absf(p.y-3430)
				if value<score:score=value;chosen=p
			assert(chosen!=Vector3.ZERO)
			var at=Vector2(chosen.x,chosen.z)-Vector2(chosen.x,chosen.z).normalized()*16
			var downhill=Vector3.DOWN.slide(field.contact_normal(at.x,at.y))
			sites.append({"id":"upper_face"+str(face_id),"origin":[at.x,at.y],"heading":atan2(downhill.x,downhill.z)})
	else:
		var old=JSON.parse_string(FileAccess.get_file_as_string(output_root+"/old_views_"+str(seed_number)+"/views.json"))
		sites=old.sites.duplicate(true);old_views=old.views
		var old_survey=JSON.parse_string(FileAccess.get_file_as_string(output_root+"/old_"+str(seed_number)+".json"))
		var high_sites={}
		for tree in field.tree_data.positions:
			if tree.y<old_survey.elevation.max+40:continue
			var face_id:int=field.adjacent_faces(Vector2(tree.x,tree.z))[0].index
			if not high_sites.has(face_id) or tree.y>high_sites[face_id].y:high_sites[face_id]=tree
		var high_faces=high_sites.keys()
		high_faces.sort_custom(func(a,b):return high_sites[a].y>high_sites[b].y)
		for face_id in high_faces:
			if sites.size()>=old.sites.size()+2:break
			var tree:Vector3=high_sites[face_id]
			var uphill=-Vector3.DOWN.slide(field.contact_normal(tree.x,tree.z)).normalized()
			var at=Vector2(tree.x+uphill.x*18,tree.z+uphill.z*18)
			sites.append({"id":"new_upper_face"+str(face_id),"origin":[at.x,at.y],"heading":atan2(-uphill.x,-uphill.z),"new_only":true,"tree_altitude_m":tree.y})
	for site in sites:
		var p=Vector3(site.origin[0],field.height_at(site.origin[0],site.origin[1]),site.origin[1])
		for close in [false,true]:
			game.start_run(false);game.set_physics_process(false);game.active=true;game.summit_ready=false;game.session.eligible=false
			game.sim.reset(p,site.heading);game.sim.prime_contacts(game.field)
			game.previous_position=game.sim.position;game.skier.reset_animation(game.sim)
			game.camera.close_view=close;game.camera.reset();game.camera.make_current()
			game.hud.hide_menu();game.hud.root.hide();game._process(0)
			var label:String=site.id+("_first_person" if close else "_chase")
			if not baseline and not site.get("new_only",false):
				var saved=old_views.filter(func(v):return v.id==label)[0]
				game.camera.global_transform=str_to_var(saved.camera);game.camera.fov=saved.fov
			for frame in 120:await process_frame
			await RenderingServer.frame_post_draw
			var img=root.get_texture().get_image();assert(img.get_size()==Vector2i(3840,2160))
			assert(img.save_webp(output+"/"+label+".webp",true,.9)==OK)
			views.append({"id":label,"camera":var_to_str(game.camera.global_transform),"fov":game.camera.fov,"trees_175m":field.tree_data.nearby(p,175).size(),"position":[p.x,p.y,p.z],"pending_regions":game.world.scenery.density_forest.report().get("pending_regions",-1)})
			print("NATURAL_FOREST_VIEW ",label)
	FileAccess.open(output+"/views.json",FileAccess.WRITE).store_string(JSON.stringify({"seed":seed_number,"generator":field.GENERATOR_VERSION,"sites":sites,"views":views,"families":game.world.scenery.family_counts,"display":game.display_settings.report(root,Vector2i(3840,2160)),"performance_acceptance":false},"\t"))
	game.effects.stop_audio();game.queue_free();await process_frame;quit()
func capture_motion()->void:
	var trace_tools=preload("res://tests/performance_trace.gd")
	motion_trace=JSON.parse_string(FileAccess.get_file_as_string(output_root+"/new_traces/"+motion_habitat+".json"))
	assert(trace_tools.preflight_error(motion_trace,Definition.CURRENT_VERSION,false).is_empty())
	assert(trace_tools.matches(field,motion_trace.identity))
	game.start_run(false);game.set_physics_process(false);game.set_process(false)
	game.active=true;game.summit_ready=false;game.session.eligible=false;game.timed=false
	game.benchmark_input=motion_input;game.benchmark_no_captures=true
	var at=motion_trace.scenario_origin
	game.sim.reset(Vector3(at[0],field.height_at(at[0],at[1]),at[1]),motion_trace.heading);game.sim.prime_contacts(game.field)
	game.previous_position=game.sim.position;game.skier.reset_animation(game.sim)
	game.camera_settings.restore(motion_trace.presentation.camera);game.camera.settings=game.camera_settings
	game.camera.close_view=false;game.camera.reset();game.camera.make_current()
	game.hud.hide_menu();game.hud.root.hide();game._process(0)
	for frame in 120:await process_frame
	var folder=output_root+"/motion_frames";DirAccess.make_dir_recursive_absolute(folder)
	var samples=[]
	for frame in 900:
		game._physics_process(1.0/120);game._physics_process(1.0/120);game._process(1.0/60)
		await process_frame
		if frame%4==0:
			await RenderingServer.frame_post_draw
			var img=root.get_texture().get_image();img.resize(1920,1080,Image.INTERPOLATE_LANCZOS)
			img.save_jpg(folder+"/frame_%04d.jpg"%(frame/4),.9)
		if frame%60==0:samples.append({"tick":game.sim.ticks,"position":str(game.sim.position),"trees_175m":field.tree_data.nearby(game.sim.position,175).size(),"pending_regions":game.world.scenery.density_forest.report().get("pending_regions",-1)})
		assert(not game.sim.crashed)
	var end=motion_trace.result.position
	assert(game.sim.ticks==1800 and game.sim.position==Vector3(end[0],end[1],end[2]))
	FileAccess.open(output_root+"/motion.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"15 seconds ordinary "+motion_habitat+" input; fixed 120 Hz simulation/60 Hz presentation; 15 fps capture; no performance claim","ticks":game.sim.ticks,"frames":225,"samples":samples,"exact_trace":true},"\t"))
	print("NATURAL_FOREST_MOTION_COMPLETE ticks=",game.sim.ticks)
func motion_input(tick:int)->RiderInput:
	return preload("res://tests/performance_trace.gd").Inputs.decode(motion_trace.commands[mini(tick/int(motion_trace.command_ticks),motion_trace.commands.size()-1)])
