extends "res://tests/foliage_playtest.gd"
## Matched native palette review. No gameplay settings or player data are saved.
func stand_views(profile) -> void:
	host=Scenery.new(); root.add_child(host); host.assets=assets; host.quality=profile; host.dense_woodlands=true
	forest=Forest.new(); host.add_child(forest)
	var rng=RandomNumberGenerator.new(); rng.seed=917320
	for z in range(-10,11):
		for x in range(-10,11):
			var p=Vector3(x*8+rng.randf_range(-1.8,1.8),0,z*8+rng.randf_range(-1.8,1.8))
			if x==0 and z==0: p=Vector3.ZERO
			var scale_value=10.5/float(assets.tree_record(asset).height_m)*rng.randf_range(.95,1.55)
			forest.add_tree(asset,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value),p),25)
	await forest.finish(host,Callable()); host.apply_quality(profile)
	Engine.max_fps=60
	for revision in ["before","after"]:
		for mat in assets.named_materials.values():
			if mat.resource_name=="FC_Tree" or mat.resource_name.begins_with("FC_Impostor_spruce_"):
				mat.set_shader_parameter("foliage_color_grade",Vector3.ONE if revision=="before" else Assets.NEEDLE_COLOR_GRADE)
		sun.rotation_degrees=Vector3(-42,-32,0)
		camera.position=Vector3(-23,12,-35); camera.look_at(Vector3(0,6,0)); await capture(revision+"_overview")
		camera.position=Vector3(0,2,-22); camera.look_at(Vector3(0,6,10)); await capture(revision+"_eye")
		camera.position=Vector3(0,16,-180); camera.look_at(Vector3(0,5,0)); await capture(revision+"_distant")
		sun.rotation_degrees=Vector3(-25,145,0)
		await capture(revision+"_backlit")
	results.append({"palette":Assets.NEEDLE_COLOR_GRADE,"trees":441,"purpose":"color review only; another game may be running"})
	# Gallery exercises all three detail levels and all species with final materials.
	host.hide()
	sun.rotation_degrees=Vector3(-42,-32,0)
	await gallery_views()
