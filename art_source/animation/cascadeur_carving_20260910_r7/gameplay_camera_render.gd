extends "res://tests/pose_reference_render.gd"
## Frozen production ChaseCamera transforms; deterministic plane, original skin.
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--revision="):folder=arg.trim_prefix("--revision=")
	assert(not folder.is_empty() and not FileAccess.file_exists(folder+"/sealed.json"))
	assert(DisplayServer.get_name()!="headless")
	sizes=Vector2i(1600,900);root.size=sizes
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO;root.content_scale_factor=1.0
	Engine.max_fps=120;root.title="Alpine Apex | Cascadeur gameplay-camera evidence"
	scene=Node3D.new();root.add_child(scene)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("a1a4aa")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("eef2ff");env.environment.ambient_light_energy=.85;scene.add_child(env)
	for spec in [[Vector3(-40,-30,0),1.5],[Vector3(-25,145,0),.65]]:
		var light=DirectionalLight3D.new();light.rotation_degrees=spec[0];light.light_energy=spec[1];scene.add_child(light)
	var ground=MeshInstance3D.new();ground.mesh=PlaneMesh.new();ground.mesh.size=Vector2(2000,2000);ground.rotation.x=atan(.25);ground.position.y=-.025
	var material=StandardMaterial3D.new();material.albedo_color=Color("d3dce5");material.roughness=1.;ground.material_override=material;scene.add_child(ground)
	skier=Visual.new();skier.preview_only=true;scene.add_child(skier)
	var camera=Camera3D.new();scene.add_child(camera);camera.current=true;camera.far=3000
	await process_frame
	var manifest=read(folder+"/capture/manifest.json");assert(manifest.stable_sources and manifest.failures.is_empty())
	for resource in manifest.sources:
		if resource.begins_with("res://assets/graphics/models/") and resource.ends_with(".glb"):assert(FileAccess.get_sha256(resource)==manifest.sources[resource])
	var metadata={"pixels":[1600,900],"scope":"Recorded production ChaseCamera at 30 FPS on deterministic solver plane. No mountain/scenery or performance claim.","renderer_sha256":FileAccess.get_sha256("res://art_source/animation/cascadeur_carving_20260910_r7/gameplay_camera_render.gd"),"scenarios":{}}
	for item in manifest.scenarios:
		if item.name!="carve_reversal":continue
		var data=read(folder+"/capture/"+item.name+".json");var destination=folder+"/gameplay/"+item.name;DirAccess.make_dir_recursive_absolute(destination)
		for row in data.frames:
			restore(row);camera.global_transform=unpack_t(row.gameplay_camera.transform);camera.fov=row.gameplay_camera.fov
			await screenshot(destination+"/%04d.jpg"%row.frame)
		metadata.scenarios[item.name]=data.frames.size();print("CASCADEUR_CHASE_RENDER ",item.name," frames=",data.frames.size())
	metadata.max_restored_bone_error_m=verify_error;write_meta(metadata)
	scene.queue_free();await process_frame;quit(0 if verify_error<.00001 else 1)
func write_meta(metadata):FileAccess.open(folder+"/gameplay-camera.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"\t"))

