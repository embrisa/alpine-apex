extends "res://tests/snow_readability_playtest.gd"
## Original scanned snow normals versus the adopted half-strength material.
## --production-check captures only the actual production shaders at three sites.
var preview_materials: Array[ShaderMaterial] = []
var preview_shaders: Dictionary = {}
var original_shaders: Dictionary = {}
var preview_start: Dictionary = {}
var controls: Array = []
var production_check = false

func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Snow bump comparison requires native rendering")
		quit(1); return
	production_check = "--production-check" in OS.get_cmdline_user_args()
	OUTPUT = "res://artifacts/snow_bump_comparison_20260911/"+("adopted" if production_check else "comparison")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): OUTPUT = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	source_identity = read_sources()
	var started = Time.get_ticks_usec()
	print("SNOW_BUMP_LOADING cached v15 Standard")
	field = Definition.generate(849205174,Definition.CURRENT_VERSION)
	if field==null: quit(2); return
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Snow bump comparison"),"field":field})
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	load_ms = (Time.get_ticks_usec()-started)/1000.0
	game.set_process(false); game.set_physics_process(false)
	game.start_run(false); game.summit_ready = false; game.session.eligible = false
	game.effects.muted = true; game.effects.stop_audio()
	game.weather.set_automatic(false); game.weather.set_time_cycle(false)
	game.set_graphics_quality(2)
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "native"
	game.display_settings.frame_generation = false
	game.display_settings.render_scale = 1.0
	game.display_settings.fps_limit = 30
	game.display_settings.terrain_gi = false
	game.world.environment.sdfgi_enabled = false
	game.display_settings.apply_display(root,requested_pixels)
	game.display_settings.apply_viewport(root)
	root.content_scale_size = requested_pixels
	observer = Camera3D.new(); observer.fov = 75; observer.far = 15000
	game.add_child(observer)
	for particle in game.effects.sprays+game.weather_effects.volumes+game.weather_effects.drifts:
		particle.use_fixed_seed = true; particle.seed = 849205174+particle.get_index(); particle.speed_scale = 0
	if not production_check and not prepare_preview():
		quit(2); return
	choose_sites()
	if production_check:
		await compare_site(snow_sites[0],"clear","day")
		await compare_site(snow_sites[2],"cloudy","day")
		await compare_site(snow_sites[3],"snowfall","day")
	else:
		for site in snow_sites:
			for condition in ["clear","cloudy","snowfall"]:
				await compare_site(site,condition,"day")
		await compare_site(snow_sites[0],"clear","dusk")
	for material in original_shaders: material.shader = original_shaders[material]
	if source_identity!=read_sources(): failures.append("Comparison sources changed during capture")
	if game.session.eligible or game.preferences_enabled: failures.append("Fixture isolation failed")
	var report = {"change":"Scanned snow normal contribution only: 1.0 original, 0.5 adopted production material.","production_check":production_check,
		"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"device":RenderingServer.get_video_adapter_name(),"backend":RenderingServer.get_current_rendering_driver_name(),
		"actual_pixels":[actual_pixels.x,actual_pixels.y],"display":game.display_settings.report(root,actual_pixels),
		"seed":849205174,"generator":Definition.CURRENT_VERSION,"model":game.sim.MODEL_VERSION,
		"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"cache_hit":field.cache_hit,
		"load_ms":load_ms,"unranked":not game.session.eligible,"preferences_disabled":not game.preferences_enabled,
		"preview_material_count":preview_materials.size(),"sources":source_identity,"sites":snow_sites,"samples":samples,"controls":controls,"failures":failures,
		"scope":"Frozen rendered comparisons, not motion, performance or human acceptance. Snowfall uses identical frozen GPU particles within each pair."}
	preload("res://tests/test_report.gd").write(OUTPUT+"/report.json",JSON.stringify(report,"\t"))
	print("SNOW_BUMP_COMPLETE captures=",samples.size()," production_check=",production_check," failures=",failures)
	game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func read_sources() -> Dictionary:
	var result = super.read_sources()
	for path in ["tests/snow_bump_comparison.gd","assets/graphics/terrain_sampling.gdshaderinc","assets/graphics/alpine_surface.gdshader","assets/graphics/powder_surface.gdshader","assets/graphics/powder_surface.gdshaderinc","assets/cloud_light.gdshaderinc","scripts/presentation/graphics_presets.gd","scripts/presentation/weather_controller.gd","scripts/presentation/weather_effects.gd","scripts/presentation/daylight_cycle.gd","config/weather/clear.tres","config/weather/cloudy.tres","config/weather/snowfall.tres"]:
		result[path] = FileAccess.get_sha256("res://"+path)
	return result

func prepare_preview() -> bool:
	var fragment = FileAccess.get_file_as_string("res://assets/graphics/alpine_surface_fragment.gdshaderinc")
	var needle = "sn=terrain_snow_normal(snow_tiles)*.5;"
	if fragment.count(needle)!=1:
		printerr("Scanned snow normal source changed; refusing an ambiguous preview")
		return false
	fragment = "uniform float snow_bump_comparison_scale = 1.0;\n"+fragment.replace(needle,"sn=terrain_snow_normal(snow_tiles)*snow_bump_comparison_scale;")
	var include_line = '#include "res://assets/graphics/alpine_surface_fragment.gdshaderinc"'
	for material in game.world.assets.surface_materials:
		if not material is ShaderMaterial or not material.shader: continue
		var original: Shader = material.shader
		if not original.code.contains(include_line): continue
		if not preview_shaders.has(original):
			var candidate = Shader.new()
			candidate.code = original.code.replace(include_line,fragment)
			preview_shaders[original] = candidate
			preload("res://tests/test_report.gd").write(OUTPUT+"/preview_"+original.resource_path.get_file(),candidate.code)
		original_shaders[material] = original
		material.shader = preview_shaders[original]
		preview_materials.append(material)
	print("SNOW_BUMP_MATERIALS ",preview_materials.size())
	return not preview_materials.is_empty()

func select_look(old: bool) -> void:
	before = old
	for material in preview_materials:
		material.shader = preview_shaders[original_shaders[material]] if old else original_shaders[material]
		if old: material.set_shader_parameter("snow_bump_comparison_scale",1.0)
	game.display_settings.reset_history()

func compare_site(site: Dictionary, condition: String, daylight: String) -> void:
	reset_site(site,condition,false)
	game.weather.set_time_of_day(daylight)
	game.world.render_state.clear(); game.world.weather_values.clear()
	game.world.update_weather(game.weather.state,0,false)
	game.active = false; game.skier.hide(); observer.make_current()
	observer.position = game.sim.position+Vector3.UP*1.8
	var forward = Vector3(sin(site.heading),0,cos(site.heading))
	var target = game.sim.position+forward*12.0
	target.y = field.sample(target.x,target.z).height+.35
	observer.look_at(target)
	game.weather_effects.reset()
	game.weather_effects.update_weather(game.weather.state,observer,game.sim.position,field,0,true,false,0,game.graphics.weather_quality)
	freeze_particles()
	for particle in game.weather_effects.volumes+game.weather_effects.drifts:
		if particle.visible: particle.request_particles_process(.75)
	Engine.time_scale = 0.0
	for particle in game.effects.sprays: particle.hide()
	game.hud.root.hide(); game.hud.hide_menu(); game.speed_periphery.hide()
	preview_start = frozen_state()
	var name = "%s_%s_%s"%[site.name,condition,daylight]
	for look in ([false] if production_check else [true,false]):
		select_look(look)
		for i in 50: await process_frame
		await RenderingServer.frame_post_draw
		var picture = root.get_texture().get_image()
		actual_pixels = picture.get_size()
		if actual_pixels!=requested_pixels: failures.append("Output resolution mismatch: "+name)
		if frozen_state()!=preview_start: failures.append("Scene moved during pair: "+name)
		var label = "before" if look else "after"
		var filename = name+"_"+label+".png"
		picture.save_png(OUTPUT+"/"+filename)
		samples.append({"name":name,"look":label,"image":filename,"bump_scale":1.0 if look else .5,"state":preview_start})
		print("SNOW_BUMP_VIEW ",name," ",label)
		if look and site.name in ["open_waves","tree_mounds"] and condition=="snowfall":
			for i in 50: await process_frame
			await RenderingServer.frame_post_draw
			var repeat_image = root.get_texture().get_image()
			var control_name = name+"_before_repeat.png"
			repeat_image.save_png(OUTPUT+"/"+control_name)
			controls.append({"name":name,"image":control_name,"byte_identical":picture.get_data()==repeat_image.get_data()})
			print("SNOW_BUMP_CONTROL ",name," identical=",controls[-1].byte_identical)

func frozen_state() -> Dictionary:
	return {"camera_position":var_to_str(observer.global_position),"camera_basis":var_to_str(observer.global_basis),
		"rider_position":var_to_str(game.sim.position),"tick":game.sim.ticks,"weather":game.weather.selected_preset,
		"hour":game.weather.state.time_hour,"weather_clock":game.weather.visual_time,"wind_time":game.world.assets.wind_time,
		"cloud_offset":var_to_str(game.world.cloud_offset)}
