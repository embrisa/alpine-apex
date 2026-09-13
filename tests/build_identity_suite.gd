extends SceneTree
const Build = preload("res://scripts/diagnostics/build_identity.gd")
const Evidence = preload("res://scripts/diagnostics/scenario_evidence.gd")
var checks = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ",label)
func run() -> void:
	var value = Build.current()
	check(Build.valid(value),"Checkout produces valid identity")
	check(value.compatibility.get("physics")==preload("res://scripts/core/ski_simulation.gd").MODEL_VERSION,"Identity uses live physics constant")
	check(value.compatibility.get("world")==preload("res://scripts/world/mountain_definition.gd").CURRENT_VERSION,"Identity uses live world constant")
	check(value.compatibility.get("replay")==preload("res://scripts/racing/run_replay.gd").VERSION,"Identity uses live replay constant")
	check(value.compatibility.get("tuning_sha256")==FileAccess.get_sha256("res://config/ski_default.tres"),"Identity uses actual tuning bytes")
	check(value.engine_sha256==FileAccess.get_sha256(OS.get_executable_path()),"Identity uses actual engine executable")
	check(Evidence.identity().build==value,"Scenario evidence uses same frozen identity")
	var text = JSON.stringify(value)
	var envelope = {"schema":1,"payload":text,"sha256":text.sha256_text()}
	check(Build.decode_package(JSON.stringify(envelope))==JSON.parse_string(text),"Embedded envelope round trips checkout identity through JSON")
	envelope.payload += " "
	check(Build.decode_package(JSON.stringify(envelope)).is_empty(),"Tampered package envelope rejected")
	check(Build.decode_package("{}").is_empty(),"Missing package identity rejected")
	check(not Build.valid({"schema":1,"dev":-1}),"Invalid development number rejected")
	value.compatibility.physics = -900
	check(Build.current().compatibility.physics!=-900,"Callers cannot mutate frozen identity")
	check(Build.details().contains(Build.short_label()),"Copied details include displayed identity")
	print("BUILD_IDENTITY_SUITE ",JSON.stringify({"checks":checks,"failures":failures,"build":Build.current()}))
	quit(0 if failures.is_empty() else 1)
