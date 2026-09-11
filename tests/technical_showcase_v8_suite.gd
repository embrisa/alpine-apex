extends SceneTree
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Pilot = preload("res://tests/showcase_pilot.gd")
const OUTPUT = "res://artifacts/technical_showcase_v8"
var failures: Array = []
var checks = 0
var metrics: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var field = Definition.generate(849205174,8)
	metrics.generation_ms = field.generation_ms
	metrics.obstacles = field.obstacles.size()
	metrics.trees = field.obstacles.filter(func(ob): return ob.tree).size()
	check(field.height_checksum=="ca584843caffef7d97c2eea63ba65ba787ae1745178acffcb59dda04be4b0c65" and field.obstacle_checksum=="f65bd968d755e26038d6336bfe410ed142e0e15e773a0142836901edc01f2d8f","V8 retains its frozen terrain and obstacle fingerprints")
	metrics.height_sha256 = field.height_checksum
	metrics.obstacle_sha256 = field.obstacle_checksum
	check(Definition.parse_seed("849205174").version==10,"Bare seeds select the current v10 massif")
	check(Definition.parse_seed("42 / v8").has("error") and not Definition.parse_seed("42 / v8").has("seed") and Definition.generate(42,8)==null,"Unsupported showcase seeds fail without generating a different mountain")
	var recipe = Definition.from_field(field,"Technical Showcase")
	var race = preload("res://scripts/racing/race_definition.gd").new()
	race.title = "V8 drainage compatibility"
	race.mountain = recipe.to_reference()
	var start_x = field.gully_x(600,-1)
	var end_x = field.glade_x(2380,-1)
	race.start = Vector3(start_x,field.sample(start_x,600).height,600)
	race.finish = Vector3(end_x,field.sample(end_x,2380).height,2380)
	var shared_race = race.decode(race.share_text())
	check(shared_race.has("race") and shared_race.race.mountain==recipe.to_reference() and shared_race.race.identity()==race.identity(),"Shared races round-trip the exact v8 mountain and race identity")
	var invalid_reference = recipe.to_reference()
	invalid_reference.seed = 42
	invalid_reference.scenery_seed = 42
	check("only seed" in Definition.reference_error(invalid_reference),"Unsupported v8 seeds are rejected in imported references too")
	var example = Definition.decode(FileAccess.get_file_as_string("res://examples/mountains/technical-showcase-v8.apexmountain"))
	check(example.has("mountain") and example.mountain.generator_version==8 and example.mountain.height_checksum==field.height_checksum and example.mountain.obstacle_checksum==field.obstacle_checksum,"Committed v8 recipe names the exact final physical mountain")
	var decoded = Definition.decode(recipe.share_text())
	var repeated = decoded.mountain.reconstruct().field
	check(repeated.heights==field.heights and repeated.obstacles==field.obstacles and repeated.exposure_image.get_data()==field.exposure_image.get_data(),"Portable showcase reconstructs all physical and visual feature data exactly")
	repeated = null
	var archived = Definition.generate(849205174,7)
	verify_snow(field,archived)
	var base = field.base
	var unchanged = true
	var finite = true
	var highest = -INF
	var changed = 0
	var maximum_added_relief = 0.0
	for iz in field.NZ:
		for ix in field.NX:
			var index = iz*field.NX+ix
			var p = field.vertex(ix,iz)
			finite = finite and is_finite(p.y)
			maximum_added_relief = maxf(maximum_added_relief,p.y-base.heights[index])
			highest = maxf(highest,p.y)
			if field.sector_weight(p.x,p.z)==0:
				unchanged = unchanged and field.heights[index]==base.heights[index]
			elif field.heights[index]!=base.heights[index]: changed += 1
	check(is_equal_approx(field.continuation_height(73,1355),field.sample(73,1355).height),"Analytic scenery requests inside the face use the authoritative baked surface")
	check(unchanged and changed>50000,"Only the showcase sector changes; all surrounding vertices remain exact")
	metrics.maximum_added_relief_m = maximum_added_relief
	metrics.rock_spines = field.ribs.size()
	check(field.ribs.size()>=35 and maximum_added_relief>80,"Substantial physical rock ranges remain distributed across the face")
	check(finite and absf(highest-field.spawn_point().y)<.001,"The complete heightfield is finite and the original summit remains highest")
	var old_obstacles = base.obstacles.filter(func(ob): return field.sector_weight(ob.position.x,ob.position.z)<=0)
	check(field.obstacles.slice(0,old_obstacles.size())==old_obstacles,"Every obstacle outside the showcase is preserved in order")
	var trees_in_face = 0
	var minimum_trunk = INF
	var grounded = true
	var impacts = true
	for ob in field.obstacles:
		grounded = grounded and absf(ob.position.y-field.sample(ob.position.x,ob.position.z).height)<.001
		if field.sector_weight(ob.position.x,ob.position.z)<=0: continue
		if ob.tree:
			trees_in_face += 1
			var cell = Vector2i(floori(ob.position.x/field.SPATIAL_CELL),floori(ob.position.z/field.SPATIAL_CELL))
			for dz in [-1,0,1]:
				for dx in [-1,0,1]:
					for idx in field.obstacle_grid.get(cell+Vector2i(dx,dz),[]):
						var other = field.obstacles[idx]
						if not other.tree or other.position==ob.position: continue
						minimum_trunk = minf(minimum_trunk,Vector2(other.position.x,other.position.z).distance_to(Vector2(ob.position.x,ob.position.z)))
		var a: Vector3 = ob.position+Vector3(-ob.radius-3,1,0)
		var b: Vector3 = ob.position+Vector3(ob.radius+3,1,0)
		impacts = impacts and not field.sweep_obstacle(a,b).is_empty()
	check(grounded and impacts,"All showcase obstacles sit on the physical surface and catch swept impacts")
	check(trees_in_face>2500,"The showcase contains substantial dense forest stands")
	metrics.trees_in_face = trees_in_face
	metrics.minimum_tree_spacing_m = minimum_trunk
	check(minimum_trunk>=6,"Forest spacing respects the six-metre minimum between trunks")
	# Bounded local normal changes at the fully unchanged angular/radial boundary.
	var boundary_delta = 0.0
	for z in range(400,2450,20):
		for side in [-1,1]:
			var x = z*tan(deg_to_rad(35))*side
			boundary_delta = maxf(boundary_delta,field.contact_normal(x,z).distance_to(base.contact_normal(x,z)))
	check(boundary_delta<.02,"The sector blends into surrounding contact normals without a seam")
	metrics.boundary_normal_delta = boundary_delta
	var routes: Array = []
	var gradients: Array[float] = []
	for side in [-1,1]:
		var connected = true
		var previous = Vector3.ZERO
		var steepest = 0.0
		for z in range(340,2810,4):
			var x = Pilot.target_x(field,z,side)
			var p = Vector3(x,field.sample(x,z).height,z)
			steepest = maxf(steepest,rad_to_deg(acos(field.contact_normal(x,z).y)))
			if z>340:
				gradients.append((p.y-previous.y)/4.0)
				connected = connected and p.y-previous.y<3.0 and field.sweep_obstacle(previous,p).is_empty()
			previous = p
		check(connected,"Snow alternative %d has a connected snow passage allowing small physical rolls" % side)
		var sim = SkiSimulation.new(preload("res://config/ski_default.tres").duplicate(true))
		sim.reset(field.launch_point(0),0)
		sim.prime_contacts(field)
		var seconds = 0.0
		var minimum_balance = 1.0
		var peak_impact = 0.0
		var peak_load = 0.0
		var contact_ticks = 0
		var samples: Array = []
		var input = RiderInput.new()
		for tick in 120000:
			if tick%12==0: input = Pilot.intent(sim,field,side)
			sim.step(Pilot.DT,input,field)
			seconds += Pilot.DT
			peak_impact = maxf(peak_impact,sim.landing_force)
			peak_load = maxf(peak_load,sim.normal_load/9.81)
			if sim.grounded: contact_ticks += 1
			minimum_balance = minf(minimum_balance,sim.balance)
			if tick%1200==0: samples.append({"seconds":seconds,"position":str(sim.position),"speed_kmh":sim.speed_kmh(),"grounded":sim.grounded})
			if sim.crashed or field.reached_base(sim.position): break
		var result = {"side":side,"finished":field.reached_base(sim.position),"crash":sim.crash_reason,"seconds":seconds,"peak_kmh":sim.peak_speed*3.6,"airtime_s":sim.total_airtime,"minimum_balance":minimum_balance,"contact_s":contact_ticks*Pilot.DT,"peak_normal_impact_m_s":peak_impact,"peak_normal_load_g":peak_load,"position":str(sim.position),"steepest_degrees":steepest,"samples":samples}
		routes.append(result)
		print("SHOWCASE_DESCENT ",JSON.stringify(result))
		check(result.finished and not sim.crashed,"Real-solver snow alternative %d reaches the base using ordinary inputs" % side)
	metrics.routes = routes
	metrics.v7_routes = baseline_routes(archived)
	var variation = 0.0
	for i in range(1,gradients.size()): variation += absf(gradients[i]-gradients[i-1])
	metrics.mean_grade_change_per_4m = variation/maxi(1,gradients.size()-1)
	check(metrics.mean_grade_change_per_4m>.08,"Rideable snow has substantial physical changes in pitch rather than a smooth floor")
	# Export a compact physical survey for QA; test output never feeds the game.
	var survey: Array = []
	for z in range(200,2821,12):
		var row: Array = []
		for x in range(-1500,1501,12):
			row.append([field.sample(x,z).height,field.exposure_at(x,z).r])
		survey.append(row)
	var obstacle_points: Array = []
	for ob in field.obstacles:
		if field.sector_weight(ob.position.x,ob.position.z)>0: obstacle_points.append([ob.position.x,ob.position.z,ob.radius,ob.tree])
	FileAccess.open(OUTPUT+"/survey.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":survey,"obstacles":obstacle_points}))
	FileAccess.open(OUTPUT+"/candidate.apexmountain",FileAccess.WRITE).store_string(recipe.share_text())
	FileAccess.open(OUTPUT+"/results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	print("SHOWCASE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	quit(0 if failures.is_empty() else 1)

func verify_snow(field,archived) -> void:
	check(archived.height_checksum=="9f303aab12a3a3bc97b115b4040013303b04f562c2bb5a2486214602b822b560" and archived.obstacle_checksum=="afeb8a384c013515344980dc3f913bc24bcfecffb18332ed7ce93f6ad199025a","Archived v7 fingerprints remain unchanged")
	check(Definition.from_field(field).identity()!=Definition.from_field(archived).identity(),"V8 records cannot be compared with archived v7 records")
	var lab = preload("res://scripts/world/test_slope.gd").new()
	var formula_matches = true
	for z in range(450,2400,37):
		for x in range(-900,901,31):
			formula_matches = formula_matches and absf(field.snow_relief_at(x,z)-lab.snow_relief_at(x,z))<.000001
	check(formula_matches,"Snow uses the laboratory's exact ridge, scallop, mound and noise scales")
	var final_heights = field.heights
	# Evaluate the independent expected delta against the archived pre-snow grid.
	# This catches in-place/order-dependent weighting and a later smoothing pass.
	field.heights = archived.heights
	var exact = true
	var protected = true
	var max_delta = 0.0
	var changed = 0
	for iz in range(int((160-field.Z_MIN)/field.CELL),int((2832-field.Z_MIN)/field.CELL)+1):
		var z = field.Z_MIN+iz*field.CELL
		for ix in range(int((-1792-field.X_MIN)/field.CELL),int((1792-field.X_MIN)/field.CELL)+1):
			var x = field.X_MIN+ix*field.CELL
			var index = iz*field.NX+ix
			var weight = field.snow_relief_weight(x,z)
			var expected = archived.heights[index]+field.snow_relief_at(x,z)*weight
			exact = exact and absf(final_heights[index]-expected)<.00025
			if weight==0: protected = protected and final_heights[index]==archived.heights[index]
			var delta = absf(final_heights[index]-archived.heights[index])
			max_delta = maxf(max_delta,delta)
			if delta>.01: changed += 1
	field.heights = final_heights
	check(exact,"Final grid matches relief weighted entirely from the pre-sculpt surface")
	check(protected,"Zero-weight summit, rock and sector boundary vertices remain exact")
	check(changed>10000 and max_delta>1.0 and max_delta<2.031,"Metre-scale formations are distributed across the snow face and remain bounded")
	metrics.snow_changed_vertices = changed
	metrics.snow_max_delta_m = max_delta
	var drop_exact = true
	for z in range(1620,1991,4):
		for x in range(-76,77,4):
			drop_exact = drop_exact and field.sample(x,z).height==archived.sample(x,z).height
	check(drop_exact,"The complete optional drop approach, lip and landing retain v7 geometry")
	metrics.snow_regions = []
	for side in [-1,1]:
		for region in [Vector2i(500,1150),Vector2i(2050,2420)]:
			var deltas: Array[float] = []
			for z in range(region.x,region.y,4):
				var centre = field.gully_x(z,side) if z<1850 else field.glade_x(z,side)
				for offset in [-4,0,4]:
					var x = centre+offset
					deltas.append(field.sample(x,z).height-archived.sample(x,z).height)
			var squares = 0.0
			for delta in deltas: squares += delta*delta
			var rms = sqrt(squares/deltas.size())
			check(rms>.20 and deltas.max()-deltas.min()>1.0,"Side %d %s retains visible physical snow formations" % [side,"gully" if region.x<1850 else "glade"])
			metrics.snow_regions.append({"side":side,"start_z":region.x,"rms_delta_m":rms,"range_m":deltas.max()-deltas.min()})

func baseline_routes(field) -> Array:
	var routes: Array = []
	for side in [-1,1]:
		var sim = SkiSimulation.new(preload("res://config/ski_default.tres").duplicate(true))
		sim.reset(field.launch_point(0),0)
		sim.prime_contacts(field)
		var input = RiderInput.new()
		var ticks = 0
		var contact_ticks = 0
		var peak_impact = 0.0
		var peak_load = 0.0
		for tick in 120000:
			if tick%12==0: input = Pilot.intent(sim,field,side)
			sim.step(Pilot.DT,input,field)
			ticks += 1
			if sim.grounded: contact_ticks += 1
			peak_impact = maxf(peak_impact,sim.landing_force)
			peak_load = maxf(peak_load,sim.normal_load/9.81)
			if sim.crashed or field.reached_base(sim.position): break
		var result = {"side":side,"finished":field.reached_base(sim.position),"crash":sim.crash_reason,"seconds":ticks*Pilot.DT,"contact_s":contact_ticks*Pilot.DT,"airtime_s":sim.total_airtime,"peak_kmh":sim.peak_speed*3.6,"peak_normal_impact_m_s":peak_impact,"peak_normal_load_g":peak_load}
		routes.append(result)
		check(result.finished and not sim.crashed,"Unchanged v7 comparison route %d reaches the base" % side)
	return routes
