extends SceneTree
## Capped, actual-world gravel views. No performance claim from capture timings.
var game
var camera: Camera3D
var output="res://artifacts/rock_gravel/render"
var captures=[]
var standard=false
var quick=false
func _initialize() -> void: call_deferred("run")
func capture(label: String,frames: int=45) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK)
	captures.append({"file":label+".png","camera":str(camera.global_transform),"population":game.world.minerals.gravel.population()})
func aim(p: Vector3,offset: Vector3,target: float=0) -> void:
	camera.position=p+offset
	camera.position.y=maxf(camera.position.y,game.field.sample(camera.position.x,camera.position.z).height+(.12 if offset.length()<1 else 1.5))
	camera.look_at(p+Vector3.UP*target); camera.make_current()
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	for arg in OS.get_cmdline_user_args():
		if arg=="--standard": standard=true
		if arg=="--quick": quick=true
		if arg.begins_with("--output="): output="res://"+arg.get_slice("=",1)
	DirAccess.make_dir_recursive_absolute(output); Engine.max_fps=60
	if standard:
		var field=preload("res://tests/validation_mountain.gd").load_standard()
		assert(field!=null)
		set_meta("mountain_to_load",{"definition":preload("res://scripts/world/mountain_definition.gd").from_field(field,"Gravel review"),"field":field})
	else: set_meta("test_map_fixture","perf-gravel")
	game=load("res://main.tscn").instantiate(); game.automated=true; root.add_child(game); current_scene=game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_physics_process(false); game.set_process(false); game.active=false; game.summit_ready=false
	game.effects.muted=true; game.set_audio_muted(true); game.hud.hide(); game.skier.hide()
	game.display_settings.apply_display(root,Vector2i(1920,1080)); Engine.max_fps=60
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day"); game.world.update_weather(game.weather.state,0,true)
	camera=Camera3D.new(); game.add_child(camera); camera.fov=68; camera.near=.03; camera.far=2000
	var gravel=game.world.minerals.gravel; var field=game.field
	var before=var_to_bytes([field.heights,field.obstacles,field.geology.placements,field.geology.collision.entries])
	var selected=Vector3.ZERO
	for z in (range(5,12) if not standard else []):
		var patch: Vector3=gravel.placement.patch(Vector2i(0,z))
		if patch.z>0 and gravel.placement.suitable(Vector2(patch.x,patch.y)): selected=Vector3(patch.x,field.sample(patch.x,patch.y).height,patch.y); break
	if standard:
		var trace=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/rock_gravel/standard_trace.json"))
		selected=Vector3(trace.scenario_origin[0],0,trace.scenario_origin[1]); selected.y=field.sample(selected.x,selected.z).height
	assert(selected!=Vector3.ZERO)
	aim(selected,Vector3(0,1.8,-3),.1); await capture("bed_ski_height",180)
	gravel.set_mode("off"); await capture("bed_off")
	gravel.set_mode("all"); aim(selected,Vector3(.1,.32,-.48),0); await capture("centimetre_detail",180)
	aim(selected,Vector3(2,3,-7),.2); await capture("bed_shape",120)
	var edge=Vector3(-4,field.sample(-4,selected.z).height,selected.z) if not standard else selected+Vector3(-4,0,0)
	edge.y=field.sample(edge.x,edge.z).height
	aim(edge,Vector3(2,2.5,-5),.1); await capture("snow_rock_edge",120)
	for distance in ([3.5,4.5,5.5,10.0,14.0,18.0] if not quick else []):
		aim(selected,Vector3(0,1.8,-distance),.1); await capture("lod_"+str(distance),60)
	for level in ([0,1,2] if not quick else []):
		game.world.apply_graphics(preload("res://scripts/presentation/graphics_quality.gd").preset(level))
		aim(selected,Vector3(0,1.8,-3),.1); await capture("quality_"+str(level),120)
	for preset in (["cloudy","snowfall"] if not quick else []):
		game.weather.set_preset(preset); game.world.update_weather(game.weather.state,0,true)
		await capture(preset,90)
	assert(before==var_to_bytes([field.heights,field.obstacles,field.geology.placements,field.geology.collision.entries]))
	preload("res://tests/test_report.gd").write(output.path_join("review.json"),JSON.stringify({"captures":captures,"map":field.fixture_descriptor() if not standard else {"id":"Standard-v15","seed":field.seed_value,"trees":field.tree_data.size(),"physical_signature":preload("res://scripts/world/generation_sources.gd").signature(false)},"physical_unchanged":true,"pixels":[1920,1080],"frame_cap":60,"performance_evidence":false,"human_acceptance":false},"\t"))
	game.queue_free(); await process_frame; print("GRAVEL_RENDER_COMPLETE ",captures.size()); quit()
