extends SceneTree
## Matched native before/after rendering, real solver motion, never PB eligible.
const DT = 1.0/120.0
var game
var output = "res://artifacts/skier_animation/visual"
var clips = false
var benchmark = false
var captures: Array = []
var frame_number = 0
var label: Label
var requested = Vector2i(960,720)
var rows: Array = []
var animation_us: Array[float] = []
var pose_us: Array[float] = []
var frames: Array[float] = []
var render_cpu: Array[float] = []
var gpu: Array[float] = []
var peak_video = 0.0
var peak_static = 0.0
var last_frame = 0
var measuring = false
var scenario_hops = 0
var baseline_animation
func _initialize(): call_deferred("run")

func run():
	if DisplayServer.get_name()=="headless": quit(1); return
	clips = "--clips" in OS.get_cmdline_user_args()
	benchmark = "--timing" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="): output = argument.trim_prefix("--capture-output=")
		if argument.begins_with("--baseline-animation="):
			baseline_animation = load(argument.trim_prefix("--baseline-animation=")).new()
	if benchmark and baseline_animation:
		printerr("A saved animation baseline is for matched captures only; omit it for timing.")
		quit(2)
		return
	if benchmark: requested = Vector2i(3840,2160)
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.start_speed_lab(70)
	game.effects.muted = true
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	game.hud.hide()
	game.camera.effects_enabled = false
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "fsr2" if benchmark else "native"
	game.display_settings.render_scale = .75 if benchmark else 1.0
	game.display_settings.fps_limit = 120
	game.display_settings.apply_display(root,requested)
	game.display_settings.apply_viewport(root)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var overlay = CanvasLayer.new()
	root.add_child(overlay)
	label = Label.new()
	label.position = Vector2(24,18)
	label.add_theme_font_size_override("font_size",24)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	overlay.add_child(label)
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	var actual = root.get_texture().get_image().get_size()
	if actual!=requested: printerr("Pixel mismatch ",actual); quit(2); return
	if benchmark:
		process_frame.connect(measure_frame)
		for enabled in [false,true]:
			game.skier.animation_enabled = enabled
			label.text = "ATHLETIC SKIER / "+("ANIMATION" if enabled else "BASELINE")
			reset_rider(20.0)
			var intent = RiderInput.new()
			intent.tuck = .8
			for tick in range(240):
				advance(intent)
				game._process(DT)
				await physics_frame
			animation_us.clear(); pose_us.clear(); frames.clear(); render_cpu.clear(); gpu.clear()
			measuring = true
			for tick in range(1440):
				if tick%360==0: reset_rider(20.0)
				intent.steer = sin(tick*.016)*.5
				intent.jump_held = tick%360>=180 and tick%360<210
				intent.jump = tick%360==210
				advance(intent)
				var begin = Time.get_ticks_usec()
				game._process(DT)
				pose_us.append(Time.get_ticks_usec()-begin)
				await physics_frame
			measuring = false
			rows.append({"animation_enabled":enabled,"frame_ms":stats(frames),"render_cpu_ms":stats(render_cpu),"gpu_ms":stats(gpu),"animation_step_us":stats(animation_us),"all_presentation_us":stats(pose_us)})
			print("ANIMATION_TIMING ",JSON.stringify(rows[-1]))
	else:
		for scenario in ["tuck","carve","hop","small_landing","medium_landing","large_landing"]:
			reset_rider(520.0 if scenario in ["tuck","carve"] else 20.0)
			var intent = RiderInput.new()
			var count = 75 if clips else 90
			if scenario.ends_with("landing"):
				var speed = 2.0 if scenario=="small_landing" else (6.0 if scenario=="medium_landing" else 12.0)
				var p: Vector3 = game.sim.position+Vector3.UP*.4
				game.sim.reset(p)
				game.sim.prime_contacts(game.field)
				var normal: Vector3 = game.field.sample(p.x,p.z).normal
				game.sim.velocity = Vector3.BACK.slide(normal).normalized()*12-normal*speed
				game.skier.reset_animation(game.sim)
				if baseline_animation: baseline_animation.reset(game.sim)
			for frame in range(count):
				intent.tuck = 1.0 if scenario=="tuck" else (.4 if scenario=="carve" else 0.0)
				intent.steer = (.75 if frame<40 else -.75) if scenario=="carve" else (sin(frame*.12)*.4 if scenario=="hop" and frame>30 else 0.0)
				intent.jump_held = scenario=="hop" and frame>=10 and frame<25
				for substep in range(4):
					intent.jump = scenario=="hop" and frame==25 and substep==0
					advance(intent)
				game._process(1.0/30.0)
				var key = ""
				if scenario=="tuck" and frame==65: key = "tuck"
				if scenario=="carve" and frame==30: key = "carve"
				if scenario=="hop" and frame in [23,28,35,42]: key = "hop_%02d"%frame
				if scenario.ends_with("landing") and frame in [4,8,12]: key = scenario+"_%02d"%frame
				if clips or not key.is_empty(): await capture_views(scenario,key)
				frame_number += 1
			rows.append({"scenario":scenario,"impact_speed_mps":game.skier.animation.landing_speed,"events":game.skier.animation.landing_events,"executed_hops":scenario_hops,"crashed":game.sim.crashed})
	var report = {"unranked":not game.session.eligible,"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"display":game.display_settings.report(root,actual),"cases":rows,"captures":captures,"peak_video_bytes":peak_video,"peak_engine_static_bytes":peak_static,"capture_overhead_included":false,"scope":"12 second laboratory motion loops" if benchmark else "real-solver motion with controlled starting conditions","clip_fps":30}
	report.baseline_animation = baseline_animation.get_script().resource_path if baseline_animation else "physical pose only"
	preload("res://tests/test_report.gd").write(output+("/performance.json" if benchmark else "/captures.json"),JSON.stringify(report,"\t"))
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	quit()

func reset_rider(z: float = 520.0):
	var p = Vector3(0,game.field.sample(0,z).height,z)
	game.sim.reset(p)
	game.sim.prime_contacts(game.field)
	game.sim.velocity = game.sim.support_basis().z*18.0
	game.skier.reset_animation(game.sim)
	if baseline_animation: baseline_animation.reset(game.sim)
	game.camera.reset()
	game.previous_position = game.sim.position
	scenario_hops = 0

func advance(intent):
	game.sim.step(DT,intent,game.field)
	if game.sim.jump_executed: scenario_hops += 1
	var begin = Time.get_ticks_usec()
	if not benchmark or game.skier.animation_enabled: game.skier.step_animation(DT,game.sim,intent,game.field)
	if baseline_animation: baseline_animation.step(DT,game.sim,intent,game.field)
	if measuring: animation_us.append(Time.get_ticks_usec()-begin)
	game.intent = intent
	game.session.elapsed += DT
	game.previous_position = game.sim.position

func capture_views(scenario: String, key: String):
	var animation = game.skier.animation
	for view in ["chase","side","front"]:
		for enabled in [false,true]:
			var variant = "after" if enabled else "before"
			game.skier.animation_enabled = enabled or baseline_animation!=null
			game.skier.animation = baseline_animation if not enabled and baseline_animation!=null else animation
			game.skier.pose(game.sim,1.0)
			var center: Vector3 = game.skier.to_global(Vector3(0,.8,0))
			var offset = Vector3(0,1.2,-5.8) if view=="chase" else (Vector3(3.3,.4,0) if view=="side" else Vector3(.15,.5,3.4))
			game.camera.position = center+game.skier.basis*offset
			game.camera.look_at(center)
			label.text = "%s / %s / %s"%[variant.to_upper(),scenario.replace("_"," ").to_upper(),view.to_upper()]
			await process_frame
			await RenderingServer.frame_post_draw
			var picture = root.get_texture().get_image()
			if clips:
				var folder = output+"/"+variant+"_"+view
				DirAccess.make_dir_recursive_absolute(folder)
				picture.save_jpg(folder+"/%04d.jpg"%frame_number,.88)
			if not key.is_empty():
				var name = variant+"_"+key+"_"+view+".png"
				picture.save_png(output+"/"+name)
				captures.append(name)
	game.skier.animation_enabled = true
	game.skier.animation = animation

func measure_frame():
	var now = Time.get_ticks_usec()
	if measuring and last_frame>0:
		frames.append((now-last_frame)/1000.0)
		var rid = root.get_viewport_rid()
		render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		peak_video = maxf(peak_video,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		peak_static = maxf(peak_static,Performance.get_monitor(Performance.MEMORY_STATIC))
	last_frame = now

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var sorted = values.duplicate()
	sorted.sort()
	var total = 0.0
	for value in values: total += value
	return {"mean":total/values.size(),"p95":sorted[mini(sorted.size()-1,int(sorted.size()*.95))],"p99":sorted[mini(sorted.size()-1,int(sorted.size()*.99))],"max":sorted[-1],"count":values.size()}
