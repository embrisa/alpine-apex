extends SceneTree
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")
var failures = 0

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1

func _initialize() -> void:
	var key = Cache.cache_key(849205174)
	var path = OS.get_environment("ALPINE_BAKE_OUTPUT")
	var data = Cache.Archive.read(path,key)
	check(not data.is_empty(),"Prepared bake matches current engine and shaping sources")
	check(Cache.Archive.read(path,key+"changed").is_empty(),"Incompatible identity rejected")
	check(Cache.Archive.read(path,"").is_empty(),"Missing source identity rejected")
	check(Cache.Archive.read(path+".missing",key).is_empty(),"Missing bundled bake is optional")
	if not data.is_empty():
		var broken = data.duplicate()
		broken["heights/count"] = 0
		check(Cache.restore(849205174,Cache.Settings.preset(),broken,Cache.Job.new())==null,"Wrong terrain dimensions rejected")
	var malformed = "res://artifacts/playtest-malformed-bake.bin"
	var file = FileAccess.open(malformed,FileAccess.WRITE)
	file.store_var({"key":key},false)
	file.close()
	check(Cache.Archive.read(malformed,key).is_empty(),"Invalid on-disk payload rejected")
	quit(0 if failures==0 else 1)
