extends SceneTree
## Thread-safety stress for the grass worker path: eight WorkerThreadPool tasks
## prepare grass cells across the Standard mountain while the main thread
## queries the same field and periodically blocks on every in-flight task, as
## TerrainGrass._clear_cells does. Run with ALPINE_FULL_MOUNTAIN=1 and a reason:
##   ./godotw --headless --script tests/grass_worker_stress.gd -- --seconds=240
## Authored to chase a one-off 2026-09-16 crash (propagate_notification thread
## guard at scene/main/node.cpp:2578 with a grass worker backtrace, then signal
## 11); 400 s and 156,000 cells did not reproduce it. Any error or crash here
## is a regression worth reporting.
const Placement = preload("res://scripts/presentation/grass_placement.gd")
class Work extends RefCounted:
	var source
	var key: Vector2i
	var id: int = -1
	var result: Array = []
	var bounds: Dictionary
	func run() -> void: result = source.prepare_cell(key,1.0,bounds)
var field
var mesh_bounds: Dictionary = {}
var heights: Dictionary = {}
var frame = 0
var seconds = 120
var tasks: Array = []
var done = 0
var started_at = 0
var rng = RandomNumberGenerator.new()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="): seconds = int(arg.get_slice("=",1))
	field = preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: quit(2); return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/grass/manifest.json"))
	for record in catalog.assets:
		var mesh_id = record.id+"_lod"+str(int(record.lod))
		mesh_bounds[mesh_id] = load(record.path).get_aabb()
		heights[record.id] = record.height
	rng.seed = 4242
	started_at = Time.get_ticks_msec()
	process_frame.connect(tick)
func tick() -> void:
	frame += 1
	if frame%90==0:
		# Mirror TerrainGrass._clear_cells: block on every in-flight task at once.
		for w in tasks: WorkerThreadPool.wait_for_task_completion(w.id)
		done += tasks.size(); tasks.clear()
	var remaining: Array = []
	for w in tasks:
		if WorkerThreadPool.is_task_completed(w.id):
			WorkerThreadPool.wait_for_task_completion(w.id); done += 1
		else: remaining.append(w)
	tasks = remaining
	while tasks.size()<8:
		var w = Work.new(); w.source = Placement.new(field,heights); w.bounds = mesh_bounds; w.key = Vector2i(rng.randi_range(-150,150),rng.randi_range(-150,150))
		w.id = WorkerThreadPool.add_task(w.run,false,"Grass stress")
		tasks.append(w)
	for i in 40:
		var p = Vector2(rng.randf_range(-2400,2400),rng.randf_range(-2400,2400))
		field.sample(p.x,p.y); field.stand_density(p.x,p.y); field.snow_depth_at(p.x,p.y); field.rock_fraction_at(p.x,p.y)
	if (Time.get_ticks_msec()-started_at)%10000<20: print("GRASS_STRESS cells=",done)
	if Time.get_ticks_msec()-started_at>seconds*1000:
		for w in tasks: WorkerThreadPool.wait_for_task_completion(w.id)
		print("GRASS_STRESS_DONE cells=",done+tasks.size()); quit(0)
