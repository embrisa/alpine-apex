extends SceneTree
## Actual production scenery and materials; capped captures, no timing acceptance.
const Cache=preload("res://scripts/world/mountain_cache_v16.gd")
const Quality=preload("res://scripts/presentation/graphics_quality.gd")
var output="res://artifacts/colorful_forest_variety/render_local"
var game
var field
var camera: Camera3D
var standard=false
var comparison_only=false
var seed_number=849205174
var captures=[]
var observations=[]
var pixels=Vector2i(1920,1080)
var physical_before: PackedByteArray
func _initialize(): call_deferred("run")
func capture(label: String,frames: int=12) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	assert(image.get_size()==pixels)
	assert(image.save_png(output.path_join(label+".png"))==OK)
	captures.append({"file":label+".png","camera":str(camera.global_transform),"wind_time":game.world.assets.wind_time})
func physical() -> PackedByteArray:
	if not standard: return var_to_bytes(field.obstacles)
	return var_to_bytes([field.heights,field.tree_data.positions,field.tree_data.dimensions,field.tree_data.yaws,field.tree_data.candidate_ids,field.tree_data.ecology])
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg=="--standard": standard=true
		if arg=="--comparison-only": comparison_only=true
		if arg.begins_with("--seed="): seed_number=int(arg.get_slice("=",1))
		if arg.begins_with("--output="): output="res://"+arg.get_slice("=",1)
	DirAccess.make_dir_recursive_absolute(output)
	Engine.max_fps=60; root.size=pixels
	if standard:
		if not preload("res://scripts/diagnostics/test_world_policy.gd").require_full("New species on two unchanged Standard seeds"): quit(2); return
		# Explicit warm physical restore: a missing fixture cannot start a bake.
		var job=Cache.Job.new(); var settings=Cache.Settings.preset()
		var data=Cache.Archive.read(Cache.path_for(seed_number,settings),Cache.cache_key(seed_number,settings,job),job)
		if data.is_empty(): printerr("Missing current physical seed fixture; prepare explicitly"); quit(2); return
		field=Cache.restore(seed_number,settings,data,job); field.cache_hit=true
		physical_before=physical()
		set_meta("mountain_to_load",{"definition":preload("res://scripts/world/mountain_definition.gd").from_field(field,"Colorful forest review"),"field":field})
	else: set_meta("test_map_fixture","perf-vegetation")
	game=load("res://main.tscn").instantiate(); game.automated=true; root.add_child(game); current_scene=game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	field=game.field
	if not standard: physical_before=physical()
	game.set_physics_process(false); game.set_process(false); game.active=false; game.summit_ready=false; game.session.eligible=false
	game.effects.muted=true; game.effects.set_process(false); game.hud.hide_menu(); game.hud.root.hide(); game.skier.hide()
	game.display_settings.apply_display(root,pixels); Engine.max_fps=60
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day"); game.world.update_weather(game.weather.state,0,true)
	camera=Camera3D.new(); game.add_child(camera); camera.fov=68; camera.far=10000; camera.make_current()
	if standard and comparison_only: await comparison_views()
	elif standard: await mountain_views()
	else: await local_views()
	assert(physical()==physical_before,"Visual review cannot mutate physical world")
	var digest=HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(physical_before)
	var report={"seed":field.seed_value,"map":"Standard v15" if standard else "perf-vegetation","pixels":[pixels.x,pixels.y],"frame_cap":60,"captures":captures,"observations":observations,"physical_unchanged":true,"physical_sha256":digest.finish().hex_encode(),"families":game.world.scenery.family_counts,"source_signature":preload("res://scripts/world/generation_sources.gd").signature(true),"physical_signature":preload("res://scripts/world/generation_sources.gd").signature(false),"engine_sha256":preload("res://scripts/world/generation_sources.gd").engine_identity(),"performance_acceptance":false,"human_acceptance":false}
	if standard:
		var forest=game.world.preparation.forest
		digest.start(HashingContext.HASH_SHA256); digest.update(var_to_bytes([forest.assets,forest.asset_indices,forest.poses]))
		report.visual_assignment_sha256=digest.finish().hex_encode()
	preload("res://tests/test_report.gd").write(output.path_join("review.json"),JSON.stringify(report,"\t"))
	print("COLORFUL_FOREST_RENDER ",JSON.stringify({"output":output,"captures":captures.size(),"families":report.families}))
	game.queue_free(); await process_frame; quit()
func aim(p: Vector3,offset: Vector3,target_height: float=4.0) -> void:
	camera.position=p+offset
	camera.position.y=maxf(camera.position.y,field.sample(camera.position.x,camera.position.z).height+1.8)
	camera.look_at(p+Vector3.UP*target_height)
	camera.make_current()
func local_views() -> void:
	var p=Vector3(0,field.sample(0,120).height,120)
	aim(p,Vector3(2,7,-28)); await capture("mixed_stand",120)
	await material_views()
func comparison_views() -> void:
	# Select identical views from physical data alone, including the old catalog.
	var trees=field.tree_data
	var origin=Vector3(1608,field.sample(1608,1416).height,1416)
	var selected={"woodland":origin}
	var best={"edge":INF,"scattered":INF}
	for i in range(0,trees.size(),13):
		if trees.ecology[i]!=1: continue
		var p: Vector3=trees.positions[i]
		var distance=Vector2(p.x-origin.x,p.z-origin.z).length_squared()
		if distance>minf(2500000,maxf(best.edge,best.scattered)): continue
		var count=trees.nearby(p,50).size()
		var habitat="scattered" if count<=12 else ("edge" if count<=45 else "")
		if not habitat.is_empty() and distance<best[habitat]:
			selected[habitat]=p; best[habitat]=distance
	assert(selected.size()==3,"Need woodland, edge and scattered physical views")
	for habitat in ["woodland","edge","scattered"]:
		var p: Vector3=selected[habitat]
		aim(p,Vector3(5,3,-18),4)
		game.world.assets.update_foliage_sight(camera,camera.position,1,true,60,0)
		await capture(habitat,180)
		observations.append({"habitat":habitat,"position":[p.x,p.y,p.z],"physical_trees_within_50m":trees.nearby(p,50).size()})
func mountain_views() -> void:
	var forest=game.world.preparation.forest
	var origin=Vector3(1608,field.sample(1608,1416).height,1416)
	var nearby={}; var nearest={}; var distances={}; var cells={}
	for i in forest.positions.size():
		var family=forest.assets[forest.asset_indices[i]].get_slice("_",1)
		var distance=Vector2(forest.positions[i].x-origin.x,forest.positions[i].z-origin.z).length()
		var key=Vector2i(floori(forest.positions[i].x/128),floori(forest.positions[i].z/128))
		if not cells.has(key): cells[key]={"total":0,"golden":0,"maple":0,"centre":Vector3.ZERO}
		cells[key].total+=1; cells[key].centre+=forest.positions[i]
		if family in ["golden","maple"]: cells[key][family]+=1
		if distance<175: nearby[family]=int(nearby.get(family,0))+1
		if family in ["golden","maple"] and distance<float(distances.get(family,INF)):
			distances[family]=distance; nearest[family]=i
	observations.append({"timing_origin":[1608,1416],"families_within_175m":nearby,"scenery_cache_hit":game.world.preparation.cache_hit,"build_timings":game.world.build_timings})
	aim(origin,Vector3(0,3,-5),3); await capture("timing_forest",180)
	for family in ["golden","maple"]:
		var best_score=0.0; var best={}
		for cell in cells.values():
			if cell.total<50: continue
			var score=float(cell[family])/cell.total
			if score>best_score: best_score=score; best=cell
		assert(not best.is_empty())
		var centre: Vector3=best.centre/best.total
		aim(centre,Vector3(40,30,-60),4); await capture(family+"_pocket_overview",180)
		observations.append({"family":family,"pocket_total":best.total,"pocket_members":best[family],"pocket_centre":str(centre)})
		assert(nearest.has(family))
		var id=nearest[family]; var p: Vector3=forest.positions[id]
		observations.append({"family":family,"asset":forest.assets[forest.asset_indices[id]],"tree_index":id,"position":[p.x,p.y,p.z]})
		aim(p,Vector3(7,4,-19)); await capture(family+"_stand",180)
		aim(p,Vector3(2,1.9,-4),1.2); await capture(family+"_roots")
		aim(p,Vector3(3,4,-5),4); await capture(family+"_leaves")
		aim(p,Vector3(5,3,-15));
		for strength in [0.0,50.0,100.0]:
			for frame in 60:
				game.world.assets.update_foliage_sight(camera,camera.position,1.0/60,true,60,strength)
				await process_frame
			await capture("%s_sight_%03d" % [family,strength])
		game.world.assets.update_foliage_sight(camera,camera.position,1,true,60,0)
		for weather in ["clear","snowfall"]:
			game.weather.set_preset(weather); game.world.update_weather(game.weather.state,1,true)
			await capture(family+"_"+weather)
		game.weather.set_preset("clear"); game.world.update_weather(game.weather.state,1,true)
		# Six seconds of actual resident batches crossing the near/mid/far bands.
		for frame in 360:
			var distance=lerpf(165,8,float(frame)/359)
			aim(p,Vector3(2,3,-distance))
			game.world.update_weather(game.weather.state,1.0/60,true)
			await process_frame
			if frame%6==0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg(output.path_join("%s_motion_%03d.jpg" % [family,frame]),.94)
		for level in 3:
			game.world.assets.apply_quality(Quality.preset(level)); game.world.scenery.apply_quality(Quality.preset(level))
			aim(p,Vector3(4,3,-18)); await capture("%s_quality_%d" % [family,level],90)
		game.world.assets.apply_quality(game.graphics); game.world.scenery.apply_quality(game.graphics)
	# Separate close samples display every prepared silhouette and material role.
	await material_views()
func material_views() -> void:
	game.world.hide()
	var stage=Node3D.new(); game.add_child(stage)
	var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-35,-25,0); light.light_energy=1.1; stage.add_child(light)
	var env=game.world.environment
	var saved={}
	for key in ["background_mode","background_color","fog_enabled","volumetric_fog_enabled","ambient_light_source","ambient_light_color","ambient_light_energy"]: saved[key]=env.get(key)
	env.background_mode=Environment.BG_COLOR; env.background_color=Color(.12,.16,.22); env.fog_enabled=false; env.volumetric_fog_enabled=false
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color(.7,.8,.9); env.ambient_light_energy=.7
	for family in ["golden","maple"]:
		var row=Node3D.new(); stage.add_child(row)
		for variant in range(1,4):
			var node=MeshInstance3D.new(); node.mesh=game.world.assets.mesh("forest_%s_%02d_lod0" % [family,variant]); node.position.x=(variant-2)*9; row.add_child(node)
		camera.position=Vector3(0,7,-31); camera.look_at(Vector3(0,5,0)); await capture(family+"_silhouettes")
		for variant in range(1,4):
			var p=Vector3((variant-2)*9,4,0)
			camera.position=p+Vector3(1.5,0,-3); camera.look_at(p); await capture("%s_%02d_leaf_detail" % [family,variant])
		camera.position=Vector3(1.5,4,-5); camera.look_at(Vector3(0,4,0))
		var material: ShaderMaterial=game.world.assets.named_materials.FC_Broadleaf
		var anchors=PackedVector4Array(); anchors.resize(4); anchors[0]=Vector4(0,0,0,1)
		var angles=PackedVector4Array(); angles.resize(48)
		material.set_shader_parameter("contact_anchors",anchors)
		for cluster in 12: angles[cluster]=Vector4(.12,0,.08,0)
		material.set_shader_parameter("contact_angles",angles); await capture(family+"_contact_bent")
		angles.fill(Vector4.ZERO); material.set_shader_parameter("contact_angles",angles)
		await capture(family+"_contact_released")
		row.free()
	stage.free(); game.world.show()
	for key in saved: env.set(key,saved[key])
