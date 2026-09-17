extends SceneTree
const Settings = preload("res://scripts/world/generation_settings.gd")
const Job = preload("res://scripts/world/generation_job.gd")
const Cache = preload("res://scripts/world/mountain_cache_v16.gd")
const Archive = preload("res://scripts/world/mountain_archive.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Race = preload("res://scripts/racing/race_definition.gd")
const Prep = preload("res://scripts/world/mountain_preparation.gd")
const Sources = preload("res://scripts/world/generation_sources.gd")
var failures: Array = []
var checks = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(load("res://scripts/main.gd")!=null,"Main dependencies parse")
	for i in 4:
		var s = Settings.preset(i)
		check(Settings.preset_index(s)==i and Settings.error(s).is_empty(),"Preset roundtrip %d" % i)
		for key in Settings.KEYS: check(s[key]==(1 if key=="tree_spacing" else Settings.MULTIPLIERS[i]),"Preset factor "+key)
	var original = Settings.preset(); var keys: Dictionary = {}
	for key in Settings.KEYS:
		for value in [.5,2.0 if key=="tree_spacing" else 5.0]:
			var s = original.duplicate(); s[key] = value
			check(Settings.error(s).is_empty() and Settings.preset_index(s)==4,"Independent custom control "+key)
			var identity = Cache.recipe_key(849205174,s)
			check(not keys.has(identity) and identity!=Cache.recipe_key(849205174),"Cache separation "+key); keys[identity] = true
	for bad in [null,{},true,{"tree_population":1}]: check(not Settings.error(bad).is_empty(),"Reject incomplete settings")
	for bad in [NAN,INF,0,5.01,1.001,true,"1"]:
		var s = original.duplicate(); s.tree_population = bad
		check(not Settings.error(s).is_empty(),"Reject invalid setting "+str(bad))
	check(Definition.parse_seed("849205174").version==Definition.CURRENT_VERSION,"Bare seed uses current Standard")
	check(not Definition.parse_seed("849205174 / v15").has("seed"),"Reject obsolete seed versions")
	var hashes: Array = []
	for workers in [1,2,6]:
		var job = Job.new(); job.worker_count = workers; job.begin_stage("determinism",997)
		var values = job.map_tiles(997,func(id): job.advance(); return Settings.stream(8462,71,id))
		hashes.append(var_to_bytes(values).hex_encode().sha256_text())
		check(job.snapshot().completed==997,"Thread-safe work accounting")
	check(hashes[0]==hashes[1] and hashes[1]==hashes[2],"Stable candidate order across worker counts")
	var cancelled = Job.new(); var worker = Thread.new()
	worker.start(func(): return cancelled.map_tiles(100000,func(id): OS.delay_usec(500); return id))
	await create_timer(.025).timeout; cancelled.cancel(); var then = Time.get_ticks_usec()
	while worker.is_alive(): await process_frame
	check(worker.wait_to_finish().is_empty() and Time.get_ticks_usec()-then<1000000,"Cancellation joins all bounded workers")
	var directory = "res://artifacts/generation_v16/contracts_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var path = directory.path_join("atomic.physical"); var key = "verified".sha256_text()
	var sections = [{"name":"metadata","value":{"test":1}},{"name":"packed","value":PackedVector3Array([Vector3.ONE,Vector3(2,3,4)])}]
	check(Archive.write(path,key,sections),"Publish complete archive")
	var hash_before = FileAccess.get_sha256(path)
	check(not Archive.write(path,key,[{"name":"new","value":true}],cancelled) and FileAccess.get_sha256(path)==hash_before,"Cancelled replacement preserves previous entry")
	var oversized = PackedByteArray(); oversized.resize(Archive.MAX_SECTION+1)
	check(not Archive.write(path,key,[{"name":"too_large","value":oversized}]) and FileAccess.get_sha256(path)==hash_before,"Failed bounded write preserves the previous valid entry")
	oversized.clear()
	check(Archive.read(path,key).packed==sections[1].value,"Bounded sections preserve packed types")
	check(Archive.read(path,"different".sha256_text()).is_empty(),"Source/engine/key invalidation")
	var file = FileAccess.open(path,FileAccess.READ_WRITE); file.seek(file.get_length()-1); var value = file.get_8(); file.seek(file.get_length()-1); file.store_8(value^1); file.close()
	check(Archive.read(path,key).is_empty(),"Corrupted section rejected before decoding")
	file = preload("res://tests/test_report.gd").open_write(path); file.store_string("APEXV16"); file.close()
	check(Archive.read(path,key).is_empty(),"Truncated archive rejected")
	var protected_key = "protected".sha256_text(); var old_key = "old".sha256_text(); var new_key = "new".sha256_text()
	for recipe in [old_key,new_key,protected_key]:
		file = preload("res://tests/test_report.gd").open_write(directory.path_join(recipe+".physical")); file.store_buffer(PackedByteArray([1,2,3,4])); file.close()
	file = preload("res://tests/test_report.gd").open_write(directory.path_join(new_key+".used")); file.store_8(1); file.close()
	var first_eviction = Archive.evict(protected_key,8,"",directory)
	check(first_eviction.evicted==[old_key] and FileAccess.file_exists(directory.path_join(new_key+".physical")),"Last-use eviction keeps the more recent recipe")
	var eviction = Archive.evict(protected_key,4,"",directory)
	check(eviction.bytes==4 and eviction.evicted==[new_key] and FileAccess.file_exists(directory.path_join(protected_key+".physical")),"Budget eviction protects default")
	var field = preload("res://tests/validation_mountain.gd").load_standard()
	check(field!=null and field.cache_hit,"Current physical cache reusable")
	if field == null: quit(1); return
	var definition = Definition.from_field(field,"Contract test")
	var decoded = Definition.decode(definition.share_text())
	check(decoded.has("mountain") and decoded.mountain.identity()==definition.identity(),"Recipe identity survives sharing")
	var rebuilt = decoded.mountain.reconstruct()
	check(rebuilt.has("field") and rebuilt.field.tree_data.positions==field.tree_data.positions and rebuilt.field.material_image.get_data()==field.material_image.get_data(),"Warm recipe restores final packed trees and material")
	var custom = definition.to_reference(); custom.settings.tree_population = 2.35
	check(Definition.reference_error(custom).is_empty() and JSON.stringify(custom).sha256_text()!=definition.identity(),"Custom settings carried in references")
	var race = Race.new(); race.mountain = definition.to_reference(); race.title = "V16 sharing"; race.start = Vector3(0,100,20); race.finish = Vector3(0,0,200)
	var shared = Race.decode(race.share_text())
	check(shared.has("race") and shared.race.mountain.settings==field.generation_settings,"Race sharing retains canonical settings")
	var old = JSON.parse_string(definition.share_text()); old.schema = 1
	check(not Definition.decode(JSON.stringify(old)).has("mountain"),"Old mountain schema rejected without migration")
	check(Sources.engine_identity()==FileAccess.get_sha256(OS.get_executable_path()),"Cache engine identity fingerprints the running binary")
	check(not Sources.signature().is_empty() and not Sources.signature(true).is_empty(),"Both dependency manifests complete")
	for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	var result = {"checks":checks,"failures":failures}
	preload("res://tests/test_report.gd").write("res://artifacts/generation_v16/contracts.json",JSON.stringify(result,"\t"))
	print("GENERATION_CONTRACTS ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
