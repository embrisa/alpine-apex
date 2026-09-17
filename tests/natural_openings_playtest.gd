extends SceneTree
## Matched production-world views; capture and camera survey only, never FPS evidence.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const OUT = "res://artifacts/natural_openings_20260917"
var seed_number = 849205174
var baseline = false
var features = false

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--baseline": baseline = true
		if arg == "--features": features = true
		if arg.begins_with("--seed="): seed_number = int(arg.get_slice("=",1))
	var field = Definition.Cache.generate(seed_number)
	if field == null: quit(2); return
	var output = OUT+("/features_" if features else ("/old_" if baseline else "/new_"))+str(seed_number)
	DirAccess.make_dir_recursive_absolute(output)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Natural openings review"),"field":field})
	var game = load("res://main.tscn").instantiate()
	game.automated = true; root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_physics_process(false); game.set_process(false); game.effects.stop_audio()
	game.display_settings.apply_display(root,Vector2i(3840,2160)); game.display_settings.apply_viewport(root)
	Engine.max_fps = 60
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.world.update_weather(game.weather.state,0,true)
	var sites = []
	var old_views = []
	if features:
		var cells={}
		for p in field.tree_data.positions:
			if p.y<3400 or p.y>=3500:continue
			var cell=Vector2i(floori(p.x/100),floori(p.z/100))
			if not cells.has(cell):cells[cell]={"count":0,"sum":Vector2.ZERO}
			cells[cell].count+=1;cells[cell].sum+=Vector2(p.x,p.z)
		var best={"count":0}
		for cell in cells.values():
			if cell.count>best.count:best=cell
		assert(best.count>0)
		var centre: Vector2=best.sum/best.count
		var forward=centre.normalized();var at=centre-forward*110
		sites.append({"id":"upper_groves","at":[at.x,at.y],"forward":[forward.x,forward.y],"trees_in_100m_cell":best.count})
		var world=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/generation_v17/world_standard.json"))
		var ids=[]
		for hit in world.corridors.mineral_hits:
			if hit.id in ids:continue
			ids.append(hit.id)
			for placed in field.geology.placements:
				if placed.id!=hit.id:continue
				var rock: Vector3=placed.pose.origin
				var face=field.faces[placed.face]
				forward=face.to_world(Vector2(0,1))
				at=Vector2(rock.x,rock.z)-forward*120
				sites.append({"id":"corridor_boulder_"+str(placed.id),"at":[at.x,at.y],"forward":[forward.x,forward.y]})
				break
			if ids.size()>=2:break
	elif baseline:
		for face_id in [0,3]:
			var face = field.faces[face_id]
			var passage = face.forest_passages[0]
			for candidate in face.forest_passages:
				if ((candidate.start+candidate.finish)*.5-Vector2(0,1950)).length() < ((passage.start+passage.finish)*.5-Vector2(0,1950)).length(): passage = candidate
			var local: Vector2 = (passage.start+passage.finish)*.5
			var at: Vector2 = face.to_world(local-Vector2(0,130))
			var forward: Vector2 = face.to_world(Vector2(0,1))
			sites.append({"id":"forest_face"+str(face_id),"at":[at.x,at.y],"forward":[forward.x,forward.y]})
			at = face.to_world(Vector2(0,1100))
			sites.append({"id":"terrain_face"+str(face_id),"at":[at.x,at.y],"forward":[forward.x,forward.y]})
	else:
		var old = JSON.parse_string(FileAccess.get_file_as_string(OUT+"/old_"+str(seed_number)+"/views.json"))
		sites = old.sites; old_views = old.views
	var views = []
	for site in sites:
		var at = Vector2(site.at[0],site.at[1])
		var p = Vector3(at.x,field.height_at(at.x,at.y),at.y)
		var forward = Vector3(site.forward[0],0,site.forward[1])
		for survey in [true,false]:
			game.start_run(false); game.set_physics_process(false); game.active = true; game.summit_ready = false; game.session.eligible = false
			game.sim.reset(p,atan2(forward.x,forward.z)); game.sim.prime_contacts(game.field)
			game.previous_position = game.sim.position; game.skier.reset_animation(game.sim)
			game.camera.close_view = false; game.camera.reset(); game.camera.make_current()
			game.hud.hide_menu(); game.hud.root.hide(); game._process(0)
			var label: String = site.id+("_survey" if survey else "_chase")
			if survey:
				game.camera.global_position = p-forward*(30 if features else 40)+Vector3.UP*(70 if features else 150)
				var target = p+forward*(120 if features else 270)
				target.y = field.height_at(target.x,target.z)
				game.camera.look_at(target); game.camera.fov = 70
			if not baseline and not features and survey:
				var saved = old_views.filter(func(v): return v.id==label)[0]
				game.camera.global_transform = str_to_var(saved.camera); game.camera.fov = saved.fov
			var camera_at: Vector3 = game.camera.global_position
			var clearance: float = camera_at.y-field.height_at(camera_at.x,camera_at.z)
			assert(clearance>.3,"Review camera must remain above current terrain")
			for frame in 150: await process_frame
			await RenderingServer.frame_post_draw
			var img = root.get_texture().get_image()
			assert(img.save_webp(output+"/"+label+".webp",true,.9)==OK)
			views.append({"id":label,"camera":var_to_str(game.camera.global_transform),"fov":game.camera.fov,"clearance_m":clearance,"comparison":"Current feature review" if features else ("Identical survey transform" if survey else "Same production chase profile on current support"),"pending_regions":game.world.scenery.density_forest.report().get("pending_regions",-1)})
			print("NATURAL_OPENINGS_VIEW ",label)
	FileAccess.open(output+"/views.json",FileAccess.WRITE).store_string(JSON.stringify({"seed":seed_number,"generator":field.GENERATOR_VERSION,"sites":sites,"views":views,"display":game.display_settings.report(root,Vector2i(3840,2160)),"performance_acceptance":false},"\t"))
	game.effects.stop_audio(); game.queue_free(); await process_frame; quit()
