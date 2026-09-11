extends SceneTree
const Trace = preload("res://tests/performance_trace.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run() -> void:
	var current := {"identity":{"sources":Trace.source_identity(),"model":Trace.Simulation.MODEL_VERSION,"generator":15},"result":{"finished":true,"crash":""},"commands":[[0,1,0,false,false,0,0,0]]}
	check(Trace.preflight_error(current,15).is_empty(),"Current complete trace passes source preflight (terrain/replay still checked by benchmark)")
	check(not Trace.preflight_error(null,15).is_empty(),"Malformed JSON fails before setup")
	var changed: Dictionary = current.duplicate(true); changed.identity.sources = {}
	check(not Trace.preflight_error(changed,15).is_empty(),"Missing source digests fail before setup")
	changed = current.duplicate(true); changed.identity.model -= 1
	check(not Trace.preflight_error(changed,15).is_empty(),"Old model fails before setup")
	check(not Trace.preflight_error(current,14).is_empty(),"Wrong generator fails before setup")
	changed = current.duplicate(true); changed.result.finished = false
	check(not Trace.preflight_error(changed,15).is_empty(),"Incomplete pilot fails before setup")
	changed = current.duplicate(true); changed.result.crash = "TREE IMPACT"
	check(not Trace.preflight_error(changed,15).is_empty(),"Crashed pilot fails before setup")
	changed = current.duplicate(true); changed.commands = []
	check(not Trace.preflight_error(changed,15).is_empty(),"Empty trace fails before setup")
	quit(0 if failures.is_empty() else 1)
