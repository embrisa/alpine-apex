extends SceneTree
## Isolated native equipment inspection, independent of terrain burial.
var assets
func _initialize(): call_deferred("run")
func run():
	if DisplayServer.get_name()=="headless": quit(1); return
	root.size=Vector2i(1000,1000)
	var scene=Node3D.new(); root.add_child(scene)
	var lighting=preload("res://scripts/presentation/cloud_lighting.gd").new()
	assets=preload("res://scripts/presentation/alpine_assets.gd").new(lighting,preload("res://scripts/presentation/graphics_quality.gd").preset(2))
	var environment=WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.16,.19,.23)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.75,.82,1)
	environment.environment.ambient_light_energy=.7
	scene.add_child(environment)
	var sun=DirectionalLight3D.new(); scene.add_child(sun); sun.rotation_degrees=Vector3(-45,-35,0); sun.light_energy=1.3
	var camera=Camera3D.new(); scene.add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	DirAccess.make_dir_recursive_absolute("res://artifacts/equipment_v1/gallery")
	for id in ["ski","binding","pole"]:
		var node=MeshInstance3D.new(); scene.add_child(node)
		node.mesh=assets.mesh("binding_detailed_v2" if id=="binding" else id+"_detailed_v1").duplicate()
		var aabb=node.mesh.get_aabb(); var size=aabb.size.length()
		var center=aabb.get_center()
		var pair: MeshInstance3D
		camera.size=size*1.18
		camera.position=center+Vector3(1.0,1.2,1.3)*size
		if id=="pole": camera.position=center+Vector3(1,.15,1.6)*size
		camera.look_at(center)
		if id=="ski":
			node.position.x=-.12
			pair=MeshInstance3D.new(); scene.add_child(pair)
			pair.mesh=assets.mesh("ski_detailed_v1_left")
			pair.position.x=.12
			camera.position=center+Vector3(0,3,0)
			camera.look_at(center,Vector3.BACK)
		for f in range(6): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/equipment_v1/gallery/%s.png"%id)
		node.queue_free()
		if pair: pair.queue_free()
		await process_frame
	quit()
