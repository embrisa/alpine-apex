extends "res://tests/foliage_playtest.gd"
## One candidate through all authored LODs before expanding the collection.
func gallery_views() -> void:
	Engine.max_fps=60
	var tree=MultiMeshInstance3D.new(); tree.multimesh=MultiMesh.new()
	tree.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	tree.multimesh.mesh=assets.mesh(asset+"_lod0"); tree.multimesh.instance_count=1
	var scale_value=10.5/float(assets.tree_record(asset).height_m)
	tree.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_value),Vector3.ZERO))
	tree.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(tree)
	var shadow=MultiMeshInstance3D.new(); shadow.multimesh=MultiMesh.new()
	shadow.multimesh.transform_format=MultiMesh.TRANSFORM_3D; shadow.multimesh.mesh=assets.tree_shadow(asset)
	shadow.multimesh.instance_count=1; shadow.multimesh.set_instance_transform(0,tree.multimesh.get_instance_transform(0))
	shadow.material_override=ShaderMaterial.new(); shadow.material_override.shader=load("res://assets/graphics/pc_forest_shadow.gdshader")
	shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY; root.add_child(shadow)
	for lod in 3:
		tree.multimesh.mesh=assets.mesh(asset+"_lod%d" % lod)
		camera.position=Vector3(-10,7,-15); camera.look_at(Vector3(0,5,0)); await capture("whole_lod%d" % lod)
	tree.multimesh.mesh=assets.mesh(asset+"_lod0")
	camera.position=Vector3(-2.6,3.6,-3.5); camera.look_at(Vector3(0,3.8,0)); await capture("needles")
	sun.rotation_degrees=Vector3(-25,145,0); await capture("needles_backlit")
	sun.rotation_degrees=Vector3(-42,-32,0)
	for frame in 120:
		var angle=lerpf(-.9,.9,float(frame)/119)
		camera.position=Vector3(sin(angle)*4,3.6,-cos(angle)*4); camera.look_at(Vector3(0,3.8,0))
		assets.update_wind({"wind_velocity":Vector3(3,0,.7),"enabled":true},1.0/60,true)
		await process_frame
		if frame%3==0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(output+"/orbit_%03d.jpg" % frame,.94)
