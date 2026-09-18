extends SceneTree
## Chronological production weather/camera evidence on the small contact fixture.
## Captures are visual evidence only; no FPS or controller acceptance.
var game
var output="res://artifacts/cloud_motion_20260918/before"
var clips=[]
var suite="clouds"
var cloud_reference=false
var pixels=Vector2i(1920,1080)
func _initialize():call_deferred("run")
func run():
	assert(DisplayServer.get_name()!="headless")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output="res://"+arg.get_slice("=",1)
		if arg.begins_with("--suite="):suite=arg.get_slice("=",1)
		if arg=="--cloud-reference":cloud_reference=true
	assert(suite in ["clouds","snow","sky"])
	assert(not DirAccess.dir_exists_absolute(output),"Preserve earlier evidence")
	DirAccess.make_dir_recursive_absolute(output)
	set_meta("test_map_fixture","perf-slopes" if suite=="snow" else "smooth-slope")
	Engine.max_fps=30
	game=load("res://main.tscn").instantiate();game.automated=true;game.benchmark_no_captures=true
	root.add_child(game);current_scene=game
	while not game.initialized or (game.loading and game.loading.busy):await process_frame
	game.set_process(false);game.set_physics_process(false);game.set_audio_muted(true)
	pixels=Vector2i(1920,1080) if suite=="clouds" else Vector2i(3840,2160)
	# Exact output avoids retaining a previous fullscreen viewport rectangle.
	game.display_settings.display.apply(root,pixels,true)
	game.display_settings.upscaler="native" if suite=="clouds" else "auto"
	game.display_settings.render_scale=1.0 if suite=="clouds" else .75
	game.display_settings.apply_viewport(root)
	for frame in 6:await process_frame
	game.weather.set_automatic(false);game.weather.set_time_cycle(false)
	game.weather.set_time_of_day("day")
	if suite=="clouds":
		game.camera_settings.shared.auto_recenter=false
		for preset in ["cloudy","snowfall","rain","snowstorm"]:
			for close in [false,true]:await capture_clip(preset,close)
	elif suite=="snow":
		for speed in [90.0,140.0]:
			for preset in ["clear","cloudy","snowfall","snowstorm"]:
				for close in [false,true]:await capture_clip(preset,close,speed,"day",60)
	else:
		game.camera_settings.shared.auto_recenter=false
		game.camera_settings.update_profile("chase",{"rest_tilt":25.0,"fast_tilt":25.0,"slope_follow":0.0,"rest_fov":68.0,"fast_fov":68.0})
		for band in ["day","dusk","night","dawn"]:
			for preset in ["clear","snowstorm"]:await capture_clip(preset,false,90.0,band,90)
		await capture_clip("cloudy",false,90.0,"night",90)
	preload("res://tests/test_report.gd").write(output+"/review.json",JSON.stringify({"clips":clips,"pixels":[pixels.x,pixels.y],"capture_hz":30,"suite":suite,"cloud_reference":cloud_reference,"fixture":game.field.fixture_descriptor(),"scope":"Chronological rendered weather and camera; no FPS or human acceptance"},"\t"))
	game.effects.stop_audio();game.queue_free();await process_frame;quit()
func capture_clip(preset:String,close:bool,speed:float=60.0,band:String="day",frame_count:int=180):
	var label=preset+("_first_person" if close else "_chase")
	if suite!="clouds":label+="_%d_%s"%[speed,band]
	var folder=output+"/"+label;DirAccess.make_dir_recursive_absolute(folder)
	game.start_run(false);game.set_physics_process(false)
	game.automated_ticks=0;game.screenshot_ticks=[]
	var origin_z=96.0 if suite=="snow" else 0.0
	game.sim.reset(Vector3(0,game.field.sample(0,origin_z).height,origin_z),0);game.sim.prime_contacts(game.field)
	game.sim.velocity=Vector3.BACK.slide(game.sim.surface_normal).normalized()*speed/3.6
	game.previous_position=game.sim.position;game.skier.reset_animation(game.sim)
	game.camera.close_view=close;game.camera.reset();game.menu_camera.leave();game.camera.make_current()
	game.weather.set_preset(preset);game.weather.set_time_of_day(band);game.weather.cloud_x=0;game.weather.cloud_z=0
	game.weather.visual_time=0;game.weather._sample();game.weather_effects.reset()
	game.hud.hide_menu();game.hud.root.hide();game.active=true
	game.display_settings.reset_history()
	var frames=[]
	for frame in frame_count:
		for tick in 4:game._physics_process(1.0/120.0)
		if suite=="sky":game.camera.look_yaw=deg_to_rad((float(frame)/frame_count-.5)*60.0)
		if suite=="clouds":game.camera.look_pitch=deg_to_rad(30.0)
		game._process(1.0/30.0)
		if suite=="clouds" and cloud_reference:
			# Isolate the old wind-to-cloud mapping without editing live owners.
			game.weather.cloud_offset=Vector2(game.weather.cloud_x,game.weather.cloud_z)
			game.weather.state.cloud_offset=game.weather.cloud_offset
			game.world.update_weather(game.weather.state,0,false)
		for particle in game.weather_effects.volumes+game.weather_effects.drifts+game.effects.sprays:
			particle.speed_scale=0.0
			if particle.visible:particle.request_particles_process(1.0/30.0)
		await process_frame
		if frame%10==0 or frame==frame_count-1 or (suite=="sky" and preset=="clear" and band=="night"):
			await RenderingServer.frame_post_draw
			var path=folder+"/%03d.webp"%frame
			var picture=root.get_texture().get_image()
			assert(picture.get_size()==pixels,"Actual capture %s must match requested %s"%[picture.get_size(),pixels])
			assert(picture.save_webp(path,true)==OK)
			frames.append({"frame":frame,"time":(frame+1)/30.0,"cloud_offset":str(game.weather.cloud_offset),"camera":str(game.camera.global_transform),"image":path})
	clips.append({"label":label,"frames":frames,"speed_kmh":speed,"final_cloud_offset":str(game.weather.cloud_offset),"physical_wind":str(game.weather.state.wind_velocity),"crashed":game.sim.crashed,"particle_budget":game.weather_effects.particle_budget()})
	print("CLOUD_MOTION_CLIP ",label)
