extends SceneTree
## Functional captures only: fixed pixels/cap, no frame-time/GPU/CPU statistics.
const Cache=preload("res://scripts/world/mountain_cache_v15.gd")
const Quality=preload("res://scripts/presentation/graphics_quality.gd")
var output="res://artifacts/terrain_grass_20260913/local"
var game
var field
var camera: Camera3D
var captures: Array=[]
var standard=false
var motion_only=false
var seed_number=849205174
var pixels=Vector2i(1280,720)
var chronology: Array=[]
var focus_anchor=Vector3.ZERO
const Obstacles=preload("res://scripts/world/obstacle_access.gd")
func _initialize() -> void: call_deferred("run")
func capture(label: String,frames: int = 3) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	var path=output+"/"+label+".png"
	var image=root.get_texture().get_image()
	assert(image.get_size()==pixels,"Requested output pixels")
	assert(image.save_png(path)==OK)
	captures.append({"file":path,"camera":str(camera.global_transform),"focus":[focus_anchor.x,focus_anchor.y,focus_anchor.z],"wind_time":game.world.assets.wind_time,"population":game.world.grass.population()})
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg=="--standard": standard=true
		if arg=="--motion-only": motion_only=true
		if arg.begins_with("--seed="): seed_number=int(arg.get_slice("=",1))
		if arg.begins_with("--output="): output="res://"+arg.get_slice("=",1)
	DirAccess.make_dir_recursive_absolute(output)
	Engine.max_fps=60
	root.size=pixels
	if standard:
		field=Cache.generate(seed_number)
		if not field: quit(1); return
		set_meta("mountain_to_load",{"definition":preload("res://scripts/world/mountain_definition.gd").from_field(field,"Grass habitat review"),"field":field})
	else: set_meta("test_map_fixture","perf-mixed")
	game=load("res://main.tscn").instantiate(); game.automated=true
	root.add_child(game); current_scene=game
	while not game.initialized or (game.loading and game.loading.busy):
		Engine.max_fps=60
		await process_frame
	field=game.field
	game.set_physics_process(false); game.set_process(false)
	game.active=false; game.summit_ready=false; game.session.eligible=false
	game.effects.muted=true; game.effects.set_process(false)
	game.hud.hide_menu(); game.hud.root.hide()
	game.display_settings.apply_display(root,pixels); Engine.max_fps=60
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.world.update_weather(game.weather.state,1.0,true)
	camera=Camera3D.new(); game.add_child(camera); camera.far=10000; camera.fov=65; camera.make_current()
	await isolated()
	if standard: await habitats()
	else: await local_motion()
	var report={"seed":field.seed_value,"map":"Standard v15" if standard else "perf-mixed","pixels":[pixels.x,pixels.y],"frame_cap":60,"captures":captures,"chronology":chronology,"motion_render_steps":900,"motion_capture_interval_steps":15,"performance_acceptance":false,"human_acceptance":false,"simulation":"Synthetic bounded visual influence; physical regression is separate","source_signature":preload("res://scripts/world/generation_sources.gd").signature(true),"engine":Engine.get_version_info().string,"engine_sha256":preload("res://scripts/world/generation_sources.gd").engine_identity()}
	report.display=game.display_settings.report(root,pixels)
	preload("res://tests/test_report.gd").write(output+"/review.json",JSON.stringify(report,"\t"))
	print("GRASS_RENDER_COMPLETE captures=",captures.size()," output=",output)
	game.queue_free(); await process_frame; quit()
func isolated() -> void:
	game.world.hide(); game.skier.hide()
	for effect in [game.effects,game.weather_effects,game.storm_effects]:
		if effect is Node3D: effect.hide()
	var stage=Node3D.new(); game.add_child(stage)
	var sun=DirectionalLight3D.new(); stage.add_child(sun); sun.rotation_degrees=Vector3(-35,-25,0); sun.light_energy=1.1
	var env: Environment=game.world.environment
	var saved={}
	for key in ["background_mode","background_color","fog_enabled","volumetric_fog_enabled","ambient_light_source","ambient_light_color","ambient_light_energy"]: saved[key]=env.get(key)
	env.background_mode=Environment.BG_COLOR; env.background_color=Color(.10,.13,.17)
	env.fog_enabled=false; env.volumetric_fog_enabled=false
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color(.6,.7,.85); env.ambient_light_energy=.65
	for i in 3:
		var mm=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.use_custom_data=true
		mm.mesh=game.world.grass.mesh_cache["forest_fan_02_"+["green","dusted","snow"][i]+"_lod1"]
		mm.instance_count=1; mm.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3((i-1)*1.05,0,0)))
		mm.set_instance_custom_data(0,Color(.2,.49,.5,1))
		var mesh=MultiMeshInstance3D.new(); mesh.multimesh=mm; mesh.material_override=game.world.grass.materials[0]; stage.add_child(mesh)
		mesh.set_instance_shader_parameter("grass_birth",-1.0)
	camera.position=Vector3(0,.7,2.8); camera.look_at(Vector3(0,.22,0))
	await capture("isolated_vegetation_only",6)
	for i in [0,2]:
		camera.position=Vector3((i-1)*1.05,.38,1.0); camera.look_at(Vector3((i-1)*1.05,.22,0))
		await capture("isolated_"+["green","dusted","snow"][i],6)
	stage.free(); game.world.show()
	for key in saved: env.set(key,saved[key])
func focus(p: Vector3,offset: Vector3,budget: int = 625) -> void:
	focus_anchor=p
	var normal: Vector3=field.sample(p.x,p.z).normal
	var best=p+offset; var best_score=INF
	for attempt in 8:
		var lateral=Vector3(offset.x,0,offset.z).rotated(Vector3.UP,attempt*TAU/8).slide(normal)
		var at=p+lateral+normal*offset.y
		at.y=maxf(at.y,field.sample(at.x,at.z).height+.4)
		var score=0.0
		for probe in range(1,9):
			var point=(p+Vector3.UP*.12).lerp(at,float(probe)/8)
			if point.y<field.sample(point.x,point.z).height+.06: score+=10
			if not clear_of_trunks(point,.18): score+=1
		if field.has_method("ray_geology") and not field.ray_geology(p+Vector3.UP*.12,at,.15).is_empty(): score+=10
		if score<best_score: best=at; best_score=score
		if score==0: break
	camera.position=best; camera.look_at(p+Vector3.UP*.12); camera.make_current()
	game.world.grass.stream(camera.position,budget)
func clear_of_trunks(p: Vector3,margin: float) -> bool:
	for id in field.nearby_obstacle_indices(p,3.0):
		var tree: Dictionary=Obstacles.record(field,id)
		if Vector2(p.x-tree.position.x,p.z-tree.position.z).length()<tree.radius+margin: return false
	return true
func habitats() -> void:
	var survey: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/terrain_grass_20260913/survey_%d.json" % seed_number))
	for finish in ["green","dusted","snow"]:
		if motion_only: break
		var examples: Array=survey.examples[finish]
		assert(not examples.is_empty())
		for index in [0,mini(6,examples.size()-1)]:
			var item: Dictionary=examples[index]
			var p=Vector3(item.position[0],item.position[1]+item.burial,item.position[2])
			# Keep the surveyed cell/finish but avoid reviewing a tuft hidden in a trunk.
			if not clear_of_trunks(p,.55):
				for candidate in game.world.grass.placement.cell(Vector2i(item.key[0],item.key[1])):
					if candidate.asset.ends_with(finish) and clear_of_trunks(candidate.pose.origin,.55):
						p=candidate.pose.origin; p.y=field.sample(p.x,p.z).height; break
			focus(p,Vector3(1.2,.7,1.7))
			await capture("%s_%d_close" % [finish,index],30)
			await skiing_camera(p,"%s_%d" % [finish,index])
	var best: Dictionary=survey.dense_cells[0]
	var items=game.world.grass.placement.cell(Vector2i(best.key[0],best.key[1]))
	var centre: Vector3=items[items.size()/2].pose.origin
	centre.y=field.sample(centre.x,centre.z).height
	focus(centre,Vector3(2,1.4,3))
	await capture("forest_pocket",15)
	await motion(centre,"forest_motion")
	await streaming(centre)
	for period in ["dusk","night"]:
		game.weather.set_time_of_day(period); game.world.update_weather(game.weather.state,0,false)
		await capture("forest_"+period,8)
	game.weather.set_time_of_day("day"); game.weather.set_preset("snowfall"); game.world.update_weather(game.weather.state,0,false)
	await capture("forest_snowfall",8)
func skiing_camera(p: Vector3,label: String) -> void:
	# Actual production chase and first-person placement at a stable 60 km/h pose.
	var observer=camera
	focus_anchor=p
	game.sim.reset(p,0)
	game.sim.velocity=Vector3(0,0,60.0/3.6)
	game.sim.prime_contacts(field)
	game.skier.pose(game.sim,1.0); game.skier.show()
	camera=game.camera; camera.make_current()
	for close in [false,true]:
		camera.close_view=close; camera.reset()
		game.skier.body_pivot.visible=not close
		for frame in 30:
			camera.update_camera(game.sim,field,p,1.0/60.0,false,true,false)
			game.world.grass.stream(camera.position,625)
			await process_frame
		await capture(label+("_first_person" if close else "_chase"),12)
	camera.close_view=false
	game.skier.body_pivot.show()
	camera=observer; camera.make_current(); game.skier.hide()
func local_motion() -> void:
	# Exact authored mixed production map, plus isolated actual grass materials.
	var centre=Vector3(38,field.sample(38,180).height,180)
	var nearest=INF
	var selected=centre
	for z in range(9,14):
		for x in range(0,5):
			for item in game.world.grass.placement.cell(Vector2i(x,z)):
				var distance=centre.distance_squared_to(item.pose.origin)
				if distance<nearest: nearest=distance; selected=item.pose.origin
	assert(nearest<400,"Grass exists near selected local mixed-map camera")
	centre=selected; centre.y=field.sample(centre.x,centre.z).height
	focus(centre,Vector3(1,1.2,2))
	await capture("mixed_ground",30)
	await motion(centre,"local_motion")
	await streaming(centre)
func streaming(centre: Vector3) -> void:
	var before=game.world.grass.motion.ends.duplicate()
	var previous=centre-Vector3.RIGHT*56
	for frame in 12:
		var p=centre+Vector3.RIGHT*(frame-6)*8
		p.y=field.sample(p.x,p.z).height
		for tick in 15:
			var at=previous.lerp(p,float(tick+1)/15)
			at.y=field.sample(at.x,at.z).height
			# Queue only: production _process owns the normal three-cell budget.
			focus(at,Vector3(1,1.2,2),0)
			await process_frame
		previous=p
		await capture("stream_%02d" % frame,1)
	assert(before==game.world.grass.motion.ends,"Camera streaming cannot create skier influence")
	focus(centre,Vector3(0,10,40)); await capture("distance_fade",20)
	focus(centre,Vector3(1,1.2,2))
	var off=Quality.numbered(7,{"scrub_density":0.0})
	game.world.grass.apply_quality(off)
	if game.world.minerals: game.world.minerals.apply_quality(off)
	await capture("density_off",5)
	assert(game.world.grass.population()==0)
	game.world.grass.apply_quality(game.graphics)
	if game.world.minerals: game.world.minerals.apply_quality(game.graphics)
	focus(centre,Vector3(1,1.2,2)); await capture("density_restored",30)
func motion(centre: Vector3,label: String) -> void:
	# 15 seconds, 60 chronological captures: wind, passage, recovery, pause,
	# airborne separation, reversal and an explicit teleport reset.
	game.world.grass.reset()
	var initial_wind: Vector3=game.weather.state.wind_velocity
	var previous=centre-Vector3.RIGHT*8
	for frame in 60:
		var time=float(frame)*.25
		var p=centre+Vector3.RIGHT*(time-2.0)*8
		p.y=field.sample(p.x,p.z).height
		if time>7.0: p.y+=4.0
		if time>10.0: p=centre-Vector3.RIGHT*(time-10)*48; p.y=field.sample(p.x,p.z).height
		game.weather.state.wind_velocity=Vector3(4,0,1) if time<10 else Vector3(-5,0,1)
		for tick in 15:
			var actor=previous.lerp(p,float(tick+1)/15)
			game.world.grass.update_actor(actor,(p-previous)/.25,1.0/60.0,time<5.5 or time>6.5)
			game.world.update_weather(game.weather.state,1.0/60.0,time<5.5 or time>6.5)
			# Advance the actual visible pose on every rendered step so temporal
			# reconstruction sees continuous motion between chronological captures.
			game.sim.reset(actor,PI*.5 if time<10 else -PI*.5)
			game.sim.velocity=(p-previous)/.25
			game.sim.prime_contacts(field)
			game.skier.pose(game.sim,1.0); game.skier.show()
			await process_frame
		if frame==55: game.world.grass.reset()
		chronology.append({"frame":frame,"seconds":(frame+1)*.25,"actor":[p.x,p.y,p.z],"speed_m_s":game.sim.velocity.length(),"wind":str(game.weather.state.wind_velocity),"influence_at_focus":game.world.grass.motion.influence_at(centre),"paused":time>=5.5 and time<=6.5,"reset":frame==55})
		previous=p
		await capture("%s_%03d" % [label,frame],1)
	game.skier.hide()
	game.weather.state.wind_velocity=initial_wind
