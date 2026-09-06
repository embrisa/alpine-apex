extends SceneTree
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Pilot = preload("res://tests/showcase_pilot.gd")
const OUTPUT = "res://artifacts/technical_showcase_v6"
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
var segments = false
var captures = false
var peak_video_bytes = 0.0
var physics_us: Array[float] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--side="): side = int(arg.get_slice("=",1))
		if arg.begins_with("--weather="): weather = arg.get_slice("=",1)
	segments = "--segments" in OS.get_cmdline_user_args()
	views = "--views" in OS.get_cmdline_user_args()
	captures = "--captures" in OS.get_cmdline_user_args()
	pov_forest = "--pov-forest" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	field = Definition.generate(849205174,6)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Technical Showcase"),"field":field})
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_physics_process(false)
	game.set_graphics_quality(0)
	game.effects.muted = true
	game.weather.set_preset(weather)
	game.start_run(false)
	game.session.eligible = false
	game.summit_ready = false
	root.size = Vector2i(1440,900)
	await RenderingServer.frame_post_draw
	actual_pixels = root.get_texture().get_image().get_size()
	if views or segments:
		await inspect_views()
		game.queue_free()
		await process_frame
		quit()
		return
	var sim = game.sim
	sim.reset(field.launch_point(0),0)
	sim.prime_contacts(field)
	for i in 120: await process_frame
	process_frame.connect(_measure)
	recording = true
	var ticks = 0
	var input = RiderInput.new()
	for i in 120000:
		ticks = i+1
		if i%12==0: input = Pilot.intent(sim,field,side)
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
		if sim.crashed or field.reached_base(sim.position): break
	recording = false
	var result = {"generator_version":field.GENERATOR_VERSION,"finished":field.reached_base(sim.position),"crash":sim.crash_reason,"side":side,"seconds":ticks*Pilot.DT,"peak_kmh":sim.peak_speed*3.6,"airtime_s":sim.total_airtime,"position":str(sim.position),"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,
		"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"backend":RenderingServer.get_current_rendering_driver_name(),"actual_pixels":[actual_pixels.x,actual_pixels.y],"graphics":"Low","weather":weather,"weather_quality":game.weather.quality,"warmup_frames":120,"capture_overhead_included":captures,"frame_ms":timing(frames),"forest_frame_ms":timing(forest_frames),"pov_forest":pov_forest,"draw_calls":timing(draws),"physics_step_us":timing(physics_us),"peak_video_bytes":peak_video_bytes,"world_build_ms":game.world.generation_ms,"unranked":not game.session.eligible}
	FileAccess.open(OUTPUT+"/native_%d_%s.json" % [side,weather],FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SHOWCASE_NATIVE ",JSON.stringify(result))
	await capture("finish_%d_%s" % [side,weather])
	game.queue_free()
	await process_frame
	quit(0 if result.finished and result.crash.is_empty() else 1)

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
		for p in [Vector2(field.gully_x(600,-1),600),Vector2(field.gully_x(900,-1),900),Vector2(field.gully_x(1250,-1),1250),Vector2(field.glade_x(2170,-1),2170),Vector2(field.glade_x(2380,-1),2380)]:
			game.sim.reset(Vector3(p.x,field.sample(p.x,p.y).height,p.y),0)
			game.sim.prime_contacts(field)
			game.camera.reset()
			for close in [false,true]:
				game.camera.close_view = close
				await capture("%s_%d_%s" % [preset,p.y,"pov" if close else "chase"])
	game.camera.close_view = false

func capture(label: String) -> void:
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png")

func _measure() -> void:
	var now = Time.get_ticks_usec()
	if recording and previous_recording and last_frame>0:
		frames.append((now-last_frame)/1000.0)
		if game.sim.position.z>1900 and game.sim.position.z<2450: forest_frames.append((now-last_frame)/1000.0)
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
