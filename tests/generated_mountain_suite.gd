extends SceneTree
const Terrain = preload("res://scripts/world/generators/drainage_v3.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Store = preload("res://scripts/world/mountain_store.gd")
const Race = preload("res://scripts/racing/race_definition.gd")
var failures: Array = []
var checks: int = 0
var metrics: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ",label)
	if not value: failures.append(label)

func run() -> void:
	var legacy = Definition.generate(849205174,1)
	var legacy_file = Definition.decode(FileAccess.get_file_as_string("res://examples/mountains/849205174.apexmountain"))
	check(legacy.height_checksum=="0ed82c22719010fd77995ed3a6f97933ceb631b1b5ee853b5976e3167a14f0a6" and legacy.obstacle_checksum=="c57948415fda4626b30bc3c5e37ca1023bc717657b3b01137e3b419876e301f6","Archived generator v1 retains its original terrain and obstacles")
	check(legacy_file.has("mountain") and legacy_file.mountain.reconstruct().field.heights==legacy.heights,"Existing v1 mountain file reconstructs its unchanged physical surface")
	check(legacy_file.mountain.identity()==Definition.from_field(legacy).identity(),"Existing v1 mountain identity survives the v2 update")
	check(Race.reconstruct_surface(legacy_file.mountain.to_reference()).field.heights==legacy.heights,"Existing v1 race reference reconstructs its original surface")
	var archived_v2 = Definition.generate(849205174,2)
	var a = Terrain.new(849205174)
	var b = Terrain.new(849205174)
	check(a.heights==b.heights and a.obstacles==b.obstacles and a.parameters==b.parameters,"Same seed reconstructs exact terrain, landforms and physical obstacles")
	check(a.height_checksum==b.height_checksum and a.obstacle_checksum==b.obstacle_checksum,"Reconstructed fingerprints are identical")
	check(a.GENERATOR_VERSION==3 and a.height_checksum!=legacy.height_checksum,"Steeper generation has a distinct version and terrain identity")
	check(archived_v2.height_checksum=="386b2b1dc89c6df713f057d916bb6081bd8c47943f7b6e6280e131372acf5c93" and archived_v2.obstacle_checksum=="a8bc9fbc2ec8312c5a69bf7808e162eb7584c647adfb0c3e9452b9113dd8274f","Generator v2 reference fingerprint is frozen; future terrain changes require versioning")
	check(a.height_checksum=="a63348d8ceefaa1380d04fa6f13b0408a5df5d9e56bf068c7ac5168d559d0eb7" and a.obstacle_checksum=="04b32758eaf3f0f43664bc68bea2fc6bd5785726b527749235fb41c88a84e890","Generator v3 reference fingerprints are frozen")
	check(a.bounds().size==Vector2(1536,4096),"New terrain has four times the skiable area at unchanged 4 m resolution")
	check(a.ski_bounds().has_point(Vector2(600,3200)) and a.sweep_obstacle(Vector3(0,5000,3000),Vector3(0,5000,3001)).is_empty(),"The expanded lower mountain is inside real playable bounds")
	var lab = preload("res://scripts/world/test_slope.gd").new()
	# Baseline source is deliberately not required by the committed test.
	check(a.heights!=lab.heights,"Generated terrain replaces the physical laboratory, not just scenery")
	var seeds = [0,1,42,12981,849205174,2147483647]
	for seed_value in seeds:
		var field = a if seed_value==a.seed_value else Terrain.new(seed_value)
		if seed_value!=a.seed_value: check(field.height_checksum!=a.height_checksum,"Seed %d changes large landforms" % seed_value)
		var spawn: Vector3 = field.spawn_point()
		check(Race.point_error(spawn,field).is_empty() and rad_to_deg(acos(field.contact_normal(spawn.x,spawn.z).y))<20,"Seed %d has a clear, gentle spawn" % seed_value)
		var sim = SkiSimulation.new(preload("res://config/ski_default.tres").duplicate(true))
		sim.reset(spawn,field.spawn_heading())
		sim.prime_contacts(field)
		var intent = RiderInput.new()
		intent.tuck = .6
		for i in 1200: sim.step(1.0/120.0,intent,field)
		check(not sim.crashed and sim.position.z>65 and sim.speed_kmh()>60,"Seed %d launches cleanly above 60 km/h within ten seconds with the real ski solver" % seed_value)
		var finite = true
		for h in field.heights: finite = finite and is_finite(h)
		check(finite,"Seed %d has finite heights" % seed_value)
		var stats = connectivity(field)
		stats["entry_kmh_at_10s"] = sim.speed_kmh()
		metrics.append(stats)
		check(stats.reached_basin and stats.branch_width_m>160,"Seed %d offers connected downhill terrain on both sides of its ridge" % seed_value)
		check(stats.vertical_m>2000 and stats.vertical_m<2600,"Seed %d has 2000–2600 m of vertical relief" % seed_value)
		check(stats.trees>40 and stats.rocks>40 and field.obstacles.size()<1800,"Seed %d has forests and rock hazards within the bounded obstacle budget" % seed_value)
		check(stats.steep_fraction>.5 and stats.steep_fraction<.9 and field.contact_normal(0,field.finish_z).y>cos(deg_to_rad(18)),"Seed %d has sustained steep faces with a gentler entry and runout" % seed_value)
		# Triangle interpolation is independently checked at interior barycentric positions.
		var ix = 74
		var iz = 150
		var v0: Vector3 = field.vertex(ix,iz)
		var v1: Vector3 = field.vertex(ix+1,iz)
		var v2: Vector3 = field.vertex(ix,iz+1)
		var point = v0*.3+v1*.2+v2*.5
		check(absf(field.sample(point.x,point.z).height-point.y)<.001,"Seed %d ski height matches its rendered triangle" % seed_value)
	var mountain = Definition.from_field(a,"Ridge / & Bowl 🏔")
	var original_id: String = mountain.identity()
	mountain.title = "Renamed Basin"
	check(mountain.identity()==original_id,"Renaming leaves terrain and race compatibility unchanged")
	var code: String = mountain.share_text()
	var decoded = Definition.decode(code)
	check(code.to_utf8_buffer().size()<1024 and decoded.has("mountain") and decoded.mountain.reconstruct().has("field"),"Compact export imports and reconstructs with verified fingerprints")
	var store = Store.new()
	store.directory = "user://mountain_test_%d" % Time.get_ticks_usec()
	check(store.save(mountain).is_empty(),"Local library saves a named mountain")
	mountain.title = "New name"
	check(store.save(mountain).is_empty() and store.load_all().size()==1 and store.load_all()[0].title=="New name","Saving a renamed mountain updates the existing entry")
	var exported = store.directory.path_join("roundtrip.apexmountain")
	check(Store.write_file(exported,mountain).is_empty() and Store.read_file(exported).mountain.share_text()==mountain.share_text(),"File export/import preserves name, seed, versions and checksums")
	for seed_text in ["849205174","Mountain Seed: 849205174","0","2147483647","Mountain Seed: 849205174 / v1","Mountain Seed: 849205174 / v2","Mountain Seed: 849205174 / v3"]:
		check(Definition.parse_seed(seed_text).has("seed"),"Accept seed text: "+seed_text)
	for invalid in ["","-1","2147483648","1.5","seed","99999999999999999999999","42 / v99","42 / v2 / v1","42 / v1.5"]:
		check(not Definition.parse_seed(invalid).has("seed"),"Reject invalid seed: "+invalid)
	for invalid in ["{}","null","[]",code.repeat(20),code.replace('"schema": 1','"schema": 99'),code.replace('"version": 3','"version": 99'),code.replace('"Renamed Basin"','""')]:
		check(not Definition.decode(invalid).has("mountain"),"Reject malformed, oversized or unsupported mountain recipe")
	check(Definition.parse_seed("849205174").version==4,"Bare seeds select the current generator")
	var legacy_seed = Definition.parse_seed(Definition.from_field(legacy).seed_text())
	check(Definition.generate(legacy_seed.seed,legacy_seed.version).heights==legacy.heights,"Copied seeds include a reconstructable legacy version")
	check(not Definition.decode(code.replace('"version": 3','"version": 1')).mountain.reconstruct().has("field"),"Changing a recipe version without its fingerprints cannot load different terrain")
	var corrupted = JSON.parse_string(code)
	corrupted.mountain.height_sha256 = "a".repeat(64)
	check(not Definition.decode(JSON.stringify(corrupted)).mountain.reconstruct().has("field"),"A mismatched physical fingerprint cannot silently load")
	var race = Race.new()
	race.title = "Basin descent"
	race.mountain = Race.mountain_reference(a,a.seed_value)
	race.start = a.spawn_point()
	race.finish = Vector3(0,a.sample(0,3390).height,3390)
	var parsed = Race.decode(race.share_text())
	check(parsed.has("race") and parsed.race.validate_surface(a).is_empty(),"Generated mountains support portable open-route races")
	check(not race.validate_surface(lab).is_empty(),"Same numeric seed cannot confuse laboratory and generated race identities")
	check(Race.reconstruct_surface(race.mountain).field.heights==a.heights,"A shared race reconstructs its generated physical terrain")
	for name in DirAccess.get_files_at(store.directory): DirAccess.remove_absolute(store.directory.path_join(name))
	DirAccess.remove_absolute(store.directory)
	DirAccess.make_dir_recursive_absolute("res://artifacts/jump_upgrade")
	var output = {"checks":checks,"failures":failures,"seeds":metrics,"example":JSON.parse_string(code)}
	FileAccess.open("res://artifacts/jump_upgrade/generator_results.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("GENERATED_MOUNTAIN_RESULTS ",JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)

func connectivity(field) -> Dictionary:
	# Monotone downhill graph over the actual surface, including swept obstacle
	# clearance. It verifies route choice, not a predetermined racing corridor.
	var step = 16.0
	var reachable: Dictionary = {roundi(field.spawn_point().x/step):true}
	var branch_width = 10000.0
	var gentle = 0
	var steep = 0
	var samples = 0
	for z in range(66,int(field.finish_z),16):
		var next: Dictionary = {}
		for ix in range(-43,44):
			var x = ix*step
			var point = Vector3(x,field.sample(x,z).height,z)
			var slope = rad_to_deg(acos(field.contact_normal(x,z).y))
			samples += 1
			if slope<18: gentle += 1
			if slope>35: steep += 1
			if slope>48: continue
			for dx in [-1,0,1]:
				if not reachable.has(ix+dx): continue
				var prev = Vector3((ix+dx)*step,field.sample((ix+dx)*step,z-16).height,z-16)
				if point.y<prev.y and field.sweep_obstacle(prev,point).is_empty():
					next[ix] = true
					break
		reachable = next
		if z>800 and z<2400 and not reachable.is_empty():
			var keys = reachable.keys()
			keys.sort()
			branch_width = minf(branch_width,(keys.back()-keys.front())*step)
	var trees = field.obstacles.filter(func(ob): return ob.tree).size()
	return {"seed":field.seed_value,"reached_basin":not reachable.is_empty(),"branch_width_m":branch_width if branch_width<10000 else 0,
		"vertical_m":field.spawn_point().y-field.sample(0,field.finish_z).height,"gentle_fraction":float(gentle)/samples,"steep_fraction":float(steep)/samples,
		"trees":trees,"rocks":field.obstacles.size()-trees,"generation_ms":field.generation_ms,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum}
