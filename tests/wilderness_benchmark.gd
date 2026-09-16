extends "res://tests/massif_playtest.gd"
## Same-process complete-apron/panorama ABBA comparison. No screenshots inside measurement windows.

func inspect_massif() -> void:
	game.active = false
	game.summit_ready = false
	game.set_process(false) # Keep the chosen fixed-view camera authoritative.
	game.hud.root.hide()
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	game.world.update_weather(game.weather.state,0.0,false)
	var observer = Camera3D.new()
	game.add_child(observer)
	observer.far = 32000
	observer.fov = 75
	observer.make_current()
	var fixture = comparison_fixture()
	await fixture.build(game.world)
	# Capture fixtures cap loading at 30; timed blocks restore the requested cap.
	Engine.max_fps = game.display_settings.fps_limit
	assert(Engine.max_fps==game.display_settings.fps_limit and actual_pixels==requested_pixels)
	var sources_before = game.world.wilderness.source_hashes()
	var blocks: Array = []
	var pooled: Dictionary = {}
	for label in ["baseline","upgraded"]:
		pooled[label] = {"frame_ms":[] as Array[float],"gpu_ms":[] as Array[float],"cpu_ms":[] as Array[float],"draw_calls":[] as Array[float]}
	for view in [[0,false],[2,false],[4,false],[0,true],[2,true],[4,true]]:
		var index: int = view[0]
		var heading: float = field.faces[index].heading
		observer.position = field.spawn_point()+Vector3.UP*65
		observer.look_at(observer.position+Vector3(sin(heading)*10000,-1900,cos(heading)*10000))
		if view[1]:
			var p: Vector2 = field.faces[index].to_world(Vector2(0,2600))
			observer.position = Vector3(p.x,field.sample(p.x,p.y).height+3,p.y)
			observer.look_at(observer.position+Vector3(sin(heading)*5000,-300,cos(heading)*5000))
		for enabled in [false,true,true,false]:
			fixture.select(game.world,not enabled)
			for i in 120: await process_frame
			var frame_values: Array[float] = []
			var gpu_values: Array[float] = []
			var cpu_values: Array[float] = []
			var draw_values: Array[float] = []
			var previous = Time.get_ticks_usec()
			for i in 360:
				await process_frame
				var now = Time.get_ticks_usec()
				frame_values.append((now-previous)/1000.0)
				previous = now
				gpu_values.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				cpu_values.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
				draw_values.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			blocks.append({"face":index,"lower_view":view[1],"upgraded":enabled,"frame_ms":frame_timing(frame_values),"gpu_ms":timing(gpu_values),"cpu_ms":timing(cpu_values),"draw_calls":timing(draw_values)})
			var samples: Dictionary = pooled["upgraded" if enabled else "baseline"]
			samples.frame_ms.append_array(frame_values)
			samples.gpu_ms.append_array(gpu_values)
			samples.cpu_ms.append_array(cpu_values)
			samples.draw_calls.append_array(draw_values)
			print("WILDERNESS_BLOCK ",JSON.stringify(blocks.back()))
	var report = {"blocks":blocks,"display":game.display_settings.report(root,actual_pixels),"geometry":game.world.wilderness.report(),"actual_pixels":[actual_pixels.x,actual_pixels.y],"device":RenderingServer.get_video_adapter_name(),"capture_overhead":false,"unranked":true,"physics_active":false,"world_build_ms":game.world.generation_ms,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum}
	report.pooled = {}
	for label in pooled:
		report.pooled[label] = {}
		for metric in pooled[label]:
			report.pooled[label][metric] = frame_timing(pooled[label][metric]) if metric=="frame_ms" else timing(pooled[label][metric])
	report.effective_fps_cap = Engine.max_fps
	report.source_sha256_before = sources_before
	report.source_sha256_after = game.world.wilderness.source_hashes()
	report.stable_sources = report.source_sha256_before==report.source_sha256_after
	var a: Dictionary = report.pooled.baseline
	var b: Dictionary = report.pooled.upgraded
	report.budget = {"gpu_delta_ms":b.gpu_ms.median-a.gpu_ms.median,"p95_ratio":b.frame_ms.p95/a.frame_ms.p95,"p99_ratio":b.frame_ms.p99/a.frame_ms.p99}
	report.budget.relative_pass = report.budget.gpu_delta_ms<=.5 and report.budget.p95_ratio<=1.05 and report.budget.p99_ratio<=1.05
	report.budget.absolute_pass = b.frame_ms.p95<=11.1 and b.frame_ms.p99<=16.7
	fixture.select(game.world,false)
	fixture.dispose()
	preload("res://tests/test_report.gd").write(OUTPUT+"/comparison.json",JSON.stringify(report,"\t"))
	print("OFFMAP_BUDGET ",JSON.stringify(report.budget))

func comparison_fixture():
	return preload("res://tests/offmap_fixture.gd").new()
