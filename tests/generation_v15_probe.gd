extends SceneTree
const Terrain = preload("res://scripts/world/generators/alpine_massif_v15.gd")
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")
const Settings = preload("res://scripts/world/generation_settings.gd")
const Job = preload("res://scripts/world/generation_job.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var seed_number = 849205174; var settings = Settings.preset(); var job = Job.new(); var name = "first_standard"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_number = int(arg.get_slice("=",1))
		if arg.begins_with("--preset="): settings = Settings.preset(int(arg.get_slice("=",1)))
		if arg.begins_with("--workers="): job.worker_count = int(arg.get_slice("=",1))
		if arg.begins_with("--spacing="): settings.tree_spacing = float(arg.get_slice("=",1))
		if arg.begins_with("--name="): name = arg.get_slice("=",1).validate_filename()
	var field = Cache.generate(seed_number,settings,job)
	if field==null: printerr("V15_PROBE_FAILED"); quit(1); return
	var report = {"unranked":true,"engine":Engine.get_version_info().string,"seed":seed_number,"settings":settings,"workers":job.worker_count,
		"cache_hit":field.cache_hit,"generation_ms":field.generation_ms,"stages":field.generation_stages,"work":job.snapshot().work,"population":field.population,
		"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"snow":field.tree_snow_statistics,"memory_peak":OS.get_static_memory_peak_usage()}
	DirAccess.make_dir_recursive_absolute("res://artifacts/generation_v15")
	FileAccess.open("res://artifacts/generation_v15/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("V15_PROBE_READY ",JSON.stringify(report))
	quit()
