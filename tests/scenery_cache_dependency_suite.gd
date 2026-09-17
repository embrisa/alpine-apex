extends SceneTree
## Cache-key and archive fixture. No physical mountain or scenery generation.
const Cache = preload("res://scripts/world/scenery_cache.gd")
const Sources = Cache.Sources
const Archive = Cache.Archive
const Job = preload("res://scripts/world/generation_job.gd")
var checks = 0
var failures: Array[String] = []
var output = "res://artifacts/scenery_dependency_root_20260918"
var mode = "unit"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr(label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--integration="): mode = arg.trim_prefix("--integration=")
	DirAccess.make_dir_recursive_absolute(output)
	var rows: Dictionary = {}
	if mode!="reuse": unit_checks(rows)
	if mode in ["prime","reuse"]:
		# Exercise the actual source-build key, including normal runtime asset
		# dependency validation. The wrapper changes only the two display files.
		var key = Cache.key({"height_checksum":"flat-fixture-height","obstacle_checksum":"fixture-trees"},{"level":2})
		check(key.length()==64,"Actual source-build cache key is available")
		var path = output+"/bounded.scenery"
		if mode=="prime":
			var transforms = PackedFloat32Array(); transforms.resize(12*128)
			for i in transforms.size(): transforms[i] = float(i)*.125
			check(Archive.write(path,key,[{"name":"poses","value":transforms},{"name":"origin","value":Vector2(32,64)}]),"Publish isolated packed-array fixture")
			preload("res://tests/test_report.gd").write(output+"/key.txt",key)
		else:
			check(key==FileAccess.get_file_as_string(output+"/key.txt"),"Both actual display-source edits preserve the bake key")
			var restored = Archive.read(path,key)
			check(restored.get("poses") is PackedFloat32Array and restored.poses.size()==12*128 and restored.poses[1535]==191.875 and restored.origin==Vector2(32,64),"Existing packed scenery arrays reuse without a write or bake")
		rows.integration_key = key
		rows.archive_bytes = FileAccess.get_file_as_bytes(path).size()
	var report = {"checks":checks,"failures":failures,"mode":mode,"evidence":rows,"scope":"Normal source-build key and compact archive reuse. Synthetic digest mutations cover invalidation/export projection. No full mountain load, startup timing or FPS claim."}
	preload("res://tests/test_report.gd").write(output+"/"+mode+".json",JSON.stringify(report,"\t"))
	print("SCENERY_DEPENDENCY_RESULTS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func unit_checks(rows: Dictionary) -> void:
	# Enumerate real dependency paths, but use synthetic digests: no asset audit.
	var values: Dictionary = {}
	for path in Sources.dependencies(true): values[path] = "a".repeat(64)
	var expected = Cache._bake_signature(values)
	check(expected.length()==64,"Current dependency inventory supplies bake identity")
	var kept = 0
	for path in values:
		var changed = values.duplicate(); changed[path] = "b".repeat(64)
		var same = Cache._bake_signature(changed)==expected
		check(same==(path in Cache.DISPLAY_ONLY),"Dependency invalidation: "+path)
		if path not in Cache.DISPLAY_ONLY: kept += 1
	var reordered: Dictionary = {}
	var keys = values.keys(); keys.reverse()
	for path in keys: reordered[path] = values[path]
	check(Cache._bake_signature(reordered)==expected,"Dictionary order does not change identity")
	var missing = values.duplicate(); missing.erase(Sources.PHYSICAL[0])
	check(Cache._bake_signature(missing).is_empty(),"Missing required preparation input rejects reuse")
	missing = values.duplicate(); missing[Sources.PHYSICAL[0]] = ""
	check(Cache._bake_signature(missing).is_empty(),"Unreadable dependency digest rejects reuse")
	var added = values.duplicate(); added["res://assets/new_model.glb.import"] = "c".repeat(64)
	check(Cache._bake_signature(added)!=expected,"New asset/import dependency changes identity")
	var full = JSON.stringify(values,"",true,true).sha256_text()
	var manifest = {"scenery":values,"scenery_sha256":full}
	check(Cache._export_signature(manifest,full)==expected,"Validated export map agrees with source bake projection")
	var changed_export = values.duplicate(); changed_export[Cache.DISPLAY_ONLY[0]] = "b".repeat(64)
	var next_full = JSON.stringify(changed_export,"",true,true).sha256_text()
	check(next_full!=full,"Complete export identity still covers display sources")
	check(Cache._export_signature({"scenery":changed_export,"scenery_sha256":next_full},next_full)==expected,"Valid resealed display-only export preserves bake identity")
	check(Cache._export_signature({"scenery":changed_export,"scenery_sha256":full},full).is_empty(),"Tampered export source map rejects reuse")
	check(Cache._export_signature(manifest,"b".repeat(64)).is_empty(),"Mismatched validated export receipt rejects reuse")
	var job = Job.new(); job.cancel()
	check(Cache.source_signature(job).is_empty() and Cache._bake_signature(values,job).is_empty() and Cache._export_signature(manifest,full,job).is_empty(),"Cancellation rejects all signature paths")
	var key = Cache._key(expected,"engine","height","obstacles",2)
	for args in [["changed","engine","height","obstacles",2],[expected,"other-engine","height","obstacles",2],[expected,"engine","changed","obstacles",2],[expected,"engine","height","changed",2],[expected,"engine","height","obstacles",1]]:
		check(Cache._key.callv(args)!=key,"Bake, engine, terrain, placement or quality mismatch rejects key")
	check(Cache._key("","engine","height","obstacles",2).is_empty(),"Missing signature never forms a valid key")
	rows.retained_dependency_paths = kept
	rows.excluded_dependency_paths = Cache.DISPLAY_ONLY
