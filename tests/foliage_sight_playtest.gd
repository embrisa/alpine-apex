extends "res://tests/foliage_playtest.gd"
## Production first-person/chase visibility, with identical aid-off references.
var actor = Vector3.ZERO
var aid = false
var size_percent = 88.0

func settle() -> void:
	for frame in 90:
		assets.update_foliage_sight(camera,actor,Vector3(0,0,16),1.0/60,true,60.0 if aid else 0.0,size_percent)
		await process_frame

func stand_views(profile) -> void:
	host=Scenery.new(); root.add_child(host); host.assets=assets; host.quality=profile; host.dense_woodlands=true
	forest=Forest.new(); host.add_child(forest)
	var rng=RandomNumberGenerator.new(); rng.seed=917320
	for z in range(-5,9):
		for x in range(-5,6):
			var p=Vector3(x*7+rng.randf_range(-1.5,1.5),0,z*7+rng.randf_range(-1.5,1.5))
			if x==0: p.x=2.0 if z%2==0 else -2.0
			var id="forest_%s_01" % ["spruce","fir","pine"][posmod(x+z,3)]
			var s=10.5/float(assets.tree_record(id).height_m)*1.35
			forest.add_tree(id,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*s),p),25)
	await forest.finish(host,Callable()); host.apply_quality(profile)
	Engine.max_fps=60
	var size_review="--size-review" in OS.get_cmdline_user_args()
	for mode in ["first_person","chase"]:
		for revision in (["size_20","size_50","size_88","size_100"] if size_review else ["before","after"]):
			aid=size_review or revision=="after"
			size_percent=float(revision.get_slice("_",1)) if size_review else 88.0
			assets.wind_time=0.0
			assets.update_wind({"wind_velocity":Vector3(3,0,1),"enabled":true},0.0,true)
			actor=Vector3(0,0,-6)
			camera.position=actor+Vector3(0,1.75,0) if mode=="first_person" else actor+Vector3(0,5,-6)
			camera.look_at(actor+Vector3(0,1.35,18))
			sun.rotation_degrees=Vector3(-42,-32,0)
			await settle(); await capture(mode+"_"+revision)
			if size_review:
				results.append({"view":mode,"size":size_percent,"reach":60,"window":assets.foliage_sight.window,"parameters":assets.foliage_sight.parameters})
				continue
			sun.rotation_degrees=Vector3(-25,145,0)
			await capture(mode+"_"+revision+"_backlit")
			sun.rotation_degrees=Vector3(-42,-32,0)
			for frame in 180:
				actor=Vector3(sin(float(frame)/179*PI)*.75,0,lerpf(-6,12,float(frame)/179))
				camera.position=actor+Vector3(0,1.75,0) if mode=="first_person" else actor+Vector3(0,5,-6)
				camera.look_at(actor+Vector3(sin(float(frame)/179*TAU)*3,1.35,18))
				assets.update_wind({"wind_velocity":Vector3(3,0,1),"enabled":true},1.0/60,true)
				assets.update_foliage_sight(camera,actor,Vector3(0,0,16),1.0/60,true,60.0 if aid else 0.0,size_percent)
				await process_frame; await RenderingServer.frame_post_draw
				if frame%3==0: root.get_texture().get_image().save_jpg(output+"/%s_%s_%03d.jpg" % [mode,revision,frame],.94)
	# Static comparison after FSR history settles: edges and shadows retain coverage.
	results.append({"trees":154,"strength":60,"window":assets.foliage_sight.window,"parameters":assets.foliage_sight.parameters,"no_solver_changes":true})
