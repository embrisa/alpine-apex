extends "res://tests/snow_readability_playtest.gd"
## Current production scene, changing only the crystal sampler within each pair.
## --timing: three interleaved 15 s ordinary-input pairs, uncapped and capture-free.
const Mountain = preload("res://tests/validation_mountain.gd")
const RoundReference = "res://tests/fixtures/snow_crystal_round_reference.gdshaderinc"
const CrystalPath = "res://assets/graphics/snow_crystals.gdshaderinc"
var variants: Dictionary = {}
var graph_sources: Dictionary = {}
var selected = "after"
var controls: Array = []

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	timing_run = "--timing" in OS.get_cmdline_user_args()
	OUTPUT = "res://artifacts/snow_crystal_shape/"+("timing" if timing_run else "visual")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): OUTPUT = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var started = Time.get_ticks_usec()
	field = Mountain.load_standard()
	if field==null: quit(2); return
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Crystal comparison"),"field":field})
	game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	load_ms = (Time.get_ticks_usec()-started)/1000.0
	game.set_process(false); game.set_physics_process(false)
	game.session.record_directory = OUTPUT+"/isolated_records"
	game.session.benchmark_path = OUTPUT+"/isolated_benchmark.json"
	game.start_run(false); game.summit_ready = false; game.session.eligible = false
	game.effects.muted = true; game.effects.stop_audio()
	game.weather.set_automatic(false); game.weather.set_time_cycle(false)
	game.set_graphics_quality(2)
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "auto" if timing_run else "native"
	game.display_settings.render_scale = .75 if timing_run else 1.0
	game.display_settings.frame_generation = false
	game.display_settings.fps_limit = 0 if timing_run else 30
	game.display_settings.terrain_gi = false; game.world.environment.sdfgi_enabled = false
	game.display_settings.apply_display(root,requested_pixels)
	game.display_settings.apply_viewport(root); root.content_scale_size = requested_pixels
	Engine.max_fps = 0 if timing_run else 30
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	observer = Camera3D.new(); observer.fov = 65; observer.far = 15000; game.add_child(observer)
	for particle in game.effects.sprays+game.weather_effects.volumes+game.weather_effects.drifts:
		particle.use_fixed_seed = true; particle.seed = 849205174+particle.get_index()
	choose_sites(); register_materials()
	source_identity = read_sources()
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	actual_pixels = root.get_texture().get_image().get_size()
	if actual_pixels!=requested_pixels: failures.append("Output size mismatch")
	if timing_run:
		await timings()
		if "--motion" in OS.get_cmdline_user_args() and failures.is_empty():
			if source_identity!=read_sources(): failures.append("Sources changed during timing")
			save_report()
			OUTPUT = OUTPUT.get_base_dir()+"/motion"; DirAccess.make_dir_recursive_absolute(OUTPUT)
			samples.clear(); controls.clear(); comparisons.clear(); timing_run = false
			await capture_motion()
	else:
		await stills()
		if "--stills-only" not in OS.get_cmdline_user_args(): await capture_motion()
	select_look(false)
	if source_identity!=read_sources(): failures.append("Sources changed during comparison")
	if game.session.eligible or game.preferences_enabled: failures.append("Isolation failed")
	save_report()
	print("SNOW_CRYSTAL_COMPLETE ",OUTPUT," failures=",failures)
	game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func comparison_materials() -> Array:
	var result = super.comparison_materials()
	result.append(game.world.scenery.powder_caps.material)
	if game.effects.powder_surface.material: result.append(game.effects.powder_surface.material)
	return result

func register_materials() -> void:
	for material in comparison_materials():
		if not material is ShaderMaterial or current_shaders.has(material): continue
		var original: Shader = material.shader
		current_shaders[material] = original
		if variants.has(original): continue
		var modes = {"after":original}
		for mode in ["before","fine_only","large_only","off"]:
			var sampler = FileAccess.get_file_as_string(RoundReference)
			if mode in ["large_only","off"]:
				sampler = sampler.replace("24.0,vec2(10,32),vec2(0),.045", "24.0,vec2(10,32),vec2(0),0.0")
			if mode in ["fine_only","off"]:
				sampler = sampler.replace("8.0,vec2(20,60),vec2(173.1,527.7),.085", "8.0,vec2(20,60),vec2(173.1,527.7),0.0")
			# Zero radius alone still has footprint coverage in the reference.
			if mode!="before": sampler = sampler.replace("float coverage=grain*", "float coverage=step(.001,radius)*grain*")
			var shader = Shader.new(); shader.code = expand_shader(original.code,sampler)
			modes[mode] = shader
		variants[original] = modes

func expand_shader(code: String,sampler: String) -> String:
	var expression = RegEx.new(); expression.compile('#include\\s+"([^"]+)"')
	for match in expression.search_all(code):
		var path = match.get_string(1)
		graph_sources[path] = FileAccess.get_sha256(path)
		var content = sampler if path==CrystalPath else FileAccess.get_file_as_string(path)
		code = code.replace(match.get_string(),expand_shader(content,sampler))
	return code

func select_mode(mode: String) -> void:
	selected = mode; before = mode=="before"
	register_materials()
	for material in current_shaders: material.shader = variants[current_shaders[material]][mode]
	game.display_settings.reset_history()

func select_look(old: bool) -> void:
	select_mode("before" if old else "after")

func read_sources() -> Dictionary:
	var result = super.read_sources()
	for path in graph_sources: result[path] = FileAccess.get_sha256(path)
	for path in [RoundReference,"res://tests/snow_crystal_shape_playtest.gd","res://scripts/presentation/graphics_presets.gd"]:
		result[path] = FileAccess.get_sha256(path)
	return result

func surface_view(site: Dictionary,condition: String="clear",daylight: String="day",distance_m: float=2.0) -> void:
	reset_site(site,condition,false); game.weather.set_time_of_day(daylight)
	game.world.render_state.clear(); game.world.weather_values.clear()
	game.world.update_weather(game.weather.state,0,false)
	game.active = false; game.skier.hide(); observer.make_current()
	var p: Vector3 = game.sim.position
	var normal: Vector3 = field.contact_normal(p.x,p.z)
	var sun: Vector3 = game.weather.state.sun_direction
	var reflection = (-sun+2.0*normal*normal.dot(sun)).normalized()
	if reflection.y<.1: reflection = (normal+Vector3.UP).normalized()
	observer.position = p+reflection*distance_m+Vector3.UP*.1
	observer.look_at(p)
	freeze_particles(); game.weather_effects.hide()
	game.hud.hide(); game.hud.hide_menu()

func save_view(name: String) -> Image:
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	var picture = root.get_texture().get_image()
	var path = OUTPUT+"/"+name+"_"+selected+".png"
	picture.save_png(path)
	samples.append({"name":name,"look":selected,"image":path,"camera_position":str(observer.position),"camera_basis":str(observer.basis),"weather":game.weather.selected_preset,"hour":game.weather.state.time_hour,"glow":game.world.environment.glow_enabled})
	print("SNOW_CRYSTAL_VIEW ",name," ",selected)
	return picture

func pair(name: String) -> void:
	for mode in ["before","after"]:
		select_mode(mode); await save_view(name)

func stills() -> void:
	# Direct reflection near the ground makes mask size/bloom expansion inspectable.
	surface_view(snow_sites[0])
	for mode in ["before","fine_only","large_only","off","after"]:
		select_mode(mode); await save_view("sun_layers")
	var glow: bool = game.world.environment.glow_enabled
	game.world.environment.glow_enabled = false
	await pair("sun_glow_off")
	game.world.environment.glow_enabled = glow
	for distance_m in [.8,4.5,12.0]:
		surface_view(snow_sites[0],"clear","day",distance_m)
		await pair("sun_distance_"+str(distance_m))
	for condition in ["cloudy","snowfall"]:
		surface_view(snow_sites[-1],condition); await pair(condition)
	for daylight in ["dusk","night"]:
		surface_view(snow_sites[0],"clear",daylight)
		await pair(daylight)
		if daylight=="night":
			select_mode("after"); var enabled = await save_view("night_isolation")
			select_mode("off"); var disabled = await save_view("night_isolation")
			var identical = enabled.get_data()==disabled.get_data()
			controls.append({"name":"night_crystal_off","byte_identical":identical})
			if not identical: failures.append("Night crystal isolation differed")
	for level in [0,1,2]:
		game.set_graphics_quality(level); register_materials()
		surface_view(snow_sites[0]); await pair("quality_"+str(level))
	game.set_graphics_quality(2); register_materials()
	game.display_settings.upscaler = "auto"; game.display_settings.render_scale = .75
	game.display_settings.apply_viewport(root)
	surface_view(snow_sites[0]); await pair("production_upscaler")
	for close in [false,true]:
		reset_site(snow_sites[0],"clear",close)
		for i in 90: step_frame(4); await process_frame
		game.active = false; freeze_particles()
		await pair("pov_tracks" if close else "chase_tracks")

func capture_motion() -> void:
	# Four seconds per view is sufficient to inspect temporal sparkle stability.
	for close in [false,true]:
		for old in [true,false]: await ride(snow_sites[0],"clear",close,old,false)

func timings() -> void:
	var order = [true,false] if "--one-pair" in OS.get_cmdline_user_args() else [true,false,false,true,true,false]
	for old in order:
		reset_site(snow_sites[0],"clear",false); select_look(old)
		Engine.max_fps = 0
		# Independently warm the selected shader and the same moving route.
		for i in 120: await process_frame
		for i in 360: step_frame(1); await process_frame
		reset_site(snow_sites[0],"clear",false); select_look(old)
		for i in 60: await process_frame
		var wall: Array[float] = []; var gpu: Array[float] = []; var cpu: Array[float] = []
		var trajectory = PackedFloat64Array()
		var last = Time.get_ticks_usec(); var completed = 0
		var first_draw = Engine.get_frames_drawn(); var last_draw = first_draw
		var stalled_frames = 0; var query_updates = 0
		for i in 1800:
			step_frame(1)
			trajectory.append_array(PackedFloat64Array([game.sim.position.x,game.sim.position.y,game.sim.position.z]))
			await process_frame
			var now = Time.get_ticks_usec(); wall.append((now-last)/1000.0); last = now
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
			var current_draw = Engine.get_frames_drawn()
			stalled_frames = stalled_frames+1 if current_draw==last_draw else 0
			last_draw = current_draw
			if gpu.size()>1 and (gpu[-1]!=gpu[-2] or cpu[-1]!=cpu[-2]): query_updates += 1
			completed += 1
			if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED or stalled_frames>8:
				failures.append("Render window minimized or frames stopped advancing; timing invalid")
				break
			if game.sim.crashed: break
		var hash = HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(trajectory.to_byte_array())
		var checksum = hash.finish().hex_encode()
		if comparisons.has("timing") and comparisons.timing!=checksum: failures.append("Timing trajectory changed")
		comparisons.timing = checksum
		if completed!=1800: failures.append("Timing ride stopped early: "+game.sim.crash_reason)
		if query_updates<completed/2 or gpu.max()<=0: failures.append("Stale or unavailable renderer timings")
		var row = {"look":selected,"seconds":completed/120.0,"ticks":completed,"rendered_frame_delta":last_draw-first_draw,"query_updates":query_updates,"stop":"duration" if completed==1800 else "invalid_or_crash","trajectory_sha256":checksum,"frame_ms":timing(wall),"gpu_ms":timing(gpu),"render_cpu_ms":timing(cpu)}
		row.wall_seconds = row.frame_ms.mean*completed/1000.0
		row.frame_ms.rendered_fps = 1000.0/row.frame_ms.mean
		samples.append(row); print("SNOW_CRYSTAL_TIMING ",JSON.stringify(row))
		if not failures.is_empty(): break

func save_report() -> void:
	var report = {"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"backend":RenderingServer.get_current_rendering_driver_name(),"device":RenderingServer.get_video_adapter_name(),"pixels":[actual_pixels.x,actual_pixels.y],"display":game.display_settings.report(root,actual_pixels),"load_ms":load_ms,"cache_hit":field.cache_hit,"height_sha256":field.height_checksum,"model":game.sim.MODEL_VERSION,"sources":source_identity,"samples":samples,"controls":controls,"failures":failures,"unranked":not game.session.eligible,"preferences_disabled":not game.preferences_enabled,"scope":"bounded matched scenarios; no full-descent or human acceptance; only crystal sampler differs"}
	preload("res://tests/test_report.gd").write(OUTPUT+"/report.json",JSON.stringify(report,"\t"))
