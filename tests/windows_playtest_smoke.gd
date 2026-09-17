extends SceneTree
## Run externally against an exported PCK with isolated APPDATA and the bundle.
var started_ms = 0

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func _initialize() -> void:
	started_ms = Time.get_ticks_msec()
	call_deferred("run")

func run() -> void:
	var out = OS.get_environment("ALPINE_SMOKE_OUT")
	if not require(not out.is_empty(),"Set ALPINE_SMOKE_OUT"): return
	var cache = load("res://scripts/world/mountain_cache_v16.gd")
	if not require(not FileAccess.file_exists(cache.path_for(849205174)),"Test requires an empty user mountain cache"): return
	if not require(FileAccess.file_exists(OS.get_executable_path().get_base_dir().path_join("data/default_mountain_v16.physical")),"Bundled bake missing"): return
	if not require(not ProjectSettings.has_setting("autoload/MCPRuntimeServer"),"Development autoload was not stripped"): return
	if not require(not cache.Archive.read(OS.get_executable_path().get_base_dir().path_join("data/default_mountain_v16.physical"),cache.cache_key(849205174)).is_empty(),"Bundled bake does not match the exported engine and source data"): return
	started_ms = Time.get_ticks_msec()
	print("PLAYTEST_FIRST_LAUNCH_BEGIN ",OS.get_user_data_dir())
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	while not game.initialized or game.loading.busy:
		await process_frame
	var ready_ms = Time.get_ticks_msec()-started_ms
	if not require(game.field.cache_hit and game.field.generation_stages.get("cache_source")=="bundled","First launch must use the validated bundled bake"): return
	if not require(game.world.preparation!=null and game.world.preparation.cache_hit,"Bundled scenery preparation must be reused"): return
	if not require(game.field.GENERATOR_VERSION==16 and game.effects.wind.available,"World version or native audio incorrect"): return
	var estimates = load("res://scripts/world/generation_estimates.gd")
	var standard_estimate = estimates.estimate(game.field.seed_value,game.field.generation_settings)
	if not require(standard_estimate.physical_cache_expected and standard_estimate.preparation_cache_expected,"Default estimates must recognize both bundled caches"): return
	var custom_settings = game.field.generation_settings.duplicate(); custom_settings.tree_spacing = .67
	var custom_estimate = estimates.estimate(game.field.seed_value,custom_settings)
	if not require(not custom_estimate.physical_cache_expected and not custom_estimate.preparation_cache_expected,"Custom estimates must not reuse the Standard bundle hint"): return
	game.display_settings.display_mode = "windowed"
	game.display_settings.fps_limit = 60
	game.display_settings.apply_display(root,Vector2i(1280,720))
	game.display_settings.apply_viewport(root)
	for frame in 60: await process_frame
	await RenderingServer.frame_post_draw
	if not require(root.get_texture().get_image().save_png(out.path_join("menu.png"))==OK,"Menu capture failed"): return
	await game.mountain_library.open()
	var library = game.mountain_library
	library.advanced_toggle.button_pressed = false
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("richness_standard.png"))
	library._preset_changed(4); library.settings_controls.tree_population.value = 1.01; library.settings_controls.tree_spacing.value = .67
	var create_scroll = library.tabs.get_current_tab_control()
	if not require(create_scroll.size.y>=300,"Mountain controls have insufficient usable height"): return
	create_scroll.ensure_control_visible(library.settings_controls.tree_spacing)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("richness_custom.png"))
	create_scroll.ensure_control_visible(library.estimates_label)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("richness_estimates.png"))
	library._apply_settings(game.field.generation_settings); library.advanced_toggle.button_pressed = false; library.close()
	game.start_run(false)
	game.summit_drop_armed = true
	game.drop_from_summit()
	var origin: Vector3 = game.sim.position
	for frame in 240: await process_frame
	await RenderingServer.frame_post_draw
	if not require(root.get_texture().get_image().save_png(out.path_join("skiing.png"))==OK,"Skiing capture failed"): return
	if not require(game.sim.position.distance_to(origin)>1.0,"Skier did not move downhill"): return
	if not require(not game.preferences_enabled and not game.timed,"Test must not write player preferences or timed records"): return
	var result = {"ready_ms":ready_ms,"cache_ms":game.field.generation_ms,"scene_ms":game.world.generation_ms,"cache_source":game.field.generation_stages.cache_source,"preparation_cache":game.world.preparation.cache_hit,"bundled_estimate_hints":true,"custom_estimate_separation":true,"physics_model":game.sim.MODEL_VERSION,"height_sha256":game.field.height_checksum,"obstacle_sha256":game.field.obstacle_checksum,"movement_m":game.sim.position.distance_to(origin),"native_wind":game.effects.wind.available,"graphics":game.display_settings.report(root,Vector2i(1280,720))}
	preload("res://tests/test_report.gd").write(out.path_join("results.json"),JSON.stringify(result,"\t"))
	print("PLAYTEST_FIRST_LAUNCH_PASS ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0)
