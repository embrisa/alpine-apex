extends SceneTree
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var job = Cache.Job.new(); var worker = Thread.new()
	worker.start(func(): return Cache.Terrain.new(73810291,true,{},job))
	await create_timer(.025).timeout; job.cancel()
	while worker.is_alive(): await process_frame
	var field = worker.wait_to_finish(); print("REFERENCES ",field.get_reference_count())
	var observer = weakref(field); field = null
	print("AFTER_RESULT_RELEASE ",observer.get_ref()!=null)
	worker = null
	print("AFTER_THREAD_RELEASE ",observer.get_ref()!=null)
	job = null
	print("AFTER_CONTEXT_RELEASE ",observer.get_ref()!=null)
	quit(0 if observer.get_ref()==null else 1)
