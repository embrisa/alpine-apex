extends SceneTree
const Profile = preload("res://tests/v14_generation_profile.gd")
const Cache = preload("res://scripts/world/mountain_cache_v14.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/generation_v15")
	var report = {"engine":Engine.get_version_info(),"unranked":true,"version":14,"seed":849205174,"runs":[]}
	for repetition in 3:
		var field = Profile.new(849205174)
		var row = {"repetition":repetition+1,"cold_ms":field.generation_ms,"stages":field.generation_stages.duplicate(),"trees":field.obstacles.size(),"minerals":field.geology.placements.size(),"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"memory_static":OS.get_static_memory_usage(),"memory_peak":OS.get_static_memory_peak_usage()}
		field = null
		var warm = Cache.generate(849205174)
		row.cache_hit = warm.cache_hit
		row.physical_cache_ms = warm.generation_ms
		row.cache_matches = warm.height_checksum==row.height_sha256 and warm.obstacle_checksum==row.obstacle_sha256
		warm = null
		report.runs.append(row)
		preload("res://tests/test_report.gd").write("res://artifacts/generation_v15/v14_baseline.json",JSON.stringify(report,"\t"))
		print("V14_PROFILE_RUN ",JSON.stringify(row))
	print("V14_PROFILE_COMPLETE")
	quit()
