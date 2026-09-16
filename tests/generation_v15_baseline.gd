extends SceneTree
const Terrain = preload("res://scripts/world/generators/alpine_massif_v15.gd")
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")
const Archive = preload("res://scripts/world/mountain_archive.gd")
const Job = preload("res://scripts/world/generation_job.gd")
const Estimates = preload("res://scripts/world/generation_estimates.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report = {"engine":Engine.get_version_info(),"unranked":true,"version":15,"seed":849205174,"physical_source_sha256":Cache.Sources.signature(),"settings":Cache.Settings.preset(),"runs":[]}
	var failed = false
	for repetition in 4:
		var job = Job.new(); job.worker_count = 6 if repetition<3 else 1
		var field = Terrain.new(849205174,true,{},job)
		if not field.valid: quit(1); return
		var row = {"repetition":repetition+1,"workers":job.worker_count,"cold_ms":field.generation_ms,"stages":field.generation_stages.duplicate(),"work":job.snapshot().work,
			"trees":field.tree_data.size(),"minerals":field.geology.placements.size(),"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"memory_static":OS.get_static_memory_usage(),"memory_peak":OS.get_static_memory_peak_usage()}
		job.begin_stage("physical_cache_write")
		var wrote = Archive.write(Cache.path_for(849205174),Cache.cache_key(849205174),Cache.sections(field),job)
		job.end_stage("physical_cache_write"); row.cache_write_ms = job.snapshot().timings_ms.physical_cache_write
		Estimates.record(field,0)
		field = null
		var warm = Cache.generate(849205174)
		row.cache_hit = warm!=null and warm.cache_hit
		row.physical_cache_ms = warm.generation_ms if warm else -1
		row.cache_matches = warm!=null and warm.height_checksum==row.height_sha256 and warm.obstacle_checksum==row.obstacle_sha256
		warm = null
		row.matches_first = repetition==0 or (row.height_sha256==report.runs[0].height_sha256 and row.obstacle_sha256==report.runs[0].obstacle_sha256)
		failed = failed or not wrote or not row.cache_hit or not row.cache_matches or not row.matches_first
		report.runs.append(row)
		DirAccess.make_dir_recursive_absolute("res://artifacts/generation_v15")
		preload("res://tests/test_report.gd").write("res://artifacts/generation_v15/v15_baseline.json",JSON.stringify(report,"\t"))
		print("V15_PROFILE_RUN ",JSON.stringify(row))
	print("V15_PROFILE_COMPLETE failed=",failed)
	quit(1 if failed else 0)
