extends SceneTree
## Run with the target runtime before exporting. Compiled exports use this receipt.
const Sources = preload("res://scripts/world/generation_sources.gd")
const Cache = preload("res://scripts/world/mountain_cache_v17.gd")
func _initialize() -> void:
	if OS.has_feature("generation_export"):
		var physical = Sources.signature(); var scenery = Sources.signature(true)
		if physical.is_empty() or scenery.is_empty(): printerr("EXPORT_MANIFEST_INVALID"); quit(1); return
		var field = Cache.generate(849205174)
		print("EXPORT_CACHE_CHECK ",JSON.stringify({"engine":Engine.get_version_info().string,"physical":physical,"scenery":scenery,"cache_hit":field!=null and field.cache_hit,"height":field.height_checksum if field else "","obstacles":field.obstacle_checksum if field else ""}))
		quit(0 if field and field.cache_hit else 2); return
	var manifest = Sources.export_manifest()
	if manifest.is_empty(): printerr("EXPORT_DEPENDENCIES_MISSING"); quit(1); return
	manifest.engine_sha256 = FileAccess.get_sha256(OS.get_executable_path())
	DirAccess.make_dir_recursive_absolute("res://config")
	var file = FileAccess.open(Sources.MANIFEST,FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t",true,true)); file.close()
	print("EXPORT_MANIFEST_READY ",manifest.physical_sha256," ",manifest.scenery_sha256)
	quit()
