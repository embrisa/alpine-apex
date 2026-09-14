extends Node
## Optional scene work after menu readiness. Owns its worker independently of
## LoadingOverlay so a new menu action can start loading immediately.
signal completed
var started: bool = false
var finished: bool = false
var worker: Thread
var target: WeakRef
var retained_asset: Resource

func start(world: Node) -> void:
	if started: return
	started = true
	target = weakref(world)
	_run.call_deferred()

func _run() -> void:
	await checkpoint()
	var world = target.get_ref()
	if is_instance_valid(world) and not world.is_queued_for_deletion():
		if world.startup_vistas_pending and world.surface.is_summit_mountain():
			retained_asset = await optional_resource(preload("res://scripts/world/wilderness_data.gd").DEFAULT_ASSET)
			if not is_instance_valid(world) or world.is_queued_for_deletion():
				finished = true; completed.emit(); queue_free(); return
			if retained_asset==null:
				world.startup_vistas_pending = false
				push_warning("Optional distant scenery unavailable")
		await world.finish_startup_cosmetics(checkpoint,run_data)
	finished = true
	completed.emit()
	queue_free()

func checkpoint(_label: String = "", _percent: float = -1.0) -> void:
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw

func optional_resource(path: String) -> Resource:
	if not ResourceLoader.exists(path): return null
	if ResourceLoader.load_threaded_request(path)!=OK: return null
	while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED: return null
	return ResourceLoader.load_threaded_get(path)

func run_data(work: Callable):
	worker = Thread.new()
	if worker.start(work)!=OK:
		worker = null
		return work.call()
	while worker.is_alive(): await get_tree().process_frame
	var result = worker.wait_to_finish()
	worker = null
	return result

func _exit_tree() -> void:
	if worker and worker.is_started(): worker.wait_to_finish()
	worker = null
