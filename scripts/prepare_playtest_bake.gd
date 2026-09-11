extends SceneTree
## Prepare current data through the normal validated cache, never a stale copy.
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")
const Mountain = preload("res://scripts/world/mountain_definition.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var destination = OS.get_environment("ALPINE_BAKE_OUTPUT")
	if destination.is_empty():
		push_error("ALPINE_BAKE_OUTPUT must name the staged data/default_mountain_v15.physical")
		quit(1)
		return
	var field = Mountain.generate(849205174,15)
	var key = Cache.cache_key(849205174)
	var source = Cache.path_for(849205174)
	var data = Cache.Archive.read(source,key)
	if data.is_empty() or data.meta.height_sha256!=field.height_checksum or data.meta.obstacle_sha256!=field.obstacle_checksum:
		push_error("Current default mountain bake did not validate")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(source),destination)!=OK:
		quit(1)
		return
	var scenery = preload("res://scripts/world/scenery_cache.gd")
	var prepared = preload("res://scripts/world/mountain_preparation.gd").new()
	if not prepared.load_cached(field,preload("res://scripts/presentation/graphics_quality.gd").preset(2),Cache.Job.new()):
		push_error("Run the Standard High rendered profile to prepare current scenery before packaging.")
		quit(1); return
	var scenery_destination = destination.get_base_dir().path_join("default_mountain_v15.scenery")
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(scenery.path_for(field)),scenery_destination)!=OK:
		quit(1); return
	print("PLAYTEST_BAKE_READY ",JSON.stringify({"destination":destination,"cache_hit":field.cache_hit,"generation_ms":field.generation_ms,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"sha256":FileAccess.get_sha256(destination)}))
	quit(0)
