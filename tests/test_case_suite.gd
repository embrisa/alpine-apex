extends SceneTree
const Store = preload("res://scripts/diagnostics/case_store.gd")
const Sim = preload("res://scripts/diagnostics/case_simulation.gd")
const Surface = preload("res://scripts/diagnostics/case_surface.gd")
const Policy = preload("res://scripts/diagnostics/case_policy.gd")
const Recorder = preload("res://scripts/diagnostics/case_recorder.gd")
const Controller = preload("res://scripts/diagnostics/test_cases.gd")
const Main = preload("res://scripts/main.gd")
var failures: Array[String] = []
var checks = 0
var directory = "res://artifacts/test_cases/contracts"
class CasePlane extends "res://scripts/world/heightfield_surface.gd":
	func sample(_x: float,z: float) -> Dictionary: return {"height":-z*.15,"normal":Vector3(0,1,.15).normalized()}
	func contact_normal(_x: float,_z: float) -> Vector3: return Vector3(0,1,.15).normalized()
	func snow_depth_at(_x: float,_z: float) -> float: return 0.0
	func rock_fraction_at(_x: float,_z: float) -> float: return 0.0
	func ski_bounds() -> Rect2: return Rect2(-1000,-1000,2000,2000)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ",label)
	else: print("PASS ",label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var plane = CasePlane.new()
	plane.add_obstacle({"position":Vector3(0,-.3,2),"radius":.3,"height":4.0,"tree":true})
	plane.add_obstacle({"position":Vector3(0,-.6,4),"radius":.4,"height":4.0,"tree":false})
	for immune in [false,true]:
		for trees in [false,true]:
			for rocks in [false,true]:
				var sim = Sim.new(preload("res://config/ski_default.tres").duplicate(true))
				sim.policy.values.merge({"immortal":immune,"trees":trees,"rocks":rocks},true)
				var surface = Surface.new(plane,plane,sim.policy)
				var hit: Dictionary = surface.sweep_obstacle_contact(Vector3.ZERO,Vector3(0,-.9,6))
				check(hit.get("reason","")==("TREE IMPACT" if trees else "ROCK IMPACT" if rocks else ""),"Independent obstacle combination %s/%s/%s"%[immune,trees,rocks])
				sim.impacts.hit(100,7,"TEST",sim.tuning)
				check((sim.impacts.reserve==1.0)==immune,"Immortality damage policy %s/%s/%s"%[immune,trees,rocks])
	var sim = Sim.new(preload("res://config/ski_default.tres").duplicate(true)); sim.reset(Vector3.ZERO); sim.prime_contacts(plane)
	var surface = Surface.new(plane,plane,sim.policy)
	sim.policy.queue_speed(120); var events = sim.policy.before_tick(sim,surface,1)
	check(absf(sim.speed_kmh()-120)<.0001 and events.size()==1,"One-shot speed is applied exactly once")
	sim.velocity *= .5; sim.policy.before_tick(sim,surface,2)
	check(absf(sim.speed_kmh()-60)<.00001,"One-shot speed is not repeated")
	sim.policy.queue_speed(0); sim.policy.before_tick(sim,surface,3); check(sim.velocity==Vector3.ZERO,"Zero-speed application")
	sim.policy.queue_settings({"hold_speed":true,"speed_kmh":170.0,"immortal":true,"trees":true,"rocks":true})
	sim.policy.before_tick(sim,surface,4); check(absf(sim.speed_kmh()-170)<.0001,"Hold target speed")
	sim.policy.values.trees = false; sim.policy.queue_settings(Policy.DEFAULTS)
	sim.policy.before_tick(sim,surface,5,[Vector3(0,-.3,2)])
	check(not sim.policy.values.trees and not sim.policy.error.is_empty(),"Re-enable rejects overlapping rider")
	sim.policy.queue_settings(Policy.DEFAULTS); sim.policy.before_tick(sim,surface,6,[Vector3.ZERO])
	check(sim.policy.values.trees,"Re-enable succeeds when clear")
	var normal = preload("res://scripts/core/ski_simulation.gd").new(preload("res://config/ski_default.tres").duplicate(true))
	var plain = CasePlane.new(); sim = Sim.new(normal.tuning.duplicate(true)); surface = Surface.new(plain,plain,sim.policy)
	for item in [normal,sim]: item.reset(Vector3.ZERO); item.prime_contacts(plain)
	var equal = true
	for tick in 240:
		var input = RiderInput.new(); input.tuck = .6; input.steer = sin(tick*.025)*.5
		sim.policy.before_tick(sim,surface,tick+1); sim.step(1.0/120,input,surface); normal.step(1.0/120,input,plain)
		equal = equal and sim.position==normal.position and sim.velocity==normal.velocity and sim.impacts.reserve==normal.impacts.reserve
	check(equal,"Inactive diagnostic rules preserve every ordinary solver tick")
	physics_controls(plane)
	store_contracts()
	print("TEST_CASE_CONTRACTS ",JSON.stringify({"checks":checks,"failures":failures}))
	preload("res://tests/test_report.gd").write(directory+"/results.json",JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)

func physics_controls(plane) -> void:
	var sim = Sim.new(preload("res://config/ski_default.tres").duplicate(true))
	var surface = Surface.new(plane,plane,sim.policy)
	sim.reset(Vector3.ZERO); sim.prime_contacts(plane)
	sim.policy.values.immortal = true; sim.policy.values.hold_speed = true; sim.policy.values.speed_kmh = 120
	var maximum_z = 0.0
	for tick in 180:
		sim.policy.before_tick(sim,surface,tick+1); sim.step(1.0/120,RiderInput.new(),surface)
		maximum_z = maxf(maximum_z,sim.position.z)
	check(maximum_z<1.37 and not sim.crashed,"Held speed and immortality cannot force through a solid tree")
	check(sim.impacts.prevented_damage>0 and sim.impacts.last_speed>0,"Immunity retains impact severity and prevented damage")
	sim.policy.values.hold_speed = false; sim.grounded = false; sim.velocity = Vector3(2,3,4)
	var direction = sim.velocity.normalized(); sim.policy.queue_speed(90); sim.policy.before_tick(sim,surface,200)
	check(sim.velocity.normalized().is_equal_approx(direction) and absf(sim.speed_kmh()-90)<.0001,"Airborne speed change preserves travel direction")
	sim.policy.values.immortal = false
	sim.impacts.step(.31,true,sim.tuning)
	sim.impacts.hit(100,7,"NORMAL DAMAGE",sim.tuning)
	check(sim.impacts.reserve<1,"Turning immortality off resumes real damage")
	var props = preload("res://scripts/world/prop_collision_surface.gd").new(plane)
	props.register_props(1,[{"transform":Transform3D(Basis.IDENTITY,Vector3(0,.2,6)),"size":Vector3(1,4,1),"reason":"PROP IMPACT"}])
	sim.policy.values.trees = false; sim.policy.values.rocks = false
	var filtered = Surface.new(plane,props,sim.policy)
	check(filtered.sweep_obstacle(Vector3.ZERO,Vector3(0,-1.2,8))=="PROP IMPACT","Disabling natural obstacles retains the next solid prop")
	check(filtered.sample(0,4)==plane.sample(0,4),"Disabling rocks preserves authoritative terrain support")
	var collision = preload("res://scripts/world/crash_collision.gd").new(); root.add_child(collision)
	var ground = collision._static(BoxShape3D.new(),Vector3.ZERO)
	var tree = collision._static(CylinderShape3D.new(),Vector3.ZERO); tree.set_meta("audio_material",2); collision.obstacles[0] = tree
	var rock = collision._static(BoxShape3D.new(),Vector3.ZERO); collision.mineral_bodies[0] = rock
	collision.set_diagnostic_filter(false,true)
	check(tree.collision_layer==0 and rock.collision_layer==8 and ground.collision_layer==8,"Ragdoll category switches preserve terrain and enabled rocks")
	var streamed = collision._static(CylinderShape3D.new(),Vector3.ZERO); collision._filter_body(streamed,true)
	check(streamed.collision_layer==0,"New streamed body uses the current category switch")
	collision.set_diagnostic_filter(true,false)
	check(tree.collision_layer==8 and rock.collision_layer==0,"Ragdoll category switches restore existing bodies")
	collision.free()

func store_contracts() -> void:
	var data = Store.new()
	data.metadata = {"start_tick":0,"end_tick":2,"duration_ticks":2,"input_ticks":2,"policy_version":1,"input_version":1,"initial_settings":Policy.DEFAULTS.duplicate(),"identity":{"sources":{},"engine_sha256":"fixture","mountain":{}},"rig":{"names":["Hips"]},"title":"Contract fixture","what":"","expected":""}
	var weather = preload("res://scripts/presentation/weather_controller.gd").new()
	var weather_snapshot = weather.snapshot(); weather.free()
	for tick in 3:
		data.append("ticks",{"t":tick/120.0,"tick":tick,"input":PackedFloat64Array([.317,.7,0,0,0,0,0,0,0]) if tick>0 else PackedFloat64Array(),"state":fixture_state(),"events":[{"tick":tick,"kind":"speed","value":120.0}] if tick==1 else []})
		data.append("frames",{"t":tick/120.0,"tick":tick,"pose":PackedFloat32Array([0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1]),"camera":PackedFloat64Array([0,0,0,1,0,0,0,1,0,0,0,1,60]),"weather":weather_snapshot,"contacts":PackedFloat32Array(),"crashed":false})
	var path = directory+"/original-"+str(Time.get_ticks_usec())+".apexcase"
	check(data.save(path).is_empty(),"Atomic package save")
	var opened = Store.open_case(path)
	check(opened.error.is_empty(),"Indexed package opens")
	var ticks = opened.rows("ticks")
	check(ticks.size()==3 and ticks[1].input[0]==.317 and ticks[1].state.heading==-.21349858753203,"Packed inputs and telemetry retain exact double bits")
	var clipped = opened.trim(1,2,"One tick","Observed","Expected")
	var clip_path = directory+"/clip-"+str(Time.get_ticks_usec())+".apexcase"
	check(clipped.save(clip_path).is_empty(),"One-tick clip saves")
	DirAccess.remove_absolute(path)
	var standalone = Store.open_case(clip_path)
	check(standalone.error.is_empty() and standalone.rows("ticks").size()==3 and standalone.rows("ticks")[1].events.size()==1,"Clip survives removal of original with complete event prefix")
	check(standalone.trim(1,2,"Nested","","").rows("ticks").size()==3,"Nested trim retains original time and prefix")
	check(not standalone.trim(2,2,"Empty","","").error.is_empty(),"Empty interval is rejected")
	check(not standalone.save(clip_path).is_empty(),"Existing case is never overwritten")
	var bad = directory+"/bad.apexcase"; preload("res://tests/test_report.gd").write(bad,"malformed")
	check(not Store.open_case(bad).error.is_empty(),"Malformed package fails closed")
	var intact_hash = FileAccess.get_sha256(clip_path)
	check(not standalone.save(bad+"/impossible.apexcase").is_empty() and FileAccess.get_sha256(clip_path)==intact_hash,"Save failure preserves the source case")
	var damaged = directory+"/damaged.apexcase"
	var bytes = FileAccess.get_file_as_bytes(clip_path); bytes[bytes.size()-1] ^= 0x5a
	preload("res://tests/test_report.gd").write_bytes(damaged,bytes)
	var corrupt = Store.open_case(damaged); corrupt.rows("frames")
	check(not corrupt.error.is_empty(),"Corrupted compressed content is rejected")
	data = standalone.trim(1,2,"Bounded","",""); data.raw_bytes = Store.MAX_RAW-1
	check(not data.append("ticks",{"t":0,"tick":0}) and data.error=="size_limit","Capture stops before exceeding its raw-byte budget")
	check(Store.same_data({"a":[1,2],"b":.85},{"b":.85,"a":[1.0,2.0]}),"JSON integer representation cannot change metadata identity")
	var wrong_layout = standalone.metadata.duplicate(true); wrong_layout.input_version = 999
	check(not Store.validate_metadata(wrong_layout).is_empty(),"Unknown input layout is rejected")
	check(not Store.valid_state({"heading":0}),"Incomplete telemetry is rejected before replay")
	var duplicate_frames = Store.new(); duplicate_frames.metadata = standalone.metadata.duplicate(true)
	var frames = standalone.rows("frames")
	var second: Dictionary = frames[0].duplicate(true); second.pose[0] = 12
	duplicate_frames.append("frames",frames[0]); duplicate_frames.append("frames",second)
	check(duplicate_frames.frame_by_index(0).pose[0]!=duplicate_frames.frame_by_index(1).pose[0],"Captured-frame index preserves distinct renders at the same physics time")
	var recorder = Recorder.new(); recorder.running = true; recorder.tick = Store.MAX_TICKS-1
	var sim = Sim.new(preload("res://config/ski_default.tres").duplicate(true))
	recorder.observe_tick(sim,RiderInput.new(),true,[])
	check(recorder.tick==Store.MAX_TICKS and not recorder.running,"Ten-minute limit stops at the last completed tick")

func fixture_state() -> Dictionary:
	var sim = Sim.new(preload("res://config/ski_default.tres").duplicate(true))
	var state = Recorder.state(sim); state.heading = -.21349858753203
	return state
