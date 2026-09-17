extends SceneTree
const Trace = preload("res://tests/performance_trace.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run() -> void:
	var current := {"identity":{"sources":Trace.source_identity(),"model":Trace.Simulation.MODEL_VERSION,"generator":16},"result":{"finished":true,"crash":"","ticks":12},"input_fields":Trace.Inputs.FIELDS,"command_ticks":12,"commands":[[0,1,0,false,false,0,0,false,0]]}
	check(Trace.preflight_error(current,16).is_empty(),"Current complete trace passes source preflight (terrain/replay still checked by benchmark)")
	check(not Trace.preflight_error(null,16).is_empty(),"Malformed JSON fails before setup")
	var changed: Dictionary = current.duplicate(true); changed.identity.sources = {}
	check(not Trace.preflight_error(changed,16).is_empty(),"Missing source digests fail before setup")
	changed = current.duplicate(true); changed.identity.model -= 1
	check(not Trace.preflight_error(changed,16).is_empty(),"Old model fails before setup")
	check(not Trace.preflight_error(current,15).is_empty(),"Wrong generator fails before setup")
	changed = current.duplicate(true); changed.result.finished = false
	check(not Trace.preflight_error(changed,16).is_empty(),"Incomplete pilot fails before setup")
	changed = current.duplicate(true); changed.result.crash = "TREE IMPACT"
	check(not Trace.preflight_error(changed,16).is_empty(),"Crashed pilot fails before setup")
	changed = current.duplicate(true); changed.commands = []
	check(not Trace.preflight_error(changed,16).is_empty(),"Empty trace fails before setup")
	changed = current.duplicate(true); changed.commands[0].pop_back()
	check(not Trace.preflight_error(changed,16).is_empty(),"Missing air tilt fails before setup")
	changed = current.duplicate(true); changed.commands[0][0] = NAN
	check(not Trace.preflight_error(changed,16).is_empty(),"Nonfinite control fails before setup")
	changed = current.duplicate(true); changed.result.ticks = 13
	check(not Trace.preflight_error(changed,16).is_empty(),"Missing tick input fails before setup")
	changed = current.duplicate(true); changed.result.finished = false
	check(Trace.preflight_error(changed,16,false).is_empty(),"Explicit scenario playback accepts a short clip")
	changed.result.crash = "TREE IMPACT"
	check(Trace.preflight_error(changed,16,false).is_empty(),"Explicit scenario playback retains a captured crash")
	changed = current.duplicate(true); changed.scenario_origin = [1608,1416]
	check(not Trace.preflight_error(changed,16).is_empty(),"Local origins cannot claim a complete descent")
	check(Trace.preflight_error(changed,16,false).is_empty(),"Explicit ordinary scenario accepts a finite local origin")
	changed.scenario_origin = [NAN,1416]
	check(not Trace.preflight_error(changed,16,false).is_empty(),"Nonfinite local origin rejected")
	changed.scenario_origin = [1608]
	check(not Trace.preflight_error(changed,16,false).is_empty(),"Incomplete local origin rejected")
	quit(0 if failures.is_empty() else 1)
