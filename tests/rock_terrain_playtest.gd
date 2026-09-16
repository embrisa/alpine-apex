extends "res://tests/technical_showcase_playtest.gd"
## Default v11 mountain, real solver contact followed by bounded VFX inspection.
## Explicitly unranked; capture time is excluded from the stationary effect probe.
func inspect_views() -> void:
	game.set_process(false)
	game.set_physics_process(false)
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	game.world.update_weather(game.weather.state,0,false)
	game.camera.effects_enabled=false
	game.camera.close_view=false
	game.hud.menu.hide()
	var result={"cases":[],"material_bytes":field.material_image.get_data().size(),"seed":field.seed_value,"version":field.GENERATOR_VERSION}
	var texture: Texture2D=game.world.snow_material.get_shader_parameter("contact_material")
	var tex_image=texture.get_image()
	result.material_matches_gpu=tex_image.get_data()==field.material_image.get_data()
	for on_rock in [false,true]:
		var p = find_contact(on_rock)
		if not p.is_finite(): printerr("No suitable contact fixture"); quit(3); return
		var n: Vector3=field.contact_normal(p.x,p.z)
		var forward=Vector3.DOWN.slide(n).normalized()
		var sim=game.sim
		sim.reset(p,atan2(forward.x,forward.z)); sim.prime_contacts(field)
		sim.velocity=forward*22.0
		game.intent=RiderInput.new(); game.intent.tuck=.5
		game.effects.reset(); game.skier.reset_animation(sim)
		game.active=true
		var trace=[]
		for tick in 120:
			sim.step(1.0/120.0,game.intent,game.world.ski_surface)
			game.skier.step_animation(1.0/120.0,sim,game.intent,field)
			game.previous_position=sim.position
			game._process(1.0/120.0)
			if tick%30==0: trace.append({"rock":sim.rock_contact,"reserve":sim.impacts.reserve,"kmh":sim.speed_kmh()})
			await process_frame
			if sim.crashed: break
		var label="rock" if on_rock else "snow"
		await capture(label+"_chase")
		# Freeze this completed physical contact to inspect trails and sparks.
		var observer=Camera3D.new(); observer.far=15000; observer.fov=60
		game.add_child(observer); observer.make_current()
		var f: Vector3=sim.ski_forward
		observer.position=sim.position-f*3.6+sim.support_basis().x*3.8+Vector3.UP*1.2
		observer.look_at(sim.position-f*.4+Vector3.UP*.35)
		var response_rows=[]
		for response in game.effects.responses: response_rows.append(response.report())
		for frame in 50:
			game.effects.update_effects(sim,field,sim.position,1.0/120.0,true,game.weather.state)
			await process_frame
		var probe_frames: Array[float]=[]
		var probe_gpu: Array[float]=[]
		var probe_cpu: Array[float]=[]
		var last=Time.get_ticks_usec()
		for frame in 240:
			game.effects.update_effects(sim,field,sim.position,1.0/120.0,true,game.weather.state)
			await process_frame
			var now=Time.get_ticks_usec(); probe_frames.append((now-last)/1000.0); last=now
			probe_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			probe_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		await capture(label+"_contact")
		result.cases.append({"material":label,"position":str(sim.position),"trace":trace,"crash":sim.crash_reason,"responses":response_rows,"tracks":game.effects.snow_tracks.written,"frame_ms":timing(probe_frames),"gpu_ms":timing(probe_gpu),"render_cpu_ms":timing(probe_cpu),"probe":"stationary completed-contact VFX, not full descent"})
		if on_rock:
			sim.impacts.reserve=.15 # HUD warning fixture only, never performance evidence.
			game._process(1.0/120.0)
			await capture("rock_low_reserve")
		observer.queue_free(); game.camera.make_current()
	result.peak_video_bytes=Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	result.static_memory_bytes=OS.get_static_memory_usage()
	result.display=game.display_settings.report(root,actual_pixels)
	result.device=RenderingServer.get_video_adapter_name()
	result.backend=RenderingServer.get_current_rendering_driver_name()
	result.unranked=not game.session.eligible
	preload("res://tests/test_report.gd").write(OUTPUT+"/rock_render.json",JSON.stringify(result,"\t"))
	print("ROCK_RENDER ",JSON.stringify(result))
	game.effects.stop_audio()

func find_contact(on_rock: bool) -> Vector3:
	var best=Vector3.INF
	var best_score=-INF
	for z in range(500,1700,32):
		for x in range(-1300,1300,32):
			var n: Vector3=field.contact_normal(x,z)
			if n.y<.74 or n.y>.95: continue
			var fraction: float=field.rock_fraction_at(x,z)
			if (fraction>.65)!=on_rock or (not on_rock and fraction>.2): continue
			var p=Vector3(x,field.sample(x,z).height,z)
			var f=Vector3.DOWN.slide(n).normalized()
			var valid=true
			var score=0.0
			for distance_m in [0,5,10,15,20,25,30]:
				var next=p+f*distance_m
				var rock: float=field.rock_fraction_at(next.x,next.z)
				if (rock>=.5)!=on_rock: valid=false; break
				if field.contact_normal(next.x,next.z).y<.72: valid=false; break
				score += rock if on_rock else 1-rock
				var projected=Vector3(next.x,field.sample(next.x,next.z).height,next.z)
				if not field.sweep_obstacle(p,projected).is_empty(): valid=false; break
			if valid and score>best_score:
				best=p; best_score=score
	print("ROCK_CONTACT_CHOICE ",on_rock," ",best)
	return best
