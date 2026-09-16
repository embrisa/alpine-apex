extends "res://tests/massif_playtest.gd"
## Screenshot-free component isolation at the densest lower background view.
func inspect_massif() -> void:
	game.active=false; game.summit_ready=false; game.set_process(false)
	game.hud.hide_menu(); game.hud.root.hide()
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.world.update_weather(game.weather.state,0.0,false)
	var observer=Camera3D.new(); game.add_child(observer)
	observer.far=32000; observer.fov=75; observer.make_current()
	var heading: float=field.faces[2].heading
	var p: Vector2=field.faces[2].to_world(Vector2(0,2600))
	observer.position=Vector3(p.x,field.sample(p.x,p.y).height+3,p.y)
	observer.look_at(observer.position+Vector3(sin(heading)*5000,-300,cos(heading)*5000))
	Engine.max_fps=120
	var rows=[]
	for mode in ["all","no_near","no_rocks","no_props","all"]:
		for node in game.world.wilderness.props.get_children():
			node.visible=mode!="no_props" and not (mode=="no_near" and node.name.begins_with("Batch_near")) and not (mode=="no_rocks" and node.name.begins_with("Batch_rock"))
		for i in 120: await process_frame
		var gpu: Array[float]=[]; var frames: Array[float]=[]
		var previous=Time.get_ticks_usec()
		for i in 360:
			await process_frame
			var now=Time.get_ticks_usec(); frames.append((now-previous)/1000.0); previous=now
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		rows.append({"mode":mode,"gpu_ms":timing(gpu),"frame_ms":frame_timing(frames)})
		print("OFFMAP_COMPONENT ",JSON.stringify(rows.back()))
	preload("res://tests/test_report.gd").write(OUTPUT+"/components.json",JSON.stringify({"rows":rows,"geometry":game.world.wilderness.report(),"actual_pixels":[actual_pixels.x,actual_pixels.y],"capture_overhead":false},"\t"))
	observer.queue_free()
