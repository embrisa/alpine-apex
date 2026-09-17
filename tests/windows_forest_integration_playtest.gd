extends "res://tests/foliage_playtest.gd"
## Bounded DX12 foliage/global-cloud integration views, not an FPS benchmark.
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	assert(RenderingServer.get_current_rendering_driver_name()=="d3d12")
	output="res://artifacts/windows_integration_20260917/forest"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output="res://"+arg.get_slice("=",1)
	DirAccess.make_dir_recursive_absolute(output)
	display.apply_arguments(OS.get_cmdline_user_args())
	display.quality=7; display.fps_limit=60; display.frame_generation=false
	display.apply_display(root,Vector2i(3840,2160)); display.apply_viewport(root)
	Engine.max_fps=60
	var env=WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color(.43,.57,.70)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(.69,.79,.93); env.environment.ambient_light_energy=.70
	env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC; root.add_child(env)
	sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-42,-32,0)
	sun.light_color=Color(1,.94,.85); sun.light_energy=1.7; sun.shadow_enabled=true
	sun.directional_shadow_max_distance=110; root.add_child(sun)
	camera=Camera3D.new(); root.add_child(camera); camera.current=true; camera.fov=75; camera.far=1600
	var profile=Quality.numbered(7); var clouds=Clouds.new(); assets=Assets.new(clouds,profile)
	var ground=MeshInstance3D.new(); ground.mesh=PlaneMesh.new(); ground.mesh.size=Vector2(600,600)
	ground.material_override=assets.terrain_material(); ground.position.y=-.06; root.add_child(ground)
	host=Scenery.new(); root.add_child(host); host.assets=assets; host.quality=profile; host.dense_woodlands=true
	forest=Forest.new(); host.add_child(forest)
	for index in 3:
		var id="forest_%s_01" % ["spruce","fir","pine"][index]
		var scale_value=10.5/float(assets.tree_record(id).height_m)
		forest.add_tree(id,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_value),Vector3((index-1)*7,0,0)),10.5)
	await forest.finish(host,Callable()); host.apply_quality(profile)
	camera.position=Vector3(0,3,-20); camera.look_at(Vector3(0,5,0))
	for frame in 120: await process_frame
	var ranges={}
	for batch in host.batches:
		if batch.get_meta("pc_tree",false): ranges[str(batch.get_meta("art_lod"))]=str(batch.get_instance_shader_parameter("pc_lod_ranges"))
	for distance_m in [6.0,9.5,12.0,14.5,20.0,40.0,61.5,64.0,66.5,82.0]:
		camera.position=Vector3(0,3,-distance_m); camera.look_at(Vector3(0,5,0))
		await capture("distance_%05.1f" % distance_m)
		results.append({"distance_m":distance_m,"forest":forest.report()})
	# Same camera, frozen wind and sun: only cloud inputs change.
	camera.position=Vector3(-13,11,-32); camera.look_at(Vector3(0,3,0))
	var state={"enabled":true,"cloud_coverage":0.0}
	clouds.update(state,Vector2.ZERO,-sun.global_basis.z); await capture("cloud_clear")
	state.cloud_coverage=.80
	clouds.update(state,Vector2.ZERO,-sun.global_basis.z); await capture("cloud_active")
	clouds.update(state,Vector2(1400,2300),-sun.global_basis.z); await capture("cloud_shifted")
	assert(clouds.state_ready and is_equal_approx(clouds.parameters.z,.80))
	preload("res://tests/test_report.gd").write(output+"/report.json",JSON.stringify({"engine":Engine.get_version_info().string,"backend":RenderingServer.get_current_rendering_driver_name(),"display":display.report(root,Vector2i(3840,2160)),"profile":profile.snapshot(),"bound_lod_ranges":ranges,"scope":"Three production trees; capped visual integration only; no gameplay or FPS claim","images":images,"views":results,"cloud_receivers":clouds.materials.size(),"cloud_parameters":str(clouds.parameters)},"\t"))
	print("WINDOWS_FOREST_INTEGRATION_DONE ",output)
	quit()
