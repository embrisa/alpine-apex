extends SceneTree
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")
const Prep = preload("res://scripts/world/mountain_preparation.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var failures: Array = []
var samples: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var recipe_job = Cache.Job.new(); var recipe_worker = Thread.new()
	recipe_worker.start(func(): return Cache.Terrain.new(73810291,true,{},recipe_job))
	await create_timer(.025).timeout; var recipe_start = Time.get_ticks_usec(); recipe_job.cancel()
	while recipe_worker.is_alive(): await process_frame
	var cancelled_recipe = recipe_worker.wait_to_finish()
	if cancelled_recipe.valid or Time.get_ticks_usec()-recipe_start>2000000: failures.append("Early recipe cancellation failed")
	samples.append({"stage":"recipe","join_ms":(Time.get_ticks_usec()-recipe_start)/1000.0})
	cancelled_recipe = null; recipe_worker = null
	var prior_path = Cache.path_for(849205174); var previous_hash = FileAccess.get_sha256(prior_path)
	var job = Cache.Job.new(); var worker = Thread.new()
	worker.start(func(): return Cache.Terrain.new(849205174,true,{},job))
	while worker.is_alive() and job.snapshot().stage!="tree_snow": await process_frame
	var before = Time.get_ticks_usec(); job.cancel()
	while worker.is_alive(): await process_frame
	var partial = worker.wait_to_finish(); worker = null; var duration = (Time.get_ticks_usec()-before)/1000.0
	if partial.valid or duration>2000: failures.append("Tree-snow cancellation did not stop/join within 2 seconds")
	samples.append({"stage":"tree_snow","join_ms":duration,"valid":partial.valid}); var partial_ref = weakref(partial); partial = null
	if partial_ref.get_ref()!=null: failures.append("Cancelled mountain retained a reference cycle")
	if FileAccess.get_sha256(prior_path)!=previous_hash: failures.append("Cancelled build changed previous valid cache")
	job = Cache.Job.new(); worker = Thread.new(); worker.start(Cache.generate.bind(849205174,{},job))
	await create_timer(.015).timeout; before = Time.get_ticks_usec(); job.cancel()
	while worker.is_alive(): await process_frame
	var cached = worker.wait_to_finish(); duration = (Time.get_ticks_usec()-before)/1000.0
	if cached!=null or duration>2000: failures.append("Physical-cache cancellation exceeded checkpoint bound")
	samples.append({"stage":"physical_cache_read","join_ms":duration})
	var field = Cache.generate(849205174); job = Cache.Job.new()
	var prep = Prep.new(); worker = Thread.new(); worker.start(prep.build.bind(field,{},Quality.preset(2),job))
	await create_timer(.025).timeout; before = Time.get_ticks_usec(); job.cancel()
	while worker.is_alive(): await process_frame
	worker.wait_to_finish(); duration = (Time.get_ticks_usec()-before)/1000.0
	if prep.ready or duration>2000: failures.append("Scenery cancellation exceeded checkpoint bound")
	samples.append({"stage":"scenery_maps","join_ms":duration}); prep = null
	var report = {"samples":samples,"failures":failures}
	FileAccess.open("res://artifacts/generation_v15/cancellation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("V15_CANCELLATION ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
