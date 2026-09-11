extends "res://tests/foliage_playtest.gd"
## Production streamed detail transitions, including grazing branch crossings.
func stand_views(profile) -> void:
	host=Scenery.new(); root.add_child(host); host.assets=assets; host.quality=profile; host.dense_woodlands=true
	forest=Forest.new(); host.add_child(forest)
	for index in 3:
		var id="forest_%s_01" % ["spruce","fir","pine"][index]
		var scale_value=10.5/float(assets.tree_record(id).height_m)
		forest.add_tree(id,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_value),Vector3((index-1)*7,0,0)),25)
	await forest.finish(host,Callable()); host.apply_quality(profile)
	Engine.max_fps=60
	for lighting in ["day","backlit"]:
		sun.rotation_degrees=Vector3(-42,-32,0) if lighting=="day" else Vector3(-25,145,0)
		camera.position=Vector3(1.8,3,-100); camera.look_at(Vector3(0,5,0))
		for frame in 180: await process_frame
		for frame in 600:
			var distance_m=lerpf(100,-2,float(frame)/599)
			camera.position=Vector3(1.8,3,-distance_m); camera.look_at(Vector3(0,5,0))
			assets.update_wind({"wind_velocity":Vector3(3,0,1),"enabled":true},1.0/60,true)
			await process_frame; await RenderingServer.frame_post_draw
			if frame%3==0: root.get_texture().get_image().save_jpg(output+"/%s_%03d.jpg" % [lighting,frame],.94)
			if frame in [120,180,240,360,480,570]:
				root.get_texture().get_image().save_png(output+"/%s_%03d.png" % [lighting,frame])
	results.append({"distance_m":[100,-2],"frames_per_lighting":600,"lighting":["day","backlit"],"species":["spruce","fir","pine"],"forest":forest.report()})
