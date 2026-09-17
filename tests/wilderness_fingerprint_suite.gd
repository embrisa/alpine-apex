extends SceneTree
## Current Standard physical data remains unchanged by background preparation.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Apron = preload("res://scripts/world/mountain_data.gd")
const Wilderness = preload("res://scripts/world/alpine_wilderness.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
class Assets:
	extends RefCounted
	func terrain_material(_bias: float = 0.0,_scale: float = .075) -> ShaderMaterial: return ShaderMaterial.new()
var checks = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
func run() -> void:
	var field = Definition.generate(849205174)
	if field==null: quit(2); return
	check(field.GENERATOR_VERSION==Definition.CURRENT_VERSION and field.tree_data.size()==preload("res://scripts/world/generation_settings.gd").TREE_BASELINE,"Current Standard physical world loaded")
	var physical = [field.heights.to_byte_array(),field.tree_data.positions.to_byte_array(),field.tree_data.dimensions.to_byte_array()]
	var apron = Apron.new(); apron.generate(field,field.seed_value)
	var scenery = [apron.height_image.get_data(),apron.environment_image.get_data()]
	var wilderness = Wilderness.new(); root.add_child(wilderness)
	wilderness.prepare(field,apron)
	var connector=preload("res://scripts/world/alpine_backdrop.gd").new(); root.add_child(connector)
	await connector.build(field,Assets.new(),apron,wilderness.data)
	wilderness.apron_sources=connector.triangle_sources
	await wilderness.apply_quality(Quality.preset(0))
	check(physical==[field.heights.to_byte_array(),field.tree_data.positions.to_byte_array(),field.tree_data.dimensions.to_byte_array()] and scenery==[apron.height_image.get_data(),apron.environment_image.get_data()],"V3 preparation and scene submission leave physical and source scenery bytes unchanged")
	var report = {"checks":checks,"failures":failures,"version":field.GENERATOR_VERSION,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum}
	DirAccess.make_dir_recursive_absolute("res://artifacts/offmap_v3")
	preload("res://tests/test_report.gd").write("res://artifacts/offmap_v3/fingerprints.json",JSON.stringify(report,"\t"))
	print("WILDERNESS_FINGERPRINT_RESULTS ",JSON.stringify(report))
	wilderness.queue_free(); connector.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
