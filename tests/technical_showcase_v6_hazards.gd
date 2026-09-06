extends SceneTree
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Pilot = preload("res://tests/showcase_pilot.gd")
var field
var results: Array = []
var failures: Array = []
var checks = 0
func check(ok: bool,label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	field = Definition.generate(849205174,6)
	for speed in [40.0,55.0,70.0,95.0]:
		for x in [0.0,-190.0]:
			var sim = SkiSimulation.new(preload("res://config/ski_default.tres").duplicate(true))
			var start = Vector3(x,field.sample(x,1705).height,1705)
			sim.reset(start,0)
			sim.prime_contacts(field)
			# Fixture entry speed only. All subsequent motion uses normal intent.
			sim.velocity = Vector3.BACK.slide(field.contact_normal(x,1705)).normalized()*speed/3.6
			var input = RiderInput.new()
			var peak_impact = 0.0
			var airborne = false
			var landed = false
			for i in 2400:
				sim.step(Pilot.DT,input,field)
				if not sim.grounded: airborne = true
				if airborne and sim.grounded: landed = true
				peak_impact = maxf(peak_impact,sim.landing_force)
				if sim.crashed or sim.position.z>1965: break
			if x==0:
				check(airborne and landed and not sim.crashed,"Optional drop lands through the real solver from a %.0f km/h entry fixture" % speed)
			results.append({"fixture":"drop" if x==0 else "straight_unbraked_gully","entry_kmh":speed,"airtime_s":sim.total_airtime,"landed":landed,"crash":sim.crash_reason,"position":str(sim.position),"peak_normal_impact_m_per_s":peak_impact})
	for side in [-1,1]:
		var sim = SkiSimulation.new(preload("res://config/ski_default.tres").duplicate(true))
		sim.reset(field.launch_point(0),0)
		sim.prime_contacts(field)
		var input = RiderInput.new()
		for i in 24000:
			if i%12==0: input = Pilot.intent(sim,field,side,true)
			sim.step(Pilot.DT,input,field)
			if sim.crashed or field.reached_base(sim.position): break
		results.append({"fixture":"overspeed","side":side,"finished":field.reached_base(sim.position),"crash":sim.crash_reason,"peak_kmh":sim.peak_speed*3.6,"airtime_s":sim.total_airtime,"position":str(sim.position)})
	for tree in [false,true]:
		var candidates = field.obstacles.filter(func(value): return value.tree==tree and field.sector_weight(value.position.x,value.position.z)>.99 and field.contact_normal(value.position.x,value.position.z).y>.75)
		candidates.sort_custom(func(a,b): return a.radius>b.radius)
		var ob = candidates[0]
		var sim = SkiSimulation.new(preload("res://config/ski_default.tres").duplicate(true))
		var downhill = Vector3.DOWN.slide(field.contact_normal(ob.position.x,ob.position.z)).normalized()
		var heading = atan2(downhill.x,downhill.z)
		var start: Vector3 = ob.position-Vector3(sin(heading),0,cos(heading))*(ob.radius+5)
		start.y = field.sample(start.x,start.z).height
		sim.reset(start,heading)
		sim.prime_contacts(field)
		sim.velocity = Vector3(sin(heading),0,cos(heading)).slide(field.contact_normal(start.x,start.z)).normalized()*20
		for i in 120:
			sim.step(Pilot.DT,RiderInput.new(),field)
			if sim.crashed: break
		check(sim.crash_reason==("TREE IMPACT" if tree else "ROCK IMPACT"),"Real-solver deliberate %s collision crashes on its visible envelope" % ("tree" if tree else "rock"))
		results.append({"fixture":"deliberate_tree" if tree else "deliberate_rock","crash":sim.crash_reason})
	check(results.filter(func(value): return value.fixture=="overspeed" and not value.crash.is_empty()).size()==2,"No-braking attempts encounter physical consequences on both alternatives")
	FileAccess.open("res://artifacts/technical_showcase_v6/hazards.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	print("HAZARDS ",JSON.stringify(results))
	quit(0 if failures.is_empty() else 1)
