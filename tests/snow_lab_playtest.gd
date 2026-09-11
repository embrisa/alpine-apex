extends SceneTree
## Synthetic contact/visual stress fixtures, not a solver or handling test.
## Render captures are separate from screenshot-free measured frames.
var game
var output = "res://artifacts/snow_upgrade/lab"
var rows: Array = []
var captures: Array = []
var requested = Vector2i(3840,2160)
var last_us = 0
var frames: Array[float] = []
var cpu: Array[float] = []
var gpu: Array[float] = []
var updates: Array[float] = []
var peak_video = 0.0
var measuring = false
var quick = false

func _initialize() -> void: call_deferred("run")
func _process(_dt: float) -> bool:
	var now = Time.get_ticks_usec()
	if measuring and last_us>0:
		frames.append((now-last_us)/1000.0)
		var rid = root.get_viewport_rid()
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		peak_video = maxf(peak_video,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	last_us = now
	return false

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	quick = "--quick" in OS.get_cmdline_user_args()
	if quick: requested = Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.start_speed_lab(130)
	game.hud.hide()
	game.weather_effects.hide()
	game.effects.muted = true
	game.camera.effects_enabled = false
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	game.world.update_weather(game.weather.state,0,false)
	game.display_settings.apply_display(root,requested)
	Engine.max_fps = 120
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var actual = root.get_texture().get_image().get_size()
	if actual!=requested: printerr("Pixel mismatch ",actual); quit(2); return
	for quality in ([2] if quick else [0,1,2]):
		game.set_graphics_quality(quality)
		for mode in ["clean","carve","skid","wind","extreme"]:
			game.effects.reset()
			game.sim.reset(Vector3(0,game.field.sample(0,600).height,600))
			game.sim.prime_contacts(game.field)
			game.camera.close_view = false
			game.camera.reset()
			for frame in range(150):
				contact_fixture(mode,frame/120.0)
				await process_frame
			frames.clear(); cpu.clear(); gpu.clear(); updates.clear()
			measuring = not quick
			for frame in range(180 if quick else 480):
				var begin = Time.get_ticks_usec()
				contact_fixture(mode,(frame+150)/120.0)
				if measuring: updates.append((Time.get_ticks_usec()-begin)/1000.0)
				await process_frame
			measuring = false
			var result = {"quality":game.graphics.label(),"mode":mode,"frame_ms":summary(frames),"render_cpu_ms":summary(cpu),"gpu_ms":summary(gpu),"fixture_update_ms":summary(updates),"budget":game.effects.snow_budget(),"responses":[game.effects.responses[0].report(),game.effects.responses[1].report()]}
			rows.append(result)
			if game.effects.snow_tracks.written<100 or not game.active:
				printerr("Fixture failed to generate active track history")
				quit(3); return
			await capture(game.graphics.label()+"_"+mode+"_chase")
			for spray in game.effects.sprays: spray.speed_scale = 0.0
			var p: Vector3 = game.sim.position
			var f: Vector3 = game.sim.velocity.normalized()
			var r: Vector3 = game.sim.surface_normal.cross(f).normalized()
			game.camera.position = p-f*4.5-r*5.5+Vector3.UP*2.0
			game.camera.look_at(p-f*2.0+Vector3.UP*.5)
			await capture(game.graphics.label()+"_"+mode+"_side")
			if mode=="clean":
				game.camera.position = p+f*5.0+Vector3.UP*2.5
				game.camera.look_at(p-f*40.0)
				await capture(game.graphics.label()+"_look_back")
			if mode=="skid":
				game.camera.close_view = true
				game.camera.reset()
				game._process(1.0/120.0)
				for spray in game.effects.sprays: spray.speed_scale = 0
				await capture(game.graphics.label()+"_skid_pov")
			print("SNOW_FIXTURE ",JSON.stringify(result))
	var report = {"synthetic_contacts":true,"unranked":not game.session.eligible,"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name(),"display":game.display_settings.report(root,actual),"warmup_frames_per_case":150,"capture_overhead_included":false,"peak_video_bytes":peak_video,"cases":rows,"captures":captures}
	FileAccess.open(output+("/quick.json" if quick else "/performance.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	quit()

func contact_fixture(mode: String, seconds: float) -> void:
	var sim = game.sim
	var speed_kmh = 160.0 if mode=="clean" else (220.0 if mode=="extreme" else 130.0)
	var z = 600.0+seconds*speed_kmh/3.6*.92
	var p = Vector3(0,game.field.sample(0,z).height,z)
	var n: Vector3 = game.field.contact_normal(0,z)
	var f = Vector3.BACK.slide(n).normalized()
	var r = n.cross(f).normalized()
	var slip = 0.0 if mode=="clean" else (.045 if mode=="carve" else .85)
	var edge = 0.0 if mode=="clean" else .70
	sim.position = p
	game.previous_position = p
	sim.surface_normal = n
	sim.ski_forward = f.rotated(n,slip)
	sim.heading = atan2(sim.ski_forward.x,sim.ski_forward.z)
	sim.edge_angle = edge
	sim.slip_angle = slip
	sim.velocity = f*speed_kmh/3.6
	sim.grounded = true
	sim.crashed = false
	sim.normal_load = 9.81
	sim.effective_tuck = .1
	for i in range(2):
		var ski = sim.skis[i]
		ski.position = p+r*ski.side*.24
		ski.position.y = game.field.sample(ski.position.x,ski.position.z).height
		ski.previous_position = ski.position
		ski.normal = n
		ski.forward = sim.ski_forward
		ski.edge_angle = edge
		ski.slip_angle = slip
		ski.grounded = true
		ski.load_n = sim.tuning.rider_mass*9.81*(.75 if i==0 else .25)
		ski.grip_n = ski.load_n*.65 if edge>0 else 0.0
		ski.snow_depth = .24
		ski.penetration = .075
		ski.orientation = Basis(n.cross(ski.forward).normalized(),n,ski.forward)*Basis(Vector3.BACK,-edge)
		ski.previous_orientation = ski.orientation
	sim.body._pose(sim,1.0/120.0)
	sim.body.pose_frame = Transform3D(sim.support_basis(),p)
	sim.body.previous_pose_frame = sim.body.pose_frame
	sim.body.previous_joints = sim.body.joints.duplicate()
	sim.body.previous_rotations = sim.body.rotations.duplicate()
	game._process(1.0/120.0)
	# The game samples weather inside _process; install the controlled wind after
	# that update so the GPU receives the actual fixture rather than clear gusts.
	game.weather.state.wind_velocity = r*14.0 if mode=="wind" else Vector3.ZERO
	for spray in game.effects.sprays:
		spray.process_material.set_shader_parameter("wind_velocity",game.weather.state.wind_velocity)

func capture(id: String) -> void:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+id+".png")
	captures.append(id)

func summary(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"available":false}
	values.sort()
	var total = 0.0
	for value in values: total += value
	return {"samples":values.size(),"mean":total/values.size(),"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)]}
