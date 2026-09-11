extends SceneTree
const Terrain = preload("res://scripts/world/generators/alpine_massif_v12.gd")
const Cache = preload("res://scripts/world/mountain_cache_v12.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Survey = preload("res://tests/alpine_route_survey.gd")
const Probe = preload("res://tests/alpine_terrain_probe.gd")
var checks = 0
var failures: Array = []
var reports: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ",label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/alpine_v12")
	check(Definition.parse_seed("42 / v12").version==12,"Archived v12 remains explicitly selectable")
	check(Definition.parse_seed("849205174 / v12").version==12,"Explicit v12 seed sharing")
	var seeds = [849205174] if "--quick" in OS.get_cmdline_user_args() else [849205174,0,42,2147483647]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seeds = [clampi(int(arg.get_slice("=",1)),0,2147483647)]
	for seed_value in seeds:
		print("ALPINE_V12_GENERATE ",seed_value)
		var field = Cache.generate(seed_value)
		print("ALPINE_V12_BAKED ",seed_value," ms=",field.generation_ms)
		field.build_material_map()
		var report = Probe.measure(field)
		print("ALPINE_V12_COVERAGE ",report.counts)
		var count: Dictionary = report.counts
		check(float(count.snow)/count.samples>.55,"Seed %d is predominantly snow" % seed_value)
		check(float(count.hard)/count.samples<.38 and float(count.hard)/count.samples>.12,"Seed %d retains secondary, meaningful hard terrain" % seed_value)
		check(count.moderate>count.samples*.18 and count.steep>count.samples*.28 and count.gentle>count.samples*.04,"Seed %d mixes open, steep and gentle support" % seed_value)
		check(field.obstacles.size()<75000 and field.obstacles.size()>15000,"Seed %d stays within the dense regional tree budget" % seed_value)
		check(field.geology.placements.size()>900 and field.geology.placements.size()<2400,"Seed %d has bounded clustered mineral detail" % seed_value)
		check(field.geology.statistics.max_stamp_m<=8.001,"Bounded rock foundation fitting")
		var finite = true
		for h in field.heights: finite = finite and is_finite(h) and h<=field.heights[(field.NZ/2)*field.NX+field.NX/2]+.01
		check(finite,"Highest-point summit and finite full grid")
		var grounded = true
		for placed in field.geology.placements:
			for local in field.geology.catalog.records[placed.asset].seating:
				var p: Vector3 = placed.pose*local
				grounded = grounded and p.y<=float(field.sample(p.x,p.z).height)+.001
		check(grounded,"Seed %d seats mineral foundations on final snow" % seed_value)
		var trees_clear = true
		for ob in field.obstacles: trees_clear = trees_clear and field.geology_clear(ob.position,ob.radius+1.9)
		check(trees_clear,"Trees avoid solid mineral footprints")
		var surveys: Array = []
		for face in field.faces:
			var stats = Survey.survey(field,face.index)
			var paths: Array = stats.paths
			var widths: Array = stats.reachable_columns.slice(20)
			var ordered_widths = widths.duplicate()
			ordered_widths.sort()
			check(not paths[0].is_empty() and not paths[1].is_empty() and paths[0][-1].y>=2784 and paths[1][-1].y>=2784,"Seed %d face %d has two sampled summit-to-base alternatives" % [seed_value,face.index])
			var separation = 0.0
			if not paths[0].is_empty() and not paths[1].is_empty(): separation = paths[0][-1].distance_to(paths[1][-1])
			check(separation>=500 and widths.min()>=1 and ordered_widths[ordered_widths.size()/2]>=12,"Seed %d face %d offers distributed reachable snow with local constrictions" % [seed_value,face.index])
			check(stats.merge_nodes>100,"Seed %d face %d has branching and rejoining connections" % [seed_value,face.index])
			var treeline = 0
			var dense = 0
			var sparse = 0
			var open = 0
			for z in range(1400,2641,40):
				for x in range(-1040,1041,40):
					var density: float = face.stand_density(x,z)
					dense += int(density>.4)
					sparse += int(density>.03 and density<.23)
					open += int(density<.02)
			for ob in field.obstacles:
				var q: Vector2 = face.to_local(Vector2(ob.position.x,ob.position.z))
				if face.sector_weight(q.x,q.y)>.65: treeline += 1
			check(dense>5 and sparse>15 and open>15 and treeline>300,"Seed %d face %d mixes dense woods, sparse margins and openings" % [seed_value,face.index])
			var forest_counts: Array = []
			for stand in face.stands:
				var centre: Vector2 = face.to_world(stand.position)
				var trunks = 0
				for ob in field.obstacles:
					if centre.distance_squared_to(Vector2(ob.position.x,ob.position.z))<60*60: trunks += 1
				forest_counts.append(trunks)
			forest_counts.sort()
			check(forest_counts[-2]>=100,"Seed %d face %d has multiple actual dense woodland cores" % [seed_value,face.index])
			stats.forest_core_trunks_within_60m = forest_counts
			var continuous = true
			for r in range(400,2601,100):
				var angle: float = face.heading+PI/6
				var a = Vector2(sin(angle-.00001),cos(angle-.00001))*r
				var b = Vector2(sin(angle+.00001),cos(angle+.00001))*r
				continuous = continuous and absf(field.sample(a.x,a.y).height-field.sample(b.x,b.y).height)<.3
			check(continuous,"Seed %d face %d joins its neighbour continuously" % [seed_value,face.index])
			stats.endpoint_separation_m = separation
			stats.minimum_reachable_width_m = widths.min()*Survey.X_STEP
			stats.median_reachable_width_m = ordered_widths[ordered_widths.size()/2]*Survey.X_STEP
			stats.paths = paths.map(func(path): return path.map(func(p): return [p.x,p.y]))
			surveys.append(stats)
			print("ALPINE_V12_FACE ",seed_value," ",face.index," exits=",separation," width=",stats.minimum_reachable_width_m)
		report.surveys = surveys
		var recipe = Definition.from_field(field,"Alpine regions")
		check(Definition.decode(recipe.share_text()).error.is_empty(),"V12 recipe round trip")
		var height_hash: String = field.height_checksum
		var obstacle_hash: String = field.obstacle_checksum
		if "--repeat" in OS.get_cmdline_user_args() and seed_value==849205174:
			field = null
			field = Terrain.new(seed_value)
			check(field.height_checksum==height_hash and field.obstacle_checksum==obstacle_hash,"Fresh independent bake repeats both fingerprints")
		field = null
		var warm = Cache.generate(seed_value)
		check(warm.cache_hit and warm.height_checksum==height_hash and warm.obstacle_checksum==obstacle_hash,"Warm cache retains geometry and obstacles")
		warm = null
		reports.append(report)
		FileAccess.open("res://artifacts/alpine_v12/survey_%d.json" % seed_value,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	FileAccess.open("res://artifacts/alpine_v12/generation_tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"seeds":reports},"\t"))
	print("ALPINE_V12_RESULTS ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
