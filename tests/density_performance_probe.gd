extends "res://tests/alpine_v13_playtest.gd"
## Native diagnostic only. The same world and camera isolate GPU costs.
func terrain_benchmark() -> void:
	Engine.max_fps=120
	game.camera.make_current()
	game.set_process(true)
	process_frame.connect(_measure)
	var results: Array=[]
	var forest=game.world.scenery.density_forest
	var face=field.faces[2]
	var p=forest_site(2)
	game.sim.reset(Vector3(p.x,field.sample(p.x,p.y).height,p.y),face.heading)
	game.sim.prime_contacts(field)
	game.previous_position=game.sim.position
	game.skier.reset_animation(game.sim)
	game.camera.reset()
	game.active=false
	for i in 180: await process_frame
	forest.set_process(false)
	var residency=forest.residency_image.duplicate()
	var shadows: Dictionary={}
	for node in game.world.scenery.batches: shadows[node]=node.cast_shadow
	for mode in ["normal","cards_only","no_shadows","no_minerals"]:
		for node in game.world.scenery.batches:
			node.visible=not (mode=="cards_only" and node.get_meta("art_lod") in [0,1,5])
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if mode=="no_shadows" else shadows[node]
		for node in game.world.minerals.batches: node.visible=mode!="no_minerals"
		forest.residency_image=residency.duplicate()
		if mode=="cards_only": forest.residency_image.fill(Color(0,0,0,1))
		forest.residency_texture.update(forest.residency_image)
		for i in 120: await process_frame
		frames.clear(); gpu_ms.clear(); render_cpu_ms.clear(); physics_us.clear(); draws.clear()
		previous_recording=false; recording=true
		for i in 360: await process_frame
		recording=false
		results.append({"mode":mode,"frame_ms":frame_timing(frames),"gpu_ms":timing(gpu_ms),"draw_calls":timing(draws)})
		print("DENSITY_GPU_PROBE ",JSON.stringify(results[-1]))
	preload("res://tests/test_report.gd").write(OUTPUT+"/gpu_probe.json",JSON.stringify(results,"\t"))
