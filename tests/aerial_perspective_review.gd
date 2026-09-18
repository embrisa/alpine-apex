extends SceneTree
## Weather/handover review on the explicitly admitted warm Standard fixture.
const Definition=preload("res://scripts/world/mountain_definition.gd")
var output=""
var game
var field
var camera:Camera3D
var views=[]
var study=false
var timing=false
var timings=[]
var recording=false
var previous_frame=0
var unfocused=0
var samples={}
var failures=[]
var pixels=Vector2i(3840,2160)
func _initialize():call_deferred("run")
func run():
	assert(DisplayServer.get_name()!="headless")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg=="--study":study=true
		if arg=="--measure":timing=true
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")==("FpsCritical" if timing else "Exclusive"),"Use Exclusive for captures/cache refresh; FpsCritical only after warming the same sources")
	assert(not output.is_empty() and not DirAccess.dir_exists_absolute(output))
	DirAccess.make_dir_recursive_absolute(output)
	metadata("before")
	field=preload("res://tests/validation_mountain.gd").load_standard()
	if field==null:quit(2);return
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Aerial perspective"),"field":field})
	game=load("res://main.tscn").instantiate();game.automated=true;game.benchmark_no_captures=true
	root.add_child(game);current_scene=game
	while not game.initialized or (game.loading and game.loading.busy):await process_frame
	game.set_process(false);game.set_physics_process(false);game.set_audio_muted(true)
	game.start_run(false);game.summit_ready=false;game.session.eligible=false
	game.weather.set_automatic(false);game.weather.set_time_cycle(false)
	game.display_settings.display.apply(root,pixels,true);game.display_settings.apply_viewport(root);Engine.max_fps=0 if timing else 30
	game.hud.hide_menu();game.hud.root.hide();game.skier.hide()
	camera=Camera3D.new();camera.fov=68;camera.far=32000;game.add_child(camera);camera.make_current()
	for particle in game.effects.sprays+game.weather_effects.volumes+game.weather_effects.drifts:particle.speed_scale=0
	if timing:
		await costs()
	else:
		var conditions=[["clear","day"]] if study else [["clear","day"],["clear","dawn"],["clear","dusk"],["clear","night"],["cloudy","day"],["snowfall","day"],["snowstorm","day"]]
		for condition in conditions:
			game.weather.set_preset(condition[0]);game.weather.set_time_of_day(condition[1])
			for mode in (["reference","engine","shared"] if study else ["reference","production"]):
				select_mode(mode)
				for site in ["ride","summit","collar"]:
					place(site);game.world.update_weather(game.weather.state,0,false);game.display_settings.reset_history()
					await picture("%s_%s_%s_%s"%[condition[0],condition[1],site,mode])
		if not study:
			game.weather.set_preset("clear");game.weather.set_time_of_day("day");place("collar")
			for strength in [.5,1.5]:
				game.world.quality.fog_strength=strength
				await game.world.wilderness.apply_quality(game.world.quality)
				select_mode("production");await picture("fog_strength_"+str(strength))
	metadata("after")
	var differences=metadata_command(["compare","--before",output+"/inputs_before.json","--after",output+"/inputs_after.json"],output+"/input_changes.json")
	if not differences.get("stable_inputs",false):failures.append("Input metadata drift")
	preload("res://tests/test_report.gd").write(output+"/results.json",JSON.stringify({"views":views,"timings":timings,"failures":failures,"stable_sources":differences.get("stable_inputs",false),"pixels":[pixels.x,pixels.y],"display":game.display_settings.report(root,pixels),"generator":Definition.CURRENT_VERSION,"seed":field.seed_value,"scope":"Stationary full-mountain fog cost; not skiing FPS" if timing else "Capped full-mountain boundary/depth-plane review; no FPS or human acceptance"},"\t"))
	print("AERIAL_REVIEW_COMPLETE views=",views.size())
	game.effects.stop_audio();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
func place(site:String):
	var heading:float=field.faces[0].heading;var forward=Vector3(sin(heading),0,cos(heading))
	if site=="summit":
		camera.position=field.spawn_point()+Vector3.UP*65;camera.look_at(camera.position+forward*10000+Vector3.DOWN*1900)
	elif site=="ride":
		var p:Vector2=field.faces[0].to_world(Vector2(0,950));camera.position=Vector3(p.x,field.sample(p.x,p.y).height+6,p.y)
		camera.look_at(camera.position+forward*1000+Vector3.DOWN*220)
	else:
		camera.position=Vector3(2835,field.sample(2835,0).height+1.8,0);camera.look_at(camera.position+Vector3(1000,-80,0))
func shared_trial():
	var s=game.weather.state;var env=game.world.environment
	var sky:Color=s.sky_horizon.srgb_to_linear().lerp(s.sky_top.srgb_to_linear(),.55).lerp(s.cloud_color.srgb_to_linear(),s.cloud_coverage*.45)
	var color:Color=(s.fog_color.srgb_to_linear()*env.fog_light_energy).lerp(sky,.4)
	env.fog_light_color=color.linear_to_srgb();env.fog_light_energy=1;env.fog_density*=1.3
	var wilderness=game.world.wilderness
	for material in [wilderness.material,wilderness.apron_material]+wilderness.props.materials:
		material.set_shader_parameter("offmap_fog_color",Vector3(color.r,color.g,color.b));material.set_shader_parameter("offmap_depth_density",env.fog_density)
func picture(label:String):
	for frame in 24:await process_frame
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image();assert(image.get_size()==pixels);assert(image.save_webp(output+"/"+label+".webp",true)==OK)
	var env=game.world.environment
	views.append({"image":label+".webp","camera":str(camera.global_transform),"weather":game.weather.selected_preset,"hour":game.weather.daylight.hour,"fog_color":str(env.fog_light_color),"fog_energy":env.fog_light_energy,"fog_density":env.fog_density,"aerial":env.fog_aerial_perspective})
	print("AERIAL_REVIEW_VIEW ",label)

func select_mode(mode:String):
	game.world.weather_values.clear();game.world.render_state.clear();game.world.wilderness.weather_values.clear()
	game.world.update_weather(game.weather.state,0,false)
	game.world.environment.fog_aerial_perspective=0
	if mode in ["reference","engine","shared"]:
		# Explicit current experiment control only; never a production fallback.
		var s=game.weather.state;var env=game.world.environment
		var golden=smoothstep(0.0,.16,s.sun_direction.y)*(1.0-smoothstep(.20,.98,s.cloud_coverage))
		env.fog_light_color=s.fog_color;env.fog_light_energy=lerpf(.75,.85,golden);env.fog_density=s.fog_density*game.world.quality.fog_strength
		var color:Color=s.fog_color.srgb_to_linear()*env.fog_light_energy
		var wilderness=game.world.wilderness
		for material in [wilderness.material,wilderness.apron_material]+wilderness.props.materials:
			material.set_shader_parameter("offmap_fog_color",Vector3(color.r,color.g,color.b));material.set_shader_parameter("offmap_depth_density",s.fog_density)
			material.set_shader_parameter("offmap_valley_density",lerpf(.000035,.000085,s.cloud_coverage) if s.enabled else 0.0)
	if mode=="engine":game.world.environment.fog_aerial_perspective=.45
	if mode=="shared":shared_trial()

func costs():
	game.weather.set_preset("clear");game.weather.set_time_of_day("day");place("ride")
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);root.grab_focus()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().get_size()==pixels)
	process_frame.connect(sample_frame)
	for mode in ["reference","reference","production"]:
		select_mode(mode);game.display_settings.reset_history();await create_timer(3.0).timeout
		samples={"frame_ms":[],"gpu_ms":[],"render_cpu_ms":[]};previous_frame=0;unfocused=0
		var before:Dictionary=game.display_settings.fsr_status();var started=Time.get_ticks_usec();recording=true
		await create_timer(6.0).timeout
		recording=false;var after:Dictionary=game.display_settings.fsr_status()
		var row={"mode":mode,"seconds":(Time.get_ticks_usec()-started)/1000000.0,"unfocused_frames":unfocused,"fsr_before":before,"fsr_after":after}
		for key in samples:
			row[key]=preload("res://scripts/diagnostics/frame_costs.gd").stats(samples[key])
			if samples[key].size()<30 or not samples[key].all(func(v):return is_finite(v) and v>0):failures.append("Invalid "+key)
		row.fps=1000.0/row.frame_ms.mean;row.camera=str(camera.global_transform);timings.append(row)
		if unfocused>0 or not root.has_focus():failures.append("Unfocused timing")
		if after.get("frame_generation_active",false) or not str(after.get("error","")).is_empty():failures.append("Unexpected FSR status")
		if after.get("upscale_dispatches",0)<=before.get("upscale_dispatches",0):failures.append("No fresh upscaler dispatches")
		var presents=int(after.get("rendered_present_calls",0))-int(before.get("rendered_present_calls",0))
		if absi(presents-samples.frame_ms.size())>maxi(5,ceili(samples.frame_ms.size()*.03)):failures.append("Rendered presents disagree")
		preload("res://tests/test_report.gd").write(output+"/samples_%d.json"%timings.size(),JSON.stringify(samples))
		print("AERIAL_COST ",JSON.stringify(row))
	process_frame.disconnect(sample_frame)
func sample_frame():
	if not recording:return
	var now=Time.get_ticks_usec()
	if previous_frame>0:
		samples.frame_ms.append((now-previous_frame)/1000.0)
		samples.gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		samples.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		if not root.has_focus() or not game.application_focused or root.mode==Window.MODE_MINIMIZED:unfocused+=1
	previous_frame=now
func metadata(phase:String):
	return metadata_command(["capture","--root",ProjectSettings.globalize_path("res://"),"--scope",ProjectSettings.globalize_path("res://config/benchmark_metadata_scope.json"),"--producer","tests/aerial_perspective_review.gd","--engine",OS.get_executable_path()],output+"/inputs_"+phase+".json")
func metadata_command(arguments:Array,destination:String)->Dictionary:
	var args=PackedStringArray([ProjectSettings.globalize_path("res://scripts/benchmark_metadata.py")]);var messages=[]
	for argument in arguments:args.append(str(argument))
	args.append_array(PackedStringArray(["--output",ProjectSettings.globalize_path(destination)]))
	assert(OS.execute("python",args,messages,true)==0,str(messages))
	return JSON.parse_string(FileAccess.get_file_as_string(destination))
