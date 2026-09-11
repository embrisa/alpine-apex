extends "res://tests/camera_playtest.gd"
## Uncaptured, stationary render-cost probes complement the cautious descent
## pilot. Fixed speed telemetry exercises the 72/110-degree camera endpoints.
func inspect_massif() -> void:
	install_camera_baseline()
	Engine.max_fps = game.display_settings.fps_limit
	game.hud.hide_menu()
	game.summit_ready = false
	game.active = true
	var probes: Array = []
	for z in [820,2170]:
		for kmh in [0,200]:
			place_on_face(face_index,z,false)
			game.sim.velocity = game.sim.support_basis().z * kmh / 3.6
			game.sim.reset_pose_history()
			game.camera.reset()
			for i in 120: await process_frame
			var wall: Array[float] = []
			var cpu: Array[float] = []
			var gpu: Array[float] = []
			var draws_local: Array[float] = []
			var memory = 0.0
			var previous = Time.get_ticks_usec()
			for i in 360:
				await process_frame
				var now = Time.get_ticks_usec()
				wall.append(float(now-previous)/1000.0)
				previous = now
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				draws_local.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				memory = maxf(memory,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
			probes.append({"local_z_m":z,"telemetry_kmh":kmh,"fov":game.camera.fov,"frame_ms":frame_timing(wall),"render_cpu_ms":timing(cpu),"render_gpu_ms":timing(gpu),"draw_calls":timing(draws_local),"video_memory_bytes":memory})
	var report = {"scope":"Stationary upper gully and forest render probes; fixed speed telemetry, not a 200 km/h skiing benchmark","capture_overhead_included":false,"warmup_frames_per_probe":120,"samples_per_probe":360,"actual_pixels":[actual_pixels.x,actual_pixels.y],"display":game.display_settings.report(root,actual_pixels),"probes":probes,"unranked":not game.session.eligible}
	FileAccess.open(OUTPUT+"/camera_fov_timing.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CAMERA_FOV_TIMING ",JSON.stringify(report))
