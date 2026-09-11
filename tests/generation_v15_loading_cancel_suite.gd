extends SceneTree
## Exercise the real startup Cancel button, including partial GPU construction.
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")
var failures: Array = []
var samples: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if "--ui-staged-loading" not in OS.get_cmdline_user_args(): quit(2); return
	DirAccess.make_dir_recursive_absolute("res://artifacts/generation_v15")
	var physical_path = Cache.path_for(849205174)
	var original_cache = FileAccess.get_sha256(physical_path)
	for phase in ["physical_cache_read","terrain_upload","background_preparation","background_upload","rider_and_interface","ready"]:
		var game = load("res://main.tscn").instantiate(); root.add_child(game)
		var observed = false; var deadline = Time.get_ticks_msec()+240000
		while Time.get_ticks_msec()<deadline:
			await process_frame
			if phase=="physical_cache_read":
				observed = game.loading.worker_snapshot_active and game.generation_job.snapshot().stage==phase
			elif phase=="terrain_upload":
				observed = game.world!=null and game.world.terrain_chunks.size()>=4
			elif phase=="background_preparation":
				observed = game.world!=null and game.world.wilderness!=null and game.loading.worker_snapshot_active
			elif phase=="background_upload":
				if game.world!=null and game.world.wilderness!=null:
					var staging = game.world.wilderness.get_node_or_null("RidgeBatches")
					observed = staging!=null and staging.get_child_count()>24 and staging.get_child(24).get_child_count()>=16
			elif phase=="ready":
				observed = game.initialized and game.loading.busy
			else:
				var progress: Dictionary = game.generation_job.snapshot()
				observed = progress.stage=="rider_and_interface" and progress.completed>=2
			if observed or game.initialized: break
		if not observed:
			failures.append("Did not reach cancellable stage "+phase); game.queue_free(); await process_frame; continue
		if phase=="terrain_upload":
			var snap: Dictionary = game.generation_job.snapshot()
			if snap.stage!="terrain_meshes_uploads" or snap.completed<4 or snap.total!=576: failures.append("GPU construction is absent from the shared job snapshot")
		var field_ref = weakref(game.field) if game.field else null
		var world_ref = weakref(game.world) if game.world else null
		var start = Time.get_ticks_usec(); game.loading.cancel_button.pressed.emit()
		while not game.loading.retry_button.visible and Time.get_ticks_usec()-start<10000000: await process_frame
		for frame in 3: await process_frame
		var joined_ms = (Time.get_ticks_usec()-start)/1000.0
		var good = game.field==null and game.world==null and game.loading.worker==null and game.loading.retry_button.visible
		good = good and (world_ref==null or world_ref.get_ref()==null) and (field_ref==null or field_ref.get_ref()==null) and not game.initialized
		if phase in ["rider_and_interface","ready"]: good = good and game.effects==null and game.skier==null and game.camera==null
		if not good or joined_ms>2000: failures.append("Startup cancellation failed at "+phase)
		samples.append({"stage":phase,"cancel_ms":joined_ms,"partial_world_released":good})
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/generation_v15/cancel_"+phase+".png")
		if phase!="physical_cache_read" and not has_meta("mountain_retry_recipe"): failures.append("Retry lost the selected mountain recipe")
		game.queue_free(); await process_frame
		remove_meta("mountain_retry_recipe")
	if FileAccess.get_sha256(physical_path)!=original_cache: failures.append("Startup cancellation changed the existing physical cache")
	var report = {"samples":samples,"failures":failures,"native":DisplayServer.get_name()!="headless"}
	FileAccess.open("res://artifacts/generation_v15/loading_cancellation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("V15_LOADING_CANCELLATION ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
