extends SceneTree
## Match v14's complete Cache.generate boundary, including dependency checks.
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rows: Array = []
	var failed = false
	for repetition in 3:
		var started = Time.get_ticks_usec()
		var field = Cache.generate(849205174)
		var wall_ms = (Time.get_ticks_usec()-started)/1000.0
		if not field or not field.cache_hit: quit(1); return
		var row = {"repetition":repetition+1,"physical_cache_wall_ms":wall_ms,"archive_reconstruction_ms":field.generation_ms,"height":field.height_checksum,"obstacles":field.obstacle_checksum}
		failed = failed or (not rows.is_empty() and (row.height!=rows[0].height or row.obstacles!=rows[0].obstacles))
		rows.append(row); field = null
	var result = {"source":Cache.Sources.signature(),"engine_sha256":Cache.Sources.engine_identity(),"runs":rows,"failed":failed}
	preload("res://tests/test_report.gd").write("res://artifacts/generation_v15/v15_cache_wall_baseline.json",JSON.stringify(result,"\t"))
	print("V15_FULL_CACHE_PROFILE ",JSON.stringify(result)); quit(1 if failed else 0)
