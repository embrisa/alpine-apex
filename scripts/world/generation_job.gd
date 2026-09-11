extends RefCounted
## One owned job, including its workers. Snapshots contain values only.
var mutex = Mutex.new()
var worker_count: int = mini(6,maxi(1,OS.get_processor_count()-2))
var started_usec: int = Time.get_ticks_usec()
var stage_started_usec: int = started_usec
var stage: String = "Preparing mountain"
var completed: int = 0
var total: int = 0
var cancelled: bool = false
var finished: bool = false
var failure: String = ""
var costs: Dictionary = {}
var counters: Dictionary = {}
var expected_stages: Dictionary = {}
var initial_estimate = Vector2(90,360)
var additional_estimate = Vector2(10,90)
var memory_estimate = Vector2(1,4)
var _next_tile: int = 0
var _results: Array = []
var _tile_count: int = 0

func cancel() -> void:
	mutex.lock(); cancelled = true; mutex.unlock()

func is_cancelled() -> bool:
	mutex.lock(); var result = cancelled; mutex.unlock(); return result

func begin_stage(name: String, work_total: int = 0) -> void:
	mutex.lock()
	stage = name; completed = 0; total = work_total; stage_started_usec = Time.get_ticks_usec()
	mutex.unlock()

func advance(amount: int = 1) -> void:
	mutex.lock(); completed += amount; mutex.unlock()

func set_total(value: int) -> void:
	mutex.lock(); total = value; mutex.unlock()

func count_work(name: String, amount: int) -> void:
	mutex.lock(); counters[name] = int(counters.get(name,0))+amount; mutex.unlock()

func end_stage(name: String, work_done: int = -1) -> void:
	mutex.lock()
	var elapsed_ms = (Time.get_ticks_usec()-stage_started_usec)/1000.0
	costs[name] = float(costs.get(name,0.0))+elapsed_ms
	counters[name] = int(counters.get(name,0))+((total if completed==0 and not cancelled else completed) if work_done<0 else work_done)
	mutex.unlock()
	print("GENERATION_STAGE ",name," ",snappedf(elapsed_ms,.01)," ms")

func snapshot() -> Dictionary:
	mutex.lock()
	var elapsed_s = (Time.get_ticks_usec()-started_usec)/1000000.0
	var stage_s = (Time.get_ticks_usec()-stage_started_usec)/1000000.0
	var remaining = maxf(0,initial_estimate.y-elapsed_s)
	var low = maxf(0,initial_estimate.x-elapsed_s)
	if not expected_stages.is_empty():
		var predicted = 0.0
		for key in expected_stages:
			if not costs.has(key): predicted += float(expected_stages[key])/1000.0
		if completed>0 and total>completed:
			predicted = maxf(0,predicted-float(expected_stages.get(stage,0))/1000.0)+stage_s*(total-completed)/completed
		low = predicted*.65; remaining = predicted*1.7
	var result = {"stage":stage,"completed":completed,"total":total,"elapsed_s":elapsed_s,"stage_elapsed_s":stage_s,
		"estimate_range_s":Vector2(low,remaining),"additional_range_s":additional_estimate,"peak_memory_gib":memory_estimate,
		"cancelled":cancelled,"finished":finished,"error":failure,"timings_ms":costs.duplicate(),"work":counters.duplicate()}
	mutex.unlock()
	return result

func complete(error_message: String = "") -> void:
	mutex.lock(); finished = true; failure = error_message; mutex.unlock()

func map_tiles(count: int, work: Callable) -> Array:
	# No nested invocation on this job. Each worker owns its returned arrays.
	_next_tile = 0; _tile_count = count; _results = []; _results.resize(count)
	var threads: Array[Thread] = []
	for i in mini(clampi(worker_count,1,6),maxi(1,count)):
		var thread = Thread.new()
		if worker_count==1 or thread.start(_tile_worker.bind(work))!=OK:
			_tile_worker(work)
		else: threads.append(thread)
	for thread in threads: thread.wait_to_finish()
	var result: Array = [] if is_cancelled() else _results
	_results = []
	return result

func _tile_worker(work: Callable) -> void:
	while true:
		mutex.lock()
		var id = _next_tile
		if cancelled or id>=_tile_count:
			mutex.unlock(); return
		_next_tile += 1
		mutex.unlock()
		var value = work.call(id)
		mutex.lock(); _results[id] = value; mutex.unlock()
