extends SceneTree
const Wilderness = preload("res://scripts/world/alpine_wilderness.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var checks = 0
var failures: Array[String] = []

class Apron:
	extends RefCounted
	var seed_value = 849205174
	const ORIGIN = Vector2(-4096,-4096)
	const EXTENT = 8192.0
	func sample_height(p: Vector2) -> float: return 2400.0+p.x*0.01+p.y*0.02

class Field:
	extends RefCounted
	func bounds() -> Rect2: return Rect2(-3072,-3072,6144,6144)
	func is_summit_mountain() -> bool: return true
	func sample(_x: float, _z: float) -> Dictionary: return {"height":2400.0}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var source = Apron.new()
	var field = Field.new()
	var world = Wilderness.new()
	root.add_child(world)
	world.build(field,source,Quality.preset(0))
	var deterministic = Wilderness.Data.new()
	deterministic.configure(source,field)
	var same = true
	for i in 100:
		var p = Vector2.from_angle(i*0.2)*(6000+i*110)
		same = same and world.data.height_at(p)==deterministic.height_at(p)
	check(same,"Backdrop landforms reproduce from an isolated scenery seed")
	var joined = true
	for i in Wilderness.Data.EDGE_SEGMENTS:
		var p = world.data.edge_point(i)
		joined = joined and world.data.sample_at(p)==deterministic.sample_at(p)
	check(joined,"All 1024 inner-edge samples share height, normal and material with the apron sampler")
	var collar = true
	for i in range(-3072,3073,32):
		for p in [Vector2(i,-3264),Vector2(i,3264),Vector2(-3264,i),Vector2(3264,i)]:
			collar = collar and world.data.height_at(p)==source.sample_height(p) and world.data.blend_at(p)==0.0
	check(collar,"The complete 192 m collar preserves the original height and material blend")
	check(world.data.edge_point(0)==world.data.edge_point(1024),"The full perimeter closes without a seam")
	for level in 3:
		world.apply_quality(Quality.preset(level))
		var safe = world.get_child_count()==24 and world.triangles<=Wilderness.TRIANGLE_LIMITS[level]
		var finite = true
		for child in world.get_children():
			safe = safe and child is MeshInstance3D and child.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and child.gi_mode==GeometryInstance3D.GI_MODE_DISABLED
			var arrays = child.mesh.surface_get_arrays(0)
			for vertex in arrays[Mesh.ARRAY_VERTEX]: finite = finite and vertex.is_finite()
		check(safe and finite,"Preset %d has finite static geometry within its triangle/batch budget and no collision/shadows/GI" % level)
	check(world.get_children().all(func(c): return c.material_override==world.material),"Every ridge shares one opaque material")
	print("WILDERNESS_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"geometry":world.report()}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
