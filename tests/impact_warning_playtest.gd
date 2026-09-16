extends SceneTree
## Matched v14 presentation fixtures. Forced reserve is diagnostic, never skiing evidence.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const DT = 1.0/60.0
const OUT = "res://artifacts/impact_warning/"
var game
var timing = false
var rows: Array = []
var captures: Array = []
var failures: Array = []
var field
var source_hashes: Dictionary = {}
var actual: Vector2i

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	timing = "--timing" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	for path in ["scripts/main.gd","scripts/presentation/impact_warning.gd","assets/speed_periphery.gdshader","scripts/core/ski_simulation.gd","scripts/core/impact_recovery.gd"]:
		source_hashes[path] = FileAccess.get_sha256("res://"+path)
	field = Definition.generate(849205174,Definition.CURRENT_VERSION)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field),"field":field})
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.start_run(false); game.summit_ready = false; game.session.eligible = false
	game.effects.muted = true; game.voice.set_muted(true)
	game.hud.hide_menu(); game.hud.toast_time = 0.0
	game.weather.set_preset("clear"); game.weather.set_time_cycle(false)
	game.world.environment.sdfgi_enabled = false
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "auto" if timing else "native"
	game.display_settings.render_scale = 0.75 if timing else 1.0
	game.display_settings.frame_generation = false
	game.display_settings.fps_limit = 120
	var requested = Vector2i(3840,2160) if timing else Vector2i(1920,1080)
	game.display_settings.apply_display(root,requested)
	game.display_settings.apply_viewport(root)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	actual = root.get_texture().get_image().get_size()
	if actual!=requested: failures.append("Wrong output pixels: "+str(actual))
	if timing:
		await benchmark()
	else:
		await visual()
	if game.session.eligible: failures.append("Diagnostic must remain unranked")
	for path in source_hashes:
		if source_hashes[path]!=FileAccess.get_sha256("res://"+path): failures.append("Source changed during run: "+path)
	var report = {"failures":failures,"rows":rows,"captures":captures,"display":game.display_settings.report(root,actual),
		"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_driver_name(),"device":RenderingServer.get_video_adapter_name(),
		"generator":field.GENERATOR_ID,"seed":field.seed_value,"cache_hit":field.cache_hit,"generation_ms":field.generation_ms,
		"physics_model":game.sim.MODEL_VERSION,"source_hashes":source_hashes,"unranked":not game.session.eligible,"human_playtest":false,
		"scope":"Fixed mountain views and diagnostic reserve ramps; timing includes rendering and screen updates, not a full skiing workload",
		"capture_overhead_included":not timing,"world_build_ms":game.world.generation_ms}
	preload("res://tests/test_report.gd").write(OUT+("timing.json" if timing else "visual.json"),JSON.stringify(report,"\t"))
	print("IMPACT_WARNING_NATIVE ",JSON.stringify(report))
	game.active = false; game.effects.stop_audio(); game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func setup(site: String, close_view: bool, daylight: String) -> void:
	game.restart(); game.summit_ready = false; game.session.eligible = false
	var face = field.faces[3]
	var point: Vector2 = face.to_world(Vector2(0,550))
	if site=="forest":
		point = face.to_world(face.clearings[0].position)
	game.sim.reset(Vector3(point.x,field.sample(point.x,point.y).height,point.y),face.heading)
	game.sim.prime_contacts(game.field)
	game.sim.reset_pose_history(); game.skier.reset_animation(game.sim)
	game.camera.close_view = close_view; game.camera.effects_enabled = false
	game.camera.reset(); game.application_focused = true
	game.weather.set_time_of_day(daylight)
	game._process(DT)
	for i in 90:
		game.application_focused = true
		game._process(DT)
		await process_frame

func visual() -> void:
	for daylight in ["day","night"]:
		for close_view in [false,true]:
			await setup("forest",close_view,daylight)
			var prefix: String = daylight+("_first" if close_view else "_chase")
			for reserve in [0.7,0.6,0.5,0.4,0.3,0.1]:
				game.sim.impacts.reserve = reserve
				game.camera.effects_enabled = true
				game.camera.motion_intensity = 0.0
				game._update_screen_effects(3.0)
				# Matched peak and trough exposures make the pulse range reviewable.
				for phase in [0.0,0.5]:
					game.impact_warning.phase = phase
					game._update_screen_effects(0.0)
					game.hud.update_hud(game.sim,game.session,game.intent,"Diagnostic",0,0,0,false)
					await capture(prefix+"_%02d_"%roundi(reserve*100)+("trough" if phase==0 else "peak"))
			game.camera.effects_enabled = false
			game._update_screen_effects(DT)
			await capture(prefix+"_steady")
			game.camera.effects_enabled = true
			# A six-second continuous warning/recovery sequence at 30 saved FPS.
			var folder = OUT+prefix+"_sequence/"
			DirAccess.make_dir_recursive_absolute(folder)
			game.impact_warning.reset()
			for frame in 180:
				var time: float = frame/30.0
				game.sim.impacts.reserve = lerpf(0.7,0.02,minf(time/2.0,1.0)) if time<3.0 else lerpf(0.02,0.9,minf((time-3.0)/3.0,1.0))
				game._update_screen_effects(1.0/30.0)
				game.hud.update_hud(game.sim,game.session,game.intent,"Diagnostic",0,0,0,false)
				await process_frame; await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg(folder+"%04d.jpg"%frame,0.9)
			for i in 600: game._update_screen_effects(DT)
			await capture(prefix+"_recovered")
			rows.append({"view":prefix,"sequence_seconds":6.0,"saved_fps":30,"final_strength":game.impact_warning.strength})
			print("IMPACT_WARNING_VIEW ",prefix)

func capture(id: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	var path = OUT+id+".png"
	root.get_texture().get_image().save_png(path)
	captures.append({"id":id,"path":path,"reserve":game.sim.impacts.reserve,"strength":game.impact_warning.strength,"pulse":game.impact_warning.pulse})

func benchmark() -> void:
	for site in ["open","forest"]:
		await setup(site,false,"day")
		# Reverse order on the second pair to expose warmup/order bias.
		for index in 4:
			var enabled: bool = index in [1,2]
			game.sim.impacts.reserve = 0.01 if enabled else 1.0
			game.impact_warning.reset()
			game.camera.effects_enabled = true
			game.camera.motion_intensity = 0.0
			for i in 180:
				game.application_focused = true
				game._update_screen_effects(1.0/120.0)
				await process_frame
			var frames: Array[float] = []
			var cpu: Array[float] = []
			var gpu: Array[float] = []
			var peak_video = 0.0
			var peak_static = 0.0
			var last = Time.get_ticks_usec()
			for i in 600:
				game.application_focused = true
				game._update_screen_effects(1.0/120.0)
				await process_frame
				var now = Time.get_ticks_usec()
				frames.append((now-last)/1000.0); last = now
				var rid = root.get_viewport_rid()
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
				peak_video = maxf(peak_video,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
				peak_static = maxf(peak_static,Performance.get_monitor(Performance.MEMORY_STATIC))
			var row = {"site":site,"enabled":enabled,"repeat":index,"frame_ms":stats(frames),"gpu_ms":stats(gpu),"render_cpu_ms":stats(cpu),"peak_video_bytes":peak_video,"peak_engine_static_bytes":peak_static}
			rows.append(row)
			print("IMPACT_WARNING_TIMING ",JSON.stringify(row))
	# Composition inspection happens after every timing window has finished.
	game.sim.impacts.reserve = 0.1
	game.camera.motion_intensity = 0.6
	game._update_screen_effects(3.0)
	game.impact_warning.phase = 0.5
	game._update_screen_effects(0.0)
	game.hud.update_hud(game.sim,game.session,game.intent,"Diagnostic",0,0,0,false)
	await capture("combined_speed_warning_4k")

func stats(values: Array[float]) -> Dictionary:
	var ordered = values.duplicate(); ordered.sort()
	var total = 0.0
	for value in values: total += value
	return {"mean":total/values.size(),"p95":ordered[int(values.size()*0.95)],"p99":ordered[int(values.size()*0.99)],"count":values.size()}
