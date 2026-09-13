extends SceneTree
## Explicit alternate seed fixture for grass habitat and scenery-material checks.
const Cache=preload("res://scripts/world/mountain_cache_v15.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if OS.get_environment("ALPINE_VALIDATION_MODE")!="Exclusive": quit(2); return
	if not preload("res://scripts/diagnostics/test_world_policy.gd").require_full("Explicit alternate 638201943 Standard habitat fixture"): quit(2); return
	var job=Cache.Job.new()
	var field=Cache.Terrain.new(638201943,true,Cache.Settings.preset(),job)
	if not field.valid: quit(1); return
	var saved=Cache.Archive.write(Cache.path_for(field.seed_value),Cache.cache_key(field.seed_value),Cache.sections(field),job)
	print("GRASS_SECOND_PREPARED ",JSON.stringify({"saved":saved,"seed":field.seed_value,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum}))
	quit(0 if saved else 1)
