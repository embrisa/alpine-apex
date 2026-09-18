extends SceneTree
const BASE="res://artifacts/meshy_snow_20260918"
const Library=preload("res://art_source/trees/meshy_snow_v1/library.gd")
var game
var field
var camera:Camera3D
var library=Library.new()
var report={"scope":"Actual Standard generator-18 game, matched cameras; visual evidence only","captures":[]}
func _initialize():call_deferred("run")
func run():
	field=preload("res://tests/validation_mountain.gd").load_standard()
	if field==null:quit(2);return
	var definition=preload("res://scripts/world/mountain_definition.gd").from_field(field,"Snowy tree family review")
	set_meta("mountain_to_load",{"definition":definition,"field":field})
	game=load("res://main.tscn").instantiate();game.automated=true;root.add_child(game);current_scene=game
	while not game.initialized or (game.loading and game.loading.busy):await process_frame
	game.set_physics_process(false);game.set_process(false);game.effects.stop_audio()
	game.hud.hide_menu();game.hud.root.hide();game.skier.hide()
	game.weather.set_preset("clear");game.weather.set_time_of_day("day");game.world.update_weather(game.weather.state,0,true)
	game.display_settings.apply_display(root,Vector2i(3840,2160));game.display_settings.apply_viewport(root);Engine.max_fps=30
	camera=Camera3D.new();camera.far=6000;camera.fov=68;root.add_child(camera);camera.make_current()
	library.setup(game.world)
	var stand=FileAccess.open("res://artifacts/far_stand_mesh_20260917/stand.bin",FileAccess.READ).get_var()
	DirAccess.make_dir_recursive_absolute(BASE+"/game_review")
	var center:Vector3=stand.center
	var views=[{"id":"forest_overview","at":center+Vector3(0,26,95),"target":center+Vector3(0,5,0)}]
	for family in ["spruce","fir","pine","birch"]:
		var chosen={};var score=INF
		for tree in stand.trees:
			if not tree.id.begins_with("forest_"+family):continue
			var at:Vector3=tree.pose.origin
			var value=at.distance_squared_to(center)
			if value<score:score=value;chosen=tree
		assert(not chosen.is_empty())
		var record:Dictionary=game.world.assets.tree_record(chosen.id)
		var point:Vector3=chosen.pose.origin;var height_m:float=record.height_m*chosen.pose.basis.y.length()
		var direction=clear_direction(point,35)
		var target=point+Vector3.UP*height_m*.50
		var c:Array=record.get("crown_center",[0,0,0]);var radius:float=record.get("crown_radius",0)*maxf(chosen.pose.basis.x.length(),maxf(chosen.pose.basis.y.length(),chosen.pose.basis.z.length()))
		var crown:Vector3=chosen.pose*Vector3(c[0],c[1],c[2]) if radius>0 else point
		for distance_m in ([6,12,32,64,85] if family=="spruce" else [8,32,85]):
			var at=crown+Vector3(direction.x*(distance_m+radius),0,direction.y*(distance_m+radius))
			at.y=maxf(at.y,field.height_at(at.x,at.z)+2)
			views.append({"id":family+"_"+str(distance_m)+"m","at":at,"target":target,"asset":chosen.id,"actual_detail_distance":at.distance_to(crown)-radius})
	for view in views:
		camera.position=view.at;camera.look_at(view.target)
		for arm in [false,true]:
			library.select(arm);game.display_settings.reset_history()
			for frame in 90:await process_frame
			assert(game.world.scenery.density_forest.pending.is_empty(),"Resident forest before capture")
			await RenderingServer.frame_post_draw
			var image=root.get_texture().get_image();assert(image.get_size()==Vector2i(3840,2160))
			var name=view.id+("_snow" if arm else "_original")
			assert(image.save_webp(BASE+"/game_review/"+name+".webp",true)==OK)
			report.captures.append({"id":name,"camera":var_to_str(camera.transform),"detail_distance_m":view.get("actual_detail_distance",-1),"pending_regions":game.world.scenery.density_forest.pending.size(),"tree_counts":game.world.scenery.family_counts});print("MESHY_GAME_CAPTURE ",name)
	library.select(false);report.inventory=library.inventory;report.display=game.display_settings.report(root,Vector2i(3840,2160))
	FileAccess.open(BASE+"/game_review/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.queue_free();await process_frame;quit()
func clear_direction(point:Vector3,distance_m:float)->Vector2:
	var best=Vector2(0,1);var score=INF
	for heading in 16:
		var direction=Vector2(sin(TAU*heading/16),cos(TAU*heading/16));var value=0.0
		for i in field.tree_data.nearby(point,distance_m+20):
			var other:Vector3=field.tree_data.positions[i]-point;var depth=Vector2(other.x,other.z).dot(direction)
			if depth<1 or depth>distance_m-1:continue
			var lateral=absf(Vector2(other.x,other.z).cross(direction));value+=maxf(0,5.5-lateral)
		if value<score:score=value;best=direction
	return best
