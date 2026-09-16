extends SceneTree
## Native-only lighting QA: identical camera/geometry with and without clouds.
var game
var captures: Array = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Lighting inspection needs a native rendered viewport.")
		quit(1)
		return
	root.size = Vector2i(1440,900)
	root.unresizable = true
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.start_speed_lab(0.0)
	var z = 500.0
	game.sim.position = Vector3(0,game.field.sample(0,z).height,z)
	game.previous_position = game.sim.position
	game.active = false
	game.hud.hide_menu()
	game.effects.visible = false
	game.weather_effects.visible = false
	game.camera.effects_enabled = false
	for i in range(8):
		game._process(0.1)
	game.set_process(false)
	for view in [false,true]:
		game.camera.close_view = view
		game.camera.reset()
		game._process(0.1)
		for period in ["dawn","day","dusk","night"]:
			for preset in ["clear","cloudy","snowfall","rain"]:
				apply(preset,period,Vector2.ZERO)
				await capture("%s_%s_%s" % ["pov" if view else "chase",period,preset])
	game.camera.close_view = false
	game.camera.reset()
	game._process(0.1)
	apply("cloudy","day",Vector2.ZERO)
	# Inspect the illuminated side: a sleeve facing away from the sun receives
	# ambient fill only, so correctly does not darken under a passing cloud.
	game.camera.global_position = game.skier.pose_probe("chest") + game.weather.state.sun_direction*6.0
	game.camera.look_at(game.skier.pose_probe("chest"))
	var jacket_point: Vector2 = game.camera.unproject_position(game.skier.pose_probe("jacket"))
	var ground: Vector3 = game.sim.position + Vector3(-2,0,1)
	ground.y = game.field.sample(ground.x,ground.z).height
	var snow_point: Vector2 = game.camera.unproject_position(ground)
	var samples: Array = []
	var bright_image: Image
	var dark_image: Image
	var high: float = -1.0
	var low: float = 10.0
	var high_offset: Vector2
	var low_offset: Vector2
	# Scan real shader output, not a separate CPU approximation of cloud noise.
	for i in range(48):
		var offset = Vector2(i*70.0,0.0)
		apply("cloudy","day",offset)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var snow = luminance(img,snow_point,5)
		var rider = luminance(img,jacket_point,1)
		samples.append({"offset_m":offset.x,"snow_luminance":snow,"jacket_luminance":rider})
		if snow>high:
			high = snow
			bright_image = img
			high_offset = offset
		if snow<low:
			low = snow
			dark_image = img
			low_offset = offset
	bright_image.save_png("res://artifacts/light_cloud_sunlit.png")
	dark_image.save_png("res://artifacts/light_cloud_shaded.png")
	var bright_jacket = luminance(bright_image,jacket_point,1)
	var dark_jacket = luminance(dark_image,jacket_point,1)
	if high-low<0.025 or bright_jacket-dark_jacket<0.015:
		failures.append("Moving clouds must visibly shade both the snow and orange sleeve")
	apply("cloudy","day",low_offset)
	game.world.cloud_lighting.shadow_strength = 0.0
	game.world.update_weather(game.weather.state,0.0,false)
	await capture("cloud_shadows_disabled")
	game.world.cloud_lighting.shadow_strength = 0.88
	apply("clear","day",high_offset)
	# Actual skier/tree shadow casting remains in the direct-light path.
	await capture("sun_object_shadows")
	apply("clear","night",low_offset)
	await capture("moon_object_shadows")
	for period in ["day","night"]:
		apply("clear",period,Vector2.ZERO)
		game.camera.look_at(game.camera.global_position+(game.weather.state.sun_direction if period=="day" else -game.weather.state.sun_direction)*100.0)
		await capture("%s_sky_disc" % period)
	# Check the continuous sun/moon handover, independently of preset jumps.
	game.camera.reset()
	game._process(0.1)
	for hour in [5.5,6.0,6.25,17.75,18.0,18.5]:
		game.weather.daylight.hour = hour
		game.weather.update_weather(0.0,false)
		game.world.update_weather(game.weather.state,0.0,false)
		await capture("twilight_%s" % str(hour).replace(".","_"))
	# Night lighting must also leave moving precipitation and the route readable.
	game.effects.visible = true
	game.weather_effects.visible = true
	game.camera.effects_enabled = true
	for view in [false,true]:
		for preset in ["snowfall","rain"]:
			game.start_speed_lab(120.0)
			game.camera.close_view = view
			game.camera.reset()
			apply(preset,"night",Vector2.ZERO)
			for frame in range(60):
				for tick in range(2):
					game.previous_position = game.sim.position
					game.sim.step(1.0/120.0,game.intent,game.field)
				game._process(1.0/60.0)
				await process_frame
			await capture("moving_%s_night_%s" % ["pov" if view else "chase",preset])
	game.active = false
	game.camera.reset()
	game._process(0.1)
	game.hud.show_menu("paused")
	game.hud.weather_button.pressed.emit()
	await capture("time_controls")
	if not root.get_visible_rect().encloses(game.hud.weather_panel.get_global_rect()):
		failures.append("Time and weather controls overflow the viewport")
	var result = {"captures":captures,"cloud_sweep":samples,"sunlit_offset_m":str(high_offset),"shaded_offset_m":str(low_offset),"sunlit_snow":high,"shaded_snow":low,"sunlit_jacket":bright_jacket,"shaded_jacket":dark_jacket,"failures":failures}
	var file = preload("res://tests/test_report.gd").open_write("res://artifacts/lighting_results.json")
	file.store_string(JSON.stringify(result,"\t"))
	print("LIGHTING_RESULTS ",JSON.stringify({"captures":captures.size()+2,"snow_delta":high-low,"jacket_delta":bright_jacket-dark_jacket,"failures":failures}))
	game.effects.stop_audio()
	await create_timer(0.10).timeout
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func apply(preset: String, period: String, offset: Vector2) -> void:
	game.weather.set_preset(preset)
	game.weather.set_time_of_day(period)
	game.world.cloud_offset = offset
	game.world.update_weather(game.weather.state,0.0,false)
	game.hud.update_hud(game.sim,game.session,game.intent,"Render test",8.3,0.1,0.2,true,game.weather.state.label+" · "+game.weather.state.time_label)
	game.hud.fps_label.text = "LIGHTING INSPECTION  /  UNRANKED"
	game.hud.toast_time = 0.0
	game.hud.toast_label.hide()

func capture(label: String) -> void:
	game.hud.update_hud(game.sim,game.session,game.intent,"Render test",8.3,0.1,0.0,true,game.weather.state.label+" · "+game.weather.state.time_label)
	game.hud.fps_label.text = "LIGHTING INSPECTION  /  UNRANKED"
	game.hud.toast_label.hide()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/light_%s.png" % label)
	captures.append({"label":label,"sun_energy":game.world.sun.light_energy,"moon_energy":game.world.moon.light_energy,"time_hour":game.weather.state.time_hour,"time_label":game.weather.state.time_label,"weather":game.weather.selected_preset,"speed_kmh":game.sim.speed_kmh(),"eligible":game.session.eligible})
	if game.session.eligible:
		failures.append("Lighting captures must not set records")

func luminance(img: Image, point: Vector2, radius: int) -> float:
	var value = 0.0
	var count = 0
	for y in range(int(point.y)-radius,int(point.y)+radius+1):
		for x in range(int(point.x)-radius,int(point.x)+radius+1):
			var color = img.get_pixel(clampi(x,0,img.get_width()-1),clampi(y,0,img.get_height()-1))
			value += color.r*0.2126+color.g*0.7152+color.b*0.0722
			count += 1
	return value/count
