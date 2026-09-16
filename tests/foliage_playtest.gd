extends SceneTree
## Production forest batches in a deterministic stand; no session or player files.
const Assets = preload("res://scripts/presentation/alpine_assets.gd")
const Clouds = preload("res://scripts/presentation/cloud_lighting.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
const Scenery = preload("res://scripts/world/alpine_scenery.gd")
const Forest = preload("res://scripts/presentation/density_forest.gd")
const Display = preload("res://scripts/presentation/pc_graphics_settings.gd")
const Costs = preload("res://scripts/diagnostics/frame_costs.gd")
var output = "res://artifacts/foliage_v3/pilot_before"
var asset = "forest_spruce_01"
var assets
var host
var forest
var camera: Camera3D
var sun: DirectionalLight3D
var display = Display.new()
var images = []
var results = []
var capture_enabled = true
var gallery = false
var failure = false
var tree_scale = 1.0

func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): output="res://artifacts/foliage_v3/"+arg.get_slice("=",1).validate_filename()
		if arg.begins_with("--asset="): asset=arg.get_slice("=",1)
		if arg=="--no-captures": capture_enabled=false
		if arg=="--gallery": gallery=true
	display.apply_arguments(OS.get_cmdline_user_args()); display.fps_limit=0
	display.apply_display(root,Vector2i(3840,2160)); display.apply_viewport(root)
	DirAccess.make_dir_recursive_absolute(output)
	var env=WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color(.43,.57,.70)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(.69,.79,.93); env.environment.ambient_light_energy=.70
	env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC; env.environment.ssao_enabled=true
	root.add_child(env)
	sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-42,-32,0); sun.light_color=Color(1,.94,.85)
	sun.light_energy=1.7; sun.shadow_enabled=true; sun.directional_shadow_max_distance=110; root.add_child(sun)
	camera=Camera3D.new(); root.add_child(camera); camera.current=true; camera.fov=75; camera.far=1600
	var profile=Quality.preset(display.quality); assets=Assets.new(Clouds.new(),profile)
	var ground=MeshInstance3D.new(); ground.mesh=PlaneMesh.new(); ground.mesh.size=Vector2(2000,2000)
	ground.material_override=assets.terrain_material(); ground.position.y=-.06; root.add_child(ground)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	if gallery:
		await gallery_views()
	else:
		await stand_views(profile)
	var pixels=root.get_texture().get_image().get_size()
	preload("res://tests/test_report.gd").write(output+"/report.json",JSON.stringify({"asset":asset,"scope":"Deterministic production MultiMesh stand; separate from full-descent performance","no_player_session":true,"device":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"display":display.report(root,pixels),"actual_pixels":[pixels.x,pixels.y],"manifest_sha256":FileAccess.get_sha256("res://assets/graphics/trees/manifest.json"),"fixture_sha256":FileAccess.get_sha256(get_script().resource_path),"images":images,"results":results},"\t"))
	print("FOLIAGE_RENDER_DONE ",output," results=",results.size())
	quit(1 if failure else 0)

func stand_views(profile) -> void:
	host=Scenery.new(); root.add_child(host); host.assets=assets; host.quality=profile; host.dense_woodlands=true
	forest=Forest.new(); host.add_child(forest)
	var rng=RandomNumberGenerator.new(); rng.seed=917320
	for z in range(-10,11):
		for x in range(-10,11):
			var p=Vector3(x*8+rng.randf_range(-1.8,1.8),0,z*8+rng.randf_range(-1.8,1.8))
			if x==0 and z==0: p=Vector3.ZERO
			var scale_value=10.5/float(assets.tree_record(asset).height_m)*rng.randf_range(.95,1.55)
			if x==0 and z==0: tree_scale=scale_value
			forest.add_tree(asset,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value),p),25)
	await forest.finish(host,Callable())
	host.apply_quality(profile)
	camera.position=Vector3(-2.4,2.1,-4.8); camera.look_at(Vector3(.1,4.2,0))
	for i in 180: await process_frame
	for repetition in 3:
		for mode in ["normal","no_shadows","cards_only"]:
			forest.set_process(false)
			var residency=forest.residency_image.duplicate()
			var flags=[]
			for node in host.batches:
				flags.append(node.cast_shadow)
				if mode=="no_shadows": node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if mode=="cards_only" and node.get_meta("art_lod") in [0,1,5]: node.hide()
			if mode=="cards_only": forest.residency_image.fill(Color(0,0,0,1)); forest.residency_texture.update(forest.residency_image)
			for i in 120: await process_frame
			var frames=[]; var gpu=[]; var cpu=[]; var draws=[]; var previous=Time.get_ticks_usec()
			for i in 360:
				assets.update_wind({"wind_velocity":Vector3(2.5,0,.8),"enabled":true},1.0/120,true)
				await process_frame
				var now=Time.get_ticks_usec(); frames.append((now-previous)/1000.0); previous=now
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
				draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			var row={"repetition":repetition,"mode":mode,"frame_ms":Costs.stats(frames),"gpu_ms":Costs.stats(gpu),"cpu_ms":Costs.stats(cpu),"draw_calls":Costs.stats(draws),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"forest":forest.report()}
			results.append(row); print("FOLIAGE_STAND_SAMPLE ",JSON.stringify(row))
			for i in host.batches.size(): host.batches[i].show(); host.batches[i].cast_shadow=flags[i]
			forest.residency_image=residency; forest.residency_texture.update(residency); forest.set_process(true)
	if not capture_enabled: return
	Engine.max_fps=60
	await capture("branch_close")
	camera.position=Vector3(0,2,-22); camera.look_at(Vector3(0,6,10)); await capture("forest_eye_height")
	camera.position=Vector3(-23,12,-35); camera.look_at(Vector3(0,6,0)); await capture("forest_overview")
	sun.rotation_degrees=Vector3(-25,145,0); await capture("forest_backlight")
	sun.rotation_degrees=Vector3(-42,-32,0)
	for frame in 120:
		camera.position=Vector3(-2.4,2.1,lerpf(-22,-2,float(frame)/119)); camera.look_at(Vector3(0,4,2))
		assets.update_wind({"wind_velocity":Vector3(3.0,0,1),"enabled":true},1.0/60,true)
		await process_frame
		if frame%3==0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(output+"/approach_%03d.jpg" % frame,.94)
	# Residency fallback remains visible before and after an arbitrary teleport.
	camera.position=Vector3(65,2,65); camera.look_at(Vector3(55,5,50)); await capture("teleport_arrival")
	for level in 3:
		host.apply_quality(Quality.preset(level)); assets.apply_quality(Quality.preset(level)); await capture("quality_%d" % level)

func gallery_views() -> void:
	Engine.max_fps=60
	var row=Node3D.new(); root.add_child(row)
	for family in ["spruce","fir","pine","birch","dead","broken"]:
		for child in row.get_children(): child.free()
		for variant in range(1,5):
			var id="forest_%s_%02d" % [family,variant]
			var tree=MultiMeshInstance3D.new(); tree.multimesh=MultiMesh.new(); tree.multimesh.transform_format=MultiMesh.TRANSFORM_3D
			tree.multimesh.mesh=assets.mesh(id+"_lod0"); tree.multimesh.instance_count=1
			var s=10.5/float(assets.tree_record(id).height_m)
			tree.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*s),Vector3((variant-2.5)*7,0,0))); row.add_child(tree)
		camera.position=Vector3(0,8,-29); camera.look_at(Vector3(0,5,0)); await capture(family+"_family")
		if family not in ["spruce","fir","pine"]: continue
		for child in row.get_children(): child.free()
		var id="forest_%s_01" % family
		var tree=MultiMeshInstance3D.new(); tree.multimesh=MultiMesh.new(); tree.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		tree.multimesh.mesh=assets.mesh(id+"_lod0")
		tree.multimesh.instance_count=1
		var s=10.5/float(assets.tree_record(id).height_m)
		tree.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*s),Vector3.ZERO)); row.add_child(tree)
		for lod in 3:
			tree.multimesh.mesh=assets.mesh(id+"_lod%d" % lod)
			camera.position=Vector3(-10,7,-15); camera.look_at(Vector3(0,5,0)); await capture(family+"_lod%d" % lod)
		tree.multimesh.mesh=assets.mesh(id+"_lod0")
		camera.position=Vector3(-2.6,3.6,-3.5); camera.look_at(Vector3(0,3.8,0)); await capture(family+"_needles")
		for frame in 60:
			var angle=lerpf(-.9,.9,float(frame)/59)
			camera.position=Vector3(sin(angle)*4,3.6,-cos(angle)*4); camera.look_at(Vector3(0,3.8,0))
			assets.update_wind({"wind_velocity":Vector3(3,0,.7),"enabled":true},1.0/60,true)
			await process_frame
			if frame%3==0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg(output+"/%s_orbit_%03d.jpg" % [family,frame],.94)

func capture(id: String) -> void:
	if not capture_enabled: return
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+id+".png"); images.append(id)
