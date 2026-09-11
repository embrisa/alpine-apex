extends SceneTree
const Wilderness = preload("res://scripts/world/alpine_wilderness.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var world
var checks=0
var failures: Array=[]
var stages=0
var replace_during_checkpoint=false
class Job:
	extends RefCounted
	var cancelled=false
	func is_cancelled() -> bool: return cancelled
class Field:
	extends RefCounted
	var job=Job.new()
	func bounds() -> Rect2: return Rect2(-3072,-3072,6144,6144)
	func sample(_x: float,_z: float) -> Dictionary: return {"height":2400.0}
class Mountain:
	extends RefCounted
	var seed_value=849205174
	const ORIGIN=Vector2(-4096,-4096)
	const EXTENT=8192.0
	func sample_height(p: Vector2) -> float: return 2400.0+p.x*.01
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
func quality(level: int):
	var q=Quality.preset(level); q.offmap_prop_density=0.0; return q
func checkpoint(_label: String,_percent: float) -> void:
	stages+=1
	if replace_during_checkpoint and stages==2:
		replace_during_checkpoint=false
		await world.apply_quality(quality(2))
	await process_frame
func run() -> void:
	var field=Field.new()
	world=Wilderness.new(); root.add_child(world)
	# Inject a real baked terrain resource with empty prop batches to keep
	# cancellation ordering independent of asset upload throughput.
	world.data.asset=load(Wilderness.Data.DEFAULT_ASSET).duplicate()
	var levels: Array[Dictionary]=[]
	for source in world.data.asset.levels:
		var preset: Dictionary=source.duplicate()
		preset.groups=[]; preset.apron_count=0
		levels.append(preset)
	world.data.asset.levels=levels
	await world.build(field,Mountain.new(),quality(0))
	var old_root=world.terrain_root
	var old_triangles: int=world.triangles
	field.job.cancelled=true
	await world.apply_quality(quality(1),checkpoint)
	check(world.terrain_root==old_root and world.level==0 and world.triangles==old_triangles,"Cancelled quality build retains complete active geometry")
	check(world.get_child_count()==1 and world.source_arrays.is_empty(),"Cancelled staging and triangle inputs are released")
	field.job.cancelled=false
	await world.apply_quality(quality(1),checkpoint)
	check(world.level==1,"A cancelled requested preset can be retried")
	stages=0; replace_during_checkpoint=true
	await world.apply_quality(quality(0),checkpoint)
	check(world.level==2 and world.get_child_count()==1 and world.ridge_nodes().size()==24,"Newest quality request wins during staged construction")
	var reference=weakref(world.props)
	world.queue_free(); await process_frame; await process_frame
	check(reference.get_ref()==null,"World destruction frees its background prop owner")
	print("OFFMAP_LIFECYCLE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
