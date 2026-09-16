extends SceneTree
const Terrain = preload("res://scripts/world/generators/alpine_massif_v10.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Pilot = preload("res://tests/massif_pilot.gd")
var failures: Array = []
var checks = 0
var results: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run() -> void:
	var seeds = [849205174] if "--quick" in OS.get_cmdline_user_args() else [849205174,0,1,42,12981,2147483647]
	var previous_hash = ""
	for seed_value in seeds:
		print("GENERATING v10 seed ",seed_value)
		var field = preload("res://scripts/world/mountain_definition.gd").generate(seed_value,10) if "--cached" in OS.get_cmdline_user_args() else Terrain.new(seed_value)
		print("GENERATED ",field.generation_ms," ms; ",field.obstacles.size()," obstacles; ",field.generation_stages)
		check(field.NX==1537 and field.CELL==4 and field.faces.size()==6,"Seed %d uses one 4 m grid and six faces" % seed_value)
		check(field.height_checksum!=previous_hash,"Seed %d produces distinct terrain" % seed_value)
		previous_hash = field.height_checksum
		var valid = true
		for h in field.heights: valid = valid and is_finite(h) and h<=field.spawn_point().y+.01
		check(valid,"Seed %d has finite heights and a highest-point summit" % seed_value)
		var grounded = true
		for ob in field.obstacles: grounded = grounded and absf(ob.position.y-field.sample(ob.position.x,ob.position.z).height)<.001 and not field.in_landing_fan(ob.position.x,ob.position.z)
		check(grounded,"Seed %d obstacles rest on the final grid and clear landings" % seed_value)
		var per_face: Array = []
		for face in field.faces:
			var selected = -1
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--face="): selected = int(arg.get_slice("=",1))
			if selected>=0 and face.index!=selected: continue
			var trees = 0
			var rocks = 0
			var elevation_trees = [0,0,0]
			for ob in field.obstacles:
				var q: Vector2 = face.to_local(Vector2(ob.position.x,ob.position.z))
				if absf(atan2(q.x,q.y))>PI/6: continue
				if ob.tree:
					trees += 1
					elevation_trees[0 if q.y<1230 else (1 if q.y<1930 else 2)] += 1
				else: rocks += 1
			check(trees>100 and rocks>20,"Seed %d face %d has forest stands and rock fields" % [seed_value,face.index])
			check(elevation_trees[0]>40 and elevation_trees[1]>80 and elevation_trees[2]>80,"Seed %d face %d has upper, middle and lower woods %s" % [seed_value,face.index,str(elevation_trees)])
			var cliff_min = INF
			var cliff_max = -INF
			for crag in face.crags:
				cliff_min = minf(cliff_min,crag.position.y)
				cliff_max = maxf(cliff_max,crag.position.y)
			check(cliff_max-cliff_min>150,"Seed %d face %d cliffs occupy varied elevations" % [seed_value,face.index])
			var p: Vector2 = face.to_world(Vector2(face.gully_x(820,-1),820))
			check(field.snow_depth_at(p.x,p.y)>=.17 and field.powder_region(p.x,p.y)>.9,"Seed %d face %d has deep sheltered powder" % [seed_value,face.index])
			var continuity = true
			for r in range(400,2601,100):
				var a = face.heading+PI/6
				var left = Vector2(sin(a-.00001),cos(a-.00001))*r
				var right = Vector2(sin(a+.00001),cos(a+.00001))*r
				continuity = continuity and absf(field.sample(left.x,left.y).height-field.sample(right.x,right.y).height)<.3
			check(continuity,"Seed %d face %d joins its neighbour continuously" % [seed_value,face.index])
			var sim = Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
			sim.reset(field.launch_point(face.heading),face.heading)
			sim.prime_contacts(field)
			var input = RiderInput.new()
			input.tuck = .75
			for tick in 1200:
				sim.step(1.0/120,input,field)
				if sim.crashed: break
			check(not sim.crashed and sim.speed_kmh()>20,"Seed %d face %d has a usable summit entry" % [seed_value,face.index])
			per_face.append({"face":face.index,"trees":trees,"trees_upper_middle_lower":elevation_trees,"rocks":rocks,"ribs":face.ribs.size(),"crags":face.crags.size(),"cliff_elevation_spread_m":cliff_max-cliff_min,"entry_kmh":sim.speed_kmh(),"crash":sim.crash_reason})
			var max_rise = -INF
			var clear = true
			for side in [-1,1]:
				var before = field.launch_point(face.heading)
				for z in range(32,2851,8):
					var x: float = face.gully_x(z,side) if z<1850 else face.glade_x(z,side)
					var p2: Vector2 = face.to_world(Vector2(x,z))
					var after = Vector3(p2.x,field.sample(p2.x,p2.y).height,p2.y)
					max_rise = maxf(max_rise,after.y-before.y)
					clear = clear and field.sweep_obstacle(before,after).is_empty()
					before = after
			check(clear and max_rise<1.0,"Seed %d face %d drainages have clear connected outlets (max rise %.3f m)" % [seed_value,face.index,max_rise])
			if "--descents" in OS.get_cmdline_user_args():
				sim.reset(field.launch_point(face.heading),face.heading)
				sim.prime_contacts(field)
				var ticks = 0
				for tick in 100000:
					if tick%12==0: input = Pilot.intent(sim,field,face.index)
					sim.step(Pilot.DT,input,field)
					ticks = tick+1
					if sim.crashed or field.reached_base(sim.position): break
				per_face[-1].descent = {"finished":field.reached_base(sim.position),"crash":sim.crash_reason,"seconds":ticks*Pilot.DT,"peak_kmh":sim.peak_speed*3.6,"position":str(sim.position)}
				print("DESCENT ",per_face[-1].descent)
				check(field.reached_base(sim.position) and not sim.crashed,"Seed %d face %d completes an ordinary-input descent" % [seed_value,face.index])
		results.append({"seed":seed_value,"generation_ms":field.generation_ms,"stages":field.generation_stages,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"obstacles":field.obstacles.size(),"faces":per_face})
		if seed_value==849205174 and "--repeat" in OS.get_cmdline_user_args():
			var repeated = Terrain.new(seed_value)
			check(repeated.height_checksum==field.height_checksum and repeated.obstacle_checksum==field.obstacle_checksum,"Repeated generation matches both physical fingerprints")
	DirAccess.make_dir_recursive_absolute("res://artifacts/massif_v10")
	preload("res://tests/test_report.gd").write("res://artifacts/massif_v10/generator_results.json",JSON.stringify({"checks":checks,"failures":failures,"seeds":results},"\t"))
	print("MASSIF_RESULTS checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
