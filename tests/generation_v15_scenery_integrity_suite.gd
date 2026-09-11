extends SceneTree
## A valid section checksum does not excuse a structurally invalid preparation.
const Physical = preload("res://scripts/world/mountain_cache_v15.gd")
const Cache = preload("res://scripts/world/scenery_cache.gd")
const Preparation = preload("res://scripts/world/mountain_preparation.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func run() -> void:
	var field = Physical.generate(849205174)
	var quality = Quality.preset(2); var job = Physical.Job.new()
	var prepared = Preparation.new()
	check(prepared.load_cached(field,quality,job),"Current High preparation loads")
	if not prepared.ready: quit(1); return
	var previous = [prepared.mountain,prepared.terrain,prepared.forest,prepared.readability,prepared.minerals]
	var key = Cache.key(field,quality)
	var data = Physical.Archive.read(Cache.path_for(field),key)
	data["forest_regions/count"] = -1
	var sections: Array = []
	for name in data: sections.append({"name":name,"value":data[name]})
	var path = "res://artifacts/generation_v15/invalid_scenery_structure.scenery"
	check(Physical.Archive.write(path,key,sections),"Malformed structure retains valid bounded section checksums")
	check(not Cache.load_into(prepared,field,quality,job,path),"Structural corruption is rejected")
	check(previous==[prepared.mountain,prepared.terrain,prepared.forest,prepared.readability,prepared.minerals],"Rejected preparation leaves all previously published data intact")
	DirAccess.remove_absolute(path)
	var result = {"checks":4,"failures":failures}
	FileAccess.open("res://artifacts/generation_v15/scenery_integrity.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("V15_SCENERY_INTEGRITY ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
