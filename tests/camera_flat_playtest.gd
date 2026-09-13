extends SceneTree
## Frozen production flat-pad views, optionally paired with an archived camera.
## No solver descent, personal preferences, records or performance measurement.
const Camera = preload("res://scripts/presentation/chase_camera.gd")
var output = "res://artifacts/camera_flat/visual"
var baseline = ""
var game
var rows: Array = []
var failures: Array = []

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--baseline-script="): baseline = arg.trim_prefix("--baseline-script=")
	if DirAccess.dir_exists_absolute(output):
		push_error("Choose a fresh camera capture output"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	Engine.max_fps = 30
	set_meta("test_map_fixture","flat-pad")
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized: await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.effects.haptic_hardware_enabled = false
	game.effects.muted = true; game.voice.set_muted(true)
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "native"
	game.display_settings.render_scale = 1.0
	game.display_settings.fps_limit = 30
	game.display_settings.apply_display(root,Vector2i(1280,720))
	game.display_settings.apply_viewport(root)
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.hud.hide(); game.session.eligible = false
	game.sim.reset(Vector3.ZERO,0)
	game.sim.prime_contacts(game.field)
	game.skier.reset_animation(game.sim)
	game.skier.pose(game.sim,1.0)
	for frame in 5: await process_frame
	for preset in game.CameraSettings.BUILT_INS:
		for kmh in [0,120]:
			for close in [false,true]:
				for variant in (["before","after"] if not baseline.is_empty() else ["after"]):
					var cam = (load(baseline) if variant=="before" else Camera).new()
					cam.settings.apply_preset("first_person" if close else "chase",preset)
					cam.close_view = close
					cam.near = game.camera.near; cam.far = game.camera.far
					game.add_child(cam); cam.make_current()
					game.sim.velocity = Vector3.BACK*kmh/3.6
					cam.update_camera(game.sim,game.field,game.sim.position,0)
					for frame in 4: await process_frame
					await RenderingServer.frame_post_draw
					var label = "%s_%s_%d_%s" % [preset.to_lower(),"pov" if close else "chase",kmh,variant]
					var pixels = root.get_texture().get_image()
					if pixels.get_size()!=Vector2i(1280,720) or pixels.save_png(output+"/"+label+".png")!=OK:
						failures.append(label+": capture failed or incorrect dimensions")
					var horizon = cam.unproject_position(cam.position+Vector3.BACK*10000)/Vector2(root.size)
					var row = {"label":label,"pitch_degrees":rad_to_deg(asin(-cam.global_basis.z.y)),
						"horizon_y":horizon.y,"position":str(cam.position),"fov":cam.fov,"skier_visible":true}
					if not close:
						for point in [Vector3(0,.05,-1),Vector3.UP*.8,Vector3.UP*1.65]:
							row.skier_visible = row.skier_visible and not cam.is_position_behind(point) and root.get_visible_rect().has_point(cam.unproject_position(point))
					if variant=="after" and (horizon.y<.15 or horizon.y>.55 or not row.skier_visible):
						failures.append(label+": horizon or skier framing")
					rows.append(row)
					cam.queue_free(); await process_frame
	var report = {"map":game.field.fixture_descriptor(),"engine":Engine.get_version_info().string,
		"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),
		"source_sha256":FileAccess.get_sha256("res://scripts/presentation/chase_camera.gd"),
		"baseline_sha256":FileAccess.get_sha256(baseline) if not baseline.is_empty() else "",
		"preferences_enabled":game.preferences_enabled,"unranked":not game.session.eligible,
		"solver_ticks":game.sim.ticks,"captures":rows,"failures":failures}
	FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CAMERA_FLAT_REVIEW ",JSON.stringify(report))
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
