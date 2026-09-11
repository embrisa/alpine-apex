extends RefCounted
## Warm Standard fixture using production archive/source/restore validation.
## A missing fixture is a setup failure, never an implicit multi-minute bake.
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")

static func load_standard(candidates: Array[String] = []):
	var started := Time.get_ticks_usec()
	var job = Cache.Job.new()
	var settings: Dictionary = Cache.Settings.preset()
	var seed_number: int = Cache.Terrain.DEFAULT_SEED
	var key: String = Cache.cache_key(seed_number,settings,job)
	var paths: Array[String] = candidates.duplicate()
	if paths.is_empty():
		paths.append(Cache.path_for(seed_number,settings))
		if not OS.has_feature("editor"):
			paths.append(OS.get_executable_path().get_base_dir().path_join("data/default_mountain_v15.physical"))
	for path in paths:
		job.begin_stage("physical_cache_read")
		var data: Dictionary = Cache.Archive.read(path,key,job)
		if data.is_empty(): continue
		var field = Cache.restore(seed_number,settings,data,job)
		if field == null: continue
		job.end_stage("physical_cache_read")
		field.cache_hit = true
		field.generation_ms = (Time.get_ticks_usec()-started)/1000.0
		field.generation_stages = job.snapshot().timings_ms
		field.generation_stages.original_bake_ms = data.meta.bake_ms
		field.generation_stages.cache_source = "user" if path.begins_with("user://") else "fixture"
		print("VALIDATION_CACHE_READY milliseconds=",field.generation_ms," path=",path)
		return field
	print("VALIDATION_CACHE_MISS Prepare the current Standard mountain explicitly (normal generation or tests/generation_v15_baseline.gd), then rerun. No cold generation was started.")
	return null
