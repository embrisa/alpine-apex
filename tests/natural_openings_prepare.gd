extends SceneTree
## Explicit preparation and population receipt for the changed physical generator.
const Cache = preload("res://scripts/world/mountain_definition.gd").Cache
const OUT = "res://artifacts/natural_openings_20260917"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if OS.get_environment("ALPINE_VALIDATION_MODE")!="Exclusive" or not preload("res://scripts/diagnostics/test_world_policy.gd").require_full("Two-seed natural opening preparation"):
		quit(2); return
	DirAccess.make_dir_recursive_absolute(OUT)
	var rows = []
	for seed_number in [849205174,638201943]:
		var job = Cache.Job.new()
		var key = Cache.cache_key(seed_number)
		var data = Cache.Archive.read(Cache.path_for(seed_number),key,job)
		var field = Cache.restore(seed_number,Cache.Settings.preset(),data,job) if not data.is_empty() else null
		var warm = field!=null
		data.clear()
		if field==null:
			field = Cache.Terrain.new(seed_number,true,Cache.Settings.preset(),job)
			if not field.valid: quit(1); return
			if not Cache.Archive.write(Cache.path_for(seed_number),key,Cache.sections(field),job): quit(1); return
		var highest = -INF; var upper = 0; var bins = {}
		for p in field.tree_data.positions:
			highest = maxf(highest,p.y)
			if p.y>=4000: upper+=1
			var bin = str(floori(p.y/100)*100)
			bins[bin]=bins.get(bin,0)+1
		var row = {"seed":seed_number,"generator":field.GENERATOR_VERSION,"warm":warm,"generation_ms":field.generation_ms,"population":field.population,"highest_tree_m":highest,"trees_above_4000m":upper,"altitude_bins":bins}
		rows.append(row)
		FileAccess.open(OUT+"/populations.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
		print("NATURAL_OPENINGS_PREPARED ",JSON.stringify(row))
		assert(field.tree_data.size()==170000 and highest>=4100 and highest<4350)
		field = null
	quit()
