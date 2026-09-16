extends "res://tests/technical_showcase_playtest.gd"
## Matched native presentation fixtures. Never a timing or ranked run.
var fixture_metadata: Array = []

func inspect_views() -> void:
	if "--quality-only" in OS.get_cmdline_user_args():
		await inspect_quality()
		return
	if "--canopy-only" in OS.get_cmdline_user_args():
		await inspect_canopy()
		return
	game.active = false
	game.set_process(false)
	game.hud.root.hide()
	var observer = Camera3D.new()
	game.add_child(observer)
	observer.far = 15000.0
	observer.fov = 75.0
	observer.make_current()
	game.weather.set_time_of_day("day")
	game.weather.visual_time = 0.0
	game.world.cloud_offset = Vector2.ZERO
	for section in [900,1370,2170]:
		var x = field.glade_x(section,-1) if section>1900 else field.gully_x(section,-1)
		var p = Vector3(x,field.sample(x,section).height,section)
		game.sim.reset(p,0)
		game.sim.prime_contacts(field)
		game.skier.hide()
		observer.position = p+Vector3.UP*1.75
		for preset in (["clear"] if "--quick" in OS.get_cmdline_user_args() else ["clear","cloudy","snowfall","rain"]):
			game.weather.set_preset(preset)
			var sun_horizontal: Vector3 = game.weather.state.sun_direction*Vector3(1,0,1)
			for angle in [0,90,180]:
				var direction = sun_horizontal.normalized().rotated(Vector3.UP,deg_to_rad(angle))
				observer.look_at(observer.position+direction+Vector3.DOWN*.10)
				game.world.update_weather(game.weather.state,0.0,false)
				await capture("%s_%d_%s" % [preset,section,["toward","across","away"][angle/90]],60)
				if "--shaft-probe" in OS.get_cmdline_user_args():
					for strength in [0.0,8.0,32.0]:
						game.world.environment.volumetric_fog_enabled = strength>0.0
						game.world.sun.light_volumetric_fog_energy = strength
						await capture("probe_%d_%d_energy%d" % [section,angle,strength],30)
	for time in (["day"] if "--quick" in OS.get_cmdline_user_args() else ["dawn","dusk","night"]):
		game.weather.set_preset("clear")
		game.weather.set_time_of_day(time)
		game.world.update_weather(game.weather.state,0.0,false)
		await capture(time+"_forest",60)
	observer.queue_free()
	game.skier.show()
	game.camera.make_current()
	game.weather.set_time_of_day("day")
	game.set_process(true)
	preload("res://tests/test_report.gd").write(OUTPUT+"/fixtures.json",JSON.stringify(fixture_metadata,"\t"))
	if "--include-canopy" in OS.get_cmdline_user_args(): await inspect_canopy()

func capture(label: String, settle_frames: int = 30) -> void:
	await super.capture(label,settle_frames)
	var cam = game.get_viewport().get_camera_3d()
	fixture_metadata.append({"name":label,"position":var_to_str(cam.global_position),"basis":var_to_str(cam.global_basis),"fov":cam.fov,"weather":game.weather.selected_preset,"hour":game.weather.daylight.hour,"cloud_offset":var_to_str(game.world.cloud_offset),"sun_direction":var_to_str(game.weather.state.sun_direction),"sun_energy":game.world.sun.light_energy,"sun_color":game.world.sun.light_color.to_html(),"exposure":game.world.environment.tonemap_exposure,"white":game.world.environment.tonemap_white,"sha_height":field.height_checksum,"sha_obstacles":field.obstacle_checksum})
	fixture_metadata.back().shafts = game.world.environment.volumetric_fog_enabled
	fixture_metadata.back().shaft_energy = game.world.sun.light_volumetric_fog_energy

func inspect_canopy() -> void:
	game.active = false
	game.set_process(false)
	game.hud.root.hide()
	game.skier.hide()
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	game.world.cloud_offset = Vector2.ZERO
	var observer = Camera3D.new()
	game.add_child(observer)
	observer.far = 15000
	observer.fov = 75
	observer.make_current()
	var trees: Array = []
	var glade = Vector3(field.glade_x(2170,-1),0,2170)
	for ob in field.obstacles:
		if ob.tree and ob.scale>1.1 and absf(ob.position.z-2170)<100:
			trees.append(ob)
	trees.sort_custom(func(a,b): return (a.position*Vector3(1,0,1)).distance_squared_to(glade)<(b.position*Vector3(1,0,1)).distance_squared_to(glade))
	var direction: Vector3 = game.weather.state.sun_direction
	var horizontal = (direction*Vector3(1,0,1)).normalized()
	for index in mini(2,trees.size()):
		for distance_m in [8.0,14.0]:
			var p: Vector3 = trees[index].position-horizontal*distance_m
			p.y = field.sample(p.x,p.z).height+1.75
			observer.position = p
			observer.look_at(p+direction)
			game.world.update_weather(game.weather.state,0.0,false)
			var label = "canopy_%d_%dm" % [index,distance_m]
			await capture(label,60)
			game.world.environment.volumetric_fog_enabled = false
			await capture(label+"_shafts_off",30)
			game.world.update_weather(game.weather.state,0.0,false)
			game.world.sun.shadow_enabled = false
			await capture(label+"_occlusion_off",30)
			game.world.sun.shadow_enabled = true
	preload("res://tests/test_report.gd").write(OUTPUT+"/fixtures.json",JSON.stringify(fixture_metadata,"\t"))
	observer.queue_free()
	game.camera.make_current()
	game.skier.show()
	game.set_process(true)

func inspect_quality() -> void:
	game.active = false
	game.set_process(false)
	game.hud.root.hide()
	game.skier.hide()
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	game.world.cloud_offset = Vector2.ZERO
	var observer = Camera3D.new()
	game.add_child(observer)
	observer.far = 15000
	observer.fov = 75
	observer.make_current()
	var x: float = field.glade_x(2170,-1)
	observer.position = Vector3(x,field.sample(x,2170).height+1.75,2170)
	var direction = (game.weather.state.sun_direction*Vector3(1,0,1)).normalized()
	observer.look_at(observer.position+direction+Vector3.DOWN*.10)
	for level in [0,1,2]:
		game.set_graphics_quality(level)
		game.world.update_weather(game.weather.state,0.0,false)
		await capture("quality_"+game.graphics.label(),60)
	preload("res://tests/test_report.gd").write(OUTPUT+"/fixtures.json",JSON.stringify(fixture_metadata,"\t"))
	observer.queue_free()
	game.camera.make_current()
	game.skier.show()
	game.set_process(true)
