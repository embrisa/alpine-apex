extends SceneTree
## Cached current-mountain UI, native visibility, bounded chronology and paired cost.
## --navigation-smoke narrows the matrix; --navigation-views-only skips timing.
## --navigation-preflight-only reuses the lower finish fixture before any Main load.
const OUTPUT = "res://artifacts/session_navigation_render_verified"
const Checks = preload("res://tests/session_navigation_checks.gd")
const Fixture = preload("res://tests/validation_mountain.gd")
const Mountain = preload("res://scripts/world/mountain_definition.gd")
const Race = preload("res://scripts/racing/race_definition.gd")
const PersonalBeams = preload("res://scripts/presentation/session_navigation_beams.gd")
var game
var audit = Checks.new()
var captures: Array = []
var samples: Array = []
var sources: Dictionary = {}
var markers: Array[Vector3] = []
var view_description: Dictionary = {}
var smoke: bool = false
var chronology: Dictionary = {}
var view_searches: Array = []
var view_cache: Dictionary = {}
var camera_settle_trace: Array = []

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	if "--navigation-preflight-only" in OS.get_cmdline_user_args():
		var preflight = load("res://tests/session_navigation_landmark_preflight.gd").new()
		await preflight.run(self)
		return
	smoke = "--navigation-smoke" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for path in ["scripts/main.gd","scripts/ui/hud.gd","scripts/ui/menu_navigation.gd","scripts/racing/race_workshop.gd","scripts/racing/session_navigation.gd","scripts/presentation/session_navigation_beams.gd","scripts/ui/session_navigation_panel.gd","scripts/ui/session_navigation_input.gd","scripts/ui/session_navigation_overlay.gd","scripts/presentation/race_beams.gd","assets/graphics/race_beam.gdshader","tests/session_navigation_playtest.gd","tests/session_navigation_checks.gd","scripts/presentation/chase_camera.gd","scripts/presentation/camera_settings.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	var field = Fixture.load_standard()
	if field==null: quit(2); return
	set_meta("test_lab_fixture",true)
	set_meta("mountain_to_load",{"definition":Mountain.from_field(field),"field":field})
	root.size = Vector2i(1920,1080)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.effects.haptic_hardware_enabled = false
	game.effects.muted = true
	game.voice.set_muted(true)
	game.preferences_enabled = false
	game.hud.feedback.persist = false
	game.hud.feedback.muted = true
	game.session.record_directory = OUTPUT+"/records"
	game.session.benchmark_path = OUTPUT+"/benchmark.json"
	game.session.eligible = false
	game.set_physics_process(false)
	game.set_process(false)
	game.active = false
	game.display_settings.frame_generation = false
	game.display_settings.apply_viewport(root)
	audit.check(field.cache_hit and field.GENERATOR_VERSION==15,"Native navigation uses a validated warm v15 Standard fixture")
	await audit.scene_checks(self,game)
	game.workshop.navigation_state.clear_points()
	markers = Checks.supported_points(game,32)
	if markers.size()!=32: audit.check(false,"32 native markers have supported anchors"); finish(); return
	populate(5)
	for resolution in ([Vector2i(1920,1080)] if smoke else [Vector2i(1920,1080),Vector2i(3840,2160)]):
		game.display_settings.apply_display(root,resolution)
		set_weather("clear","day")
		game.set_graphics_quality(2)
		game.workshop._clear_markers() # Match race-preview ownership across UI resolutions.
		view_description = {}
		game.hud.show_menu("paused")
		game.navigation._select_device(-1)
		game.workshop.open_navigation()
		game.workshop.focus_point = markers[2]
		game.workshop.survey_height = 340.0
		game._present_camera(0.0,game.sim.position)
		await capture("map_mouse_%d" % resolution.x)
		game.navigation._select_device(9001)
		game.workshop.navigation_panel.device_switched = false
		game.workshop.navigation_panel.begin_add()
		game._present_camera(0.0,game.sim.position)
		await capture("map_controller_reticle_%d" % resolution.x)
		game.workshop.navigation_panel.focus_panel()
		await capture("map_controller_panel_%d" % resolution.x)
		game.workshop.navigation_state.set_shown(false)
		await capture("map_hidden_edit_handles_%d" % resolution.x)
		game.workshop.navigation_state.set_shown(true)
		populate(32)
		game.workshop.navigation_panel.begin_add()
		await capture("map_limit_32_%d" % resolution.x)
		populate(5)
		game.workshop.leave_navigation()
		game.workshop.mode = "library" # Visual race preview, no collidable gate pair.
		game.workshop.show_race(game.workshop.suggested_race)
		game.workshop.mode = ""
		game.navigation._select_device(-1)
		game.hud.hide_menu()
		game.hud.root.hide()
		for level in ([2] if smoke else [0,1,2]):
			game.set_graphics_quality(level)
			game.display_settings.frame_generation = false
			game.display_settings.apply_viewport(root)
			for conditions in ([["clear","day"]] if smoke else [["clear","day"],["clear","night"],["snowfall","day"]]):
				set_weather(conditions[0],conditions[1])
				for distance in ([500.0] if smoke else [500.0,2000.0]):
					var found = find_view(markers[2],distance,false)
					audit.check(not found.is_empty(),"A settled, in-frame, terrain-clear %.0f m navigation preflight exists (pixels still require review)" % distance)
					if found.is_empty(): continue
					present_rider(found.position,markers[2])
					view_description.merge(found,true)
					audit.check(view_issues(shaft_probe(game.camera,markers[2]),false).is_empty(),"Final distance capture retains selection predicate")
					await capture("%d_%s_%s_%s_%dm" % [resolution.x,game.graphics.label(),conditions[0],conditions[1],int(distance)])
		game.hud.root.show()
	set_weather("clear","day")
	game.display_settings.apply_display(root,Vector2i(1920,1080))
	game.set_graphics_quality(2)
	game.hud.hide_menu()
	game.hud.root.hide()
	var ridge = find_view(markers[2],850.0,true)
	audit.check(not ridge.is_empty(),"A snow-supported ridge preflight hides the lower 100 m and exposes in-frame shaft samples")
	if not ridge.is_empty():
		present_rider(ridge.position,markers[2]); view_description.merge(ridge,true)
		audit.check(view_issues(shaft_probe(game.camera,markers[2]),true).is_empty(),"Final ridge capture retains selection predicate")
		await capture("ridge_natural_occlusion")
	for offset in [-12.0,-4.0,0.0,4.0,12.0]:
		var p = markers[2]+Vector3(0,0,offset)
		var anchored = Checks.Navigation.anchor(game.field,p)
		if not anchored.error.is_empty(): continue
		present_rider(anchored.position,anchored.position+Vector3(0,0,20),markers[2])
		await capture("close_passage_%s" % str(offset).replace("-","minus"))
	game.hud.root.show()
	await marked_descent()
	if not smoke and "--navigation-views-only" not in OS.get_cmdline_user_args():
		await cost_comparison()
	finish()

func populate(count: int) -> void:
	var model = game.workshop.navigation_state
	model.clear_points()
	for i in count: model.add_point(game.field,markers[i])
	model.set_shown(true)

func set_weather(preset: String, period: String) -> void:
	game.weather.set_automatic(false)
	game.weather.set_time_cycle(false)
	game.weather.set_preset(preset)
	game.weather.set_time_of_day(period)
	game.world.update_weather(game.weather.state,0.0,false)
	game.weather_effects.reset()

func present_rider(position: Vector3, target: Vector3, anchor: Vector3 = Vector3.INF) -> void:
	var heading = atan2(target.x-position.x,target.z-position.z)
	game.sim.reset(position,heading)
	game.sim.prime_contacts(game.field)
	game.skier.reset_animation(game.sim)
	game.previous_position = game.sim.position
	game.camera.reset()
	game.camera.close_view = false
	camera_settle_trace = []
	for frame in 60:
		game.camera.update_camera(game.sim,game.field,game.sim.position,1.0/60.0,false,false,false)
		if frame in [0,11,59]:
			camera_settle_trace.append({"frame":frame+1,"camera":vector(game.camera.global_position),
				"rotation":vector(game.camera.global_rotation),"fov":game.camera.fov})
	game.camera.make_current()
	game.presentation_camera = game.camera
	game.skier.pose(game.sim,1.0)
	game.display_settings.reset_history()
	if not anchor.is_finite(): anchor = target
	view_description = {"orientation_target":vector(target),"anchor":vector(anchor),
		"camera_to_base_m":game.camera.global_position.distance_to(anchor),
		"camera_settle_trace":camera_settle_trace.duplicate(true)}

func clear_segment(origin: Vector3, target: Vector3) -> bool:
	# At most one 4 m authority cell per sample, instead of 20 m gaps at 2 km.
	var steps = maxi(2,ceili(Vector2(origin.x-target.x,origin.z-target.z).length()/4.0))
	for i in range(1,steps):
		var p = origin.lerp(target,float(i)/steps)
		if game.field.sample(p.x,p.z).height>p.y: return false
	return true

func shaft_probe(camera: Camera3D, point: Vector3) -> Dictionary:
	var frame = root.get_visible_rect()
	var safe_frame = frame.grow(-frame.size.y*0.03)
	var in_frame: Array = []
	var exposed: Array = []
	var heights: Array = [4.0,8.0,12.0,16.0,20.0]
	heights.append_array(range(25,int(PersonalBeams.style().fade_start_m)+1,25))
	for height in heights:
		var sample = point+Vector3.UP*float(height)
		var depth = -camera.to_local(sample).z
		if depth<camera.near or depth>camera.far: continue
		if not safe_frame.has_point(camera.unproject_position(sample)): continue
		in_frame.append(height)
		if clear_segment(camera.global_position,sample): exposed.append(height)
	return {"in_frame_heights_m":in_frame,"terrain_clear_in_frame_heights_m":exposed,
		"base_terrain_clear":clear_segment(camera.global_position,point+Vector3.UP*4.0),
		"hundred_m_terrain_clear":clear_segment(camera.global_position,point+Vector3.UP*100.0),
		"note":"Geometric preflight only: heightfield LOS excludes tree/rock meshes, weather, alpha and rendered contrast. Pixel review remains required."}

func view_issues(probe: Dictionary, require_ridge: bool) -> Array[String]:
	var issues: Array[String] = []
	if probe.terrain_clear_in_frame_heights_m.size()<3:
		issues.append("shaft_outside_frustum" if probe.in_frame_heights_m.is_empty() else "insufficient_terrain_clear_samples")
	if require_ridge and (probe.base_terrain_clear or probe.hundred_m_terrain_clear):
		issues.append("ridge_lower_100m_not_hidden")
	return issues

func find_view(point: Vector3, distance: float, require_ridge: bool) -> Dictionary:
	var key = str([point,distance,require_ridge,root.get_visible_rect().size,game.camera_settings.profile("chase")])
	if view_cache.has(key): return view_cache[key].duplicate(true)
	var started = Time.get_ticks_msec()
	var best: Dictionary = {}
	var score = -1
	var rejections: Dictionary = {}
	var closest: Array = []
	var examined = 0
	for i in 64:
		if Time.get_ticks_msec()-started>10000: break
		examined += 1
		var direction = Vector2.from_angle(TAU*float(i)/64.0)
		var candidate = point+Vector3(direction.x,0,direction.y)*distance
		var anchored = Checks.Navigation.anchor(game.field,candidate)
		if not anchored.error.is_empty():
			rejections[anchored.error] = rejections.get(anchored.error,0)+1
			continue
		# Test observer safety only; personal marker placement keeps its own rules.
		var snow_error: String = Race.point_error(anchored.position,game.field)
		if not snow_error.is_empty():
			rejections[snow_error] = rejections.get(snow_error,0)+1
			continue
		present_rider(anchored.position,point)
		var probe = shaft_probe(game.camera,point)
		var issues = view_issues(probe,require_ridge)
		var next_score: int = probe.terrain_clear_in_frame_heights_m.size()
		if not issues.is_empty():
			for issue in issues: rejections[issue] = rejections.get(issue,0)+1
			closest.append({"position":vector(anchored.position),"score":next_score,"issues":issues,
				"probe":probe,"camera":camera_snapshot(game.camera)})
			closest.sort_custom(func(a,b): return a.score>b.score)
			if closest.size()>3: closest.resize(3)
			continue
		if next_score>score:
			score = next_score
			best = {"position":anchored.position,"anchor":vector(point),"horizontal_distance_m":distance,
				"selection_probe":probe,"ridge_required":require_ridge,
				"scope":"Stationary production chase, 60 updates settled; no upward aim or lens override"}
	view_searches.append({"anchor":vector(point),"distance_m":distance,"ridge":require_ridge,
		"examined":examined,"rejections":rejections,"closest_rejected":closest,"selected":best.duplicate(true),
		"milliseconds":Time.get_ticks_msec()-started,"budget_exhausted":examined<64})
	view_cache[key] = best.duplicate(true)
	return best

func camera_snapshot(camera: Camera3D) -> Dictionary:
	return {"camera":vector(camera.global_position),"rider":vector(game.sim.position),
		"camera_basis":[vector(camera.global_basis.x),vector(camera.global_basis.y),vector(camera.global_basis.z)],
		"fov":camera.fov,"projection":camera.projection,"near_m":camera.near,"far_m":camera.far,
		"keep_aspect":camera.keep_aspect,"orthographic_size":camera.size,
		"viewport_size":vector(Vector3(root.get_visible_rect().size.x,root.get_visible_rect().size.y,0)),
		"camera_profile":game.camera_settings.profile("chase")}

func capture_view() -> Dictionary:
	var camera: Camera3D = root.get_camera_3d()
	audit.check(camera==game.presentation_camera,"Capture uses the active presentation camera")
	var result: Dictionary = {} if game.workshop.mode=="navigation" else view_description.duplicate(true)
	result.merge(camera_snapshot(camera),true)
	result.personal_points = []
	result.shown = game.workshop.navigation_state.shown
	result.style = PersonalBeams.style()
	result.geometrically_exposed_points = 0
	for entry in game.workshop.navigation_state.points():
		var probe = shaft_probe(camera,entry.position)
		if probe.terrain_clear_in_frame_heights_m.size()>=3: result.geometrically_exposed_points += 1
		result.personal_points.append({"id":entry.id,"anchor":vector(entry.position),"probe":probe,
			"camera_to_base_m":camera.global_position.distance_to(entry.position)})
	return result

func draw_frame(dt: float) -> void:
	call_group("race_beam_vfx","update_effect",dt,true,game.hud.feedback.reduced_motion)
	game.weather_effects.update_weather(game.weather.state,game.presentation_camera,game.sim.position,game.field,dt,false,true,0.0,game.graphics.weather_quality)
	await process_frame

func capture(label: String) -> void:
	for i in 20: await draw_frame(1.0/60.0)
	if game.workshop.mode=="navigation":
		game.workshop.navigation_panel.overlay.refresh()
		await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	image.save_png(OUTPUT+"/"+label+".png")
	captures.append({"label":label,"view":capture_view(),"pixels":[image.get_width(),image.get_height()],
		"weather":game.weather.state.label,"time":game.weather.state.time_label,"quality":game.graphics.label(),
		"points":game.workshop.navigation_state.count(),"display":game.display_settings.report(root,image.get_size())})
	print("NAVIGATION_CAPTURE ",label)

func marked_descent() -> void:
	game.hud.root.show()
	game.workshop.close()
	game.start_run(false)
	game.session.eligible = false
	if game.summit_ready: game.drop_from_summit()
	# Five successive landmarks along this bounded heading, not one cross-slope row.
	var model = game.workshop.navigation_state
	model.clear_points()
	model.set_shown(true)
	var basis = Basis(Vector3.UP,game.sim.heading)
	for ahead in [30.0,90.0,150.0,210.0,270.0]:
		for lateral in [0.0,-12.0,12.0]:
			var result = model.add_point(game.field,game.sim.position+basis*Vector3(lateral,0,ahead))
			if result.error.is_empty(): break
	audit.check(model.count()==5,"Bounded descent has five supported longitudinal landmarks")
	var retained = model.points()
	view_description = {}
	game.automated = true
	game.benchmark_input = func(_tick):
		var input = RiderInput.new()
		input.tuck = .55
		return input
	game.active = true
	var initial_tick: int = game.sim.ticks
	var frames: Array = []
	var stopped = "15 second bound"
	for tick in 1800:
		game._physics_process(1.0/120.0)
		if tick%2==0:
			game._process(1.0/60.0)
			await process_frame
		if tick%240==0:
			await RenderingServer.frame_post_draw
			var label = "descent_%04d" % tick
			root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png")
			frames.append({"tick":game.sim.ticks,"position":vector(game.sim.position),"camera":vector(game.camera.global_position),"capture":label,"view":capture_view()})
		if game.sim.crashed or not game.active:
			stopped = "crash" if game.sim.crashed else "session stopped"
			break
	audit.check(model.points()==retained,"Passing landmarks does not remove or move them")
	chronology = {"points":capture_view().personal_points,"ticks":game.sim.ticks-initial_tick,"seconds":float(game.sim.ticks-initial_tick)/120.0,"stop":stopped,"frames":frames,
		"scope":"Ordinary-input marked 15 s descent with periodic captures; not a screenshot-free performance sample"}
	game.active = false
	game.automated = false
	game.benchmark_input = Callable()

func cost_comparison() -> void:
	game.restart()
	game.active = false
	game.session.eligible = false
	game.hud.root.hide()
	game.display_settings.frame_generation = false
	game.display_settings.apply_viewport(root)
	for near in [true,false]:
		var found = find_view(markers[2],30.0 if near else 500.0,false)
		if found.is_empty(): audit.check(false,"Cost view has valid terrain"); continue
		present_rider(found.position,markers[2])
		var references: Dictionary = {}
		for count in [0,5,32]:
			populate(count)
			await capture("cost_reference_%s_%d" % ["near" if near else "far",count])
			references[count] = captures[-1].duplicate(true)
			if count>0:
				audit.check(references[count].view.geometrically_exposed_points>0,"Cost camera has an exposed navigation preflight; inspect reference pixels")
		for repetition in 3:
			# Paired forward/reverse count order controls drift at the same camera.
			for count in [0,5,32,32,5,0]:
				populate(count)
				var sample = await measure()
				sample.merge({"count":count,"near":near,"repetition":repetition,"reference":references[count].label,"view":references[count].view},true)
				samples.append(sample)
				print("NAVIGATION_TIMING ",JSON.stringify(sample))

func measure() -> Dictionary:
	var rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	game.display_settings.reset_history()
	for i in 60: await draw_frame(1.0/120.0)
	var frame: Array[float] = []
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var previous = Time.get_ticks_usec()
	for i in 240:
		await draw_frame(1.0/120.0)
		var now = Time.get_ticks_usec()
		frame.append(float(now-previous)/1000.0); previous = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
	return {"frames":240,"frame_ms":distribution(frame),"gpu_ms":distribution(gpu),"render_cpu_ms":distribution(cpu),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"display":game.display_settings.snapshot(),"frame_generation":false}

static func distribution(values: Array[float]) -> Dictionary:
	var sorted = values.duplicate()
	sorted.sort()
	var total = 0.0
	for value in values: total += value
	var mean = total/values.size()
	var variance = 0.0
	for value in values: variance += pow(value-mean,2.0)
	return {"mean":mean,"median":sorted[sorted.size()/2],"p95":sorted[int(sorted.size()*.95)],"stddev":sqrt(variance/values.size()),"min":sorted[0],"max":sorted[-1]}

static func vector(value: Vector3) -> Array: return [value.x,value.y,value.z]

func finish() -> void:
	for path in sources: audit.check(FileAccess.get_sha256("res://"+path)==sources[path],"Reviewed source remained unchanged: "+path)
	FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":audit.checks,"failures":audit.failures,
		"sources":sources,"view_searches":view_searches,"visual_acceptance":"pending actual pixel review","captures":captures,"samples":samples,"chronology":chronology,"engine":Engine.get_version_info(),
		"device":RenderingServer.get_video_adapter_name(),"mountain_identity":game.workshop.navigation_state.mountain_identity,
		"height_sha256":game.field.height_checksum,"obstacle_sha256":game.field.obstacle_checksum,
		"scope":"Native visibility and bounded diagnostic cost only; physical-controller comfort and route usefulness require user acceptance"},"\t"))
	game.effects.stop_audio()
	game.free()
	quit(0 if audit.failures.is_empty() else 1)
