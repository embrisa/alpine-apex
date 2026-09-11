extends "res://tests/snow_readability_playtest.gd"
## Current v15, identical inputs/cameras, frozen pre-softening shader graph.
## Run through scripts/validate_soft_snow.ps1; motion is retained at native 4K.

func reference_root() -> String:
	return "res://artifacts/soft_snow/baseline/"

func comparison_materials() -> Array:
	var materials = super.comparison_materials()
	materials.append(game.world.scenery.powder_caps.material)
	return materials

func select_look(old: bool) -> void:
	before = old
	for material in current_shaders:
		material.shader = reference_shaders[material] if old else current_shaders[material]
		if material in hollow_receivers: game.world.snow_readability.bind(material)
	var q = SnowQuality.preset(game.graphics.level)
	if old:
		q.snow_sheen = [.06,.084,.132][q.level]
		q.highlight_glow_intensity = [0.0,.252,.35][q.level]
	# Keep the selected lighting profile active throughout motion/weather updates.
	game.graphics.snow_sheen = q.snow_sheen
	game.graphics.highlight_glow_intensity = q.highlight_glow_intensity
	game.world.quality = game.graphics
	for material in current_shaders:
		q.apply_snow_material(material,.35 if material==game.effects.snow_tracks.material else 1.0)
	game.world.render_state.clear(); game.world.weather_values.clear()
	game.world.update_weather(game.weather.state,0,false)
	game.display_settings.reset_history()

func read_sources() -> Dictionary:
	var result = super.read_sources()
	for path in ["tests/soft_snow_playtest.gd","assets/graphics/powder_cap.gdshader",
		"assets/graphics/powder_surface.gdshader","scripts/presentation/pc_graphics_settings.gd"]:
		result[path] = FileAccess.get_sha256("res://"+path)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(reference_root()+"manifest.json"))
	for path in manifest.frozen_sha256:
		var digest = FileAccess.get_sha256(reference_root()+path)
		result[reference_root()+path] = digest
		if digest!=manifest.frozen_sha256[path]: failures.append("Frozen baseline changed: "+path)
	return result

func save_report() -> void:
	super.save_report()
	var path = OUTPUT+"/report.json"
	var report = JSON.parse_string(FileAccess.get_file_as_string(path))
	report.title = "Softer, more luminous snow"
	report.comparison_description = "Previous snow versus softer grain, gentler ripples and increased sun sheen/glow on the same v15 Standard mountain. Texture assets, crystal strength/density, terrain and simulation are unchanged."
	report.generator_version = Definition.CURRENT_VERSION
	report.video_resolution = "3840×2160"
	report.baseline_revision = JSON.parse_string(FileAccess.get_file_as_string(reference_root()+"manifest.json")).revision
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))

func paired_view(name: String) -> void:
	for look in [true,false]:
		select_look(look)
		await capture_pair(name)
		var row: Dictionary = samples[-1]
		row.display = game.display_settings.report(root,actual_pixels)
		row.glow_intensity = game.world.environment.glow_intensity
		row.sheen = game.graphics.snow_sheen

func surface_camera(site: Dictionary,condition: String) -> void:
	reset_site(site,condition,false)
	game.active = false; game.skier.hide(); observer.make_current()
	observer.position = game.sim.position+Vector3.UP*1.8
	observer.look_at(observer.position+game.sim.ski_forward+Vector3.DOWN*.35)

func stills() -> void:
	if "--native-controls" in OS.get_cmdline_user_args():
		await native_controls()
		return
	for site in snow_sites:
		for condition in ["clear","cloudy","snowfall"]:
			surface_camera(site,condition)
			await paired_view(site.name+"_"+condition)
	surface_camera(snow_sites[0],"clear")
	observer.position = game.sim.position+Vector3.UP*.8
	observer.look_at(observer.position+game.sim.ski_forward*2+Vector3.DOWN*.9)
	await paired_view("close_powder")
	surface_camera(snow_sites[2],"clear")
	var sun: Vector3 = game.weather.state.sun_direction
	for angle in [0,90,180]:
		var direction = Vector3(sun.x,0,sun.z).normalized().rotated(Vector3.UP,deg_to_rad(angle))
		observer.look_at(observer.position+direction+Vector3.DOWN*.35)
		await paired_view("bank_sun_%d"%angle)
	for level in [0,1,2]:
		game.set_graphics_quality(level); Engine.max_fps = 30
		reset_site(snow_sites[0],"clear",false); select_look(false)
		for i in 90:
			step_frame(4); await process_frame
		game.active = false; game.skier.hide(); observer.make_current()
		observer.position = game.sim.position+Vector3.UP*8-game.sim.ski_forward*9
		observer.look_at(game.sim.position-game.sim.ski_forward*7)
		await paired_view("tracks_quality_%d"%level)
	game.set_graphics_quality(2); Engine.max_fps = 30
	surface_camera(snow_sites[-1],"clear")
	game.weather.set_time_of_day("night")
	await paired_view("forest_night")
	surface_camera(snow_sites[0],"clear")
	game.weather.set_quality(0)
	await paired_view("weather_fx_off")
	game.weather.set_quality(2)
	# Same 4K output and camera, with the upscaler removed as a control.
	game.display_settings.upscaler = "native"
	game.display_settings.apply_viewport(root)
	for site in [snow_sites[0],snow_sites[-1]]:
		surface_camera(site,"clear")
		await paired_view(site.name+"_native")
	game.display_settings.upscaler = "auto"
	game.display_settings.apply_viewport(root)

func capture_motion() -> void:
	if "--native-controls" in OS.get_cmdline_user_args(): return
	for close in [false,true]:
		for look in [true,false]: await ride(snow_sites[0],"clear",close,look,false)
	for look in [true,false]: await ride(snow_sites[-1],"clear",false,look,false)

func save_motion_frame(picture: Image,path: String) -> void:
	picture.save_jpg(path,.96)

func native_controls() -> void:
	# Resetting the solver retains its previous ski-forward presentation value.
	# Derive an explicit downhill camera so native/FSR controls share its basis.
	for site in [snow_sites[0],snow_sites[-1]]:
		surface_camera(site,"clear")
		var n: Vector3 = field.contact_normal(site.p[0],site.p[1])
		var downhill = Vector3.DOWN.slide(n).normalized()
		observer.position = game.sim.position+Vector3.UP*2.4
		observer.look_at(observer.position+downhill+Vector3.DOWN*.06)
		for mode in ["auto","native"]:
			game.display_settings.upscaler = mode
			game.display_settings.apply_viewport(root)
			await paired_view(site.name+"_control_"+mode)

func timings() -> void:
	game.display_settings.fps_limit = 120; Engine.max_fps = 120
	process_frame.connect(_measure)
	for look in [true,false,false,true]:
		for site in [snow_sites[0],snow_sites[-1]]:
			await ride(site,"clear",false,look,true)
