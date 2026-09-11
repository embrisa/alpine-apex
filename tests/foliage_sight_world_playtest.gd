extends "res://tests/performance_descent.gd"
## Short ordinary-input comparisons on the densest sampled part of the v15 trace.
var fixture_tick=0
func run() -> void:
	output="res://artifacts/foliage_v3/sight_world_wide"
	DirAccess.make_dir_recursive_absolute(output)
	trace=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/foliage_v3/descent_input.json"))
	field=Definition.generate(849205174,15); field.build_material_map()
	if not Trace.matches(field,trace.identity): printerr("SIGHT_TRACE_IDENTITY_CHANGED"); quit(2); return
	var simulation=load("res://scripts/core/ski_simulation.gd").new(preload("res://config/ski_default.tres").duplicate(true))
	simulation.reset(field.launch_point(trace.heading),trace.heading); simulation.prime_contacts(field)
	var site={"count":-1}
	for tick in 34001:
		if tick%120==0:
			var count=field.tree_data.nearby(simulation.position,18).size()
			if count>site.count:
				site={"count":count,"tick":tick,"position":simulation.position,"velocity":simulation.velocity,"heading":simulation.heading}
		simulation.step(1.0/120,super.input_at_tick(tick),field)
	print("SIGHT_WORLD_SITE ",JSON.stringify(site))
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Forest visibility review"),"field":field})
	game=load("res://main.tscn").instantiate(); game.automated=true; root.add_child(game); current_scene=game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_physics_process(false); game.set_process(false)
	game.benchmark_input=input_at_tick; game.benchmark_no_captures=true
	game.camera_settings.load_preferences(); game.camera.settings=game.camera_settings
	game.display_settings.frame_generation=false; game.display_settings.fps_limit=60
	game.display_settings.apply_display(root,Vector2i(3840,2160)); game.display_settings.apply_viewport(root)
	var cases=[]
	for weather in ["clear","snowfall"]:
		for close in [true,false]:
			for strength in [0.0,60.0]:
				fixture_tick=site.tick
				var id="%s_%s_%s" % [weather,"first_person" if close else "chase","before" if strength==0 else "after"]
				game.start_run(false); game.summit_ready=false; game.physics_modified=true; game.session.eligible=false
				game.sim.reset(site.position,site.heading); game.sim.prime_contacts(field); game.sim.velocity=site.velocity
				game.previous_position=game.sim.position; game.skier.reset_animation(game.sim)
				game.camera_settings.forest_visibility=strength; game.camera.close_view=close; game.camera.reset()
				game.hud.hide_menu(); game.weather.set_preset(weather); game.weather.set_time_of_day("day")
				game.weather.visual_time=0; game.world.assets.wind_time=0; game.world.cloud_offset=Vector2.ZERO
				game.effects.reset(); game.weather_effects.reset(); game.active=true
				for frame in 180:
					game._process(1.0/60); await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output+"/"+id+".png")
				for frame in 90:
					game._physics_process(1.0/120); game._physics_process(1.0/120); game._process(1.0/60)
					await process_frame; await RenderingServer.frame_post_draw
					if frame%3==0: root.get_texture().get_image().save_jpg(output+"/%s_%03d.jpg" % [id,frame],.94)
					if game.sim.crashed: break
				cases.append({"id":id,"end":str(game.sim.position),"velocity":str(game.sim.velocity),"crash":game.sim.crash_reason,"sight":game.world.assets.foliage_sight.parameters})
				print("SIGHT_WORLD_CASE ",JSON.stringify(cases[-1]))
	game.active=false; game.hud.show_menu("paused"); game.hud.open_settings()
	game.hud.settings_tabs.current_tab=3
	game.hud.camera_setting_controls.forest_visibility.grab_focus()
	for frame in 45: game._process(1.0/60); await process_frame
	var camera_scroll=game.hud.settings_tabs.get_child(3) as ScrollContainer
	camera_scroll.scroll_vertical=int(camera_scroll.get_v_scroll_bar().max_value)
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(output+"/camera_settings.png")
	for i in range(0,cases.size(),2):
		if cases[i].end!=cases[i+1].end or cases[i].velocity!=cases[i+1].velocity: failures.append("Aid changes motion: "+cases[i].id)
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"site":site,"cases":cases,"display":game.display_settings.report(root,Vector2i(3840,2160)),"camera":game.camera_settings.snapshot(),"capture_overhead_included":true,"unranked":not game.session.eligible,"failures":failures},"\t"))
	game.effects.stop_audio(); game.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
func input_at_tick(tick: int) -> RiderInput: return super.input_at_tick(fixture_tick+tick)
