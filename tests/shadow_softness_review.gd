extends "res://tests/targeted_performance.gd"
## Current production casters, plus two labelled-height diagnostic posts.
## --capture-map compares angular sizes; uncapped runs measure one selected size.
var selected_angle=0.0
var selected_preset=7
var views=[]
var motion=false
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--shadow-motion":motion=true
		if arg.begins_with("--shadow-angle="):selected_angle=float(arg.get_slice("=",1))
		if arg.begins_with("--shadow-preset="):selected_preset=int(arg.get_slice("=",1))
	assert(selected_preset in [4,7,10] and selected_angle>=-1 and selected_angle<=.6)
	super._initialize()
func prepare_start()->void:
	super.prepare_start()
	game.set_graphics_preset(selected_preset)
	if selected_angle>=0:
		game.world.sun.light_angular_distance=selected_angle
		game.world.moon.light_angular_distance=selected_angle
	game.world.update_weather(game.weather.state,0,false)
func capture_source_metadata(phase:String)->Dictionary:
	return metadata_command(["capture","--root",ProjectSettings.globalize_path("res://"),
		"--scope",ProjectSettings.globalize_path("res://config/benchmark_metadata_scope.json"),
		"--producer","tests/shadow_softness_review.gd","--extra-path","tests/targeted_performance.gd",
		"--engine",OS.get_executable_path()],output.path_join("inputs_"+phase+".json"))
func captures()->void:
	if motion:
		await moving_views();report.stop_reason="capture_complete";return
	game.set_process(false);game.hud.hide();game.set_physics_process(false)
	var camera=Camera3D.new();game.add_child(camera);camera.fov=62;camera.make_current()
	for item in [[6.0,1.0],[10.0,6.0]]:
		var node=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=Vector3(.3,item[1],.3)
		node.mesh=mesh;node.position=Vector3(item[0],game.field.sample(item[0],76).height+item[1]/2,76)
		var material=StandardMaterial3D.new();material.albedo_color=Color(.15,.18,.22);node.material_override=material;game.add_child(node)
	for preset in [4,7,10]:
		game.set_graphics_preset(preset)
		for band in ["day","dawn"]:
			game.weather.set_time_of_day(band);game.world.update_weather(game.weather.state,0,false)
			for view in ["contacts","forest"]:
				if view=="contacts":
					camera.position=Vector3(15,game.field.sample(15,60).height+6,60)
					camera.look_at(Vector3(3,game.field.sample(3,80).height+1,80))
				else:
					camera.position=Vector3(10,game.field.sample(10,42).height+8,42)
					camera.look_at(Vector3(0,game.field.sample(0,135).height+4,135))
				for angle in [0.0,.53]:
					game.world.sun.light_angular_distance=angle;game.world.moon.light_angular_distance=angle
					game.display_settings.reset_history()
					await picture("preset%d_%s_%s_%s"%[preset,band,view,"soft" if angle>0 else "reference"],preset,band,angle)
	game.set_graphics_preset(7);game.weather.set_time_of_day("night");game.world.update_weather(game.weather.state,0,false)
	for angle in [0.0,.53]:
		game.world.sun.light_angular_distance=angle;game.world.moon.light_angular_distance=angle
		game.display_settings.reset_history();await picture("night_"+("soft" if angle>0 else "reference"),7,"night",angle)
	report.stop_reason="capture_complete"
func picture(label:String,preset:int,band:String,angle:float)->void:
	for frame in 24:await process_frame
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image();check(image.get_size()==game.benchmark_resolution,"Actual capture pixels match")
	check(image.save_webp(output.path_join(label+".webp"),true)==OK,"Saved "+label)
	views.append({"image":label+".webp","preset":preset,"band":band,"angle":angle,"camera":str(root.get_camera_3d().global_transform),"shadow_filter":game.graphics.shadow_quality,"shadow_distance":game.graphics.shadow_distance_m})
	print("SHADOW_REVIEW_VIEW ",label)
func finish()->void:
	report.shadow_angle=selected_angle;report.shadow_preset=selected_preset;report.views=views
	report.diagnostic_posts="Capture only: 0.3m wide, 1m/6m tall at x6/x10,z76. Timing retains the unmodified perf-mixed population."
	await super.finish()

func moving_views()->void:
	game.set_process(false);game.set_physics_process(false);game.hud.hide()
	var camera=Camera3D.new();camera.fov=62;game.add_child(camera)
	# Identical camera travel over fixed production casters exposes crawling,
	# bias gaps and moving cascade boundaries without a camera-controller change.
	for item in [[4,"dawn"],[7,"day"],[7,"dawn"],[7,"night"],[10,"dawn"]]:
		for reference in [true,false]:
			if reference and item[0]==4:continue # Shipped preset 4 retains PCF.
			game.set_graphics_preset(item[0]);game.weather.set_time_of_day(item[1])
			game.world.update_weather(game.weather.state,0,false)
			if reference:
				game.world.sun.light_angular_distance=0;game.world.moon.light_angular_distance=0
			camera.make_current();game.display_settings.reset_history()
			for frame in 90:
				var z=42.0+float(frame)*1.2
				camera.position=Vector3(8,game.field.sample(8,z).height+6,z)
				camera.look_at(Vector3(0,game.field.sample(0,z+90).height+4,z+90))
				await process_frame;await RenderingServer.frame_post_draw
				if frame%9==0 or frame==89:
					var label="move_%d_%s_%s_%03d"%[item[0],item[1],"reference" if reference else "production",frame]
					var image=root.get_texture().get_image();check(image.get_size()==game.benchmark_resolution,"Actual moving capture pixels match")
					check(image.save_webp(output.path_join(label+".webp"),true)==OK,"Saved "+label)
					views.append({"image":label+".webp","preset":item[0],"band":item[1],"angle":game.world.sun.light_angular_distance,"camera":str(camera.global_transform),"frame":frame,"shadow_filter":game.graphics.shadow_quality,"shadow_distance":game.graphics.shadow_distance_m})
			print("SHADOW_REVIEW_MOTION ",item," reference=",reference)
