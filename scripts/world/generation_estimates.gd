extends RefCounted
## Broad initial ranges, calibrated only by completed local runs of this code.
const Settings = preload("res://scripts/world/generation_settings.gd")
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")
const Sources = preload("res://scripts/world/generation_sources.gd")
const PATH = "user://generation_measurements_v15.json"
const SCENERY_STAGES = ["preparation_cache_read","scenery_maps","terrain_arrays","snow_readability","tree_scenery_preparation","mineral_batches","preparation_cache_write"]
static var mutex = Mutex.new()
static var estimate_source: String = ""

static func work_units(settings: Dictionary) -> Dictionary:
	var complexity = 1+.35*(settings.landform_complexity-1)
	var spacing = 4.5*minf(settings.tree_spacing,1/sqrt(settings.tree_population))
	var candidates = pow(ceili(5560/spacing),2)
	var trees = Settings.TREE_BASELINE*settings.tree_population
	return {"recipe":6*complexity,"terrain_shaping":2362369*complexity,"geology_foundations":settings.landform_complexity,
		"normals_before_snow":2362369,"exposure_before_snow":2362369*complexity,"snow_shaping":2362369*(.5+.5*settings.snow_feature_density),
		"geology_placement":settings.mineral_density*(.9+.1*settings.landform_complexity),"normals_before_trees":2362369,"exposure_before_trees":2362369*complexity,
		"ecology_filters":769*769*complexity,"tree_candidates":candidates,"tree_filtering":trees,"tree_snow":trees,"final_seating":trees+16022*settings.mineral_density,
		"collision_preparation":trees+16022*settings.mineral_density*12,"final_normals":2362369,"hashing":2362369+trees,"physical_cache_write":2362369+trees*8,
		"physical_cache_read":2362369+trees*8,"preparation_cache_read":2362369+trees*16,"scenery_maps":4194304,"terrain_arrays":576,"snow_readability":2362369,
		"tree_scenery_preparation":trees,"mineral_batches":16022*settings.mineral_density,"preparation_cache_write":2362369+trees*16}

static func estimate(seed_number: int, settings: Dictionary, use_cache_hints: bool = true) -> Dictionary:
	var values = Settings.canonical(settings)
	var units = work_units(values)
	# Estimate-only source memoization keeps slider edits off the large catalog.
	# The actual loaders still hash every dependency before accepting an entry.
	var source = _estimate_source()
	var expected_key = (Cache.recipe_key(seed_number,values)+"|"+source+"|"+Sources.engine_identity()).sha256_text() if not source.is_empty() else ""
	var cache_expected = use_cache_hints and _header_matches(Cache.path_for(seed_number,values),expected_key)
	var bundle_directory = OS.get_executable_path().get_base_dir().path_join("data")
	var bundled_recipe = seed_number==Cache.Terrain.DEFAULT_SEED and values==Settings.preset() and not OS.has_feature("editor")
	if use_cache_hints and bundled_recipe and not cache_expected:
		cache_expected = _header_matches(bundle_directory.path_join("default_mountain_v15.physical"),expected_key)
	var prep_found = FileAccess.file_exists(Cache.DIRECTORY.path_join(Cache.recipe_key(seed_number,values)+".scenery"))
	if bundled_recipe: prep_found = prep_found or FileAccess.file_exists(bundle_directory.path_join("default_mountain_v15.scenery"))
	var prep_expected = prep_found and cache_expected
	var cold = 220.0*(.40+.25*values.tree_population+.15*values.mineral_density+.20*values.landform_complexity)
	var submission_units = .25+.25*values.tree_population+.50*values.mineral_density
	var additional = 70.0*submission_units
	var predicted: Dictionary = {}
	mutex.lock()
	var history = _read()
	mutex.unlock()
	var learned = false
	var submission_s = float(history.get("scene_ms",44000))/1000.0*submission_units/maxf(.5,float(history.get("scene_units",1.0)))
	if history.get("source")==source:
		for name in history.get("rates",{}):
			if units.has(name): predicted[name] = history.rates[name]*units[name]
		if predicted.has("terrain_shaping"):
			cold = 0
			for name in predicted:
				if name not in ["physical_cache_read","preparation_cache_read","scenery_maps","terrain_arrays","snow_readability","tree_scenery_preparation","mineral_batches","preparation_cache_write"]: cold += predicted[name]/1000.0
			learned = true
		if predicted.has("tree_scenery_preparation"):
			additional = submission_s
			for name in ["scenery_maps","terrain_arrays","snow_readability","tree_scenery_preparation","mineral_batches","preparation_cache_write"]: additional += float(predicted.get(name,0))/1000.0
	var generation = float(predicted.get("physical_cache_read",3000*(.5+.5*values.tree_population)))/1000.0 if cache_expected else cold
	if prep_expected: additional = float(predicted.get("preparation_cache_read",4000*(.5+.5*values.tree_population)))/1000.0+submission_s
	# Complete 4K High loading includes driver/resource memory beyond Godot's
	# allocator. Fresh process telemetry measured about 6.1 GiB for Standard.
	var memory = 5.0+.30*values.tree_population+.08*values.mineral_density
	if history.get("source")==source and history.has("peak_gib"):
		# Asset/terrain memory is mostly fixed. Scale packed populations additively
		# instead of multiplying every loaded texture by the requested tree factor.
		memory = maxf(memory,history.peak_gib+.30*(values.tree_population-float(history.get("tree_factor",1)))+.08*(values.mineral_density-float(history.get("mineral_factor",1))))
	return {"generation_s":Vector2(generation*(.65 if learned else .4),generation*(1.7 if learned else 2.5)),"additional_s":Vector2(additional*.5,additional*2),
		"peak_memory_gib":Vector2(memory*.8,memory*1.7),"physical_cache_expected":cache_expected,"preparation_cache_expected":prep_expected,"calibrated":learned,"stages":predicted,"submission_s":submission_s}

static func configure(job, seed_number: int, settings: Dictionary) -> void:
	var value = estimate(seed_number,settings)
	job.set_meta("estimate_recipe",{"seed":seed_number,"settings":Settings.canonical(settings),"cache_expected":value.physical_cache_expected})
	_apply_physical(job,value)

static func _apply_physical(job, value: Dictionary, elapsed_s: float = 0.0) -> void:
	job.mutex.lock()
	job.initial_estimate = value.generation_s+Vector2.ONE*elapsed_s; job.additional_estimate = value.additional_s; job.memory_estimate = value.peak_memory_gib
	job.expected_stages = value.stages.duplicate()
	var cached_ms = job.expected_stages.get("physical_cache_read",value.generation_s.y*700)
	for name in SCENERY_STAGES+["physical_cache_read"]: job.expected_stages.erase(name)
	if value.physical_cache_expected: job.expected_stages = {"physical_cache_read":cached_ms}
	job.mutex.unlock()

static func reconcile(job, progress: Dictionary) -> void:
	# Header hints are provisional. A rejected archive starts the ordinary recipe
	# stages; promptly restore the complete cold-work estimate in both loading UIs.
	if progress.stage not in ["recipe","terrain_shaping"] or not job.has_meta("estimate_recipe"): return
	var recipe: Dictionary = job.get_meta("estimate_recipe")
	if not recipe.cache_expected: return
	recipe.cache_expected = false
	job.set_meta("estimate_recipe",recipe)
	_apply_physical(job,estimate(recipe.seed,recipe.settings,false),progress.elapsed_s)

static func configure_scenery(job, field, allow_cached: bool = true) -> void:
	var value = estimate(field.seed_value,field.generation_settings)
	var elapsed_s = job.snapshot().elapsed_s
	job.mutex.lock()
	job.initial_estimate = value.additional_s+Vector2.ONE*elapsed_s
	job.expected_stages = {}
	for name in SCENERY_STAGES:
		if value.stages.has(name): job.expected_stages[name] = value.stages[name]
	if value.preparation_cache_expected and allow_cached:
		job.expected_stages = {"preparation_cache_read":value.stages.get("preparation_cache_read",4000.0)}
	else: job.expected_stages.erase("preparation_cache_read")
	# Submission remains an explicit estimate until the main-thread build finishes.
	job.expected_stages.scene_submission = value.submission_s*1000
	job.mutex.unlock()

static func record(field, scene_ms: float = 0) -> void:
	if not field.valid or field.job.is_cancelled(): return
	# Explicit determinism experiments do not recalibrate normal loading workers.
	if field.job.worker_count!=mini(6,maxi(1,OS.get_processor_count()-2)): return
	var stages: Dictionary = field.job.snapshot().timings_ms; var units = work_units(field.generation_settings)
	var source = Sources.signature()
	mutex.lock()
	estimate_source = source
	var history = _read()
	if history.get("source")!=source: history = {"schema":1,"source":source,"runs":0,"rates":{}}
	for name in stages:
		if not units.has(name) or float(stages[name])<=0: continue
		var rate = float(stages[name])/maxf(1,float(units[name]))
		history.rates[name] = lerpf(float(history.rates.get(name,rate)),rate,.35)
	history.runs += 1
	if scene_ms>0:
		var units_here = .25+.25*field.generation_settings.tree_population+.50*field.generation_settings.mineral_density
		var previous_ms = float(history.get("scene_ms",scene_ms))/maxf(.5,float(history.get("scene_units",units_here)))*units_here
		history.scene_ms = lerpf(previous_ms,scene_ms,.35); history.scene_units = units_here
	if scene_ms>0:
		# Conservative process-memory proxy: allocator + graphics resources +
		# driver allowance. Raw allocator-only numbers cannot predict time-to-ski RAM.
		history.peak_gib = (OS.get_static_memory_peak_usage()+Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))/1073741824.0+1.0
		history.tree_factor = field.generation_settings.tree_population; history.mineral_factor = field.generation_settings.mineral_density
	var file = FileAccess.open(PATH+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(history)); file.flush(); file.close(); DirAccess.rename_absolute(PATH+".tmp",PATH)
	mutex.unlock()

static func _estimate_source() -> String:
	mutex.lock(); var value = estimate_source; mutex.unlock()
	if not value.is_empty(): return value
	value = Sources.signature()
	mutex.lock(); estimate_source = value; mutex.unlock()
	return value

static func _read() -> Dictionary:
	if not FileAccess.file_exists(PATH): return {}
	var file = FileAccess.open(PATH,FileAccess.READ)
	if not file or file.get_length()>65536: return {}
	var result = JSON.parse_string(file.get_as_text())
	if not result is Dictionary or result.get("schema")!=1 or not result.get("source") is String or result.source.length()!=64: return {}
	if not result.get("rates") is Dictionary or result.rates.size()>64: return {}
	for name in result.rates:
		if not name is String or not (result.rates[name] is float or result.rates[name] is int) or not is_finite(float(result.rates[name])) or result.rates[name]<0: return {}
	for name in ["runs","scene_ms","scene_units","peak_gib","tree_factor","mineral_factor"]:
		if result.has(name) and (not (result[name] is float or result[name] is int) or not is_finite(float(result[name])) or result[name]<0): return {}
	return result

static func _header_matches(path: String, key: String) -> bool:
	if key.is_empty() or not FileAccess.file_exists(path): return false
	var file = FileAccess.open(path,FileAccess.READ)
	return file!=null and file.get_length()>=80 and file.get_buffer(8).get_string_from_ascii()=="APEXV15\n" and file.get_32()==1 and file.get_buffer(64).get_string_from_ascii()==key

static func label(value: Dictionary) -> String:
	return "%s estimates · generation %s · additional time to ski %s · broad peak RAM %.1f–%.1f GiB\n%s · %s" % ["Locally calibrated" if value.calibrated else "Broad initial",_range(value.generation_s),_range(value.additional_s),value.peak_memory_gib.x,value.peak_memory_gib.y,
		"Physical cache available (validation required)" if value.physical_cache_expected else "Fresh generation","Scenery entry found (quality/source validation required)" if value.preparation_cache_expected else "Scenery preparation required"]

static func _range(seconds: Vector2) -> String:
	return "%d–%d s" % [maxi(1,floori(seconds.x)),maxi(1,ceili(seconds.y))]
