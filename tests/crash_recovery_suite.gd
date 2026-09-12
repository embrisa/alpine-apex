extends SceneTree
## Bounded Node-free timing/placement checks. Never opens personal records.
const Recovery = preload("res://scripts/core/crash_recovery.gd")
const Session = preload("res://scripts/core/run_session.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Race = preload("res://scripts/racing/race_definition.gd")
const Surface = preload("res://scripts/world/heightfield_surface.gd")
const Props = preload("res://scripts/world/prop_collision_surface.gd")
const Zone = preload("res://scripts/world/mountain_zone.gd")
const DT = 1.0/120.0
var checks = 0
var failures: Array[String] = []
var queries: Array = []

class Fixture extends Surface:
	const GENERATOR_ID = "laboratory"
	const GENERATOR_VERSION = 3
	func _init(degrees: float = 15.0, cliff: bool = false) -> void:
		X_MIN = -64.0; Z_MIN = -64.0; NX = 65; NZ = 65
		heights.resize(NX*NZ)
		for z in NZ:
			for x in NX:
				var wz = Z_MIN+z*CELL
				heights[z*NX+x] = 100.0-tan(deg_to_rad(degrees))*wz-(30.0 if cliff and wz>=4.0 else 0.0)
	func snow_depth_at(_x: float, _z: float) -> float: return .12
	func spawn_point() -> Vector3: return Vector3(0,sample(0,0).height,0)

class SessionProbe extends Session:
	var saves = 0
	func save_record() -> void: saves += 1
	func load_record() -> void: pass

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func run() -> void:
	_timing()
	_placement()
	_identity()
	var report = {"checks":checks,"failures":failures,"placement_queries":queries,"acceptance":"automated only; native/controller pending"}
	FileAccess.open("res://artifacts/orchestration_20260912/crash/core-results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CRASH_RECOVERY_RESULTS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _sim(field):
	var sim = Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
	sim.reset(field.spawn_point(),0.0)
	sim.prime_contacts(field)
	return sim

func _session():
	var s = SessionProbe.new()
	s.reset()
	s.finish_z = 100.0
	s.split_origin = Vector2.ZERO; s.split_axis = Vector2(0,1); s.split_length = 100.0
	return s

func _timing() -> void:
	var field = Fixture.new()
	var sim = _sim(field)
	var s = _session()
	s.personal_best = 40.0; s.best_splits = [4.0,8.0,12.0]
	s.reset(); s.split_origin = Vector2.ZERO; s.split_length = 100.0
	s.begin_capture(sim)
	var original_capture = s.recording
	var reference = s.reference_splits.duplicate()
	var intent = RiderInput.new()
	for i in 12:
		s.step(DT,sim.position,sim.position,sim,intent)
	var elapsed: float = s.elapsed
	sim.crash("FIXTURE")
	s.step(DT,Vector3(0,100,24),Vector3(0,100,26),sim,intent)
	check(s.begin_crash(sim),"Onset enters recovery after the normal elapsed tick")
	var split: float = s.split_times[0]
	for i in 360: s.step_crash(DT)
	check(absf(s.elapsed-(elapsed+361*DT))<.00000001,"Exactly 360 inactive ticks plus one onset tick; no fixed penalty")
	check(s.split_times[0]==split and s.split_times[1]<0 and not s.finished,"Crash interval grants no split or finish")
	check(s.recording==original_capture and s.recording.ticks==373,"Same recorder includes inactive timeline ticks")
	s.recovery_paused = true
	var frozen: float = s.elapsed
	for i in 60: s.step_crash(DT)
	check(s.elapsed==frozen and s.recording.ticks==373,"Genuine pause suspends clock and input timeline")
	check(not s.recover(sim),"Paused/crashed physical state cannot recover")
	s.recovery_paused = false
	sim.peak_speed = 60.0; sim.total_airtime = 4.25
	sim.body.roll_velocity = 5.0; sim.air_control.angular_velocity = Vector3.ONE*3.0
	Recovery.restore_at_rest(sim,{"position":field.spawn_point(),"heading":0.0},field)
	check(sim.velocity==Vector3.ZERO and sim.body.angular_momentum==Vector2.ZERO and sim.body.roll_velocity==0 and sim.body.pitch_velocity==0 and sim.body.height_velocity==0 and sim.air_control.angular_velocity==Vector3.ZERO,"Recovery boundary has zero translational/angular/settling motion")
	check(sim.grounded and sim.contact_count==2 and sim.body.initialized and sim.impacts.reserve==1.0,"Recovery primes two authoritative contacts/body and full reserve")
	check(sim.peak_speed==60.0 and sim.total_airtime==4.25,"Attempt peak speed and total airtime survive")
	check(s.recover(sim) and not s.recover(sim),"Recovery succeeds exactly once")
	check(s.eligible and s.elapsed==frozen and s.previous_elapsed==s.elapsed and s.split_times[0]==split and s.reference_splits==reference,"Recovery preserves clock, eligibility, split and frozen PB comparison")
	# A recovered run may win; physical reset is not a new attempt.
	var before = Vector3(0,100,99)
	sim.position = Vector3(0,100,101)
	check(s.step(DT,before,sim.position,sim,intent),"Recovered run can cross the finish normally")
	check(s.new_best,"Eligible recovered run may earn a PB; archive/render payload checked by lifecycle fixture")
	check(absf(s.elapsed-(frozen+DT*.5))<.00000001,"Exact sub-tick finish remains after crash time")
	check(not s.begin_crash(sim),"Finished attempt rejects stale crash entry")
	var attempt: int = s.attempt_id
	s.reset()
	check(s.elapsed==0 and s.recovery_count==0 and s.attempt_id==attempt+1 and s.split_times==[-1.0,-1.0,-1.0],"Full reset creates a fresh attempt")
	for reason in ["automation","modified physics","changed weather"]:
		s.reset(); s.mark_practice(reason)
		sim.crash("FIXTURE"); s.begin_crash(sim)
		for i in 120: s.step_crash(DT)
		Recovery.restore_at_rest(sim,{"position":field.spawn_point(),"heading":0.0},field)
		s.recover(sim)
		check(not s.eligible and s.practice_reason==reason and s.recording==null and absf(s.elapsed-1.0)<.00000001,"Recovery preserves ineligibility but still advances time: "+reason)
	sim.step(DT,intent,field)
	check(sim.velocity.length()>0 and not sim.crashed,"Ordinary gravity accelerates after zero-speed boundary")

func _resolve(field, sim, s, label: String, props = null, zone = null, support: Dictionary = {}) -> Dictionary:
	var recovery = Recovery.new()
	recovery.last_support = support
	recovery.capture(sim,s.attempt_id,field.get_instance_id())
	var result = recovery.resolve(field,props if props else field,s,zone,true)
	queries.append({"fixture":label,"candidates":recovery.candidates_checked,"height_queries":recovery.height_queries,"obstacle_queries":recovery.obstacle_queries,"usec":recovery.query_usec,"result":result})
	check(recovery.candidates_checked<=34,"Bounded candidate count: "+label)
	return result

func _placement() -> void:
	var field = Fixture.new()
	var sim = _sim(field)
	var s = _session()
	var original: Vector3 = sim.position
	var exact = _resolve(field,sim,s,"clear onset")
	check(exact.has("position") and exact.position.is_equal_approx(original) and absf(exact.heading)<.001,"Clear onset is preferred and faces downhill")
	var flat = Fixture.new(0.0)
	var flat_sim = _sim(flat); flat_sim.heading = 1.2
	var flat_result = _resolve(flat,flat_sim,s,"flat heading")
	check(flat_result.has("position") and flat_result.heading==1.2,"Flat support uses captured heading")
	var support = {"position":original+Vector3(0,tan(deg_to_rad(15.0))*3,-3),"heading":0.0}
	field.add_obstacle({"position":original,"radius":.6,"height":5.0,"tree":true})
	var blocked = _resolve(field,sim,s,"tree onset",null,null,support)
	check(blocked.has("position") and blocked.position.z<=original.z and blocked.position.distance_to(original)<=8.1,"Blocked onset retreats to connected supported snow")
	var recovery = Recovery.new(); recovery.capture(sim,9,field.get_instance_id())
	sim.position += Vector3(100,-100,100)
	check(recovery.anchor.position==original and recovery.matches(9,field.get_instance_id()) and not recovery.matches(10,field.get_instance_id()),"Captured anchor ignores later travel and rejects old attempt")
	check(not recovery.matches(9,flat.get_instance_id()),"Different world invalidates recovery token")
	recovery.invalidate(); check(recovery.anchor.is_empty(),"Explicit transition invalidates anchor")
	var cliff = Fixture.new(15.0,true)
	var cliff_sim = _sim(cliff)
	cliff_sim.position = Vector3(0,100,8)
	var airborne = _resolve(cliff,cliff_sim,s,"airborne cliff")
	check(not airborne.has("position"),"Airborne cliff without a connected near support cannot project to valley floor")
	var ledge = _resolve(cliff,cliff_sim,s,"near ledge support",null,null,{"position":cliff.spawn_point()+Vector3(0,1.07,-4),"heading":0.0})
	check(not ledge.has("position"),"Stale support outside 8 m cannot become a checkpoint")
	cliff_sim.position = Vector3(0,100,4)
	# The material stencil sees the upcoming cliff before its raw height falls:
	# z=-3's downhill ski tip has 56.25% rock, so this is NOT safe snow.
	var rocky_ledge = _resolve(cliff,cliff_sim,s,"nearby rocky cliff ledge",null,null,{"position":Vector3(0,cliff.sample(0,-3).height,-3),"heading":0.0})
	check(cliff.rock_fraction_at(0,-3+Recovery.FOOTPRINT_HALF_LENGTH_M)>.25 and not rocky_ledge.has("position"),"Nearby ledge with rock inside the ski footprint stays unavailable")
	# Move the airborne onset one metre closer; a full snowy footprint at -4.5
	# now fits inside the same 8 m bound. No material override or relaxed query.
	cliff_sim.position = Vector3(0,100,3)
	var snowy_support = Vector3(0,cliff.sample(0,-4.5).height,-4.5)
	check(cliff_sim.position.y-cliff.sample(0,cliff_sim.position.z).height>Recovery.MAX_DROP_M and cliff.rock_fraction_at(0,snowy_support.z+Recovery.FOOTPRINT_HALF_LENGTH_M)<=.25,"Airborne fixture has a distant floor and a nearby complete snow footprint")
	var nearby_ledge = _resolve(cliff,cliff_sim,s,"nearby snowy cliff recovery",null,null,{"position":snowy_support,"heading":0.0})
	check(nearby_ledge.has("position") and nearby_ledge.position.is_equal_approx(snowy_support) and absf(nearby_ledge.position.z-cliff_sim.position.z)<=Recovery.MAX_RADIUS_M and nearby_ledge.position.y>=cliff_sim.position.y,"Airborne onset can use a nearby supported pre-crash ledge without valley projection")
	var steep = Fixture.new(50.0)
	check(not _resolve(steep,_sim(steep),s,"steep").has("position"),"Unsafe steep support has no arbitrary fallback")
	var open = Fixture.new()
	var at = _sim(open)
	var props = Props.new(open)
	props.register_props(91,[{"transform":Transform3D(Basis.IDENTITY,at.position+Vector3(0,1.0,0)),"size":Vector3(2,2,2),"reason":"ACTIVE GATE"}])
	check(not _resolve(open,at,s,"gate encloses onset",props).has("position"),"Active race props participate in all recovery clearance queries")
	var zone = Zone.new(); zone.enabled = true; zone.center = Vector2.ZERO; zone.radius_m = 1.0
	check(not _resolve(open,at,s,"return boundary",null,zone).has("position"),"Boundary owner retains its return zone")
	s.finish_z = -.1
	check(not _resolve(open,at,s,"unearned lab finish").has("position"),"Recovery cannot cross an unearned lab finish")
	var race = Race.new(); race.start=Vector3(0,100,-40); race.finish=Vector3(0,100,0); race.finish_heading=0
	s.race = race
	var finish_recovery = _resolve(open,at,s,"finish plane")
	check(not finish_recovery.has("position") or finish_recovery.position.z<=-1.0,"Recovery on the finish plane is unavailable or safely behind it")

func _identity() -> void:
	var field = Fixture.new()
	var race = Race.new()
	race.title="Recovery rules fixture"; race.start=field.spawn_point(); race.finish=Vector3(0,field.sample(0,80).height,80)
	race.mountain=Race.mountain_reference(field,849209361)
	var data = race.to_data()
	check(Race.SCHEMA==6 and data.race.recovery.rules==Recovery.RULES_VERSION and data.conditions.rules==1,"Portable schema versions recovery while retaining weather")
	check(Race.decode(race.share_text()).has("race"),"Current recovery definition round trips")
	for edit in [{"rules":2},{"anchor":"ragdoll"},{"clock":"stopped"},{"speed":10.0},{"extra":1}]:
		var bad = data.duplicate(true)
		bad.race.recovery.merge(edit,true)
		var rejected = Race.decode(JSON.stringify(bad))
		check(not rejected.has("race") and rejected.get("error") is String and not str(rejected.error).is_empty(),"Malformed recovery rule returns an explicit decode error: "+str(edit))
	for key in ["anchor","clock","speed","rules"]:
		for value in [10.0,true,null,[],{},"unsupported"]:
			var bad = data.duplicate(true)
			bad.race.recovery[key] = value
			var rejected = Race.decode(JSON.stringify(bad))
			check(not rejected.has("race") and rejected.get("error") is String and rejected.error=="Unsupported crash recovery rules.","Malformed recovery field returns a typed error: %s = %s" % [key,str(value)])
	var missing = data.duplicate(true); missing.race.erase("recovery")
	check(not Race.decode(JSON.stringify(missing)).has("race"),"Missing recovery rule rejected without migration")
	var old = data.duplicate(true); old.schema = 5
	check(not Race.decode(JSON.stringify(old)).has("race"),"Old portable schema rejected")
	check("recovery1" in race.record_identity() and "recovery1" in Session.laboratory_identity(),"Race and timed laboratory identities pin recovery rules")
