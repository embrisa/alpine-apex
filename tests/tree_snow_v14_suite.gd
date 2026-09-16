extends SceneTree
const Terrain = preload("res://scripts/world/generators/alpine_massif_v14.gd")
const Bake = preload("res://scripts/world/generators/tree_snow_v14.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const OUTPUT = "res://artifacts/planted_snow"
var failures: Array = []
var checks = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func run() -> void:
	var preview = "--from-before" in OS.get_cmdline_user_args()
	var field
	var original = PackedFloat32Array()
	if preview:
		var cache = FileAccess.open(OUTPUT+"/before_tree_mounds/default.bin",FileAccess.READ).get_var(false)
		field = Terrain.new(849205174,false)
		field.heights = cache.heights
		original = cache.heights
		field.exposure_image = Image.create_from_data(field.NX,field.NZ,false,Image.FORMAT_RGBA8,cache.exposure)
		for ob in cache.obstacles: field.add_obstacle(ob)
		field.geology.restore(cache.placements,cache.geology_statistics)
		Bake.apply(field)
		field._refresh_identity()
		preload("res://tests/test_report.gd").write_var(OUTPUT+"/tree_snow_preview.bin",{"heights":field.heights,"tree_snow_height":field.tree_snow_height,"tree_snow_statistics":field.tree_snow_statistics,"obstacles":field.obstacles,"placements":field.geology.placements,"geology_statistics":field.geology.statistics,"exposure":field.exposure_image.get_data(),"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum})
	else: field = Definition.generate(849205174,14)
	var stats: Dictionary = field.tree_snow_statistics
	check(stats.trees==200000,"Every retained tree participates in the physical accumulation pass")
	check(stats.coverage_5cm>=.85,"At least 85 percent of tree bases gain modest physical deposits")
	check(stats.median_center_rise_m>=.10 and stats.median_center_rise_m<=.50,"Typical trunk rise stays modest")
	check(stats.median_prominence_6m>=.08 and stats.median_prominence_6m<=.25,"Typical local tree pile is 8-25 cm high")
	check(stats.prominence_percentiles_m[2]<=.50,"At least 90 percent of tree piles have at most 50 cm local prominence")
	check(stats.max_grid_rise_m<=Bake.MAX_RISE_M+.001,"Overlapping tree deposits retain a bounded height")
	for face in stats.per_face:
		check(face.raised_5cm>=face.trees*.80,"Most tree bases on each face have modest physical mounds")
	var exact_seats = true; var positive = true; var faithful = true; var snow_material = true
	for ob in field.obstacles:
		exact_seats = exact_seats and absf(ob.position.y-field.sample(ob.position.x,ob.position.z).height)<.001
	for i in field.tree_snow_height.size():
		positive = positive and field.tree_snow_height[i]>=0 and is_finite(field.heights[i])
		if preview: faithful = faithful and absf(field.heights[i]-original[i]-field.tree_snow_height[i])<.00025
		if field.tree_snow_height[i]>=.15: snow_material = snow_material and field.exposure_image.get_pixel(i%field.NX,i/field.NX).r<.001
	check(exact_seats,"Trees are seated on the finished physical mounds")
	check(positive and faithful,"One finite authoritative grid contains the actual added snow")
	check(snow_material,"Substantial tree deposits stay snow instead of exposing rock on their new slopes")
	var mineral_seats = true
	for placed in field.geology.placements:
		for local in field.geology.catalog.records[placed.asset].seating:
			var p: Vector3 = placed.pose*local
			if p.y>field.sample(p.x,p.z).height+.001: mineral_seats = false
	check(mineral_seats,"Reseated mineral foundations remain buried in final snow")
	# Per-ski contact must sample the same mound height, not a separate collider.
	var matched = true
	for i in range(0,field.obstacles.size(),4000):
		var p: Vector3 = field.obstacles[i].position+Vector3(2,0,0)
		p.y = field.sample(p.x,p.z).height
		var sim = SkiSimulation.new(); sim.reset(p,0); sim.prime_contacts(field)
		for ski in sim.skis:
			matched = matched and absf(ski.position.y-field.sample(ski.position.x,ski.position.z).height)<.002
	check(matched,"Independent skis use the physical tree-mound triangles")
	preload("res://tests/test_report.gd").write(OUTPUT+("/tree_snow_preview.json" if preview else "/tree_snow.json"),JSON.stringify({"checks":checks,"failures":failures,"statistics":stats,"height_sha256":Terrain._digest(field.heights.to_byte_array()),"preview":preview},"\t"))
	print("TREE_SNOW_RESULT checks=",checks," statistics=",JSON.stringify(stats)," failures=",failures)
	quit(0 if failures.is_empty() else 1)
