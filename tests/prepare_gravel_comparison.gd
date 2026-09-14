extends SceneTree
## Warm scenery only; a missing physical archive is an explicit setup failure.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Exclusive")
	var field=preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: quit(2); return
	var quality=preload("res://scripts/presentation/graphics_quality.gd").numbered(7)
	var prepared=preload("res://scripts/world/mountain_preparation.gd").new()
	if not prepared.load_cached(field,quality,field.job):
		var assets=preload("res://scripts/presentation/alpine_assets.gd").new(preload("res://scripts/presentation/cloud_lighting.gd").new(),quality)
		var metadata=await preload("res://scripts/presentation/forest_placement.gd").metadata_async(assets,Callable(),field.job)
		prepared.build(field,metadata,quality,field.job)
	print("GRAVEL_SCENERY_CACHE ready=",prepared.ready," hit=",prepared.cache_hit)
	quit(0 if prepared.ready else 1)
