extends SceneTree
## Rendered, unranked review; captures and screenshot-free paired GPU samples.
const OUTPUT = "res://artifacts/race_beams_central"
const Beams = preload("res://scripts/presentation/race_beams.gd")
var game
var camera: Camera3D
var race
var failures: Array[String] = []
var captures: Array = []
var measurements: Array = []
var sources: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for path in ["scripts/presentation/race_beams.gd","assets/graphics/race_beam.gdshader","assets/graphics/race_beam_base.gdshader","scripts/racing/race_workshop.gd","scripts/world/alpine_world.gd","scripts/main.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	root.borderless = true
	root.size = Vector2i(3840,2160)
	root.position = Vector2i.ZERO
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	current_scene = game
	while not game.initialized: await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.preferences_enabled = false
	game.active = false
	game.effects.muted = true
	game.voice.set_muted(true)
	game.display_settings.apply_display(root,Vector2i(3840,2160))
	check(game.field.GENERATOR_VERSION==15 and game.field.seed_value==849205174,"Review uses the validated default v15 mountain")
	race = game.workshop.suggested_race
	check(race!=null,"The current mountain supplies a valid race")
	if race==null: game.free(); quit(1); return
	game.workshop.open_library()
	game.workshop.show_race(race)
	camera = game.workshop.survey
	game.workshop.focus_point = race.start.lerp(race.finish,.5)
	game.workshop.survey_height = 650.0
	game.workshop._update_survey()
	await capture("library_overhead")
	game.workshop.begin_creation()
	game.workshop.place_point(race.start)
	game.workshop.place_point(race.finish)
	await capture("authoring_overhead")
	if "--survey-only" in OS.get_cmdline_user_args():
		FileAccess.open(OUTPUT+"/survey_review.json",FileAccess.WRITE).store_string(JSON.stringify({
			"failures":failures,"captures":captures,"source_sha256":sources,"version":game.field.GENERATOR_VERSION,
			"note":"Corrected survey-camera captures supplement report.json"},"\t"))
		game.effects.stop_audio()
		game.free()
		quit(0 if failures.is_empty() else 1)
		return
	game.workshop.back_pressed()
	await game.play_custom_race(race)
	game.active = false
	game.session.eligible = false
	check(game.world.ski_surface.groups.size()-game.world.flavor.props.size()==2,"Active race retains exactly two collidable arches")
	# Exercise the real presentation dispatch before switching to a fixed camera.
	var active_beam = game.workshop.markers.get_node("FinishBeam")
	var clock_before: float = active_beam.visual_time
	game.active = true
	game._process(0.1)
	check(active_beam.visual_time>clock_before,"Racing advances the central beam VFX through normal presentation")
	game.active = false
	clock_before = active_beam.visual_time
	game._process(0.1)
	check(active_beam.visual_time==clock_before,"Pausing the race freezes its beam motion")
	game.hud.feedback.reduced_motion = true
	game.active = true
	game._process(0.1)
	check(active_beam.visual_time==clock_before and active_beam.motion_reduced,"Reduced Motion keeps the beacon steady")
	game.hud.feedback.reduced_motion = false
	game.active = false
	var review_camera = Camera3D.new()
	review_camera.far = 32000.0
	review_camera.fov = 68.0
	game.add_child(review_camera)
	camera = review_camera
	camera.current = true
	game.hud.root.hide()
	game.skier.hide()
	game.speed_periphery.hide()
	game.vectors.hide()
	PhysicsServer3D.set_active(false)
	set_weather("clear","day")
	if "--base-only" in OS.get_cmdline_user_args():
		var base_camera: Vector3 = race.finish+Basis(Vector3.UP,race.finish_heading)*Vector3(12,18,-20)
		base_camera.y = maxf(base_camera.y,game.field.sample(base_camera.x,base_camera.z).height+10.0)
		view(base_camera,race.finish+Vector3.UP*1.5)
		await capture("base_day")
		set_weather("clear","dusk")
		await capture("base_dusk")
		game.display_settings.apply_display(root,Vector2i(1920,1080))
		await motion_clip("base_motion")
		FileAccess.open(OUTPUT+"/base_review.json",FileAccess.WRITE).store_string(JSON.stringify({
			"failures":failures,"captures":captures,"source_sha256":sources,"clip_pixels":[1920,1080]},"\t"))
		game.effects.stop_audio()
		game.free()
		quit(0 if failures.is_empty() else 1)
		return
	close_view(race.start,race.heading)
	await capture("start_close")
	close_view(race.finish,race.finish_heading)
	await capture("finish_close")
	game.display_settings.apply_display(root,Vector2i(1920,1080))
	await motion_clip("motion")
	game.display_settings.apply_display(root,Vector2i(3840,2160))
	var basis = Basis(Vector3.UP,race.finish_heading)
	for offset in [-4.0,0.0,4.0]:
		var p: Vector3 = race.finish+basis*Vector3(0,0,offset)
		p.y = game.field.sample(p.x,p.z).height+1.7
		view(p,p+basis*Vector3(0,0,20))
		await capture("passage_%s" % str(offset).replace("-","minus"))
	for distance_m in [500.0,2000.0]:
		var p = distant_position(race.finish,distance_m,false)
		view(p,race.finish+Vector3.UP*230.0)
		await capture("finish_%dm" % int(distance_m))
	var ridge = distant_position(race.finish,850.0,true)
	check(not ridge.is_zero_approx(),"Found a real ridge hiding the base while exposing the upper beam")
	if not ridge.is_zero_approx():
		view(ridge,race.finish+Vector3.UP*260.0)
		await capture("ridge_occlusion")
	for level in [0,1,2]:
		game.set_graphics_quality(level)
		for setting in [["clear","day"],["clear","dusk"],["clear","night"],["snowfall","day"]]:
			set_weather(setting[0],setting[1])
			view(distant_position(race.finish,500.0,false),race.finish+Vector3.UP*230.0)
			await capture("%s_%s_%s" % [game.graphics.label().to_lower(),setting[0],setting[1]])
	game.set_graphics_quality(2)
	set_weather("clear","day")
	if "--views-only" not in OS.get_cmdline_user_args():
		for near_gate in [true,false]:
			if near_gate: close_view(race.finish,race.finish_heading)
			else: view(distant_position(race.finish,500.0,false),race.finish+Vector3.UP*230.0)
			# ABBA controls drift without mixing image readback into frame samples.
			for enabled in [true,false,false,true]:
				for marker in game.workshop.markers.get_children():
					if marker is Beams: marker.visible = enabled
				var sample = await measure()
				sample.beams = enabled
				sample.view = "near_gate" if near_gate else "500m"
				measurements.append(sample)
				print("BEAM_SAMPLE ",JSON.stringify(sample))
	game.restart()
	game.active = false
	game.session.eligible = false
	game.workshop.show_race(race)
	check(game.world.ski_surface.groups.size()-game.world.flavor.props.size()==2,"Retry retains one collidable gate pair")
	game.start_run(false)
	game.active = false
	game.session.eligible = false
	check(game.workshop.markers.get_child_count()==0,"Free skiing removes all race visuals")
	check(game.world.ski_surface.groups.size()==game.world.flavor.props.size(),"Free skiing removes only race collision")
	for path in sources:
		check(FileAccess.get_sha256("res://"+path)==sources[path],"Reviewed source stayed unchanged: "+path)
	var actual = root.get_texture().get_image().get_size()
	check(actual==Vector2i(3840,2160),"Captured output is exactly 3840x2160")
	var report = {"failures":failures,"captures":captures,"measurements":measurements,"source_sha256":sources,
		"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),
		"display":game.display_settings.report(root,actual),"unranked":not game.session.eligible,
		"seed":game.field.seed_value,"version":game.field.GENERATOR_VERSION,
		"height_sha256":game.field.height_checksum,"obstacle_sha256":game.field.obstacle_checksum,
		"scope":"Fixed real-mountain views with animated beam VFX; no screenshots in timing intervals"}
	FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RACE_BEAMS_RESULT ",JSON.stringify({"failures":failures,"captures":captures.size(),"measurements":measurements.size()}))
	game.effects.stop_audio()
	game.free()
	quit(0 if failures.is_empty() else 1)

func view(position: Vector3, target: Vector3) -> void:
	camera.global_position = position
	camera.look_at(target)
	camera.current = true
	game.display_settings.reset_history()

func close_view(point: Vector3, yaw: float) -> void:
	var p = point+Basis(Vector3.UP,yaw)*Vector3(12,3,-27)
	p.y = maxf(p.y,game.field.sample(p.x,p.z).height+2.0)
	view(p,point+Vector3.UP*4.0)

func set_weather(preset: String, period: String) -> void:
	game.weather.set_preset(preset)
	game.weather.set_time_of_day(period)
	game.world.update_weather(game.weather.state,0.0,false)

func visible_segment(origin: Vector3, target: Vector3) -> bool:
	for i in range(1,80):
		var p = origin.lerp(target,float(i)/80.0)
		if game.field.sample(p.x,p.z).height>p.y: return false
	return true

func distant_position(point: Vector3, distance_m: float, require_ridge: bool) -> Vector3:
	var best = Vector3.ZERO
	var best_score = -1
	for i in 48:
		var direction = Vector2.from_angle(TAU*float(i)/48.0)
		var p = point+Vector3(direction.x,0,direction.y)*distance_m
		if not game.field.ski_bounds().has_point(Vector2(p.x,p.z)): continue
		p.y = game.field.sample(p.x,p.z).height+2.0
		var base_visible = visible_segment(p,point+Vector3.UP*5.0)
		if require_ridge and base_visible: continue
		var score = 0
		for height in [100.0,400.0,700.0]:
			if visible_segment(p,point+Vector3.UP*height): score+=1
		if score>best_score and (not require_ridge or score>=2):
			best_score = score
			best = p
	return best

func capture(label: String) -> void:
	# Main's presentation-camera dispatch is paused during this static harness.
	camera.current = true
	for i in 60:
		call_group("race_beam_vfx","update_effect",1.0/60.0,true,false)
		game.weather_effects.update_weather(game.weather.state,camera,camera.position,game.field,1.0/60.0,false,true,0.0,game.weather.quality)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png")
	captures.append({"label":label,"camera":[camera.position.x,camera.position.y,camera.position.z]})
	print("BEAM_CAPTURE ",label)

func motion_clip(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT+"/"+folder)
	for i in 20: await process_frame
	for frame in 90:
		call_group("race_beam_vfx","update_effect",1.0/30.0,true,false)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT+"/"+folder+"/%03d.png" % frame)
	print("BEAM_MOTION_FRAMES ",folder," 90 at 30 fps")

func measure() -> Dictionary:
	var rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	game.display_settings.reset_history()
	for i in 180:
		call_group("race_beam_vfx","update_effect",1.0/120.0,true,false)
		await process_frame
	var frames: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var previous = Time.get_ticks_usec()
	for i in 600:
		call_group("race_beam_vfx","update_effect",1.0/120.0,true,false)
		await process_frame
		var now = Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0)
		previous = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	return {"frame_ms":game._timing_summary(frames),"render_cpu_ms":game._timing_summary(cpu),
		"gpu_ms":game._timing_summary(gpu),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"static_memory_bytes":OS.get_static_memory_usage(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
