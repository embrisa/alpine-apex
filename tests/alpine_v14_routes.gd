extends SceneTree
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Density = preload("res://tests/density_contract.gd")
const OUTPUT = "res://artifacts/planted_snow"
var failures: Array = []
var checks = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"/v14_849205174.json"))
	var field = Definition.generate(849205174,14)
	check(data.height_sha256==field.height_checksum and data.obstacle_sha256==field.obstacle_checksum,"Route survey matches current bake")
	var paths_for_pilot: Array = []
	for route in data.routes:
		var paths: Array = []; var portable: Array = []
		for path in route.paths:
			var vectors: Array = []; var pairs: Array = []
			for item in path:
				var pair = str(item).trim_prefix("(").trim_suffix(")").split(",") if item is String else item
				var p = Vector2(float(pair[0]),float(pair[1])); vectors.append(p); pairs.append([p.x,p.y])
			paths.append(vectors); portable.append(pairs)
		var widths: Array = route.reachable_columns.slice(20*int(route.refinement)); widths.sort()
		check(widths.min()>=1 and widths[widths.size()/2]*route.across_m>=144,"Distributed snow width on face %d"%route.face)
		check(route.merge_nodes>100,"Routes branch and rejoin on face %d"%route.face)
		check(Density.swept_routes_clear(field,field.faces[int(route.face)],paths),"Actual continuous trunk/mineral sweeps clear on face %d"%route.face)
		paths_for_pilot.append({"face":route.face,"paths":portable})
	var mineral_seats = true
	for placed in field.geology.placements:
		for local in field.geology.catalog.records[placed.asset].seating:
			var p: Vector3 = placed.pose*local
			if p.y>float(field.sample(p.x,p.z).height)+.001: mineral_seats = false
	check(mineral_seats,"Mineral foundations match final snow")
	preload("res://tests/test_report.gd").write(OUTPUT+"/routes.json",JSON.stringify({"checks":checks,"failures":failures,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"surveys":paths_for_pilot,"minerals":field.geology.placements.size(),"unranked":true},"\t"))
	print("V14_ROUTE_CONTRACT checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
