extends SceneTree
## Capped Standard views for coupled tone/ambient/material review. Never timing.
const Definition=preload("res://scripts/world/mountain_definition.gd")
const Survey=preload("res://tests/alpine_v13_route_survey.gd")
var output="res://artifacts/snow_appearance_20260918/before"
var game
var field
var camera:Camera3D
var captures=[]
var sites=[]
var materials=[]
var tone_study=false
var motion=false
var supplement=false
var wind_samples=[]
var pixels=Vector2i(3840,2160)
func _initialize():call_deferred("run")
func run():
	assert(DisplayServer.get_name()!="headless")
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Exclusive","Standard scenery may need refreshed preparation; reserve Exclusive admission")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output="res://"+arg.get_slice("=",1)
		if arg=="--tone-study":tone_study=true
		if arg=="--motion":motion=true
		if arg=="--supplement":supplement=true
	assert(not DirAccess.dir_exists_absolute(output),"Preserve previous captures")
	DirAccess.make_dir_recursive_absolute(output)
	field=preload("res://tests/validation_mountain.gd").load_standard()
	if field==null:quit(2);return
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Snow appearance"),"field":field})
	game=load("res://main.tscn").instantiate();game.automated=true;game.benchmark_no_captures=true
	root.add_child(game);current_scene=game
	while not game.initialized or (game.loading and game.loading.busy):await process_frame
	game.set_process(false);game.set_physics_process(false);game.set_audio_muted(true)
	game.start_run(false);game.session.eligible=false;game.summit_ready=false
	game.weather.set_automatic(false);game.weather.set_time_cycle(false)
	game.display_settings.display.apply(root,pixels,true)
	game.display_settings.upscaler="auto";game.display_settings.render_scale=.75
	game.display_settings.apply_viewport(root);Engine.max_fps=30
	game.hud.hide_menu();game.hud.root.hide()
	camera=Camera3D.new();camera.fov=68;camera.far=15000;game.add_child(camera)
	for material in game.world.assets.surface_materials+[game.effects.snow_tracks.material,game.world.scenery.powder_caps.material,game.effects.powder_surface.material]:
		if material and material not in materials:materials.append(material)
	for particle in game.effects.sprays+game.weather_effects.volumes+game.weather_effects.drifts:
		particle.use_fixed_seed=true;particle.seed=849205174+particle.get_index();particle.speed_scale=0
	choose_sites()
	preload("res://tests/test_report.gd").write(output+"/wind_signal.json",JSON.stringify({"sites":sites,"samples":wind_samples,"source":"Existing Standard presentation environment alpha; no generated noise or world changes"},"\t"))
	if supplement:
		await extra_views()
	else:
		for condition in [["clear","day"],["clear","dawn"],["clear","dusk"],["clear","night"],["cloudy","day"],["snowstorm","day"]]:
			place(sites[0],condition[0],condition[1],false)
			wide_view()
			await capture("wide_"+condition[0]+"_"+condition[1])
			if condition==["clear","day"] and tone_study:
				var env=game.world.environment;var exposure=env.tonemap_exposure;var white=env.tonemap_white
				for trial in [["exposure_only",.95,white],["curve_pair",.85,1.8]]:
					env.tonemap_exposure=trial[1];env.tonemap_white=trial[2];game.display_settings.reset_history()
					await capture("tone_"+trial[0])
				env.tonemap_exposure=exposure;env.tonemap_white=white
		for site in sites:
			for close in [false,true]:
				place(site,"clear","day",close)
				await capture(site.name+("_first_person" if close else "_chase"))
				if motion:await ride(site.name+("_first_person" if close else "_chase"))
		place(sites[0],"clear","day",false)
		game.skier.hide();camera.make_current()
		var p:Vector3=game.sim.position;var normal:Vector3=field.contact_normal(p.x,p.z)
		var sun:Vector3=game.weather.state.sun_direction
		var reflection=(-sun+normal*2.0*normal.dot(sun)).normalized()
		if reflection.y<.12:reflection=(normal+Vector3.UP).normalized()
		for distance_m in [4.0,16.0]:
			camera.position=p+reflection*distance_m+Vector3.UP*.2;camera.look_at(p)
			await capture("detail_%d_full"%distance_m)
			for component in [["crystals","snow_sparkle_strength"],["sheen","snow_sheen_strength"],["normals","detail_strength"],["hollows","snow_hollows_strength"]]:
				var saved=[]
				for material in materials:
					saved.append(material.get_shader_parameter(component[1]));material.set_shader_parameter(component[1],0.0)
				game.display_settings.reset_history();await capture("detail_%d_without_%s"%[distance_m,component[0]])
				for i in materials.size():materials[i].set_shader_parameter(component[1],saved[i])
		place(sites[0],"clear","day",false);game.hud.root.show()
		await capture("bright_snow_hud")
	preload("res://tests/test_report.gd").write(output+"/review.json",JSON.stringify({"captures":captures,"sites":sites,"pixels":[pixels.x,pixels.y],"display":game.display_settings.report(root,pixels),"model":game.sim.MODEL_VERSION,"generator":Definition.CURRENT_VERSION,"scope":"Standard cached mountain required for authored wind range and near/mid/far lighting; fixed/capped rendered evidence only, no performance or human acceptance"},"\t"))
	print("SNOW_APPEARANCE_COMPLETE captures=",captures.size())
	game.effects.stop_audio();game.queue_free();await process_frame;quit()
func choose_sites():
	var data=game.world.assets.mountain
	var image:Image=data.environment_image
	for face in field.faces:
		for z in range(600,2001,200):
			for x in [-600.0,-300.0,0.0,300.0,600.0]:
				var p:Vector2=face.to_world(Vector2(x,z))
				if field.contact_normal(p.x,p.y).y<.78 or field.rock_fraction_at(p.x,p.y)>.12:continue
				var grid=(p-data.ORIGIN)/data.EXTENT*Vector2(image.get_size()-Vector2i.ONE)
				var cell=Vector2i(grid.floor()).clamp(Vector2i.ZERO,image.get_size()-Vector2i(2,2));var weight=grid-Vector2(cell)
				var a=image.get_pixel(cell.x,cell.y).a;var b=image.get_pixel(cell.x+1,cell.y).a
				var c=image.get_pixel(cell.x,cell.y+1).a;var d=image.get_pixel(cell.x+1,cell.y+1).a
				var wind=lerpf(lerpf(a,b,weight.x),lerpf(c,d,weight.x),weight.y)
				wind_samples.append({"p":[p.x,p.y],"heading":face.heading,"wind":wind,"clear":Survey.clear_at(field,p,10)})
	wind_samples.sort_custom(func(a,b):return a.wind<b.wind)
	var clear=wind_samples.filter(func(s):return s.clear)
	assert(clear.size()>3,"Need existing traversable snow samples")
	for item in [["soft",.1],["packed",.5],["scoured",.9]]:
		var chosen=clear[roundi((clear.size()-1)*item[1])].duplicate();chosen.name=item[0];sites.append(chosen)
func place(site:Dictionary,weather:String,band:String,close:bool):
	game.start_run(false);game.set_physics_process(false);game.automated_ticks=0;game.screenshot_ticks=[]
	game.summit_ready=false;game.session.eligible=false
	game.weather.set_preset(weather);game.weather.set_time_of_day(band)
	game.weather.cloud_x=0;game.weather.cloud_z=0;game.weather.visual_time=0;game.weather._sample()
	var p=Vector2(site.p[0],site.p[1]);game.sim.reset(Vector3(p.x,field.sample(p.x,p.y).height,p.y),site.heading)
	game.sim.prime_contacts(game.world.ski_surface);game.sim.velocity=game.sim.support_basis().z*25
	game.sim.reset_pose_history();game.previous_position=game.sim.position;game.skier.reset_animation(game.sim);game.skier.show()
	game.camera.close_view=close;game.camera.reset();game.camera.make_current();game.menu_camera.leave()
	game.active=true;game._process(0);game.active=false
	freeze_particles();game.hud.hide_menu();game.hud.root.hide();game.display_settings.reset_history()
func wide_view():
	var forward:Vector3=game.sim.ski_forward;var p:Vector3=game.sim.position
	camera.position=p-forward*8+Vector3.UP*6;camera.look_at(p+forward*65+Vector3.UP*10);camera.make_current()
	game.world.update_weather(game.weather.state,0,false)
func freeze_particles():
	for particle in game.effects.sprays+game.weather_effects.volumes+game.weather_effects.drifts:particle.speed_scale=0
func capture(label:String):
	for frame in 12:await process_frame
	await RenderingServer.frame_post_draw
	var picture=root.get_texture().get_image();assert(picture.get_size()==pixels)
	var path=output+"/"+label+".webp";assert(picture.save_webp(path,true)==OK)
	captures.append({"label":label,"image":path,"camera":str(root.get_camera_3d().global_transform),"position":str(game.sim.position),"ticks":game.sim.ticks,"weather":game.weather.selected_preset,"hour":game.weather.daylight.hour,"exposure":game.world.environment.tonemap_exposure,"white":game.world.environment.tonemap_white,"crashed":game.sim.crashed})
	print("SNOW_APPEARANCE_VIEW ",label)
func ride(label:String):
	game.active=true
	for frame in 60:
		for tick in 4:game._physics_process(1.0/120.0)
		game._process(1.0/30.0);freeze_particles();await process_frame
		if frame%10==0 or frame==59:await capture(label+"_move_%03d"%frame)
	game.active=false

func extra_views():
	# Correct initial framing and check native reconstruction at the same sites.
	for site in sites:
		for close in [false,true]:
			place(site,"clear","day",close)
			assert(game.presentation_camera==game.camera and not game.summit_ready)
			assert(game.camera.position.distance_to(game.sim.position)<30)
			await capture(site.name+("_first_person" if close else "_chase"))
	place(sites[0],"clear","day",false);game.hud.root.show()
	await capture("bright_snow_hud")
	for condition in [["clear","day"],["clear","dawn"],["clear","dusk"],["clear","night"],["cloudy","day"],["snowstorm","day"]]:
		place(sites[0],condition[0],condition[1],false);wide_view()
		await capture("ambient_"+condition[0]+"_"+condition[1]+"_on")
		RenderingServer.global_shader_parameter_set(&"snow_ambient_top",Vector4.ZERO)
		game.display_settings.reset_history()
		await capture("ambient_"+condition[0]+"_"+condition[1]+"_off")
		# Invalidate only diagnostic cache entries so publication restores globals.
		game.world.render_state.values[game.world.environment].erase(&"snow_ambient_top")
		game.world._publish_snow_ambient(game.weather.state)
	# Isolate lee arithmetic without altering the accepted relief or saved controls.
	var originals=[];var variants=[]
	for material in materials:
		originals.append(material.shader)
		var source=material.shader.code
		var include='#include "res://assets/graphics/alpine_surface_fragment.gdshaderinc"'
		if include in source:
			var fragment=FileAccess.get_file_as_string("res://assets/graphics/alpine_surface_fragment.gdshaderinc")
			fragment=fragment.replace(" lee*=clamp(deposit"," lee=0.0; lee*=clamp(deposit")
			var shader=Shader.new();shader.code=source.replace(include,fragment);variants.append(shader)
		else:variants.append(material.shader)
	for close in [false,true]:
		place(sites[0],"clear","day",close)
		for reconstruction in ["auto","native"]:
			game.display_settings.upscaler=reconstruction;game.display_settings.render_scale=.75 if reconstruction=="auto" else 1.0
			game.display_settings.apply_viewport(root);game.display_settings.reset_history()
			var label="lee_"+("first_person" if close else "chase")+"_"+reconstruction
			await capture(label+"_on")
			for i in materials.size():materials[i].shader=variants[i]
			game.display_settings.reset_history();await capture(label+"_off")
			for i in materials.size():materials[i].shader=originals[i]
	game.display_settings.upscaler="auto";game.display_settings.render_scale=.75;game.display_settings.apply_viewport(root)
