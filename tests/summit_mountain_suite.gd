extends SceneTree
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Race = preload("res://scripts/racing/race_definition.gd")
const World = preload("res://scripts/world/alpine_world.gd")
var checks = 0
var failures: Array = []
var metrics: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run() -> void:
	var example = Definition.generate(849205174)
	check(example.GENERATOR_VERSION==4 and example.bounds().size==Vector2(6144,6144),"Current seeds generate a complete 6.144 km square mountain")
	check(example.height_checksum=="5fae684348b894f276549e57c420b6318d5e508be169348df81431c13060b3c9" and example.obstacle_checksum=="547e534a054990f7df0f6ea2f19417c0dca408077a2184b3f384b94dbfe09e3e","Generator v4 terrain and obstacle fingerprints are frozen")
	var repeated = Definition.generate(849205174)
	check(repeated.heights==example.heights and repeated.obstacles==example.obstacles,"The same seed reconstructs every height and physical obstacle exactly")
	repeated = null
	for seed_value in [849205174,0,1,42,12981,2147483647]:
		var field = example if seed_value==849205174 else Definition.generate(seed_value)
		var high = -INF
		var finite = true
		for h in field.heights:
			finite = finite and is_finite(h)
			high = maxf(high,h)
		check(finite and absf(high-field.spawn_point().y)<.001,"Seed %d spawns at the highest vertex on the entire physical mountain" % seed_value)
		check(field.ski_bounds().has_point(Vector2(-2500,-2500)) and field.ski_bounds().has_point(Vector2(2500,2500)),"Seed %d has real physical terrain in every quadrant" % seed_value)
		var directions = 0
		var minimum_speed = INF
		for i in 8:
			var heading = TAU*i/8
			var sim = SkiSimulation.new(preload("res://config/ski_default.tres").duplicate(true))
			sim.reset(field.launch_point(heading),heading)
			sim.prime_contacts(field)
			var intent = RiderInput.new()
			intent.tuck = .75
			for tick in 2400: sim.step(1.0/120.0,intent,field)
			minimum_speed = minf(minimum_speed,sim.speed_kmh())
			if not sim.crashed and Vector2(sim.position.x,sim.position.z).length()>250 and sim.speed_kmh()>100: directions += 1
		check(directions==8,"Seed %d launches successfully in all eight directions through the real ski solver" % seed_value)
		var graph = connectivity(field)
		check(graph.octants==8,"Seed %d has connected downhill terrain reaching the base on every side" % seed_value)
		check(graph.minimum_vertical>1800 and graph.maximum_vertical<2400,"Seed %d provides 1.8–2.4 km vertical in every direction" % seed_value)
		metrics.append({"seed":seed_value,"entry_minimum_kmh_at_20s":minimum_speed,"connectivity":graph,"generation_ms":field.generation_ms,"obstacles":field.obstacles.size(),"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum})
	var mountain = Definition.from_field(example,"Summit 360")
	var decoded = Definition.decode(mountain.share_text())
	check(decoded.has("mountain") and decoded.mountain.reconstruct().field.heights==example.heights,"Compact v4 mountain files reconstruct the full summit mountain")
	check(Definition.parse_seed(mountain.seed_text()).version==4 and Definition.parse_seed("849205174").version==4,"Copied and bare seeds select the intended current version")
	for version in [1,2,3]:
		var old = Definition.generate(849205174,version)
		var old_recipe = Definition.from_field(old)
		check(old_recipe.generator_version==version and old_recipe.reconstruct().field.heights==old.heights,"Archived v%d recipe remains reconstructable" % version)
		check(old_recipe.identity()!=mountain.identity(),"Archived v%d races cannot collide with the full mountain identity" % version)
	for heading in [0.0,PI/2,PI,-PI/2]:
		var direction = Vector2(sin(heading),cos(heading))
		var race = Race.new()
		race.title = "Any face"
		race.mountain = mountain.to_reference()
		race.start = example.launch_point(heading)
		var p = direction*2810
		race.finish = Vector3(p.x,example.sample(p.x,p.y).height,p.y)
		race.heading = wrapf(heading,-PI,PI)
		check(Race.decode(race.share_text()).has("race") and race.validate_surface(example).is_empty(),"Race endpoints can span the summit and base on heading %.0f°" % rad_to_deg(heading))
		race.start = example.spawn_point()
		check(not race.validate_surface(example).is_empty(),"A timed race cannot start motionless on the summit selector")
	var session = preload("res://scripts/core/run_session.gd").new()
	session.configure_free(mountain.identity(),example.finish_z,example.finish_z)
	for p in [Vector3(0,0,-1425),Vector3(-1425,0,0),Vector3(1425,0,0),Vector3(0,0,1425)]:
		check(is_equal_approx(session.progress_percent(p),50.0),"Free-ski progress measures distance from the summit in every direction")
	session.configure()
	check(session.free_radius==0,"Returning to the benchmark clears radial free-ski progress")
	# Each decimated patch must retain every elementary edge segment. Adjacent
	# LODs then share identical boundary geometry with the full physical mesh.
	for step in [4,8]:
		var indices = World._terrain_lod_indices(64,step)
		var edges: Dictionary = {}
		var area = 0.0
		for i in range(0,indices.size(),3):
			var points: Array[Vector2] = []
			for j in 3: points.append(Vector2(indices[i+j]%65,indices[i+j]/65))
			area += (points[1]-points[0]).cross(points[2]-points[0])*.5
			for j in 3:
				var a = indices[i+j]
				var b = indices[i+(j+1)%3]
				var key = Vector2i(mini(a,b),maxi(a,b))
				edges[key] = edges.get(key,0)+1
		var complete = true
		for i in 64:
			for pair in [Vector2i(i,i+1),Vector2i(64*65+i,64*65+i+1),Vector2i(i*65,(i+1)*65),Vector2i(i*65+64,(i+1)*65+64)]:
				complete = complete and edges.get(pair,0)==1
		check(complete and is_equal_approx(area,4096.0),"LOD step %d covers the patch once and retains all 4 m boundary segments" % step)
	var output = {"checks":checks,"failures":failures,"seeds":metrics,"example":JSON.parse_string(mountain.share_text())}
	FileAccess.open("res://artifacts/summit_mountain/generator_results.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("SUMMIT_RESULTS ",JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)

func connectivity(field) -> Dictionary:
	var count = 96
	var reachable: Dictionary = {}
	for i in count: reachable[i] = true
	for r in range(48,2849,32):
		var next: Dictionary = {}
		for i in count:
			var angle = TAU*i/count
			var p = Vector3(sin(angle)*r,0,cos(angle)*r)
			p.y = field.sample(p.x,p.z).height
			if field.contact_normal(p.x,p.z).y<cos(deg_to_rad(50)): continue
			for side in [-1,0,1]:
				var previous = posmod(i+side,count)
				if not reachable.has(previous): continue
				var a = TAU*previous/count
				var before = Vector3(sin(a)*(r-32),0,cos(a)*(r-32))
				before.y = field.sample(before.x,before.z).height
				if p.y<before.y and field.sweep_obstacle(before,p).is_empty():
					next[i] = true
					break
		reachable = next
	var octants: Dictionary = {}
	var lo = INF
	var hi = -INF
	for i in count:
		var angle = TAU*i/count
		var vertical = field.spawn_point().y-field.sample(sin(angle)*field.finish_z,cos(angle)*field.finish_z).height
		lo = minf(lo,vertical)
		hi = maxf(hi,vertical)
		if reachable.has(i): octants[i/(count/8)] = true
	return {"octants":octants.size(),"reachable_samples":reachable.size(),"minimum_vertical":lo,"maximum_vertical":hi}
