extends SceneTree
const Evidence = preload("res://tests/session_navigation_evidence.gd")

func _initialize() -> void:
	var current = Engine.get_version_info()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(current))
	var failures: Array[String] = []
	if not Evidence.same_engine(saved,current): failures.append("JSON numeric types must not reject the identical engine")
	saved.hash = "different-engine-build"
	if Evidence.same_engine(saved,current): failures.append("A real engine hash change must fail")
	saved = JSON.parse_string(JSON.stringify(current))
	saved.timestamp += 1
	if Evidence.same_engine(saved,current): failures.append("A real engine timestamp change must fail")
	for failure in failures: printerr("FAIL: ",failure)
	print("Engine receipt normalization: ",3-failures.size(),"/3 passed")
	quit(0 if failures.is_empty() else 1)
