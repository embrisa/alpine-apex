extends SceneTree
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Pilot = preload("res://tests/showcase_pilot.gd")
const OUTPUT = "res://artifacts/technical_showcase"
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
	var field = Definition.generate(849205174,5)
	check(field.height_checksum=="34dd0f8e5b203c07b6b92f5ca94d796abee4bf5bca44352e9e8f695b96f41174" and field.obstacle_checksum=="f9fbcf0488d18eddf4790701c4a5e374176dd87e86db7a79cf4b1559fc1810d4","Generator v5 physical fingerprints are frozen")
	metrics.generation_ms = field.generation_ms
	metrics.obstacles = field.obstacles.size()
	metrics.trees = field.obstacles.filter(func(ob): return ob.tree).size()
	metrics.height_sha256 = field.height_checksum
	metrics.obstacle_sha256 = field.obstacle_checksum
	check(Definition.parse_seed("849205174").version==10,"Bare seeds select the current v10 massif")
	check(Definition.parse_seed("42 / v5").has("error") and not Definition.parse_seed("42 / v5").has("seed") and Definition.generate(42,5)==null,"Unsupported showcase seeds fail without generating a different mountain")
	var recipe = Definition.from_field(field,"Technical Showcase")
	var invalid_reference = recipe.to_reference()
	invalid_reference.seed = 42
	invalid_reference.scenery_seed = 42
	check("only seed" in Definition.reference_error(invalid_reference),"Unsupported v5 seeds are rejected in imported references too")
	var decoded = Definition.decode(recipe.share_text())
	var repeated = decoded.mountain.reconstruct().field
	check(repeated.heights==field.heights and repeated.obstacles==field.obstacles and repeated.exposure_image.get_data()==field.exposure_image.get_data(),"Portable showcase reconstructs all physical and visual feature data exactly")
	repeated = null
	var base = field.base
	var unchanged = true
	var finite = true
	var highest = -INF
	var changed = 0
	for iz in field.NZ:
		for ix in field.NX:
			var index = iz*field.NX+ix
			var p = field.vertex(ix,iz)
			finite = finite and is_finite(p.y)
			highest = maxf(highest,p.y)
			if field.sector_weight(p.x,p.z)==0:
				unchanged = unchanged and field.heights[index]==base.heights[index]
			elif field.heights[index]!=base.heights[index]: changed += 1
	check(is_equal_approx(field.continuation_height(73,1355),field.sample(73,1355).height),"Analytic scenery requests inside the face use the authoritative baked surface")
	check(unchanged and changed>50000,"Only the showcase sector changes; all surrounding vertices remain exact")
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
	for side in [-1,1]:
		var connected = true
		var previous = Vector3.ZERO
		var steepest = 0.0
		for z in range(340,2810,4):
			var x = Pilot.target_x(field,z,side)
			var p = Vector3(x,field.sample(x,z).height,z)
			steepest = maxf(steepest,rad_to_deg(acos(field.contact_normal(x,z).y)))
			if z>340:
				connected = connected and p.y<previous.y and field.sweep_obstacle(previous,p).is_empty()
			previous = p
		check(connected,"Snow alternative %d has a continuously descending obstacle-free connection" % side)
		var sim = SkiSimulation.new(preload("res://config/ski_default.tres").duplicate(true))
		sim.reset(field.launch_point(0),0)
		sim.prime_contacts(field)
		var seconds = 0.0
		var minimum_balance = 1.0
		var samples: Array = []
		var input = RiderInput.new()
		for tick in 48000:
			if tick%12==0: input = Pilot.intent(sim,field,side)
			sim.step(Pilot.DT,input,field)
			seconds += Pilot.DT
			minimum_balance = minf(minimum_balance,sim.balance)
			if tick%1200==0: samples.append({"seconds":seconds,"position":str(sim.position),"speed_kmh":sim.speed_kmh(),"grounded":sim.grounded})
			if sim.crashed or field.reached_base(sim.position): break
		var result = {"side":side,"finished":field.reached_base(sim.position),"crash":sim.crash_reason,"seconds":seconds,"peak_kmh":sim.peak_speed*3.6,"airtime_s":sim.total_airtime,"minimum_balance":minimum_balance,"position":str(sim.position),"steepest_degrees":steepest,"samples":samples}
		routes.append(result)
		print("SHOWCASE_DESCENT ",JSON.stringify(result))
		check(result.finished and not sim.crashed,"Real-solver snow alternative %d reaches the base using ordinary inputs" % side)
	metrics.routes = routes
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
