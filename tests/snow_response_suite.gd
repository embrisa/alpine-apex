extends SceneTree
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Response = preload("res://scripts/presentation/snow_response.gd")
const Condition = preload("res://scripts/presentation/snow_condition.gd")
var checks = 0
var failures: Array[String] = []
var matrix: Array = []
class Surface:
	extends RefCounted
	var condition = 0
	func snow_condition_at(_x: float, _z: float) -> int: return condition

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func fixture(kmh: float, slip: float, edge: float, load_fraction: float = 1.0, depth: float = .24):
	var sim = Sim.new()
	sim.reset(Vector3.ZERO)
	sim.contacts_initialized = true
	sim.velocity = Vector3.BACK*kmh/3.6
	var ski = sim.skis[0]
	ski.grounded = true
	ski.load_n = sim.tuning.rider_mass*9.81*.5*load_fraction
	ski.slip_angle = slip
	ski.edge_angle = edge
	ski.grip_n = ski.load_n*.7 if edge!=0.0 else 0.0
	ski.snow_depth = depth
	ski.penetration = depth*.3
	return sim

func response(sim, surface = null):
	var result = Response.new()
	result.sample(sim,sim.skis[0],surface)
	return result

func run() -> void:
	for speed in [0,5,45,90,130,170,220,300]:
		var clean = response(fixture(speed,0,0))
		var carve = response(fixture(speed,.025,.65))
		var skid = response(fixture(speed,.75,.7))
		matrix.append({"kmh":speed,"clean":clean.report(),"carve":carve.report(),"skid":skid.report()})
		check(clean.powder<.15 and is_zero_approx(clean.mist),"%d km/h straight glide leaves a modest trail without mist" % speed)
		if speed>=45:
			check(clean.powder>.05 and skid.powder>clean.powder*3.0 and skid.mist>carve.mist and carve.powder>clean.powder*1.5,"%d km/h technique separates visible glide, carve and skid" % speed)
		check(skid.powder<=1.0 and skid.mist<=1.0 and skid.ejection_m_s<14.0 and skid.depth_m<=.24,"%d km/h response stays bounded" % speed)
	var clean_fast = response(fixture(160,0,0))
	var skid_slower = response(fixture(130,.9,.7))
	check(skid_slower.powder>clean_fast.powder*4.0 and skid_slower.width_m>clean_fast.width_m*3.5,"130 km/h deep skid greatly exceeds the broader 160 km/h straight groove")
	var loaded = response(fixture(130,.4,.65,1.6))
	var unloaded = response(fixture(130,.4,.65,.15))
	check(loaded.powder>unloaded.powder*2 and loaded.depth_m>unloaded.depth_m,"Loaded ski produces more snow work than lightly weighted ski")
	var shallow = response(fixture(130,.4,.65,1,.02))
	check(shallow.powder<loaded.powder*.5 and shallow.depth_m<loaded.depth_m,"Shallow snow yields less spray and groove depth")
	var hard_carve = response(fixture(130,0,.85,1.7))
	var light_carve = response(fixture(130,0,.25,.5))
	check(hard_carve.width_m>clean_fast.width_m*1.3 and hard_carve.depth_m>clean_fast.depth_m*1.5,"Loaded zero-slip turn widens and deepens tracks without requiring a skid")
	check(hard_carve.contact_width_m>light_carve.contact_width_m and hard_carve.powder>light_carve.powder*2,"Tip displacement and spray rise with edge load")
	var source = fixture(130,.4,.65)
	var before = [source.position,source.velocity,source.skis[0].load_n,source.skis[0].penetration]
	for i in range(1000): response(source)
	check(before==[source.position,source.velocity,source.skis[0].load_n,source.skis[0].penetration],"Repeated presentation sampling cannot mutate the simulation")
	for inactive in ["air","unloaded","crashed"]:
		var sim = fixture(220,.9,.8)
		if inactive=="air": sim.skis[0].grounded = false
		if inactive=="unloaded": sim.skis[0].load_n = 0.0
		if inactive=="crashed": sim.crashed = true
		var result = response(sim)
		check(result.powder==0 and result.grains==0 and result.mist==0,"%s contact emits no snow" % inactive)
	var positive = response(fixture(130,.4,.6))
	var negative = response(fixture(130,-.4,-.6))
	check(positive.throw_side==-negative.throw_side and is_equal_approx(positive.powder,negative.powder),"Mirrored skiing mirrors spray direction with equal intensity")
	var surface = Surface.new()
	var fresh = response(source,surface)
	surface.condition = Condition.Kind.ICE
	var icy = response(source,surface)
	check(icy.powder<fresh.powder*.05 and icy.mist==0 and icy.depth_m<fresh.depth_m*.1,"Condition contract gives ice grains and scratches rather than powder")
	var report = {"checks":checks,"failures":failures,"matrix":matrix}
	DirAccess.make_dir_recursive_absolute("res://artifacts/snow_upgrade")
	preload("res://tests/test_report.gd").write("res://artifacts/snow_upgrade/response.json",JSON.stringify(report,"\t"))
	quit(0 if failures.is_empty() else 1)
