extends SceneTree
const Fixture = preload("res://tests/validation_mountain.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run() -> void:
	var directory := "res://artifacts/validation_fixture_checks"
	DirAccess.make_dir_recursive_absolute(directory)
	var missing := directory.path_join("missing.physical")
	check(Fixture.load_standard([missing]) == null and not FileAccess.file_exists(missing),"Missing fixture returns without baking or writing")
	var bad := directory.path_join("corrupt.physical")
	var file := preload("res://tests/test_report.gd").open_write(bad)
	file.store_string("invalid archive"); file.close()
	var before := FileAccess.get_sha256(bad)
	check(Fixture.load_standard([bad]) == null and FileAccess.get_sha256(bad) == before,"Corrupt fixture is rejected without replacing it")
	var wrong := directory.path_join("stale.physical")
	check(Fixture.Cache.Archive.write(wrong,"stale".sha256_text(),[{"name":"meta","value":{"schema":1}}]),"Stale fixture prepared outside user caches")
	check(Fixture.load_standard([wrong]) == null,"Source/engine cache-key mismatch rejected")
	var field = Fixture.load_standard()
	check(field != null and field.cache_hit and field.GENERATOR_VERSION == 15,"Current Standard fixture restores through validated production reader")
	quit(0 if failures.is_empty() else 1)
