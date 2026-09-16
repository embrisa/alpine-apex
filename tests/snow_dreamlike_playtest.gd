extends "res://tests/alpine_v13_playtest.gd"
## Matched v13 views and fixed-time motion. No timings include captures.
var snow_fixtures: Array = []
var snow_sites: Array = []

func inspect_massif() -> void:
	var reflection_only = "--snow-reflections-only" in OS.get_cmdline_user_args()
	if reflection_only:
		var previous = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"/snow_fixtures.json"))
		for fixture in previous:
			if not str(fixture.name).begins_with("reflection_"):
				snow_fixtures.append(fixture)
				inspection_captures.append(fixture.name)
	game.active = false
	game.set_process(false)
	game.hud.hide_menu()
	game.hud.root.hide()
	game.skier.hide()
	game.weather.set_time_of_day("day")
	game.weather.visual_time = 0.0
	game.world.cloud_offset = Vector2.ZERO
	var face = field.faces[0]
	snow_sites = [
		{"label":"summit","p":safe_site(face.to_world(Vector2(0,100)))},
		{"label":"slope","p":safe_site(face.to_world(Vector2(220,900)))},
		{"label":"forest","p":forest_site(0)}]
	var observer = Camera3D.new()
	observer.far = 15000
	observer.fov = 75
	game.add_child(observer)
	observer.make_current()
	if "--snow-motion-only" not in OS.get_cmdline_user_args():
		for site in ([] if reflection_only else snow_sites):
			var p: Vector2 = site.p
			var focus = Vector3(p.x,field.sample(p.x,p.y).height,p.y)
			game.sim.reset(focus,face.heading)
			game.sim.prime_contacts(field)
			game.previous_position = game.sim.position
			game.camera.reset()
			game._process(0)
			observer.make_current()
			observer.position = focus+Vector3.UP*2.0
			for preset in ["clear","cloudy","snowfall","rain"]:
				game.weather.set_preset(preset)
				game.weather.set_time_of_day("day")
				game.world.update_weather(game.weather.state,0,false)
				var sun: Vector3 = game.weather.state.sun_direction
				for angle in [0,90,180]:
					var direction = Vector3(sun.x,0,sun.z).normalized().rotated(Vector3.UP,deg_to_rad(angle))
					observer.look_at(observer.position+direction+Vector3.DOWN*.30)
					await capture("%s_%s_%d" % [site.label,preset,angle],30)
			game.weather.set_time_of_day("night")
			game.world.update_weather(game.weather.state,0,false)
			await capture(site.label+"_night",30)
		game.weather.set_time_of_day("day")
		game.weather.set_preset("clear")
		var p: Vector2 = snow_sites[1].p
		var focus = Vector3(p.x,field.sample(p.x,p.y).height,p.y)
		game.sim.reset(focus,face.heading)
		game.sim.prime_contacts(field)
		game.previous_position = game.sim.position
		game.camera.reset()
		game._process(0)
		game.world.update_weather(game.weather.state,0,false)
		observer.make_current()
		var n: Vector3 = field.contact_normal(p.x,p.y)
		var sun: Vector3 = game.weather.state.sun_direction
		var reflection = -sun+2.0*n*n.dot(sun)
		for distance_m in [5,20,40,60]:
			observer.position = focus+reflection*distance_m
			observer.look_at(focus)
			await capture("reflection_%dm" % distance_m,30)
		observer.position = focus+reflection*5
		observer.look_at(focus)
		for level in [0,1,2]:
			game.set_graphics_quality(level)
			await capture("reflection_quality_%d" % level,30)
		if "--snow-quick" not in OS.get_cmdline_user_args():
			# Native control uses the existing display API, and never persists it.
			var display = game.display_settings
			var saved = [display.upscaler,display.render_scale]
			display.upscaler = "native"
			display.render_scale = 1.0
			display.apply_viewport(root)
			await capture("reflection_native",30)
			display.upscaler = saved[0]
			display.render_scale = saved[1]
			display.apply_viewport(root)
	observer.queue_free()
	game.camera.make_current()
	if not reflection_only and "--snow-stills-only" not in OS.get_cmdline_user_args(): await snow_motion()
	preload("res://tests/test_report.gd").write(OUTPUT+"/snow_fixtures.json",JSON.stringify(snow_fixtures,"\t"))

func capture(label: String, settle_frames: int = 30) -> void:
	await super.capture(label,settle_frames)
	var cam = root.get_camera_3d()
	snow_fixtures.append({"name":label,"position":var_to_str(cam.global_position),"basis":var_to_str(cam.global_basis),"fov":cam.fov,"weather":game.weather.selected_preset,"hour":game.weather.daylight.hour,"cloud_offset":var_to_str(game.world.cloud_offset),"sun":var_to_str(game.weather.state.sun_direction),"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"pixels":[actual_pixels.x,actual_pixels.y]})
	print("SNOW_VIEW ",label)

func snow_motion() -> void:
	game.skier.show()
	game.camera.make_current()
	var particles: Array = game.effects.sprays+game.weather_effects.volumes+game.weather_effects.drifts
	for i in particles.size():
		particles[i].use_fixed_seed = true
		particles[i].seed = 849205174+i
	var clips: Array = []
	for site in [snow_sites[1],snow_sites[2]]:
		for close in [false,true]:
			for preset in ["clear","snowfall"]:
				var label = "%s_%s_%s" % [site.label,preset,"pov" if close else "chase"]
				var p: Vector2 = site.p
				var face = field.faces[0]
				game.weather.set_preset(preset)
				game.weather.set_time_of_day("day")
				game.weather.visual_time = 0
				game.world.cloud_offset = Vector2.ZERO
				game.effects.reset()
				game.weather_effects.reset()
				game.sim.reset(Vector3(p.x,field.sample(p.x,p.y).height,p.y),face.heading)
				game.sim.prime_contacts(field)
				game.skier.reset_animation(game.sim)
				game.previous_position = game.sim.position
				game.sim.velocity = Vector3(sin(face.heading),0,cos(face.heading)).slide(game.sim.surface_normal).normalized()*22.0
				game.camera.close_view = close
				game.camera.reset()
				game.active = true
				DirAccess.make_dir_recursive_absolute(OUTPUT+"/"+label)
				for frame in 180:
					var input = RiderInput.new()
					input.tuck = .5
					input.steer = sin(frame/60.0)*.12
					for tick in 2:
						game.previous_position = game.sim.position
						game.sim.step(1.0/120,input,game.world.ski_surface)
						game.skier.step_animation(1.0/120,game.sim,input,field)
					game._process(1.0/60)
					for particle in particles:
						particle.speed_scale = 0
						if particle.visible: particle.request_particles_process(1.0/60)
					await process_frame
					await RenderingServer.frame_post_draw
					if frame%2==0 or frame in [31,179]:
						var picture = root.get_texture().get_image()
						if frame in [30,31,32,90,179]: picture.save_jpg(OUTPUT+"/"+label+"_%03d.jpg" % frame,.97)
						if frame%2==0:
							picture.resize(1920,1080,Image.INTERPOLATE_LANCZOS)
							picture.save_jpg(OUTPUT+"/"+label+"/%03d.jpg" % (frame/2),.93)
				clips.append({"clip":label,"crash":game.sim.crash_reason,"position":var_to_str(game.sim.position),"duration_s":3,"frames":90,"start":var_to_str(p)})
				preload("res://tests/test_report.gd").write(OUTPUT+"/snow_motion.json",JSON.stringify({"clips":clips,"physics_hz":120,"presentation_hz":60,"review_fps":30,"unranked":not game.session.eligible,"capture_overhead":true},"\t"))
				print("SNOW_MOTION ",label," crash=",game.sim.crash_reason)
