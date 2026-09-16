extends SceneTree
## Native visual QA and Low frame timing. Uses real fixed-step flight; unranked.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Terrain = preload("res://scripts/world/generators/drainage_v3.gd")
const OUT = "res://artifacts/jump_upgrade/"
var game
var frame_times: Array[float] = []
var measuring = false
var last_frame = 0
var was_measuring = false
var captures: Array = []
var capture_enabled = not "--timing-only" in OS.get_cmdline_user_args()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1440,900)
	var field = Terrain.new()
	set_meta("mountain_to_load",{"definition":Definition.from_field(field),"field":field})
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.set_graphics_quality(0)
	game.weather.set_preset("clear")
	game.effects.muted = true
	game.automated = true
	game.start_run(false)
	game.session.eligible = false
	game.hud.root.visible = false
	game.hud.menu.visible = false
	for i in 120: await process_frame
	process_frame.connect(_measure)
	for index in [0,1,2,3,4,5]:
		var feature = field.jumps[index]
		var x: float = feature.position.x
		var z: float = feature.position.y-70
		game.sim.reset(Vector3(x,field.sample(x,z).height,z))
		game.sim.prime_contacts(field)
		game.sim.velocity = game.sim.support_basis().z*110.0/3.6
		game.camera.reset()
		game.intent = RiderInput.new()
		game.intent.tuck = .45
		game.active = true
		var flight_started = false
		var samples = 0
		var landed = false
		measuring = true
		for i in 1800:
			await physics_frame
			game.previous_position = game.sim.position
			var airborne = not game.sim.grounded
			game.sim.step(1.0/120.0,game.intent,field)
			game.session.elapsed += 1.0/120.0
			game._process(1.0/120.0)
			if game.sim.airtime>.12:
				flight_started = true
			if flight_started and game.sim.airtime>float(samples)*.35+.15 and samples<4:
				measuring = false
				var center: Vector3 = game.sim.position+Vector3.UP
				game.camera.global_position = center+Vector3(7.0,1.8,4.0)
				game.camera.look_at(center)
				await capture("feature_%d_air_%d" % [index,samples])
				samples += 1
				measuring = true
			if flight_started and airborne and game.sim.grounded:
				landed = true
			if game.sim.crashed or (landed and game.sim.position.z>feature.position.y+145): break
		measuring = false
		print("VISUAL_FEATURE ",index," landed=",landed," crash=",game.sim.crash_reason)
		# Read the whole takeoff and landing shape in one overview.
		var lip = Vector3(feature.position.x,field.sample(feature.position.x,feature.position.y).height,feature.position.y)
		game.camera.global_position = lip+Vector3(-80,45,60)
		game.camera.look_at(lip+Vector3(0,-35,65))
		await capture("feature_%d_overview" % index)
	# A normal Space hop on an ordinary slope, viewed in chase and side view.
	game.sim.reset(Vector3(0,field.sample(0,230).height,230))
	game.sim.prime_contacts(field)
	game.sim.velocity = game.sim.support_basis().z*70.0/3.6
	game.intent = RiderInput.new()
	game.camera.reset()
	for i in 190:
		await physics_frame
		game.intent.jump = i==60
		game.previous_position = game.sim.position
		game.sim.step(1.0/120.0,game.intent,field)
		game._process(1.0/120.0)
		if i==80: await capture("space_hop_chase")
		if i==105:
			var center: Vector3 = game.sim.position+Vector3.UP
			game.camera.global_position = center+Vector3(5,1.2,3)
			game.camera.look_at(center)
			await capture("space_hop_side")
	print("SPACE_HOP landed=",game.sim.grounded," crash=",game.sim.crash_reason)
	game.hud.root.visible = true
	game.hud.menu.visible = false
	game.mountain_library._set_draft(Definition.from_field(field),field)
	game.mountain_library.panel.show()
	await capture("mountain_survey")
	game.mountain_library.panel.hide()
	frame_times.sort()
	var mean = 0.0
	for ms in frame_times: mean += ms
	mean /= maxf(frame_times.size(),1)
	var output = {"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),"pixels":str(root.get_texture().get_image().get_size()),"quality":"Low","weather":"Clear","mean_ms":mean,"p95_ms":frame_times[int(frame_times.size()*.95)],"p99_ms":frame_times[int(frame_times.size()*.99)],"frames":frame_times.size(),"terrain_triangles":game.world.terrain_triangles,"world_build_ms":game.world.generation_ms,"captures":captures,"captures_enabled":capture_enabled,"eligible":game.session.eligible}
	preload("res://tests/test_report.gd").write(OUT+("native.json" if capture_enabled else "performance.json"),JSON.stringify(output,"\t"))
	print("JUMP_NATIVE ",JSON.stringify(output))
	game.active = false
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	quit()
func capture(id: String) -> void:
	if not capture_enabled: return
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+id+".png")
	captures.append(id)
func _measure() -> void:
	var now = Time.get_ticks_usec()
	if measuring and was_measuring and last_frame>0: frame_times.append((now-last_frame)/1000.0)
	last_frame = now
	was_measuring = measuring
