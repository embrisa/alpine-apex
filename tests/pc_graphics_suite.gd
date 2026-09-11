extends SceneTree
const Settings = preload("res://scripts/presentation/pc_graphics_settings.gd")
var checks = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run() -> void:
	set_meta("test_lab_fixture",true) # Explicit laboratory regression fixture.
	var settings = Settings.new()
	check(settings.quality==2 and settings.upscaler=="auto" and not settings.frame_generation and settings.render_scale==.75 and settings.fps_limit==120 and not settings.terrain_gi,"PC defaults select High, automatic 75% upscaling, frame generation off and 120 FPS")
	settings.apply_arguments(["--graphics-quality=low","--render-scale=0.1","--fps-limit=75","--upscaler=invalid"])
	check(settings.quality==0 and is_equal_approx(settings.render_scale,2.0/3.0) and settings.fps_limit==120 and settings.upscaler=="auto","Invalid display arguments are bounded without disabling valid settings")
	settings.apply_arguments(["--graphics-quality=high","--display-mode=windowed","--upscaler=native","--fps-limit=90","--terrain-gi=on"])
	var path = "res://artifacts/pc_graphics_test.cfg"
	check(settings.save_preferences(path)==OK,"Display preferences save to an isolated test file")
	var restored = Settings.new()
	restored.load_preferences(path)
	check(restored.snapshot()==settings.snapshot(),"All graphics and display choices round-trip across application launches")
	settings.restore({"render_scale":NAN,"quality":-5,"display_mode":"broken","terrain_gi":"not a bool"})
	check(settings.quality==0 and settings.render_scale==.75 and settings.display_mode=="fullscreen" and settings.terrain_gi,"Malformed preference fields retain safe typed defaults")
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.start_run(true)
	game.session.eligible = true # Explicit ranked identity fixture; no run is saved.
	var identity = [game.session.eligible,game.session.course_id,game.physics_modified,tuning_state(game)]
	for setting in [["upscaler","native"],["render_scale",2.0/3.0],["fps_limit",90],["terrain_gi",true],["upscaler","fsr2"]]:
		game.hud.display_setting_requested.emit(setting[0],setting[1])
	game.set_graphics_quality(1)
	check([game.session.eligible,game.session.course_id,game.physics_modified,tuning_state(game)]==identity,"Display and graphics controls preserve ranked eligibility, tuning and course identity")
	check(game.world.environment.sdfgi_enabled,"Terrain GI override is independent of the preset")
	game._remember_world_settings()
	var reload_state: Dictionary = get_meta("world_reload_settings")
	check(reload_state.display==game.display_settings.snapshot(),"Mountain scene reload carries the complete display state")
	remove_meta("world_reload_settings")
	game.restart()
	check(game.display_settings.fps_limit==90 and game.display_settings.terrain_gi,"Restart retains display controls")
	check(not game.preferences_enabled,"Automated tests never write the player's graphics preferences")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://art_source/pc_environment_manifest.json"))
	var hashes = true
	var budgets = true
	var masks = true
	var checked_lods = 0
	for asset in manifest.assets:
		hashes = hashes and FileAccess.get_sha256("res://"+asset.path)==asset.sha256 and asset.roundtrip_verified
		if int(asset.get("lod",-1)) in [0,1]:
			checked_lods += 1
			var mesh = game.world.assets.mesh(asset.asset)
			budgets = budgets and mesh.get_surface_count()==1 and mesh.get_faces().size()/3 <= (32000 if asset.lod==0 else 12000)
			var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			var wood = false
			var foliage = false
			var snow = false
			var clusters = false
			for color in colors:
				wood = wood or color.a<.25
				foliage = foliage or (color.a>.25 and color.a<.75)
				snow = snow or color.a>.8
				clusters = clusters or (color.a>.55 and color.a<.75)
			masks = masks and wood and foliage and snow and clusters
	for atlas in manifest.atlases:
		hashes = hashes and FileAccess.get_sha256("res://"+atlas.path)==atlas.sha256
	check(hashes and manifest.assets.size()==33,"All 33 runtime asset hashes match independently reimported Blender exports")
	check(budgets and checked_lods==18,"All 18 conifer near/mid LODs retain one surface and bounded geometry budgets")
	check(masks and checked_lods==18,"All 18 GLB imports preserve wood, needle, cutout cluster and snow masks")
	game.set_graphics_quality(2)
	check(game.world.assets.texture("snow","albedo").get_width()==4096 and game.world.assets.texture("rock","normal").get_width()==4096,"High binds real 4K scanned surface maps")
	if DisplayServer.get_name()!="headless":
		game.display_settings.apply_display(root,Vector2i(3840,2160))
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		var pixels = root.get_texture().get_image().get_size()
		check(pixels==Vector2i(3840,2160),"Native Windows output is exactly 3840 by 2160 pixels")
		check(root.scaling_3d_mode==Viewport.SCALING_3D_MODE_FSR2 and root.msaa_3d==Viewport.MSAA_DISABLED,"FSR2 owns temporal antialiasing without redundant MSAA")
	var result = {"checks":checks,"failures":failures,"native":DisplayServer.get_name()!="headless"}
	FileAccess.open("res://artifacts/pc_graphics_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PC_GRAPHICS_RESULTS ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func tuning_state(game) -> Dictionary:
	var result = {}
	for property in game.sim.tuning.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: result[property.name] = game.sim.tuning.get(property.name)
	return result
