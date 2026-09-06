extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	print("PASS: " if value else "FAIL: ",label)
	if not value: failures.append(label)
func run() -> void:
	var field = preload("res://scripts/world/test_slope.gd").new()
	var original = [hash(field.heights),hash(field.obstacles),field.seed_value]
	var a = preload("res://scripts/world/mountain_data.gd").new()
	a.generate(field,638201943)
	var b = preload("res://scripts/world/mountain_data.gd").new()
	b.generate(field,638201943)
	check(a.height_checksum==b.height_checksum and a.environment_checksum==b.environment_checksum,"Seed and generator version reproduce heights and all environment masks")
	b.generate(field,638201944)
	check(a.height_checksum!=b.height_checksum and a.environment_checksum!=b.environment_checksum,"A different scenery seed changes the generated mountains and masks")
	check(original==[hash(field.heights),hash(field.obstacles),field.seed_value],"Generation leaves the benchmark terrain and obstacles unchanged")
	var maximum_error = 0.0
	for z in range(field.NZ):
		for x in range(field.NX):
			var p: Vector3 = field.vertex(x,z)
			var px = int((p.x-a.ORIGIN.x)/a.CELL)
			var pz = int((p.z-a.ORIGIN.y)/a.CELL)
			maximum_error = maxf(maximum_error,absf(a.height_image.get_pixel(px,pz).r-p.y))
	check(maximum_error==0.0,"Every laboratory vertex is preserved exactly in the generated heightmap")
	var finite_heights = true
	for h in a.height_image.get_data().to_float32_array():
		finite_heights = finite_heights and is_finite(h)
	check(finite_heights,"All generated mountain heights are finite")
	var mask = a.environment_image
	var snow_min = 1.0
	var snow_max = 0.0
	var tree_min = 1.0
	var tree_max = 0.0
	for y in range(mask.get_height()):
		for x in range(mask.get_width()):
			var c = mask.get_pixel(x,y)
			snow_min = minf(snow_min,c.r);snow_max=maxf(snow_max,c.r)
			tree_min = minf(tree_min,c.b);tree_max=maxf(tree_max,c.b)
	check(snow_max-snow_min>.4 and tree_max-tree_min>.4,"Masks distinguish snow, exposed rock and vegetation suitability")
	var result = {"failures":failures,"descriptor":a.descriptor(),"max_lab_vertex_error_m":maximum_error,"generation_ms":a.generation_ms,"height_bytes":a.height_image.get_data_size(),"snow_range":[snow_min,snow_max],"vegetation_range":[tree_min,tree_max]}
	FileAccess.open("res://artifacts/mountain_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if failures.is_empty() else 1)
