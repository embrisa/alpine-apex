extends "res://tests/technical_showcase_playtest.gd"
## Matched v7/v8 geometry views and real-solver contact/track inspection.
## Invoke with --views; captured frames are never performance evidence.

func inspect_views() -> void:
	game.active = false
	game.set_process(false)
	game.hud.root.hide()
	game.skier.hide()
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	game.weather.visual_time = 0.0
	game.world.update_weather(game.weather.state,0,false)
	var archived = Definition.generate(849205174,7)
	var observer = Camera3D.new()
	observer.fov = 75.0
	observer.far = 15000
	game.add_child(observer)
	observer.make_current()
	var plain = StandardMaterial3D.new()
	plain.albedo_color = Color(.38,.43,.50)
	plain.roughness = .9
	var poses: Array = []
	for route in [-1,1]:
		for section in [900,2170]:
			var x = archived.gully_x(section,route) if section<1850 else archived.glade_x(section,route)
			# Fixed world poses derived only from v7, identical in both captures.
			var p = Vector3(x,archived.sample(x,section).height,section)
			var ahead = Vector3(x,archived.sample(x,section+35).height,section+35)
			# Look diagonally along the snow bed; a 24 m transverse look points
			# straight into the much taller rock shoulder in these narrow gullies.
			var across = Vector3(x+8,archived.sample(x+8,section+18).height,section+18)
			for view in ["skiing","low_angle","geometry_only"]:
				observer.position = p+Vector3.UP*2.2
				observer.look_at((ahead if view=="skiing" else across)+Vector3.UP*.25)
				for chunk in game.world.terrain_chunks:
					chunk.material_override = plain if view=="geometry_only" else game.world.snow_material
				var label = "%d_%d_%s" % [route,section,view]
				poses.append({"capture":label,"camera":str(observer.position),"basis":str(observer.basis)})
				await capture(label)
	for chunk in game.world.terrain_chunks: chunk.material_override = game.world.snow_material
	observer.queue_free()
	game.camera.make_current()
	game.skier.show()
	archived = null
	var clips: Array = []
	var failures: Array = []
	for route in [-1,1]:
		for section in [900,2170]:
			game.effects.reset()
			game.active = true
			var x = field.gully_x(section,route) if section<1850 else field.glade_x(section,route)
			game.sim.reset(Vector3(x,field.sample(x,section).height,section),0)
			game.sim.prime_contacts(field)
			game.sim.velocity = Vector3.BACK.slide(field.contact_normal(x,section)).normalized()*18.0
			game.camera.close_view = false
			game.camera.reset()
			var label = "%d_%d_motion" % [route,section]
			var contact_error = 0.0
			for frame in 180:
				for tick in 2:
					game.intent = Pilot.intent(game.sim,field,route)
					game.sim.step(Pilot.DT,game.intent,field)
					for ski in game.sim.skis:
						if ski.grounded:
							contact_error = maxf(contact_error,absf(ski.position.y-field.sample(ski.position.x,ski.position.z).height))
				game._process(1.0/60.0)
				await process_frame
				if frame in [30,31,90,179]: await capture(label+"_%03d" % frame,0)
				if game.sim.crashed: break
			game.active = false
			var tracks = game.effects.snow_tracks
			var corner_error = 0.0
			for index in tracks.written:
				var transform_value = tracks.tracks.get_instance_transform(index)
				var offsets = tracks.tracks.get_instance_custom_data(index)
				var corner = 0
				for end in [-.5,.5]:
					for edge in [-.5,.5]:
						var p: Vector3 = transform_value*Vector3(edge,0,end)
						corner_error = maxf(corner_error,absf(p.y+offsets[corner]-field.sample(p.x,p.z).height))
						corner += 1
			var surface_texture = tracks.material.get_shader_parameter("surface_heights") as Texture2D
			var exact_upload = surface_texture.get_image().get_data()==field.heights.to_byte_array()
			var ok = not game.sim.crashed and tracks.written>50 and corner_error<.001 and contact_error<.001 and exact_upload
			if not ok: failures.append(label)
			print("PASS: " if ok else "FAIL: ",label," real ski contact, GPU track corners and immutable surface upload")
			clips.append({"clip":label,"crash":game.sim.crash_reason,"airtime_s":game.sim.total_airtime,"track_instances":tracks.written,"max_ski_contact_error_m":contact_error,"max_gpu_track_corner_error_m":corner_error,"exact_surface_upload":exact_upload})
	var report = {"generator_version":version,"camera_reference_version":7,"poses":poses,"clips":clips,"failures":failures,"unranked":not game.session.eligible,"physics_hz":120,"presentation_hz":60,"capture_overhead_included":true}
	preload("res://tests/test_report.gd").write(OUTPUT+"/snow_inspection.json",JSON.stringify(report,"\t"))
	print("SNOW_INSPECTION ",JSON.stringify(report))
	if not failures.is_empty(): quit(1)
