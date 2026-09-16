extends SceneTree
## Matched v14 production captures; --baseline records the pre-air-tilt model.
const DT = 1.0/120.0
const Definition = preload("res://scripts/world/mountain_definition.gd")
var game
var output = "res://artifacts/arcade_air_v27/after"
var baseline = false
var rows: Array = []
var label: Label
var side_camera: Camera3D

func _initialize(): call_deferred("run")

func run():
	if DisplayServer.get_name()=="headless": quit(2); return
	baseline = "--baseline" in OS.get_cmdline_user_args()
	if baseline and preload("res://scripts/core/ski_simulation.gd").MODEL_VERSION!=26:
		printerr("Baseline capture requires the preserved model 26 sources; use a new --output for current candidates.")
		quit(2); return
	if baseline: output = "res://artifacts/arcade_air_v27/before"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var field = Definition.generate(849205174,Definition.CURRENT_VERSION)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Arcade air validation"),"field":field})
	game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.start_run(false); game.summit_ready = false; game.session.eligible = false; game.active = false
	game.effects.muted = true; game.effects.reset_haptics(); game.hud.hide(); game.hud.hide_menu()
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.display_settings.display_mode = "windowed"; game.display_settings.upscaler = "native"
	game.display_settings.render_scale = 1.0; game.display_settings.fps_limit = 120
	game.display_settings.apply_display(root,Vector2i(1280,720)); game.display_settings.apply_viewport(root)
	var overlay = CanvasLayer.new(); root.add_child(overlay)
	label = Label.new(); overlay.add_child(label); label.position = Vector2(18,14)
	label.add_theme_font_size_override("font_size",21); label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2); label.add_theme_constant_override("shadow_offset_y",2)
	side_camera = Camera3D.new(); game.add_child(side_camera); side_camera.fov = 55
	for i in 60: await process_frame
	var cases = ["hop","tilt","frontflip","backflip","double_flip","switch_flip","spin_flip","reverse","landing"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): cases = [arg.trim_prefix("--case=")]
	for scenario in cases:
		if scenario not in ["hop","tilt","frontflip","backflip","double_flip","switch_flip","spin_flip","reverse","landing","turn"]:
			printerr("Unknown arcade air case: ",scenario); quit(2); return
	for scenario in cases: await ride(scenario,field)
	var sources = {}
	for path in ["scripts/core/air_rotation.gd","scripts/core/ski_simulation.gd","scripts/core/rider_body.gd","scripts/core/rider_input.gd","scripts/core/input_router.gd","scripts/core/ski_tuning.gd","config/ski_default.tres","scripts/presentation/skier_full_motion.gd","scripts/presentation/skier_visual.gd","scripts/presentation/skier_pose_writer.gd","assets/animation/steep_ski_motion.res","assets/graphics/models/skier_v7.glb","tests/arcade_air_playtest.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image().get_size()
	var report = {"model":game.sim.MODEL_VERSION,"engine":Engine.get_version_info(),"seed":849205174,"generator":14,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"pixels":[pixels.x,pixels.y],"record_eligible":game.session.eligible,"sources":sources,"cases":rows,"fps":30,"capture_overhead_included":true}
	preload("res://tests/test_report.gd").write(output+"/results.json",JSON.stringify(report,"\t"))
	print("ARCADE_AIR_CAPTURE ",output," cases=",rows.size())
	game.effects.stop_audio(); game.queue_free(); await process_frame; quit()

func ride(scenario: String, field):
	var face = field.faces[0]
	var point: Vector2 = face.to_world(Vector2(face.gully_x(820.0,-1),820.0))
	var height = 0.0 if scenario=="hop" else (3.0 if scenario=="landing" else 32.0)
	game.sim.reset(Vector3(point.x,field.sample(point.x,point.y).height+height,point.y),face.heading)
	game.sim.prime_contacts(game.world.ski_surface)
	game.sim.velocity = game.sim.support_basis().z*20.0+Vector3.UP*(0.0 if scenario=="hop" else 3.0)
	if height>0: game.sim._begin_flight(game.sim.support_basis())
	if scenario=="switch_flip": game.sim.facing_backward = true; game.sim.facing_pose.capture(game.sim,true)
	game.skier.reset_animation(game.sim); game.camera.reset(); game.effects.reset()
	var trace = []; var tick_cost: Array[float] = []; var initial = game.sim.position
	for view in ["chase","side"]: DirAccess.make_dir_recursive_absolute(output+"/"+scenario+"_"+view)
	for frame_index in 90:
		var intent = RiderInput.new()
		for substep in 4:
			var tick = frame_index*4+substep
			var t = tick*DT
			intent = RiderInput.new()
			if scenario=="hop": intent.jump_held = t<.4; intent.jump = tick==48
			if scenario=="tilt":
				var tilt = 1.0 if t<.3 or (t>=.5 and t<1.2) else (-1.0 if t>=1.5 and t<2.5 else 0.0)
				# Explicit historical comparison: v26 did not have limited pitch.
				if not baseline: intent.set("air_tilt",tilt)
				intent.tuck = maxf(0.0,tilt)
			if scenario in ["frontflip","backflip","switch_flip","landing"]:
				intent.air_pitch = (-1.0 if scenario=="backflip" else 1.0) if tick<94 else 0.0
			if scenario=="double_flip": intent.air_pitch = 1.0 if tick<188 else 0.0
			if scenario=="spin_flip": intent.air_pitch = .7 if t<1.2 else 0.0; intent.air_yaw = .7 if t<1.2 else 0.0
			if scenario=="reverse": intent.air_pitch = 1.0 if t<.4 else (-1.0 if t<.9 else 0.0)
			if scenario=="turn": intent.steer = 1.0 if t<.7 else (-1.0 if t>=1.0 and t<1.7 else 0.0)
			var start = Time.get_ticks_usec()
			game.sim.step(DT,intent,game.world.ski_surface)
			tick_cost.append(Time.get_ticks_usec()-start)
			game.skier.step_animation(DT,game.sim,intent,field)
		game.intent = intent; game.session.elapsed = (frame_index+1)/30.0
		game._process(1.0/30.0); game.skier.pose(game.sim,1.0); game.speed_periphery.hide()
		var center: Vector3 = game.sim.position+game.sim.support_basis().y*.65
		side_camera.position = center+Basis(Vector3.UP,face.heading)*Vector3(5,.5,0)
		side_camera.look_at(center)
		for view in ["chase","side"]:
			if view=="side": side_camera.make_current()
			else: game.camera.make_current()
			label.text = "MODEL %d / %s / %s / %.2f s"%[game.sim.MODEL_VERSION,scenario.to_upper(),view.to_upper(),(frame_index+1)/30.0]
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(output+"/"+scenario+"_"+view+"/%04d.jpg"%frame_index,.88)
		var q: Quaternion = game.sim.support_basis().get_rotation_quaternion()
		trace.append({"frame":frame_index,"q":[q.x,q.y,q.z,q.w],"position":str(game.sim.position),"pitch":game.sim.air_control.integrated_pitch,"omega":str(game.sim.air_control.angular_velocity),"grounded":game.sim.grounded,"clips":game.skier.animation.full_motion.weights.duplicate(true)})
		if game.sim.crashed: break
	rows.append({"name":scenario,"initial":str(initial),"trace":trace,"crash":game.sim.crash_reason,"airtime":game.sim.total_airtime,"landings":game.skier.animation.landing_events,"tick_us":tick_cost})
	print("ARCADE_AIR_CASE ",scenario," frames=",trace.size()," crash=",game.sim.crash_reason)
