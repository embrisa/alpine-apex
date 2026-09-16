extends SceneTree
## A valid section checksum does not excuse a structurally invalid preparation.
const Physical = preload("res://scripts/world/mountain_cache_v15.gd")
const Cache = preload("res://scripts/world/scenery_cache.gd")
const Preparation = preload("res://scripts/world/mountain_preparation.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var failures: Array = []
var checks = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func run() -> void:
	var field = preload("res://tests/validation_mountain.gd").load_standard()
	if field == null: quit(1); return
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
	for damage in ["missing_chunk","duplicate_chunk","changed_perimeter"]:
		data=Physical.Archive.read(Cache.path_for(field),key)
		if damage=="missing_chunk":
			var count: int=data["terrain/count"]
			data["terrain/%d" % ((count-1)/8)].pop_back(); data["terrain/count"]=count-1
		elif damage=="duplicate_chunk":
			data["terrain/0"][0].center=data["terrain/0"][1].center
		else:
			var changed=false
			for section in ceili(data["terrain/count"]/8.0):
				for chunk in data["terrain/%d" % section]:
					if not changed and chunk.has("indices"):
						var indices: PackedInt32Array=chunk.indices
						indices[0]=(indices[0]+1)%4225; chunk.indices=indices; changed=true
			assert(changed)
		sections=[]
		for name in data: sections.append({"name":name,"value":data[name]})
		assert(Physical.Archive.write(path,key,sections))
		check(not Cache.load_into(prepared,field,quality,job,path),"Reject invalid retained terrain: "+damage)
	check(previous==[prepared.mountain,prepared.terrain,prepared.forest,prepared.readability,prepared.minerals],"Invalid footprint caches never replace published preparation")
	DirAccess.remove_absolute(path)
	var result = {"checks":checks,"failures":failures}
	preload("res://tests/test_report.gd").write("res://artifacts/generation_v15/scenery_integrity.json",JSON.stringify(result,"\t"))
	print("V15_SCENERY_INTEGRITY ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
