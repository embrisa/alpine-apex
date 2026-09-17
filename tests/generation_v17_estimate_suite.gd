extends SceneTree
const Estimates = preload("res://scripts/world/generation_estimates.gd")
const Job = preload("res://scripts/world/generation_job.gd")
var failures: Array = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); printerr("FAIL ",label)
func _initialize() -> void:
	var settings = Estimates.Settings.preset()
	var cached = Estimates.estimate(849205174,settings)
	var cold = Estimates.estimate(849205174,settings,false)
	check(cached.physical_cache_expected,"Validated current fixture has a cache header hint")
	check(not cold.physical_cache_expected and not cold.preparation_cache_expected,"Cache rejection selects fresh work")
	check(cold.generation_s.y>cached.generation_s.y,"Fresh generation range includes its additional work")
	var job = Job.new(); Estimates.configure(job,849205174,settings)
	job.begin_stage("recipe",6); Estimates.reconcile(job,job.snapshot())
	check(not job.expected_stages.has("physical_cache_read") and job.initial_estimate.y>=cold.generation_s.y,"Rejected cache switches the shared job estimate to fresh generation")
	var rich = settings.duplicate(); rich.tree_population = 5; rich.mineral_density = 5
	var extreme = Estimates.estimate(849205174,rich,false)
	check(extreme.peak_memory_gib.y>cold.peak_memory_gib.y and extreme.peak_memory_gib.y<cold.peak_memory_gib.y*2,"Population memory grows without multiplying fixed assets")
	print("V17_ESTIMATES 5 checks; failures=",failures); quit(0 if failures.is_empty() else 1)
