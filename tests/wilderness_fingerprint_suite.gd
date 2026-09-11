extends SceneTree
## Current v15 Standard contracts captured by the validated ordinary-input trace.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Apron = preload("res://scripts/world/mountain_data.gd")
const Wilderness = preload("res://scripts/world/alpine_wilderness.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
const HEIGHT = "e12569ae88d5c3c564e66ad6e3e5ed3744baa71398a914db6c954c6eba24e40e"
const OBSTACLES = "b84df994471e299e83aebbb114ad3d156f6f6a0306dbf44d8f8e08824c0d4159"
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
	var field = Definition.generate(849205174,15)
	check(field.height_checksum==HEIGHT and field.obstacle_checksum==OBSTACLES,"V15 Standard retains the frozen physical terrain and obstacle fingerprints")
	var physical = [field.heights.to_byte_array(),var_to_bytes(field.obstacles)]
	var apron = Apron.new(); apron.generate(field,field.seed_value+4187)
	var scenery = [apron.height_image.get_data(),apron.environment_image.get_data()]
	var wilderness = Wilderness.new(); root.add_child(wilderness)
	wilderness.prepare(field,apron)
	var connector=preload("res://scripts/world/alpine_backdrop.gd").new(); root.add_child(connector)
	await connector.build(field,Assets.new(),apron,wilderness.data)
	wilderness.apron_sources=connector.triangle_sources
	await wilderness.apply_quality(Quality.preset(0))
	check(physical==[field.heights.to_byte_array(),var_to_bytes(field.obstacles)] and scenery==[apron.height_image.get_data(),apron.environment_image.get_data()],"V3 preparation and scene submission leave physical and source scenery bytes unchanged")
	var report = {"checks":checks,"failures":failures,"version":15,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum}
	DirAccess.make_dir_recursive_absolute("res://artifacts/offmap_v3")
	FileAccess.open("res://artifacts/offmap_v3/fingerprints.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WILDERNESS_FINGERPRINT_RESULTS ",JSON.stringify(report))
	wilderness.queue_free(); connector.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
