extends SceneTree
## Isolate historical carving failures against the frozen pre-change model.
const Carve = preload("res://tests/arcade_carving_suite.gd")
const Sim = preload("res://scripts/core/ski_simulation.gd")
const OUTPUT = "res://artifacts/snow_grounding_v28"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var baseline = load(OUTPUT+"/baseline/core/ski_simulation.gd")
	var current: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"/regression/carving_model28.json"))
	var rows: Array = []; var failures: Array = []
	for entry in current.rows:
		var row = Carve.measure(baseline,entry.kmh,entry.steer,entry.tuck,entry.switch,entry.mode)
		for key in row:
			if key=="trace": continue
			var same: bool = absf(float(row[key])-float(entry[key]))<.00001 if typeof(row[key]) in [TYPE_FLOAT,TYPE_INT] else row[key]==entry[key]
			if not same: failures.append("Model 28 differs on firm carving case %d, %s"%[rows.size(),key])
		rows.append(row)
		if rows.size()%96==0: print("FROZEN_CARVING rows=",rows.size()," differences=",failures.size())
	var disabled_same = true
	for speed in [30.0,60.0,120.0,160.0]:
		for direction in [-1.0,1.0]:
			for mode in ["held","reversal","release"]:
				var a = Carve.measure(baseline,speed,direction,0.0,false,mode,{"arcade_carve_strength":0.0})
				var b = Carve.measure(Sim,speed,direction,0.0,false,mode,{"arcade_carve_strength":0.0})
				disabled_same = disabled_same and a==b
	if not disabled_same: failures.append("Disabled-carving curves differ from model 27")
	var historical = Carve.acceptance(rows)
	if historical.failures!=current.acceptance.failures: failures.append("Historical acceptance failure set differs from frozen model 27")
	var report = {"model":Sim.MODEL_VERSION,"baseline_model":27,"compared_cases":rows.size(),"disabled_carving_pairs":24,"disabled_carving_identical":disabled_same,"historical_acceptance_failures":historical.failures,"current_legacy_contract_failures":current.contracts.failures,"failures":failures,"unranked":true}
	FileAccess.open(OUTPUT+"/carving_comparison.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FROZEN_CARVING_COMPLETE cases=",rows.size()," historical failures=",historical.failures.size()," differences=",failures)
	quit(0 if failures.is_empty() else 1)
