extends SceneTree
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Pilot = preload("res://tests/showcase_pilot.gd")
var OUTPUT = "res://artifacts/pc_environment/native"
var version = 7
var requested_pixels = Vector2i(3840,2160)
var start_z = 0
var end_z = 2850
var gpu_ms: Array[float] = []
var render_cpu_ms: Array[float] = []
var segment_frames: Dictionary = {}
var inspection_captures: Array = []
var game
var field
var frames: Array[float] = []
var forest_frames: Array[float] = []
var pov_forest = false
var draws: Array[float] = []
var recording = false
var last_frame = 0
var previous_recording = false
var actual_pixels = Vector2i.ZERO
var side = -1
var weather = "clear"
var views = false
var motion = false
var segments = false
var captures = false
var peak_video_bytes = 0.0
var physics_us: Array[float] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--version="): version = int(arg.get_slice("=",1))
		if arg.begins_with("--benchmark-start="): start_z = clampi(int(arg.get_slice("=",1)),0,2400)
		if arg.begins_with("--benchmark-end="): end_z = clampi(int(arg.get_slice("=",1)),2450,2850)
		if arg.begins_with("--benchmark-label="): OUTPUT = "res://artifacts/pc_environment/"+arg.get_slice("=",1).validate_filename()
		if arg.begins_with("--benchmark-resolution="):
			var dimensions = arg.get_slice("=",1).split("x")
			if dimensions.size()==2: requested_pixels = Vector2i(int(dimensions[0]),int(dimensions[1]))
		if arg.begins_with("--side="): side = int(arg.get_slice("=",1))
		if arg.begins_with("--weather="): weather = arg.get_slice("=",1)
	segments = "--segments" in OS.get_cmdline_user_args()
	views = "--views" in OS.get_cmdline_user_args()
	motion = "--motion" in OS.get_cmdline_user_args()
	captures = "--captures" in OS.get_cmdline_user_args()
	pov_forest = "--pov-forest" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	field = Definition.generate(849205174,version)
	if field==null: quit(2); return
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Technical Showcase"),"field":field})
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_physics_process(false)
	game.effects.muted = true
	game.weather.set_preset(weather)
	game.start_run(false)
	game.session.eligible = false
	game.summit_ready = false
	game.display_settings.apply_display(root,requested_pixels)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	actual_pixels = root.get_texture().get_image().get_size()
	if actual_pixels!=requested_pixels:
		printerr("Output pixels do not match request: ",actual_pixels," vs ",requested_pixels)
		quit(2)
		return
	if views or segments or motion:
		if views or segments: await inspect_views()
		if motion: await inspect_motion()
		var views_report = {"version":version,"display":game.display_settings.report(root,actual_pixels),"captures":inspection_captures,"unranked":not game.session.eligible}
		FileAccess.open(OUTPUT+"/views.json",FileAccess.WRITE).store_string(JSON.stringify(views_report,"\t"))
		game.queue_free()
		await process_frame
		quit()
		return
	var sim = game.sim
	sim.reset(field.launch_point(0),0)
	sim.prime_contacts(field)
	if start_z>0:
		var x = field.glade_x(start_z,side) if start_z>1850 else field.gully_x(start_z,side)
		sim.reset(Vector3(x,field.sample(x,start_z).height,start_z),0)
		sim.prime_contacts(field)
		sim.velocity = Vector3.BACK.slide(field.contact_normal(x,start_z)).normalized()*12.0
	for i in 120: await process_frame
	process_frame.connect(_measure)
	recording = true
	var ticks = 0
	var input = RiderInput.new()
	for i in 120000:
		ticks = i+1
		if i%12==0: input = Pilot.intent(sim,field,side)
		if i%2400==0: print("SHOWCASE_PROGRESS tick=",i," z=",snappedf(sim.position.z,.1)," kmh=",snappedf(sim.speed_kmh(),.1))
		game.intent = input
		await physics_frame
		var begin = Time.get_ticks_usec()
		sim.step(Pilot.DT,input,field)
		physics_us.append(Time.get_ticks_usec()-begin)
		game.session.elapsed += Pilot.DT
		if captures or pov_forest:
			game.camera.close_view = sim.position.z>1900 and sim.position.z<2450
		if captures and i%2400==0:
			await capture("ride_%d_%d" % [side,i])
		if sim.crashed or field.reached_base(sim.position) or (end_z<2850 and sim.position.z>=end_z): break
	recording = false
	var result = {"generator_version":field.GENERATOR_VERSION,"finished":field.reached_base(sim.position),"crash":sim.crash_reason,"side":side,"seconds":ticks*Pilot.DT,"peak_kmh":sim.peak_speed*3.6,"airtime_s":sim.total_airtime,"position":str(sim.position),"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,
		"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"backend":RenderingServer.get_current_rendering_driver_name(),"actual_pixels":[actual_pixels.x,actual_pixels.y],"graphics":game.graphics.label(),"display":game.display_settings.report(root,actual_pixels),"render_gpu_ms":timing(gpu_ms),"render_cpu_ms":timing(render_cpu_ms),"weather":weather,"weather_quality":game.weather.quality,"warmup_frames":120,"capture_overhead_included":captures,"frame_ms":timing(frames),"forest_frame_ms":timing(forest_frames),"pov_forest":pov_forest,"draw_calls":timing(draws),"physics_step_us":timing(physics_us),"peak_video_bytes":peak_video_bytes,"world_build_ms":game.world.generation_ms,"unranked":not game.session.eligible}
	result.segments = {}
	result.scope = "full_descent" if start_z==0 and end_z==2850 else "section_probe"
	result.section_completed = sim.position.z>=end_z if end_z<2850 else result.finished
	result.generation_ms = field.generation_ms
	result.background_workload = "Existing applications left untouched; see actual process samples in system.json. WoW no longer required."
	result.frame_ms = frame_timing(frames)
	result.forest_frame_ms = frame_timing(forest_frames)
	for segment in segment_frames: result.segments[segment] = timing(segment_frames[segment])
	FileAccess.open(OUTPUT+"/native_%d_%s.json" % [side,weather],FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SHOWCASE_NATIVE ",JSON.stringify(result))
	await capture("finish_%d_%s" % [side,weather])
	game.queue_free()
	await process_frame
	quit(0 if result.section_completed and result.crash.is_empty() else 1)

func inspect_views() -> void:
	game.active = false
	await game.mountain_library.open()
	await capture("library")
	game.mountain_library.close()
	game.hud.root.hide()
	var observer = Camera3D.new()
	game.add_child(observer)
	observer.far = 15000
	observer.make_current()
	for view in [
		{"name":"face","focus":Vector2(0,1400),"offset":Vector3(1250,1250,1500)},
		{"name":"ridge","focus":Vector2(0,650),"offset":Vector3(270,260,390)},
		{"name":"rock_band","focus":Vector2(0,1370),"offset":Vector3(340,230,360)},
		{"name":"drop","focus":Vector2(0,1770),"offset":Vector3(65,70,130)},
		{"name":"forest","focus":Vector2(-320,2210),"offset":Vector3(160,100,140)}]:
		var focus = Vector3(view.focus.x,field.sample(view.focus.x,view.focus.y).height,view.focus.y)
		observer.position = focus+view.offset
		observer.look_at(focus)
		await capture(view.name)
	observer.queue_free()
	game.camera.make_current()
	for preset in ["clear","snowfall"]:
		game.weather.set_preset(preset)
		for p in [Vector2(field.gully_x(600,side),600),Vector2(field.gully_x(900,side),900),Vector2(field.gully_x(1250,side),1250),Vector2(field.glade_x(2170,side),2170),Vector2(field.glade_x(2380,side),2380)]:
			game.sim.reset(Vector3(p.x,field.sample(p.x,p.y).height,p.y),0)
			game.sim.prime_contacts(field)
			game.camera.reset()
			for close in [false,true]:
				game.camera.close_view = close
				await capture("%s_%d_%s" % [preset,p.y,"pov" if close else "chase"])
	for time in ["dawn","dusk","night"]:
		game.weather.set_preset("clear")
		game.weather.set_time_of_day(time)
		var p = Vector2(field.gully_x(1250,-1),1250)
		game.sim.reset(Vector3(p.x,field.sample(p.x,p.y).height,p.y),0)
		game.sim.prime_contacts(field)
		game.camera.close_view = false
		game.camera.reset()
		await capture(time+"_gully")
	game.weather.set_time_of_day("day")
	game.camera.close_view = false

func inspect_motion() -> void:
	# Inspection only: fixed 60 Hz presentation with real 120 Hz solver steps.
	# Readback/capture stalls are intentionally excluded from performance runs.
	game.active = true
	game.hud.root.hide()
	game.set_process(false)
	var clips = []
	for route in [-1,1]:
		for preset in ["clear","snowfall"]:
			game.weather.set_preset(preset)
			for section in ([2170] if "--motion-forest" in OS.get_cmdline_user_args() else [900,1370,1756,2170]):
				for close in [false,true]:
					var x = 0.0 if section==1756 else (field.glade_x(section,route) if section>1900 else field.gully_x(section,route))
					game.sim.reset(Vector3(x,field.sample(x,section).height,section),0)
					game.sim.prime_contacts(field)
					game.sim.velocity = Vector3.BACK.slide(field.contact_normal(x,section)).normalized()*18.0
					game.camera.close_view = close
					game.camera.reset()
					var label = "%s_%d_%d_%s" % [preset,route,section,"pov" if close else "chase"]
					for frame in 180:
						for tick in 2:
							game.intent = Pilot.intent(game.sim,field,route) if section!=1756 else RiderInput.new()
							game.sim.step(Pilot.DT,game.intent,field)
						game._process(1.0/60.0)
						await process_frame
						if frame in [30,31,32,60,90,120,179]: await capture(label+"_%03d" % frame,0)
					clips.append({"clip":label,"crash":game.sim.crash_reason,"position":str(game.sim.position),"duration_s":3.0,"airtime_s":game.sim.total_airtime})
	FileAccess.open(OUTPUT+"/motion.json",FileAccess.WRITE).store_string(JSON.stringify({"clips":clips,"physics_hz":120,"presentation_hz":60,"capture_overhead":true,"frames_per_clip":[30,31,32,60,90,120,179]},"\t"))

func capture(label: String, settle_frames: int = 30) -> void:
	for i in settle_frames: await process_frame
	await RenderingServer.frame_post_draw
	var picture = root.get_texture().get_image()
	if motion: picture.save_jpg(OUTPUT+"/"+label+".jpg",.97)
	else: picture.save_png(OUTPUT+"/"+label+".png")
	inspection_captures.append(label)

func _measure() -> void:
	var now = Time.get_ticks_usec()
	if recording and previous_recording and last_frame>0:
		frames.append((now-last_frame)/1000.0)
		if game.sim.position.z>1900 and game.sim.position.z<2450: forest_frames.append((now-last_frame)/1000.0)
		var section = "upper_gully" if game.sim.position.z<1100 else ("cliff_band" if game.sim.position.z<1700 else ("forest" if game.sim.position.z>1900 and game.sim.position.z<2450 else "apron"))
		if not segment_frames.has(section): segment_frames[section] = [] as Array[float]
		segment_frames[section].append((now-last_frame)/1000.0)
		var gpu = RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		var cpu = RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		if gpu>0: gpu_ms.append(gpu)
		if cpu>0: render_cpu_ms.append(cpu)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		peak_video_bytes = maxf(peak_video_bytes,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	previous_recording = recording
	last_frame = now

func timing(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"available":false}
	values.sort()
	var total = 0.0
	for value in values: total += value
	var slow_count = maxi(1,ceili(values.size()*.01))
	var slow_sum = 0.0
	for i in range(values.size()-slow_count,values.size()): slow_sum += values[i]
	return {"samples":values.size(),"mean":total/values.size(),"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)],"slowest_one_percent_mean":slow_sum/slow_count}

func frame_timing(values: Array[float]) -> Dictionary:
	var result = timing(values)
	if result.has("mean"):
		result.average_fps = 1000.0/result.mean
		result.slowest_one_percent_fps = 1000.0/result.slowest_one_percent_mean
	return result
