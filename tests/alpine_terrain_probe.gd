extends SceneTree
## Comparable area samples, independent of generator feature labels.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var version = 11
	var seed_value = 849205174
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--version="): version = int(arg.get_slice("=",1))
		if arg.begins_with("--seed="): seed_value = int(arg.get_slice("=",1))
	var field = load("res://scripts/world/mountain_cache_v%d.gd" % version).generate(seed_value)
	var report = measure(field)
	DirAccess.make_dir_recursive_absolute("res://artifacts/alpine_v12")
	preload("res://tests/test_report.gd").write("res://artifacts/alpine_v12/probe_v%d_%d.json" % [version,seed_value],JSON.stringify(report,"\t"))
	print("TERRAIN_PROBE ",JSON.stringify(report))
	quit()

static func measure(field) -> Dictionary:
	var counts = {"samples":0,"snow":0,"hard":0,"gentle":0,"moderate":0,"steep":0,"cliff":0,"forest":0}
	var per_face: Array = []
	for i in 6: per_face.append(counts.duplicate())
	for z in range(-2700,2701,24):
		for x in range(-2700,2701,24):
			var p = Vector2(x,z)
			if p.length()<360 or p.length()>2650: continue
			var face = field.adjacent_faces(p)[0]
			var angle = rad_to_deg(acos(clampf(field.contact_normal(x,z).y,0,1)))
			var rock: float = field.rock_fraction_at(x,z)
			var forest = int(field.stand_density(x,z)>.3)
			for bucket in [counts,per_face[face.index]]:
				bucket.samples += 1
				bucket.snow += int(rock<.42)
				bucket.hard += int(rock>=.5)
				bucket.gentle += int(angle<22)
				bucket.moderate += int(angle>=22 and angle<35)
				bucket.steep += int(angle>=35 and angle<48)
				bucket.cliff += int(angle>=48)
				bucket.forest += forest
	return {"version":field.GENERATOR_VERSION,"seed":field.seed_value,"counts":counts,"faces":per_face,"trees":field.obstacles.size(),"minerals":field.geology.statistics,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"generation_ms":field.generation_ms,"cache_hit":field.cache_hit}
