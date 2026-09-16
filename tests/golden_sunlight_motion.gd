extends "res://tests/technical_showcase_playtest.gd"
## Fixed solver/presentation/particle time, independent of screenshot stalls.
## 4K renders; 1080p review frames at 30 Hz plus adjacent native 60 Hz samples.
func inspect_motion() -> void:
	game.active = true
	game.hud.root.hide()
	game.set_process(false)
	var particles: Array = game.effects.sprays+game.weather_effects.volumes+game.weather_effects.drifts
	for i in particles.size():
		particles[i].use_fixed_seed = true
		particles[i].seed = 849205174+i
	var clips: Array = []
	if FileAccess.file_exists(OUTPUT+"/motion_checkpoint.json"):
		clips = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"/motion_checkpoint.json"))
	for route in [-1,1]:
		for preset in ["clear","snowfall"]:
			for section in [900,1370,1756,2170]:
				for close in [false,true]:
					var label = "%s_%d_%d_%s" % [preset,route,section,"pov" if close else "chase"]
					if clips.any(func(clip): return clip.clip==label): continue
					game.weather.set_preset(preset)
					game.weather.set_time_of_day("day")
					game.weather.visual_time = 0.0
					game.world.cloud_offset = Vector2.ZERO
					game.world.assets.wind_time = 0.0
					game.effects.reset()
					game.weather_effects.reset()
					var x = 0.0 if section==1756 else (field.glade_x(section,route) if section>1900 else field.gully_x(section,route))
					game.sim.reset(Vector3(x,field.sample(x,section).height,section),0)
					game.sim.prime_contacts(field)
					game.sim.velocity = Vector3.BACK.slide(field.contact_normal(x,section)).normalized()*18.0
					game.camera.close_view = close
					game.camera.reset()
					DirAccess.make_dir_recursive_absolute(OUTPUT+"/"+label)
					for frame in 180:
						for tick in 2:
							game.intent = Pilot.intent(game.sim,field,route) if section!=1756 else RiderInput.new()
							game.sim.step(Pilot.DT,game.intent,field)
						game._process(1.0/60.0)
						for particle in particles:
							particle.speed_scale = 0.0
							if particle.visible: particle.request_particles_process(1.0/60.0)
						await process_frame
						await RenderingServer.frame_post_draw
						if frame%2==0 or frame in [31,179]:
							var picture = root.get_texture().get_image()
							if frame in [30,31,32,90,179]: picture.save_jpg(OUTPUT+"/"+label+"_%03d.jpg" % frame,.97)
							if frame%2==0:
								picture.resize(1920,1080,Image.INTERPOLATE_LANCZOS)
								picture.save_jpg(OUTPUT+"/"+label+"/%03d.jpg" % (frame/2),.93)
						if frame==90 and route==-1 and preset=="clear" and section==900 and not close:
							game.hud.root.show()
							await capture("hud_clear_chase",2)
							game.hud.root.hide()
					clips.append({"clip":label,"crash":game.sim.crash_reason,"position":str(game.sim.position),"duration_s":3.0,"airtime_s":game.sim.total_airtime,"frames":90})
					preload("res://tests/test_report.gd").write(OUTPUT+"/motion_checkpoint.json",JSON.stringify(clips,"\t"))
					print("GOLDEN_MOTION ",label," crash=",game.sim.crash_reason)
	preload("res://tests/test_report.gd").write(OUTPUT+"/motion.json",JSON.stringify({"clips":clips,"physics_hz":120,"presentation_hz":60,"particle_hz":60,"review_fps":30,"native_pixels":[3840,2160],"review_pixels":[1920,1080],"capture_overhead":true,"native_samples":[30,31,32,90,179],"unranked":not game.session.eligible},"\t"))
