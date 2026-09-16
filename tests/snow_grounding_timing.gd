extends SceneTree
## Capture-free CPU ABBA comparison, separate from native rendered timing.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Suite = preload("res://tests/snow_grounding_suite.gd")
const Probe = preload("res://tests/planted_snow_probe.gd")
const Bank = preload("res://tests/snow_crush_suite.gd").Bank
const Receipt = preload("res://tests/snow_grounding_mountain.gd")
const OUTPUT = "res://artifacts/snow_grounding_v28"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var sources = Receipt.source_hashes()
	var baseline = load(OUTPUT+"/baseline/core/ski_simulation.gd")
	var fields = {"plane":Probe.SnowRipple.new(0,32,.20),"bank":Bank.new(.30,8,0,5),"roller":Probe.SnowRipple.new(.30,32,.20,.35)}
	var rows: Array = []
	for model in [baseline,Sim,Sim,baseline]:
		for name in fields:
			var field = fields[name]
			var values: Array[float] = []; var air_ticks = 0
			var input = RiderInput.new(); input.tuck = 1.0
			var sim = Suite.rider(model,field,160)
			for tick in 120: sim.step(Suite.DT,input,field)
			for repeat in 5:
				sim = Suite.rider(model,field,160); sim.effective_tuck = 1.0
				for tick in 240:
					var start = Time.get_ticks_usec()
					sim.step(Suite.DT,input,field)
					values.append(Time.get_ticks_usec()-start)
					if not sim.grounded: air_ticks += 1
			rows.append({"model":model.MODEL_VERSION,"fixture":name,"solver_us":Suite.stats(values),"ticks":values.size(),"air_ticks":air_ticks})
			print("SNOW_SOLVER ",JSON.stringify(rows[-1]))
	var failures = [] if sources==Receipt.source_hashes() else ["Source changed during CPU timing"]
	preload("res://tests/test_report.gd").write(OUTPUT+"/solver_timing.json",JSON.stringify({"rows":rows,"sources":sources,"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"order":"27,28,28,27","unranked":true,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
