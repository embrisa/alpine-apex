extends SceneTree
## Explicit one-bake preparation. Missing validation caches never invoke this implicitly.
const Cache=preload("res://scripts/world/mountain_cache_v17.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not preload("res://scripts/diagnostics/test_world_policy.gd").require_full("Explicit Standard fixture preparation"): quit(2); return
	if OS.get_environment("ALPINE_VALIDATION_MODE")!="Exclusive":
		push_error("Fixture preparation requires an Exclusive guard."); quit(2); return
	var seed_number: int=Cache.Terrain.DEFAULT_SEED
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			var value=arg.get_slice("=",1)
			if not value.is_valid_int() or int(value)<0 or int(value)>2147483647:
				printerr("Invalid explicit fixture seed"); quit(2); return
			seed_number=int(value)
	var job=Cache.Job.new()
	var field=Cache.Terrain.new(seed_number,true,Cache.Settings.preset(),job)
	if not field.valid: quit(1); return
	var saved=Cache.Archive.write(Cache.path_for(field.seed_value),Cache.cache_key(field.seed_value),Cache.sections(field),job)
	print("FIXTURE_PREPARED ",JSON.stringify({"saved":saved,"seed":field.seed_value,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"generation_ms":field.generation_ms}))
	quit(0 if saved else 1)
