extends SceneTree
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Pilot = preload("res://tests/showcase_pilot.gd")
const OUTPUT = "res://artifacts/powder_volume"
var failures: Array = []
var checks = 0
var metrics: Dictionary = {}
class ArchivedSnowFixture extends "res://scripts/world/prop_collision_surface.gd":
	# This archived pilot predates material hazards. Keep its powder-handling
	# fixture snow-only; rock wear, grip and transitions have their own suite.
	# Height, loose depth and obstacle collisions still come from the real field.
	func rock_fraction_at(_x: float,_z: float) -> float: return 0.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var previous = Definition.generate(849205174,8)
	check(previous.height_checksum=="ca584843caffef7d97c2eea63ba65ba787ae1745178acffcb59dda04be4b0c65" and previous.obstacle_checksum=="f65bd968d755e26038d6336bfe410ed142e0e15e773a0142836901edc01f2d8f","Archived v8 terrain and obstacle fingerprints remain exact")
	var field = Definition.generate(849205174,9)
	check(Definition.parse_seed("849205174").version==Definition.CURRENT_VERSION and Definition.parse_seed("849205174 / v9").version==9,"Bare seeds select the current mountain and explicit v9 loads the powder showcase")
	check(Definition.generate(42,9)==null and not Definition.parse_seed("42 / v9").has("seed"),"Unsupported v9 seeds are rejected")
	var recipe = Definition.from_field(field,"Technical Showcase")
	check(recipe.identity()!=Definition.from_field(previous).identity(),"Powder depth and physical banks have a separate replay identity")
	var decoded = Definition.decode(recipe.share_text())
	check(decoded.has("mountain") and decoded.mountain.identity()==recipe.identity(),"The versioned powder mountain survives share and import")
	var repeated = decoded.mountain.reconstruct().field
	check(repeated.heights==field.heights and repeated.obstacles==field.obstacles and repeated.exposure_image.get_data()==field.exposure_image.get_data(),"Powder banks, capped obstacles and material masks reconstruct deterministically")
	repeated = null
	var changed = 0
	var max_delta = 0.0
	var outside_exact = true
	var finite = true
	for iz in field.NZ:
		for ix in field.NX:
			var index = iz*field.NX+ix
			var p = field.vertex(ix,iz)
			finite = finite and is_finite(p.y)
			var delta = absf(field.heights[index]-previous.heights[index])
			if delta>.01: changed += 1
			max_delta = maxf(max_delta,delta)
			if field.powder_region(p.x,p.z)==0: outside_exact = outside_exact and delta==0
	check(finite and outside_exact,"New terrain is finite and every vertex outside the powder regions remains v8")
	check(field.powder_deposits.size()==32 and max_delta>2 and max_delta<6 and changed>1000,"Substantial bounded powder banks occupy both upper chutes and lower glades")
	var grounded = true
	var caps = 0
	for ob in field.obstacles:
		grounded = grounded and absf(ob.position.y-field.sample(ob.position.x,ob.position.z).height)<.001
		if ob.get("powder_cap",false): caps += 1
	check(grounded and caps>=15,"Buried outcrops sit on the same physical snow surface")
	var depth = field.snow_depth_at(field.gully_x(820,-1),820)
	check(depth>.17 and depth<.32 and field.snow_depth_at(0,0)==previous.snow_depth_at(0,0),"Loose powder is physically deeper while the summit remains unchanged")
	var layers = preload("res://scripts/presentation/powder_caps.gd").new(preload("res://scripts/presentation/cloud_lighting.gd").new())
	var assets = preload("res://scripts/presentation/alpine_assets.gd").new(layers,preload("res://scripts/presentation/graphics_quality.gd").preset(2))
	assets.lighting = preload("res://scripts/presentation/cloud_lighting.gd").new()
	var enclosed = true
	var max_cap_radius = 0.0
	var max_cap_height = 0.0
	for kind in ["boulder","ledge","buttress"]:
		for i in [1,2]:
			var id = "pc_rock_%s_%d"%[kind,i]
			var mesh = layers.mesh_for(id,assets.mesh(id))
			for p in mesh.get_faces():
				max_cap_radius = maxf(max_cap_radius,Vector2(p.x,p.z).length())
				max_cap_height = maxf(max_cap_height,p.y-layers.BURIAL)
				enclosed = enclosed and p.is_finite() and Vector2(p.x,p.z).length()<=1.35 and p.y-layers.BURIAL<=2.0
	check(enclosed,"All six snow crowns fit the existing rock impact radius and height after burial")
	metrics.routes = []
	metrics.route_scope = "Archived snow-only contact fixture; not material-aware route acceptance"
	var snow_fixture=ArchivedSnowFixture.new(field)
	for side in [-1,1]:
		var sim = SkiSimulation.new(preload("res://config/ski_default.tres").duplicate(true))
		sim.reset(field.launch_point(0),0)
		sim.prime_contacts(snow_fixture)
		var input = RiderInput.new()
		var ticks = 0
		for tick in 120000:
			if tick%12==0: input = Pilot.intent(sim,field,side)
			sim.step(Pilot.DT,input,snow_fixture)
			ticks += 1
			if sim.crashed or field.reached_base(sim.position): break
		var result = {"side":side,"finished":field.reached_base(sim.position),"crash":sim.crash_reason,"seconds":ticks*Pilot.DT,"peak_kmh":sim.peak_speed*3.6,"airtime_s":sim.total_airtime,"position":str(sim.position)}
		metrics.routes.append(result)
		print("POWDER_ROUTE ",JSON.stringify(result))
		check(result.finished and not sim.crashed,"Real solver completes archived snow-only powder fixture %d using ordinary inputs"%side)
	metrics.merge({"max_added_height_m":max_delta,"changed_vertices":changed,"loose_depth_m":depth,"hero_caps":caps,"max_cap_radius_m":max_cap_radius,"max_cap_height_m":max_cap_height,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum})
	FileAccess.open(OUTPUT+"/technical-showcase-v9.apexmountain",FileAccess.WRITE).store_string(recipe.share_text())
	FileAccess.open(OUTPUT+"/physical_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	print("POWDER_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	quit(0 if failures.is_empty() else 1)
