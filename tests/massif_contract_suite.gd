extends SceneTree
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Race = preload("res://scripts/racing/race_definition.gd")
const Cache = preload("res://scripts/world/mountain_cache_v13.gd")
var failures: Array = []
var checks = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run() -> void:
	for seed_value in [0,1,42,12981,849205174,2147483647]:
		check(Definition.parse_seed(str(seed_value)).get("version")==Definition.CURRENT_VERSION and Definition.parse_seed("%d / v10" % seed_value).get("seed")==seed_value,"Bare and explicit v10 seeds accept %d" % seed_value)
	for text in ["-1","2147483648","seed","42 / v10 / v10","42 / v99"]:
		check(not Definition.parse_seed(text).has("seed"),"Malformed or unsupported seed rejected: "+text)
	var field = Definition.generate(Definition.DEFAULT_SEED)
	var recipe = Definition.from_field(field,"Default Mountain")
	var decoded = Definition.decode(recipe.share_text())
	check(decoded.has("mountain"),"JSON recipe accepts its numeric generator version")
	if not decoded.has("mountain"): printerr(decoded); quit(1); return
	var rebuilt = decoded.mountain.reconstruct()
	check(rebuilt.has("field") and rebuilt.field.height_checksum==field.height_checksum and rebuilt.field.obstacle_checksum==field.obstacle_checksum,"Current recipe reconstructs both physical fingerprints")
	check(rebuilt.field.cache_hit and rebuilt.field.exposure_image.get_data()==field.exposure_image.get_data(),"Warm cache restores the full mountain exposure mask")
	for version in [11.5,0,Definition.CURRENT_VERSION+1,INF,NAN]:
		var ref = recipe.to_reference()
		ref.version = version
		check(not Definition.reference_error(ref).is_empty(),"Invalid version rejected: "+str(version))
	var corrupt = Definition.decode(recipe.share_text()).mountain
	corrupt.height_checksum = "0".repeat(64)
	check(not corrupt.reconstruct().has("field"),"Mismatched terrain fingerprints cannot silently load a different mountain")
	for face in field.faces:
		var race = Race.new()
		race.title = "Massif contract face %d" % face.index
		race.mountain = recipe.to_reference()
		race.start = field.launch_point(face.heading)
		race.heading = wrapf(face.heading,-PI,PI)
		var p: Vector2 = face.to_world(Vector2(0,2810))
		race.finish = Vector3(p.x,field.sample(p.x,p.y).height,p.y)
		check(Race.decode(race.share_text()).has("race") and race.validate_surface(field).is_empty(),"Face %d race round-trips with valid endpoints" % face.index)
		var session = preload("res://scripts/core/run_session.gd").new()
		session.configure_free(recipe.identity(),field.finish_z,field.finish_z)
		check(not session.eligible and session.reference_replay==null,"Face %d free skiing has no personal-best capture or ghost" % face.index)
	var file = FileAccess.open(Cache.DIRECTORY.path_join("default.bin"),FileAccess.READ)
	var data: Dictionary = file.get_var(false)
	file.close()
	check(Cache._valid(data,data.key),"Disposable bake validates its source and payload identity")
	data.heights[0] += 1
	check(not Cache._valid(data,data.key),"A corrupted bake is rejected before it can become a surface")
	check(field.heights[0]!=data.heights[0],"Cache buffers do not alias active terrain")
	DirAccess.make_dir_recursive_absolute("res://artifacts/geology_v11")
	var example = Definition.decode(FileAccess.get_file_as_string("res://examples/mountains/default-v%d.apexmountain" % Definition.CURRENT_VERSION))
	check(example.has("mountain") and example.mountain.identity()==recipe.identity(),"Bundled default recipe identifies the current terrain")
	preload("res://tests/test_report.gd").write("res://artifacts/geology_v11/contracts.json",JSON.stringify({"checks":checks,"failures":failures,"cache_load_ms":rebuilt.field.generation_ms,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum},"\t"))
	print("MASSIF_CONTRACTS checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
