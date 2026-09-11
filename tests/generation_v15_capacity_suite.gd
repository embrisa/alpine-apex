extends SceneTree
## Synthetic capacity, deliberately independent of natural placement saturation.
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")
const Trees = preload("res://scripts/world/packed_trees.gd")
const Forest = preload("res://scripts/presentation/forest_placement.gd")
const Scenery = preload("res://scripts/world/alpine_scenery.gd")
const Density = preload("res://scripts/presentation/density_forest.gd")
const Assets = preload("res://scripts/presentation/alpine_assets.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
const Clouds = preload("res://scripts/presentation/cloud_lighting.gd")
var failures: Array = []
var checks = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var field = Cache.generate(849205174)
	if not field: quit(2); return
	var start = Time.get_ticks_usec(); field.tree_data = Trees.new()
	for z in 1000:
		for x in 1000:
			var p = Vector3(-2797.2+x*5.6,0,-2797.2+z*5.6); p.y = field.height_at(p.x,p.z)
			field.tree_data.append(p,.46,11,1,float((x+z)%37)*.1,z*1000+x)
	field.tree_data.build_index()
	var report = {"synthetic":true,"unranked":true,"trees":field.tree_data.size(),"data_and_index_ms":(Time.get_ticks_usec()-start)/1000.0}
	check(field.tree_data.size()==1000000 and field.tree_data.valid() and field.obstacles.is_empty(),"One million packed trees with no dictionary population")
	var collide = Time.get_ticks_usec(); var hits = 0
	for id in range(100100,900900,997):
		var p: Vector3 = field.tree_data.positions[id]
		var hit = field._sweep_trees(p+Vector3(-2,1,0),p+Vector3(2,1,0))
		if hit.get("id",-1)==id: hits += 1
	check(hits==range(100100,900900,997).size(),"Collision query reaches indexed members across million-tree population")
	report.collision_ms = (Time.get_ticks_usec()-collide)/1000.0; report.collision_queries = hits
	field.population.trees = 1000000; field.population.requested_trees = 1000000
	field.generation_settings = Cache.Settings.preset(3)
	field.obstacle_checksum = "SYNTHETIC-CAPACITY-1M".sha256_text()
	var path = "res://artifacts/generation_v15/synthetic_capacity.physical"
	var key = "SYNTHETIC-CAPACITY-ARCHIVE".sha256_text(); var job = Cache.Job.new()
	start = Time.get_ticks_usec()
	check(Cache.Archive.write(path,key,Cache.sections(field),job),"Million-tree physical archive publishes")
	report.cache_write_ms = (Time.get_ticks_usec()-start)/1000.0
	start = Time.get_ticks_usec()
	var data = Cache.Archive.read(path,key,job)
	var restored = Cache.restore(field.seed_value,field.generation_settings,data,job); data.clear()
	check(restored!=null and restored.tree_data.positions==field.tree_data.positions and restored.tree_data.links==field.tree_data.links,"Million-tree cache restores complete indexed population")
	report.cache_read_restore_ms = (Time.get_ticks_usec()-start)/1000.0
	restored = null; DirAccess.remove_absolute(path)
	if DisplayServer.get_name()!="headless":
		root.borderless = true; root.position = DisplayServer.screen_get_position(root.current_screen); root.size = Vector2i(3840,2160); root.content_scale_size = Vector2i(3840,2160); Engine.max_fps = 120
		var host = Scenery.new(); root.add_child(host)
		host.quality = Quality.preset(2); host.dense_woodlands = true
		host.assets = Assets.new(Clouds.new(),host.quality)
		var metadata = Forest.metadata(host.assets)
		var prepared = Forest.new(); var worker = Thread.new(); start = Time.get_ticks_usec()
		worker.start(prepared.build.bind(field,metadata,job))
		while worker.is_alive(): await process_frame
		worker.wait_to_finish()
		report.scenery_preparation_ms = (Time.get_ticks_usec()-start)/1000.0
		check(prepared.poses.size()==12000000 and prepared.positions.size()==1000000,"One million shared prepared tree poses")
		var prep = preload("res://scripts/world/mountain_preparation.gd").new()
		prep.forest = prepared
		worker = Thread.new(); worker.start(func():
			prep.mountain.generate(field,field.seed_value,job); prep.terrain.build(field,job); prep.readability.prepare(field,job); prep._build_minerals(field,job))
		while worker.is_alive(): await process_frame
		worker.wait_to_finish()
		var scenery_cache = preload("res://scripts/world/scenery_cache.gd")
		var scenery_path = "res://artifacts/generation_v15/synthetic_capacity.scenery"
		start = Time.get_ticks_usec()
		check(scenery_cache.save(prep,field,host.quality,job,scenery_path),"Million-tree scenery archive publishes outside production caches")
		report.scenery_cache_write_ms = (Time.get_ticks_usec()-start)/1000.0
		var restored_prep = preload("res://scripts/world/mountain_preparation.gd").new(); start = Time.get_ticks_usec()
		check(scenery_cache.load_into(restored_prep,field,host.quality,job,scenery_path) and restored_prep.forest.poses==prepared.poses,"Million-tree scenery cache restores shared poses and regional buffers")
		report.scenery_cache_read_ms = (Time.get_ticks_usec()-start)/1000.0
		restored_prep = null
		var rejected = preload("res://scripts/world/mountain_preparation.gd").new()
		check(not scenery_cache.load_into(rejected,field,Quality.preset(1),job,scenery_path),"Scenery cache rejects different graphics settings")
		var original_height: String = field.height_checksum; field.height_checksum = "DIFFERENT-PHYSICAL-SURFACE".sha256_text()
		check(not scenery_cache.load_into(rejected,field,host.quality,job,scenery_path),"Scenery cache rejects different physical fingerprints")
		field.height_checksum = original_height
		var corrupt = FileAccess.open(scenery_path,FileAccess.READ_WRITE); corrupt.seek(corrupt.get_length()-1); var last_byte = corrupt.get_8(); corrupt.seek(corrupt.get_length()-1); corrupt.store_8(last_byte^1); corrupt.close()
		check(not scenery_cache.load_into(rejected,field,host.quality,job,scenery_path),"Corrupt scenery section is rejected before submission")
		rejected = null; prep = null; DirAccess.remove_absolute(scenery_path)
		var density = Density.new(); host.add_child(density); density.use_prepared(prepared)
		start = Time.get_ticks_usec(); await density.finish(host,checkpoint)
		report.gpu_submission_ms = (Time.get_ticks_usec()-start)/1000.0
		var uploaded = 0
		for batch in host.batches: uploaded += batch.multimesh.instance_count
		check(uploaded==1000000,"Native distant forest uploads every tree")
		var camera = Camera3D.new(); root.add_child(camera); camera.far = 16000
		var p: Vector3 = field.tree_data.positions[500500]; camera.position = p+Vector3(0,6,-12); camera.position.y = maxf(camera.position.y,field.height_at(camera.position.x,camera.position.z)+2)
		var aim = p+Vector3(0,3,20); aim.y = field.height_at(aim.x,aim.z)+3; camera.look_at(aim); camera.current = true
		density.update_residency(camera.position)
		for frame in 180: await process_frame
		var samples: Array = []; var last = Time.get_ticks_usec()
		for frame in 360:
			await process_frame; var now = Time.get_ticks_usec(); samples.append((now-last)/1000.0); last = now
		samples.sort(); report.frame_ms = {"p95":samples[342],"p99":samples[356],"samples":360}
		var pixels = root.get_texture().get_size()
		check(pixels==Vector2(3840,2160),"Native capacity fixture renders actual 4K pixels")
		report.actual_pixels = [int(pixels.x),int(pixels.y)]
		report.video_memory_bytes = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
		report.residency = density.report()
		for id in [0,100100,500500,999999]: check(prepared.pose_at(id).origin==prepared.positions[id],"Shared pose indexed access %d" % id)
		host.queue_free(); camera.queue_free(); await process_frame
	report.checks = checks; report.failures = failures; report.memory_peak = OS.get_static_memory_peak_usage()
	FileAccess.open("res://artifacts/generation_v15/capacity_"+("headless" if DisplayServer.get_name()=="headless" else "native")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("V15_CAPACITY ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
func checkpoint(_message: String, _progress: float) -> void: await process_frame
