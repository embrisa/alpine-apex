extends SceneTree
const Cache = preload("res://scripts/world/mountain_cache_v16.gd")
const Settings = preload("res://scripts/world/generation_settings.gd")
const Job = preload("res://scripts/world/generation_job.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Survey = preload("res://tests/generation_route_search.gd")
var failures: Array = []
var checks = 0
func check(value: bool, label: String) -> void:
	checks += 1
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label); printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var case_name = "standard"
	var physical_clearance = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): case_name = arg.get_slice("=",1)
		if arg=="--physical-clearance": physical_clearance = true
	var settings = Settings.preset(); var seed_number = 849205174
	match case_name:
		"alternate_standard": seed_number = 638201943
		"alternate_light": seed_number = 42; settings = Settings.preset(0)
		"alternate_rich": seed_number = 927461; settings = Settings.preset(2)
		"extreme": settings = Settings.preset(3)
		"extreme_tight": settings = Settings.preset(3); settings.tree_spacing = .5
		"saturation": settings.tree_population = 5.0; settings.tree_spacing = 2.0
		"trees": settings.tree_population = 5.0
		"trees_tight": settings.tree_population = 5.0; settings.tree_spacing = .5
		"minerals": settings.mineral_density = 5.0
		"snow": settings.snow_feature_density = 5.0
		"landforms": settings.landform_complexity = 5.0
		"spacing": settings.tree_spacing = .5
	var job = Job.new(); var field = Cache.generate(seed_number,settings,job)
	if field==null: quit(2); return
	print("V16_WORLD_POPULATION ",JSON.stringify(field.population))
	var report = {"case":case_name,"seed":seed_number,"settings":settings,"cold_or_load_ms":field.generation_ms,"cache_hit":field.cache_hit,"population":field.population,"stages":field.generation_stages,"snow":field.tree_snow_statistics,"route_clearance":{"node_m":.6 if physical_clearance else 1.8,"edge_m":.5 if physical_clearance else 1.5,"solver_trunk_expansion_m":.35},"routes":[]}
	check(field.NX==1537 and field.NZ==1537 and field.CELL==4 and field.faces.size()==6,"Dimensions and authority retained")
	check(field.obstacles.is_empty() and field.tree_data.valid(),"One packed tree population")
	check(field.population.requested_trees==roundi(Settings.TREE_BASELINE*settings.tree_population) and field.population.trees<=field.population.requested_trees,"Requested and achieved trees honest")
	check(field.population.requested_minerals==roundi(Settings.MINERAL_BASELINE*settings.mineral_density),"Requested minerals follow independent density")
	check(field.population.tree_saturated==(field.population.trees<field.population.requested_trees),"Saturation flag matches achieved count")
	var target_snow = Settings.targets(settings).snow_features; var actual_snow = 0
	for face in field.faces: actual_snow += face.snow_forms.size()
	check(actual_snow==target_snow,"Snow-feature count follows independent density")
	var tree_seats = true; var separation = true; var protection = true
	var closest_margin = INF; var dropped = 0; var sampled = 0
	for id in field.tree_data.size():
		var p: Vector3 = field.tree_data.positions[id]; var radius: float = field.tree_data.dimensions[id].x
		tree_seats = tree_seats and absf(p.y-field.height_at(p.x,p.z))<.001
		# Exhaustive neighbouring-trunk audit; each unordered pair checked once.
		for other in field.tree_data.nearby(p,maxf(4.2*settings.tree_spacing,radius+field.tree_data.max_radius+2*settings.tree_spacing)):
			if other<=id: continue
			var q: Vector3 = field.tree_data.positions[other]
			var required = maxf(4.2*settings.tree_spacing,radius+field.tree_data.dimensions[other].x+2*settings.tree_spacing)
			var margin = Vector2(p.x-q.x,p.z-q.z).length()-required
			closest_margin = minf(closest_margin,margin); separation = separation and margin>=-.001
		if id%97==0:
			sampled += 1
			for face in field.adjacent_faces(Vector2(p.x,p.z)):
				if face.drop_protected(face.to_local(Vector2(p.x,p.z)),radius+2*settings.tree_spacing) or face.woodland_opening(face.to_local(Vector2(p.x,p.z))): protection = false; dropped += 1
	check(tree_seats,"Every tree seated on final support")
	check(separation,"Every neighbouring trunk preserves separation and non-overlap")
	check(protection,"Stratified tree samples preserve protected drops and woodland openings")
	report.tree_clearance = {"minimum_margin_m":closest_margin if is_finite(closest_margin) else null,"protected_samples":sampled,"invalid":dropped}
	var finite = true; var snow_bounds = true; var snow_material = true
	var material = field.material_image.get_data()
	for i in field.heights.size():
		finite = finite and is_finite(field.heights[i]) and field.final_normals[i].is_finite()
		snow_bounds = snow_bounds and field.tree_snow_height[i]>=0 and field.tree_snow_height[i]<=1.001
		if field.tree_snow_height[i]>=.15: snow_material = snow_material and material[i]==0
	check(finite and snow_bounds,"Finite support/normals and bounded maximum-overlap snow")
	check(snow_material,"Final snow cover agrees with cached contact materials")
	var mineral_seats = true; var floating = 0; var greatest_gap = 0.0
	for placed in field.geology.placements:
		for local in field.geology.catalog.records[placed.asset].seating:
			var p: Vector3 = placed.pose*local; var gap = p.y-field.height_at(p.x,p.z)
			greatest_gap = maxf(greatest_gap,gap)
			if gap>.002: mineral_seats = false; floating += 1
	check(mineral_seats,"Every mineral foundation remains seated after final snow")
	report.mineral_seating = {"floating_samples":floating,"greatest_gap_m":greatest_gap}
	var material_agrees = true
	for z in range(0,field.NZ,41):
		for x in range(0,field.NX,41):
			var p = Vector2(field.X_MIN+x*4+1,field.Z_MIN+z*4+1)
			material_agrees = material_agrees and absf(field.sample(p.x,p.y).height-field.height_at(p.x,p.y))<.001
	check(material_agrees,"Fast queries agree with solver triangles")
	var route_job = Job.new(); route_job.worker_count = 6
	var routes = route_job.map_tiles(6,func(face): return Survey.survey(field,face,.6 if physical_clearance else 1.8,.5 if physical_clearance else 1.5))
	for route in routes:
		var connected = not route.paths[0].is_empty() and not route.paths[1].is_empty()
		var separation_m = route.paths[0][-1].distance_to(route.paths[1][-1]) if connected else 0.0
		check(connected,"Continuous downhill connection to the runout on face %d" % route.face)
		report.routes.append({"face":route.face,"connected":connected,"exit_separation_m":separation_m,"safe_samples":route.safe_samples,"refinement":route.refinement,"wide_exit_target_500m":connected and separation_m>=500})
	if case_name=="standard":
		check(report.routes.all(func(row): return row.wide_exit_target_500m),"Standard retains the existing 500 m route-choice benchmark")
	var recipe = Definition.from_field(field,"Custom validation")
	var decoded = Definition.decode(recipe.share_text())
	check(decoded.has("mountain") and decoded.mountain.generation_settings==settings,"Custom recipe sharing preserves every factor")
	var warm_started = Time.get_ticks_usec()
	var reconstructed = decoded.mountain.reconstruct()
	report.recipe_warm_ms = (Time.get_ticks_usec()-warm_started)/1000.0
	check(reconstructed.has("field") and reconstructed.field.cache_hit and reconstructed.field.height_checksum==field.height_checksum and reconstructed.field.obstacle_checksum==field.obstacle_checksum and reconstructed.field.tree_data.positions==field.tree_data.positions and reconstructed.field.material_image.get_data()==field.material_image.get_data(),"Custom cache reconstructs exact physical identity and packed data")
	report.checks = checks; report.failures = failures; report.memory_peak = OS.get_static_memory_peak_usage()
	preload("res://tests/test_report.gd").write("res://artifacts/generation_v16/world_"+case_name+("_physical" if physical_clearance else "")+".json",JSON.stringify(report,"\t"))
	print("V16_WORLD ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
