extends SceneTree
## Native before/after equipment inspection and bounded 4K laboratory timing.
const DT = 1.0/120.0
var game
var output = "res://artifacts/equipment_v1/visual"
var captures: Array = []
var rows: Array = []
var timing = false
var requested = Vector2i(1280,960)

func _initialize(): call_deferred("run")

func swap_equipment(detailed: bool):
	for i in range(2):
		game.skier.skis[i].mesh = game.world.assets.mesh(("ski_detailed_v1" if i==0 else "ski_detailed_v1_left") if detailed else "ski")
		game.skier.skis[i].get_child(0).mesh = game.world.assets.mesh("binding_detailed_v1" if detailed else "binding")
		game.skier.poles[i].mesh = game.world.assets.mesh("pole_detailed_v1" if detailed else "pole")

func reset_rider():
	game.skier.ragdoll.stop()
	game.start_speed_lab(70)
	var p = Vector3(0,game.field.sample(0,520).height,520)
	game.sim.reset(p)
	game.sim.prime_contacts(game.field)
	game.sim.velocity = Vector3.BACK.slide(game.sim.surface_normal).normalized()*70/3.6
	game.previous_position = game.sim.position
	game.skier.reset_animation(game.sim)
	game.session.eligible = false

func advance(intent):
	game.previous_position = game.sim.position
	game.sim.step(DT,intent,game.field)
	game.skier.step_animation(DT,game.sim,intent,game.field)
	game._process(DT)

func stats(values: Array[float]):
	var sorted = values.duplicate()
	sorted.sort()
	var total = 0.0
	for v in values: total += v
	return {"mean":total/values.size(),"p95":sorted[int((sorted.size()-1)*.95)],"p99":sorted[int((sorted.size()-1)*.99)],"max":sorted[-1],"count":values.size()}

func run():
	if DisplayServer.get_name()=="headless": quit(1); return
	set_meta("test_lab_fixture",true)
	timing = "--timing" in OS.get_cmdline_user_args()
	if timing: requested = Vector2i(3840,2160)
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.set_graphics_quality(2)
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	game.hud.hide()
	game.effects.muted = true
	game.camera.effects_enabled = false
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "fsr2" if timing else "native"
	game.display_settings.render_scale = .75 if timing else 1.0
	game.display_settings.fps_limit = 120
	game.display_settings.apply_display(root,requested)
	game.display_settings.apply_viewport(root)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for f in range(20): await process_frame
	await RenderingServer.frame_post_draw
	var actual = root.get_texture().get_image().get_size()
	if actual!=requested: printerr("Pixel mismatch ",actual); quit(2); return
	var reverse_order = "--reverse-equipment-order" in OS.get_cmdline_user_args()
	for detailed in ([true,false] if reverse_order else [false,true]):
		swap_equipment(detailed)
		reset_rider()
		game.camera.close_view = false
		var intent = RiderInput.new()
		intent.tuck = .55
		if timing:
			var frames: Array[float] = []
			var cpu: Array[float] = []
			var gpu: Array[float] = []
			var peak_video = 0.0
			var peak_static = 0.0
			for f in range(960):
				if f%180==0: reset_rider()
				var begin = Time.get_ticks_usec()
				intent.steer = sin(f*.02)*.15
				advance(intent)
				await process_frame
				if f>=240:
					frames.append((Time.get_ticks_usec()-begin)/1000.0)
					cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
					gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
					peak_video = maxf(peak_video,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
					peak_static = maxf(peak_static,Performance.get_monitor(Performance.MEMORY_STATIC))
			rows.append({"detailed":detailed,"frame_ms":stats(frames),"cpu_render_ms":stats(cpu),"gpu_ms":stats(gpu),"peak_video_bytes":peak_video,"peak_engine_static_bytes":peak_static})
			print("EQUIPMENT_TIMING ",JSON.stringify(rows[-1]))
		else:
			for f in range(80): advance(intent)
			var prefix = "after_" if detailed else "before_"
			for view in ["overview","boot_side","ski_tips","grip","chase","first_person","first_person_down"]:
				game.camera.close_view = view.begins_with("first_person")
				game._process(DT)
				if view in ["overview","boot_side","ski_tips"]:
					var center: Vector3 = game.skier.to_global(Vector3(0,.45,0))
					var offset = Vector3(2.6,1.2,2.5)
					if view=="boot_side": center = game.skier.skis[1].to_global(Vector3(0,.16,-.15)); offset = Vector3(.85,.22,.25)
					if view=="ski_tips": center = game.skier.to_global(Vector3(0,.12,.45)); offset = Vector3(.6,1.35,1.5)
					game.camera.global_position = center+game.skier.global_basis*offset
					game.camera.look_at(center)
				elif view=="grip":
					var center: Vector3 = game.skier.poles[1].global_position
					game.camera.global_position = center+game.skier.global_basis*Vector3(.38,.24,.42)
					game.camera.look_at(center)
				elif view=="first_person_down":
					game.camera.look_at(game.skier.to_global(Vector3(0,.04,.45)))
				await capture(prefix+view)
			game.camera.close_view = false
			reset_rider()
			for f in range(100):
				intent.steer = .5
				intent.jump = f==60
				advance(intent)
				if f in [45,66]:
					var center: Vector3 = game.skier.to_global(Vector3(0,.65,0))
					game.camera.global_position = center+Vector3(2.5,1.2,2.2)
					game.camera.look_at(center)
					await capture(prefix+("carve" if f==45 else "hop"))
			rows.append({"detailed":detailed,"airtime_s":game.sim.total_airtime,"crashed":game.sim.crashed})
			# Deliberately trigger the existing physical handoff for attachment QA.
			reset_rider()
			game.sim.crashed = true
			game.skier.ragdoll.start(game.sim)
			for f in range(45):
				await physics_frame
				game.skier.ragdoll.update_equipment()
			var center: Vector3 = game.skier.ragdoll.bone_world("Hips").origin
			game.camera.global_position = center+Vector3(2.5,1.5,2.5)
			game.camera.look_at(center)
			game.skier.ragdoll.set_frozen(true)
			await capture(prefix+"controlled_crash")
			game.skier.ragdoll.stop()
	assert(not game.session.eligible)
	var report = {"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"display":game.display_settings.report(root,actual),"unranked":true,"captures":captures,"cases":rows,"scope":"matched equipment comparison on the laboratory, existing applications left running; timing excludes captures"}
	report.reverse_order = reverse_order
	report.equipment_sha256 = {}
	for id in ["ski_detailed_v1","ski_detailed_v1_left","binding_detailed_v1","pole_detailed_v1"]:
		report.equipment_sha256[id] = FileAccess.get_sha256("res://assets/graphics/models/"+id+".glb")
	var filename = ("/performance_reverse.json" if reverse_order else "/performance.json") if timing else "/captures.json"
	preload("res://tests/test_report.gd").write(output+filename,JSON.stringify(report,"\t"))
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	quit()

func capture(id: String):
	for f in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+id+".png")
	captures.append(id)
