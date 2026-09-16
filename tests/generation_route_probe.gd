extends SceneTree
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")
const Search = preload("res://tests/generation_route_search.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var settings = Cache.Settings.preset(3); settings.tree_spacing = .5
	var field = Cache.generate(849205174,settings)
	var isolate = "--geometry-only" in OS.get_cmdline_user_args()
	var snow_material = "--snow-material" in OS.get_cmdline_user_args()
	if snow_material: field.material_image.fill(Color(0,0,0,1))
	if isolate:
		field.tree_data.heads.fill(-1); field.geology.reserved = {}
	var job = Cache.Job.new(); var start = Time.get_ticks_usec()
	var routes = job.map_tiles(6,func(face): return Search.survey(field,face,.6,.5))
	var rows: Array = []; var success = true
	for route in routes:
		var connected = not route.paths[0].is_empty() and not route.paths[1].is_empty()
		var spread = route.paths[0][-1].distance_to(route.paths[1][-1]) if connected else 0.0
		success = success and connected and spread>=500
		rows.append({"face":route.face,"connected":connected,"spread_m":spread,"visited":route.safe_samples,"refinement":route.refinement,"reachable_rows":route.get("reachable_columns",[])})
	var report = {"geometry_only":isolate,"snow_material_override":snow_material,"node_clearance_m":.6,"edge_clearance_m":.5,"solver_trunk_expansion_m":.35,"survey_ms":(Time.get_ticks_usec()-start)/1000.0,"routes":rows,"pass":success}
	preload("res://tests/test_report.gd").write("res://artifacts/generation_v15/route_support_probe.json" if snow_material else "res://artifacts/generation_v15/route_geometry_probe.json" if isolate else "res://artifacts/generation_v15/route_clearance_probe.json",JSON.stringify(report,"\t"))
	print("ROUTE_CLEARANCE ",JSON.stringify(report)); quit(0 if success else 1)
