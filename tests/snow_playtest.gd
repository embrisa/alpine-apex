extends SceneTree
## Native snow inspection: fixed input, unranked, all screenshots are rendered.
var game
var captures: Array = []
var output = "res://artifacts/snow_upgrade"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Snow playtest requires a rendered viewport")
		quit(1)
		return
	root.size = Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(output)
	Engine.max_fps = 60
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.start_speed_lab(100.0)
	game.hud.hide()
	game.effects.muted = true
	# Weather spindrift animates independently; isolate ski snow for comparisons.
	game.weather_effects.hide()
	game.camera.effects_enabled = false
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	game.sim.position = Vector3(0,game.field.sample(0,500).height,500)
	game.sim.surface_normal = game.field.contact_normal(0,500)
	game.sim.velocity = Vector3.DOWN.slide(game.sim.surface_normal).normalized()*100.0/3.6
	game.previous_position = game.sim.position
	game.camera.reset()
	for frame in range(210):
		game.intent = RiderInput.new()
		game.intent.steer = sin(frame/60.0*1.8)*0.32
		game.intent.tuck = 0.3
		for tick in range(2):
			game.previous_position = game.sim.position
			game.sim.step(1.0/120.0,game.intent,game.field)
		game._process(1.0/60.0)
		await process_frame
		if frame==155: await capture("carving")
	await capture("chase")
	for frame in range(42):
		game.intent.steer = 0.75
		game.intent.tuck = 0.0
		game.intent.brake = 0.7
		for tick in range(2):
			game.previous_position = game.sim.position
			game.sim.step(1.0/120.0,game.intent,game.field)
		game._process(1.0/60.0)
		await process_frame
	await capture("braking_powder")
	# Freeze the particle field so camera comparisons use the same powder cloud.
	for spray in game.effects.sprays: spray.speed_scale = 0.0
	var p: Vector3 = game.sim.position
	var f: Vector3 = game.sim.ski_forward
	var r: Vector3 = game.sim.surface_normal.cross(f)
	game.camera.position = p-f*6.5+r*4.5+Vector3.UP*3.3
	game.camera.look_at(p-f*2.5+Vector3.UP*.35)
	await capture("grooves_and_spray")
	game.skier.hide()
	game.camera.position = p-f*11.0+r*1.8+Vector3.UP*2.8
	game.camera.look_at(p-f*4.0)
	await capture("grooves_close")
	for quality in [0,1,2]:
		game.set_graphics_quality(quality)
		game.world.update_weather(game.weather.state,0.0,false)
		await capture("surface_%s" % game.graphics.label())
	game.set_graphics_quality(1)
	game.skier.show()
	game.camera.close_view = true
	game.camera.reset()
	game._process(1.0/60.0)
	for spray in game.effects.sprays: spray.speed_scale = 0.0
	await capture("pov")
	# Close sun-reflection angle makes filtered crystal response inspectable.
	game.skier.hide()
	var snow_point = p+r*3.0
	snow_point.y = game.field.sample(snow_point.x,snow_point.z).height
	var normal: Vector3 = game.field.contact_normal(snow_point.x,snow_point.z)
	var sun: Vector3 = game.weather.state.sun_direction
	var reflection = -sun+2.0*normal*normal.dot(sun)
	game.camera.position = snow_point+reflection*4.5
	game.camera.look_at(snow_point)
	await capture("sun_crystals")
	var sun_image = root.get_texture().get_image()
	for material in game.world.assets.surface_materials: material.set_shader_parameter("snow_sparkle_strength",0.0)
	await capture("sun_crystals_disabled")
	var crystal_pixels = changed_pixels(sun_image,root.get_texture().get_image())
	var sun_center_pixels = changed_pixels(sun_image,root.get_texture().get_image(),true)
	# A real shadow caster intercepts the sun ray without sitting between the
	# camera and the snow. This checks Godot shadow attenuation, not an on/off flag.
	var blocker = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(8,.3,8)
	blocker.mesh = box
	game.add_child(blocker)
	blocker.position = snow_point+sun*5.0
	for material in game.world.assets.surface_materials: material.set_shader_parameter("snow_sparkle_strength",game.graphics.snow_sparkle)
	await capture("crystals_cast_shadow")
	var shade_image = root.get_texture().get_image()
	for material in game.world.assets.surface_materials: material.set_shader_parameter("snow_sparkle_strength",0.0)
	await capture("crystals_cast_shadow_disabled")
	var shade_center_pixels = changed_pixels(shade_image,root.get_texture().get_image(),true)
	blocker.queue_free()
	for material in game.world.assets.surface_materials: material.set_shader_parameter("snow_sparkle_strength",game.graphics.snow_sparkle)
	# Raking view across the sculpted snow, including a plain material proof that
	# the surface relief exists in geometry rather than only a normal map.
	var drift_point = Vector3(0,game.field.sample(0,550).height,550)
	game.camera.position = drift_point+Vector3(0,.85,0)
	var across_point = Vector3(22,game.field.sample(22,550).height,550)
	game.camera.look_at(across_point+Vector3.UP*.25)
	game.world.update_weather(game.weather.state,0.0,false)
	await capture("drifts_low_angle")
	var geometry_material = StandardMaterial3D.new()
	geometry_material.albedo_color = Color(.78,.85,.94)
	geometry_material.roughness = .9
	for chunk in game.world.terrain_chunks: chunk.material_override = geometry_material
	await capture("drifts_geometry_only")
	for chunk in game.world.terrain_chunks: chunk.material_override = game.world.snow_material
	game.skier.show()
	game.camera.reset()
	game._process(1.0/60.0)
	game.weather.set_time_of_day("night")
	game.world.update_weather(game.weather.state,0.0,false)
	for spray in game.effects.sprays: spray.speed_scale = 0.0
	# Allow realtime sky radiance to settle after replacing sunlight with moonlight.
	for frame in range(30): await process_frame
	await capture("night")
	var night_image = root.get_texture().get_image()
	for material in game.world.assets.surface_materials: material.set_shader_parameter("snow_sparkle_strength",0.0)
	await capture("night_crystals_disabled")
	var night_crystal_pixels = changed_pixels(night_image,root.get_texture().get_image())
	var report = {"captures":captures,"renderer":game.world.terrain_renderer,"eligible":game.session.eligible,"crashed":game.sim.crashed,"snow_depth_m":game.sim.snow_depth,"penetration_m":game.sim.snow_penetration,"snow_drag_m_s2":game.sim.snow_drag,"track_instances":game.effects.snow_tracks.written,"sun_crystal_pixels":crystal_pixels,"night_crystal_pixels":night_crystal_pixels,"sun_center_glints":sun_center_pixels,"shadow_center_glints":shade_center_pixels}
	FileAccess.open(output+"/playtest_%s.json" % game.world.terrain_renderer,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SNOW_PLAYTEST ",JSON.stringify(report))
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	quit(0 if not report.crashed and not report.eligible and crystal_pixels>10 and night_crystal_pixels==0 and sun_center_pixels>0 and shade_center_pixels<maxi(2,int(sun_center_pixels*.20)) else 1)

func changed_pixels(a: Image, b: Image, center_only: bool = false) -> int:
	var changed = 0
	# Sample every other pixel; ignore tiny quantization changes.
	var margin_x = int(a.get_width()*.35) if center_only else 0
	var margin_y = int(a.get_height()*.35) if center_only else 0
	for y in range(margin_y,a.get_height()-margin_y,2):
		for x in range(margin_x,a.get_width()-margin_x,2):
			var delta = a.get_pixel(x,y)-b.get_pixel(x,y)
			if maxf(absf(delta.r),maxf(absf(delta.g),absf(delta.b)))>0.025: changed += 1
	return changed

func capture(id: String) -> void:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/%s_%s.png" % [game.world.terrain_renderer,id])
	captures.append(id)
