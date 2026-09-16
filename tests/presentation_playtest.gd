extends SceneTree
## Native rendered handling inspection. Never eligible for personal bests.
## Run: ./godotw --script tests/presentation_playtest.gd
const DT = 1.0 / 120.0
var game
var report: Array = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	# Keep focus changes during automated inspection out of gameplay state.
	game.automated = true
	if "--weather-matrix" in OS.get_cmdline_user_args():
		await weather_matrix()
		await finish_report()
		return
	for kmh in [30,60,90,120,150,165,200]:
		setup(kmh,500.0)
		game.camera.close_view = false
		await ride(0.65,0.0,1.0)
		await capture("chase_%03d" % kmh)
		game.camera.close_view = true
		game.camera.reset()
		await ride(0.65,0.0,1.0)
		await capture("pov_%03d" % kmh)
	setup(145,700.0)
	game.camera.close_view = false
	await ride(0.5,0.0,1.0)
	await ride(0.85,0.70,1.0)
	await capture("loaded_turn")
	await ride(0.4,-0.20,0.0,1.0)
	await capture("braking")
	setup(100,500.0)
	game.intent.jump = true
	game.previous_position = game.sim.position
	game.sim.step(DT,game.intent,game.field)
	await ride(0.25,0.0,0.0)
	await capture("airborne")
	await ride(0.48,0.0,0.0)
	await capture("landing")
	game.active = false
	game.workbench_return = "paused"
	game.hud.hide_menu()
	game.hud.tuning_panel.visible = true
	await process_frame
	await capture("workbench")
	await finish_report()

func finish_report() -> void:
	var path = "res://artifacts/weather_presentation_results.json" if "--weather-matrix" in OS.get_cmdline_user_args() else "res://artifacts/presentation_results.json"
	var file = preload("res://tests/test_report.gd").open_write(path)
	file.store_string(JSON.stringify({"captures":report,"failures":failures},"\t"))
	print("PRESENTATION_RESULTS ",JSON.stringify({"captures":report.size(),"failures":failures}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func setup(kmh: float,z: float) -> void:
	game.start_speed_lab(kmh)
	game.sim.position = Vector3(0,game.field.sample(0,z).height,z)
	var n: Vector3 = game.field.contact_normal(0,z)
	game.sim.velocity = Vector3.DOWN.slide(n).normalized()*kmh/3.6
	game.previous_position = game.sim.position
	game.camera.reset()
	game.hud.toast_time = 0.0

func ride(seconds: float,steer: float,tuck: float,brake: float = 0.0) -> void:
	game.intent = RiderInput.new()
	game.intent.steer = steer
	game.intent.tuck = tuck
	game.intent.brake = brake
	for i in range(roundi(seconds/DT)):
		await physics_frame
		game.active = true
		game.previous_position = game.sim.position
		game.sim.step(DT,game.intent,game.field)
		game.session.elapsed += DT
		var clearance: float = game.camera.position.y-game.field.sample(game.camera.position.x,game.camera.position.z).height
		if clearance<0.50:
			failures.append("Camera below clearance at %.2f km/h" % game.sim.speed_kmh())

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() != "headless":
		get_root().get_texture().get_image().save_png("res://artifacts/feel_%s.png" % label)
	report.append({"label":label,"speed_kmh":game.sim.speed_kmh(),"balance":game.sim.balance,"grounded":game.sim.grounded,"crashed":game.sim.crashed,"effective_tuck":game.sim.effective_tuck,"edge_load":game.sim.edge_load,"eligible":game.session.eligible,"weather":game.weather.state.label,"quality":game.weather.quality,"weather_particles":game.weather_effects.particle_budget(),"stretch":game.weather_effects.stretch})
	if game.session.eligible:
		failures.append("Presentation playtest must remain unranked")

func weather_matrix() -> void:
	for id in ["clear","cloudy","snowfall","rain"]:
		game.weather.set_preset(id)
		for first_person in [false,true]:
			for kmh in [30,120,200]:
				setup(kmh,500.0)
				game.camera.close_view = first_person
				await ride(1.2,0.0,1.0)
				await capture("weather_%s_%s_%03d" % [id,"pov" if first_person else "chase",kmh])
	# A turn and successive frames expose camera-locked rain or reversed flow.
	await ride(0.20,0.45,1.0)
	await capture("weather_rain_turn_a")
	await ride(0.12,0.45,1.0)
	await capture("weather_rain_turn_b")
	game.weather.set_preset("snowfall")
	setup(200,500.0)
	game.camera.close_view = false
	await ride(0.8,0.0,1.0)
	await capture("weather_snow_motion_a")
	await ride(0.12,0.0,1.0)
	await capture("weather_snow_motion_b")
	game.camera.effects_enabled = false
	await ride(0.3,0.0,1.0)
	await capture("weather_motion_off")
	game.camera.effects_enabled = true
	game.weather.set_quality(1)
	await ride(0.4,0.0,1.0)
	await capture("weather_low")
	game.weather.set_quality(0)
	await ride(0.4,0.0,1.0)
	await capture("weather_off")
	game.weather.set_quality(2)
	game.weather.set_preset("clear")
	game.weather.set_automatic(true)
	game.weather.update_weather(190.0,true)
	await ride(0.1,0.0,1.0)
	await capture("weather_transition")
	game.active = false
	game.hud.show_menu("paused")
	game.hud.weather_button.pressed.emit()
	await process_frame
	await capture("weather_controls")
	var panel: Rect2 = game.hud.weather_panel.get_global_rect()
	if not root.get_visible_rect().encloses(panel):
		failures.append("Weather controls extend beyond the viewport")
	game.hud.close_weather()
	await capture("weather_paused")
	# Reset and switch directly to ensure neither inherits a high-speed rush.
	game.camera.close_view = true
	setup(30,500.0)
	game.weather.set_automatic(false)
	game.weather.set_preset("snowfall")
	await ride(0.2,0.0,0.0)
	await capture("weather_reset")
