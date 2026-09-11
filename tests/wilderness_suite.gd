extends SceneTree
const Wilderness = preload("res://scripts/world/alpine_wilderness.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var checks = 0
var failures: Array[String] = []

class Assets:
	extends RefCounted
	func terrain_material(_bias: float = 0.0,_scale: float = .075) -> ShaderMaterial: return ShaderMaterial.new()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var field = preload("res://scripts/world/mountain_definition.gd").generate(849205174,15)
	var source = preload("res://scripts/world/mountain_data.gd").new()
	source.generate(field,field.seed_value+4187)
	var world = Wilderness.new()
	root.add_child(world)
	world.prepare(field,source)
	var apron=preload("res://scripts/world/alpine_backdrop.gd").new(); root.add_child(apron)
	await apron.build(field,Assets.new(),source,world.data)
	world.apron_sources=apron.triangle_sources
	await world.apply_quality(Quality.preset(0))
	var deterministic = Wilderness.Data.new()
	deterministic.configure(source,field)
	check(world.data.asset==deterministic.asset,"Repeated loads share one immutable authored background resource")
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
		await world.apply_quality(Quality.preset(level))
		var safe = world.ridge_nodes().size()==24 and world.triangles<=Wilderness.TRIANGLE_LIMITS[level]
		var finite = true
		for child in world.ridge_nodes():
			safe = safe and child is MeshInstance3D and child.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and child.gi_mode==GeometryInstance3D.GI_MODE_DISABLED
			var arrays = child.mesh.surface_get_arrays(0)
			for vertex in arrays[Mesh.ARRAY_VERTEX]: finite = finite and vertex.is_finite()
		check(safe and finite,"Preset %d has finite static geometry within its triangle/batch budget and no collision/shadows/GI" % level)
	check(world.ridge_nodes().all(func(c): return c.material_override==world.material),"Every ridge shares one opaque material")
	check(world.placement.ready and world.props.instances>0,"Background contains real tree and rock instances")
	check(world.props.bounds_valid and world.placement.seating_error_m<.02,"Packed props have finite bounds and use exact render-triangle planes")
	var safe_props = world.props.get_children().all(func(c): return c is MultiMeshInstance3D and c.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and c.gi_mode==GeometryInstance3D.GI_MODE_DISABLED)
	check(safe_props,"Every prop batch is presentation-only")
	check(world.props.bounds_valid and world.props.bounds_corners_checked>0,"Conservative spatial bounds contain packed mesh and billboard footprint corners")
	var fingerprint: String = world.placement.fingerprint
	await world.apply_quality(Quality.preset(0))
	await world.apply_quality(Quality.preset(2))
	check(world.placement.fingerprint==fingerprint,"Quality roundtrip reproduces placements and reseating exactly")
	check(world.source_arrays.is_empty() and not "sampler" in world.placement,"Runtime placement loads baked anchors without constructing a triangle BVH")
	print("WILDERNESS_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"geometry":world.report()}))
	world.queue_free(); apron.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
