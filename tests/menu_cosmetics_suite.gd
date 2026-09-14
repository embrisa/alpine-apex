extends SceneTree
## No mountain generation: scheduling spies and identical decorative mesh inputs.
const World = preload("res://scripts/world/alpine_world.gd")
const Runner = preload("res://scripts/presentation/menu_cosmetics.gd")
const Backdrop = preload("res://scripts/world/alpine_backdrop.gd")
var checks = 0
var failures: Array[String] = []
var yields = 0

class Field extends RefCounted:
	const GENERATOR_ID = "fixture"
	func bounds() -> Rect2: return Rect2(-64,-64,128,128)
	func is_summit_mountain() -> bool: return false
class Mountain extends RefCounted:
	const ORIGIN = Vector2(-4096,-4096)
	func sample_height(p: Vector2) -> float: return p.x*.1+p.y*.05
class Assets extends RefCounted:
	func terrain_material(_bias: float = 0.0,_scale: float = .075) -> ShaderMaterial: return ShaderMaterial.new()
class SpyWorld extends World:
	var vistas_calls = 0
	var grass_calls = 0
	func _vistas(checkpoint: Callable = Callable(), _worker: Callable = Callable()) -> void:
		vistas_calls += 1
		if checkpoint.is_valid(): await checkpoint.call()
	func _build_grass() -> void: grass_calls += 1
class DataWork extends RefCounted:
	var done = false
	func run() -> int:
		OS.delay_msec(20)
		done = true
		return 42

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ",label)
	if not value: failures.append(label)

func run() -> void:
	var world = SpyWorld.new(); root.add_child(world); world.surface = Field.new()
	world.defer_startup_cosmetics = true
	world.startup_cosmetics_pending = true; world.startup_vistas_pending = true
	world.build_job = preload("res://scripts/world/generation_job.gd").new()
	world._configure_submission_stages()
	check(not world.build_job.expected_stages.has("distant_scenery"),"Optional scenery is excluded from blocking progress")
	var runner = Runner.new(); root.add_child(runner)
	runner.start(world); runner.start(world)
	check(world.vistas_calls==0 and world.grass_calls==0,"Menu work starts only after yielding an interactive frame")
	await runner.completed
	check(world.vistas_calls==1 and world.grass_calls==1,"Duplicate admission builds optional scenery only once")
	check(not world.startup_cosmetics_pending and not world.startup_cosmetics_running,"Completion clears pending and running state")
	check(world.build_job.snapshot().timings_ms.is_empty(),"Post-menu cosmetics never mutate the finished loading job")
	await world.finish_startup_cosmetics()
	check(world.vistas_calls==1,"Repeated completion is idempotent")
	world.queue_free(); await process_frame
	world = SpyWorld.new(); root.add_child(world)
	world.startup_cosmetics_pending = true
	world.build_job = preload("res://scripts/world/generation_job.gd").new(); world.build_job.cancel()
	await world.finish_startup_cosmetics()
	check(world.grass_calls==0 and not world.startup_cosmetics_running,"Cancelled world performs no late cosmetic work")
	world.queue_free(); await process_frame
	runner = Runner.new(); root.add_child(runner)
	check(await runner.optional_resource("res://absent_optional_scenery.res")==null,"Missing optional resources return safely")
	var work = DataWork.new()
	check(await runner.run_data(work.run)==42 and runner.worker==null,"Owned data worker returns a result and is joined")
	runner.worker = Thread.new(); work = DataWork.new(); runner.worker.start(work.run)
	runner.free()
	check(work.done,"Scene teardown joins an in-flight owned worker")
	world = SpyWorld.new(); root.add_child(world)
	runner = Runner.new(); root.add_child(runner); runner.start(world); world.free()
	await runner.completed
	check(runner.finished,"A removed destination cannot strand the background owner")
	await process_frame
	var direct = Backdrop.new(); root.add_child(direct)
	await direct.build(Field.new(),Assets.new(),Mountain.new())
	var scheduled = Backdrop.new(); root.add_child(scheduled)
	await scheduled.build(Field.new(),Assets.new(),Mountain.new(),null,checkpoint,1000)
	check(yields>64,"Decorative geometry yields inside CPU loops as well as between uploads")
	check(mesh_hash(direct)==mesh_hash(scheduled) and direct.triangles==scheduled.triangles,"Cooperative scheduling preserves every decorative vertex, normal and index")
	direct.free(); scheduled.free()
	print("MENU_COSMETICS_SUITE ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func checkpoint(_label: String = "",_percent: float = -1.0) -> void:
	yields += 1
	await process_frame

func mesh_hash(node: Node) -> String:
	var hash = HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	for child in node.get_children():
		var arrays = child.mesh.surface_get_arrays(0)
		for index in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_INDEX]: hash.update(arrays[index].to_byte_array())
	return hash.finish().hex_encode()
