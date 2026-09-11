extends "res://tests/alpine_v13_playtest.gd"
## Frozen original shaders versus current materials on the current default world.
## Capture runs use fixed simulation time; uncaptured timing is reported apart.
const SnowQuality = preload("res://scripts/presentation/graphics_quality.gd")
const DT = 1.0/120.0
const REFERENCE = "res://artifacts/snow_readability/reference/"
var observer: Camera3D
var failures: Array[String] = []
var samples: Array = []
var snow_sites: Array = []
var current_shaders: Dictionary = {}
var reference_shaders: Dictionary = {}
var hollow_receivers: Array[ShaderMaterial] = []
var before = false
var timing_run = false
var quick = false
var source_identity: Dictionary = {}
var load_ms: float
var comparisons: Dictionary = {}

func run() -> void:
	var args = OS.get_cmdline_user_args()
	timing_run = "--timing" in args
	quick = "--quick" in args
	OUTPUT = "res://artifacts/snow_readability/"+("timing" if timing_run else "visual")
	for arg in args:
		if arg.begins_with("--output="): OUTPUT = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	source_identity = read_sources()
	var started = Time.get_ticks_usec()
	field = Definition.generate(849205174,Definition.CURRENT_VERSION)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Snow readability"),"field":field})
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	load_ms = (Time.get_ticks_usec()-started)/1000.0
	game.set_process(false); game.set_physics_process(false)
	game.start_run(false); game.summit_ready = false; game.session.eligible = false
	game.effects.muted = true; game.hud.root.hide(); game.hud.hide_menu()
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.weather.set_automatic(false); game.weather.set_time_cycle(false)
	game.set_graphics_quality(2)
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "auto"
	game.display_settings.frame_generation = false
	game.display_settings.render_scale = .75
	game.display_settings.fps_limit = 120 if timing_run else 30
	game.display_settings.terrain_gi = false
	game.world.environment.sdfgi_enabled = false
	game.display_settings.apply_display(root,requested_pixels)
	game.display_settings.apply_viewport(root)
	root.content_scale_size = requested_pixels
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var surfaces = comparison_materials()
	for material in surfaces:
		current_shaders[material] = material.shader
		reference_shaders[material] = load(reference_root()+material.shader.resource_path.trim_prefix("res://"))
		if material.get_shader_parameter("snow_hollows_enabled"): hollow_receivers.append(material)
	observer = Camera3D.new(); observer.fov = 75; observer.far = 15000
	game.add_child(observer)
	var particles: Array = game.effects.sprays+game.weather_effects.volumes+game.weather_effects.drifts
	for i in particles.size():
		particles[i].use_fixed_seed = true; particles[i].seed = 849205174+i; particles[i].speed_scale = 0
	choose_sites()
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	actual_pixels = root.get_texture().get_image().get_size()
	if actual_pixels!=requested_pixels: failures.append("Output pixels mismatch")
	if timing_run:
		await timings()
	else:
		await stills()
		if "--stills-only" not in args: await capture_motion()
	if "--all" in args and not timing_run:
		save_report()
		OUTPUT = OUTPUT.get_base_dir()+"/timing"
		DirAccess.make_dir_recursive_absolute(OUTPUT)
		samples = []; comparisons.clear(); timing_run = true
		await timings()
	save_report()
	print("SNOW_READABILITY_COMPLETE ",OUTPUT," failures=",failures)
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func reference_root() -> String:
	return REFERENCE

func comparison_materials() -> Array:
	var surfaces: Array = game.world.assets.surface_materials.duplicate()
	surfaces.append(game.effects.snow_tracks.material)
	return surfaces

func capture_motion() -> void:
	for site in [snow_sites[0],snow_sites[-1]]:
		for close in [false,true]:
			for condition in ["clear","snowfall"]:
				for look in [true,false]: await ride(site,condition,close,look,false)

func save_motion_frame(picture: Image,path: String) -> void:
	picture.resize(1920,1080,Image.INTERPOLATE_LANCZOS)
	picture.save_jpg(path,.94)

func timings() -> void:
	game.display_settings.fps_limit = 120; Engine.max_fps = 120
	process_frame.connect(_measure)
	# ABBA order reduces warming/order bias. Each repeat starts identically.
	for look in [true,false,false,true]:
		for condition in ["clear","snowfall"]:
			for site in [snow_sites[0],snow_sites[-1]]:
				await ride(site,condition,false,look,true)

func save_report() -> void:
	if source_identity!=read_sources(): failures.append("Sources changed during this comparison")
	if game.session.eligible: failures.append("Test became record eligible")
	var report = {"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"device":RenderingServer.get_video_adapter_name(),"backend":RenderingServer.get_current_rendering_driver_name(),
		"actual_pixels":[actual_pixels.x,actual_pixels.y],"display":game.display_settings.report(root,actual_pixels),
		"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"model":game.sim.MODEL_VERSION,"cache_hit":field.cache_hit,
		"cache_reconstruction_ms":field.generation_ms,"world_build_ms":game.world.generation_ms,"total_load_ms":load_ms,"snow_shape":game.world.snow_readability.report(),
		"unranked":not game.session.eligible,"capture_overhead_included":not timing_run,"scope":"matched short skiing fixtures; not full-descent acceptance",
		"particles":"Live clock in uncaptured timing; fixed simulation time in motion; equipment spray hidden in still comparisons",
		"peak_video_bytes":peak_video_bytes,"sources":source_identity,"sites":snow_sites,"samples":samples,"failures":failures}
	FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))

func read_sources() -> Dictionary:
	var paths = ["scripts/presentation/snow_readability.gd","scripts/presentation/alpine_atmosphere.gd","scripts/presentation/graphics_quality.gd","scripts/presentation/speed_effects.gd","scripts/world/alpine_world.gd","assets/graphics/snow_readability.gdshaderinc","assets/graphics/alpine_surface_fragment.gdshaderinc","assets/graphics/alpine_surface_uniforms.gdshaderinc","assets/graphics/ski_track.gdshader","assets/graphics/snow_crystals.gdshaderinc","scripts/main.gd","scripts/core/ski_simulation.gd","config/ski_default.tres","tests/snow_readability_playtest.gd"]
	var result: Dictionary = {}
	for path in paths: result[path] = FileAccess.get_sha256("res://"+path)
	return result

func choose_sites() -> void:
	var face = field.faces[3]
	var open = safe_site(face.to_world(Vector2(120,650)))
	snow_sites.append({"name":"open_waves","p":[open.x,open.y],"heading":face.heading})
	for kind in [0,2]:
		var chosen = open
		for form in face.snow_forms:
			if form.kind!=kind or form.position.y<600 or form.position.y>1900: continue
			var p: Vector2 = face.to_world(form.position)
			if field.rock_fraction_at(p.x,p.y)>.1 or field.contact_normal(p.x,p.y).y<.75: continue
			chosen = safe_site(p-Vector2(sin(face.heading),cos(face.heading))*24)
			break
		snow_sites.append({"name":"shallow_wave" if kind==0 else "bank_lip","p":[chosen.x,chosen.y],"heading":face.heading})
	var forest = forest_site(3)
	snow_sites.append({"name":"tree_mounds","p":[forest.x,forest.y],"heading":face.heading})

func select_look(old: bool) -> void:
	before = old
	for material in current_shaders:
		material.shader = reference_shaders[material] if old else current_shaders[material]
		if not old and material in hollow_receivers: game.world.snow_readability.bind(material)
	var q = SnowQuality.preset(game.graphics.level)
	if old:
		q.snow_sheen = [.06,.14,.22][q.level]
		q.highlight_glow_intensity = [0.0,.36,.50][q.level]
	for material in game.world.assets.surface_materials: q.apply_snow_material(material)
	q.apply_snow_material(game.world.scenery.powder_caps.material)
	q.apply_snow_material(game.effects.snow_tracks.material,.35)
	game.world.render_state.clear(); game.world.weather_values.clear()
	game.world.update_weather(game.weather.state,0,false)
	var day = smoothstep(0.0,.16,game.weather.state.sun_direction.y)
	var clear = 1.0-smoothstep(.20,.98,game.weather.state.cloud_coverage)
	game.world.environment.tonemap_exposure = lerpf(1.0,1.3 if old else 1.15,day*clear)
	game.world.environment.glow_intensity = q.highlight_glow_intensity*day*lerpf(.15,1.0,clear)
	game.world.environment.ssao_light_affect = 0.0 if old else .20
	game.world.environment.ssao_ao_channel_affect = 0.0 if old else 1.0
	game.display_settings.reset_history()

func reset_site(site: Dictionary,condition: String,close: bool) -> void:
	var p = Vector2(site.p[0],site.p[1])
	game.weather.set_preset(condition); game.weather.set_time_of_day("day")
	game.weather.visual_time = 0; game.world.cloud_offset = Vector2.ZERO
	game.world.assets.wind_time = 0; game.world.assets.wind_ready = false
	game.effects.reset(); game.weather_effects.reset()
	game.sim.reset(Vector3(p.x,field.sample(p.x,p.y).height,p.y),site.heading)
	game.sim.prime_contacts(game.world.ski_surface)
	game.sim.velocity = game.sim.support_basis().z*22.0
	game.previous_position = game.sim.position
	game.skier.reset_animation(game.sim)
	game.camera.close_view = close; game.camera.reset()
	game.active = true; game.camera.make_current(); game.skier.show()
	game.intent = RiderInput.new(); game.intent.tuck = .5
	game._process(0)
	if not timing_run:
		freeze_particles()
		for particle in game.weather_effects.volumes+game.weather_effects.drifts:
			if particle.visible: particle.request_particles_process(.5)
	game.hud.root.hide(); game.hud.hide_menu(); game.speed_periphery.hide()

func stills() -> void:
	for site in (snow_sites.slice(0,1) if quick else snow_sites):
		for condition in (["clear"] if quick else ["clear","cloudy","snowfall"]):
			reset_site(site,condition,false)
			game.skier.hide(); observer.make_current()
			observer.position = game.sim.position+Vector3.UP*1.8
			var sun: Vector3 = game.weather.state.sun_direction
			for angle in [0,90,180]:
				var direction = Vector3(sun.x,0,sun.z).normalized().rotated(Vector3.UP,deg_to_rad(angle))
				observer.look_at(observer.position+direction+Vector3.DOWN*.35)
				for look in [true,false]:
					select_look(look)
					await capture_pair("%s_%s_%d"%[site.name,condition,angle])
	# Tracks crossing the moving powder patch, quality changes, and night.
	for level in ([2] if quick else [0,1,2]):
		game.set_graphics_quality(level); Engine.max_fps = 30
		reset_site(snow_sites[0],"clear",false)
		for i in 90:
			step_frame(4)
			await process_frame
		game.active = false; game.skier.hide(); observer.make_current()
		observer.position = game.sim.position+Vector3.UP*8-game.sim.ski_forward*9
		observer.look_at(game.sim.position-game.sim.ski_forward*7)
		for look in [true,false]:
			select_look(look); await capture_pair("tracks_quality_%d"%level)
	game.set_graphics_quality(2); Engine.max_fps = 30
	reset_site(snow_sites[-1],"clear",false)
	for time in (["night"] if quick else ["dawn","dusk","night"]):
		game.weather.set_time_of_day(time)
		for look in [true,false]:
			select_look(look); await capture_pair("forest_"+time)
	# Isolate the material treatment: brightness/glow/AO stay identical.
	reset_site(snow_sites[2],"clear",false); select_look(false)
	for enabled in [false,true]:
		for material in current_shaders: material.set_shader_parameter("snow_hollows_strength",1.0 if enabled else 0.0)
		await capture_pair("shape_isolation_"+("on" if enabled else "off"))
	reset_site(snow_sites[-1],"clear",false); select_look(false)
	for enabled in [false,true]:
		game.world.environment.ssao_light_affect = .20 if enabled else 0.0
		game.world.environment.ssao_ao_channel_affect = 1.0 if enabled else 0.0
		await capture_pair("contact_isolation_"+("on" if enabled else "off"))

func capture_pair(name: String) -> void:
	# Surface comparisons must not be obscured by a differently aged spray puff.
	var spray_visibility: Array[bool] = []
	for particle in game.effects.sprays:
		spray_visibility.append(particle.visible); particle.hide()
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	var picture = root.get_texture().get_image()
	var look = "before" if before else "after"
	var path = OUTPUT+"/"+name+"_"+look+".jpg"
	picture.save_jpg(path,.97)
	var cam = root.get_camera_3d()
	samples.append({"name":name,"look":look,"image":path,"camera_position":var_to_str(cam.global_position),"camera_basis":var_to_str(cam.global_basis),"hour":game.weather.state.time_hour,"weather":game.weather.selected_preset})
	for i in game.effects.sprays.size(): game.effects.sprays[i].visible = spray_visibility[i]
	print("SNOW_READABILITY_VIEW ",name," ",look)

func freeze_particles() -> void:
	# Presentation updates restore speed_scale; override after every fixed step,
	# otherwise capture/readback wall time advances particles a second time.
	for particle in game.effects.sprays+game.weather_effects.volumes+game.weather_effects.drifts:
		particle.speed_scale = 0.0

func step_frame(ticks: int) -> void:
	for tick in ticks:
		game.previous_position = game.sim.position
		game.sim.step(DT,game.intent,game.world.ski_surface)
		game.skier.step_animation(DT,game.sim,game.intent,field)
	game.session.elapsed += ticks*DT
	game._process(ticks*DT)
	if not timing_run:
		freeze_particles()
		for particle in game.effects.sprays+game.weather_effects.volumes+game.weather_effects.drifts:
			if particle.visible: particle.request_particles_process(ticks*DT)
	game.speed_periphery.hide()

func ride(site: Dictionary,condition: String,close: bool,old: bool,measure: bool) -> void:
	reset_site(site,condition,close); select_look(old)
	Engine.max_fps = 120 if measure else 30
	var look = "before" if old else "after"
	var name = "%s_%s_%s"%[site.name,condition,"pov" if close else "chase"]
	var folder = OUTPUT+"/"+name+"_"+look
	if not measure: DirAccess.make_dir_recursive_absolute(folder)
	for material in current_shaders:
		if not old: material.set_shader_parameter("snow_hollows_strength",1.0)
	for i in 120: await process_frame
	frames.clear(); gpu_ms.clear(); render_cpu_ms.clear(); draws.clear(); physics_us.clear()
	var trajectory = PackedFloat64Array()
	recording = measure; previous_recording = false
	var frame_count = 720 if measure else 120
	var completed = 0
	for frame in frame_count:
		var begin = Time.get_ticks_usec()
		step_frame(1 if measure else 4)
		physics_us.append(Time.get_ticks_usec()-begin)
		trajectory.append_array(PackedFloat64Array([game.sim.position.x,game.sim.position.y,game.sim.position.z,game.sim.velocity.x,game.sim.velocity.y,game.sim.velocity.z]))
		completed = frame+1
		await process_frame
		if not measure:
			await RenderingServer.frame_post_draw
			var picture = root.get_texture().get_image()
			save_motion_frame(picture,folder+"/%04d.jpg"%frame)
		if game.sim.crashed: break
	recording = false
	var digest = HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(trajectory.to_byte_array())
	var checksum = digest.finish().hex_encode()
	var key = name+("_timing" if measure else "_motion")
	if comparisons.has(key) and comparisons[key]!=checksum: failures.append("Simulation trajectory changed: "+key)
	comparisons[key] = checksum
	var row = {"name":name,"look":look,"frames":completed,"crash":game.sim.crash_reason,"trajectory_sha256":checksum,"seconds":completed/(120.0 if measure else 30.0)}
	if measure:
		row.frame_ms = frame_timing(frames); row.gpu_ms = timing(gpu_ms); row.render_cpu_ms = timing(render_cpu_ms)
		row.simulation_and_presentation_us = timing(physics_us); row.draw_calls = timing(draws)
	else: row.frames_path = folder
	samples.append(row)
	print("SNOW_READABILITY_RIDE ",JSON.stringify(row))
