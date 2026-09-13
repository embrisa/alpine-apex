extends SceneTree
## Evidence collection must not affect deterministic production fixture state.
const Probe = preload("res://tests/small_landing_probe.gd")
const Evidence = preload("res://scripts/diagnostics/scenario_evidence.gd")
var checks=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); printerr("FAIL ",label)
func run() -> void:
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/diagnostics/scenarios.json"))
	for name_value in catalog.scenarios:
		var fixture: Dictionary=catalog.scenarios[name_value].fixture
		var field=Probe.surface(fixture)
		var observed=Probe.rider(field,fixture); var control=Probe.rider(field,fixture)
		var previous=Evidence.Recorder.state(observed)
		var events: Array=[]; var stable=true; var units=true
		for tick in roundi(catalog.scenarios[name_value].seconds*120):
			var intent=Probe.input(tick,fixture)
			observed.step(Probe.DT,intent,field); control.step(Probe.DT,Probe.input(tick,fixture),field)
			var row=Evidence.sample(observed,tick+1,intent,field)
			events.append_array(Evidence.events(previous,row.state)); previous=row.state
			stable=stable and Evidence.Recorder.state(observed)==Evidence.Recorder.state(control)
			units=units and is_equal_approx(row.metrics.load_n,observed.skis[0].load_n+observed.skis[1].load_n) and row.time==(tick+1)/120.0
		check(stable,name_value+": evidence collection preserves exact solver state")
		check(units,name_value+": telemetry retains physical units and tick clock")
		check(observed.position.is_finite() and not observed.crashed,name_value+": bounded fixture completes finite skiing")
		if name_value=="small-hop": check("takeoff" in events and "landing" in events,"Small hop contains departure and recovery")
	check(Evidence.events({"grounded":true,"crashed":false},{"grounded":false,"crashed":true})==["takeoff","crash"],"Simultaneous events retain both transitions")
	var envelope=Evidence.envelope("fixture",{},{})
	check(not envelope.personal_records and not envelope.performance_evidence and not envelope.human_acceptance,"Diagnostic envelope cannot claim records, FPS or human acceptance")
	print("SCENARIO_SUITE ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
