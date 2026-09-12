extends SceneTree
## Fixed-input model-27 comparison and behavioral contracts for grounded snow.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Probe = preload("res://tests/planted_snow_probe.gd")
const Bank = preload("res://tests/snow_crush_suite.gd").Bank
const Assist = preload("res://scripts/core/snow_contact_assist.gd")
const Replay = preload("res://scripts/racing/run_replay.gd")
const DT = 1.0/120.0
const OUTPUT = "res://artifacts/snow_grounding_v28"
var checks = 0
var failures: Array = []
var rows: Array = []

class SnowLedge extends RefCounted:
	func sample(_x: float,z: float) -> Dictionary:
		return {"height":0.0 if z<2.0 else -12.0,"normal":Vector3.UP}
	func snow_depth_at(_x: float,_z: float) -> float: return .2
	func sweep_obstacle(_a: Vector3,_b: Vector3) -> String: return ""

class Mixed extends Probe.SnowRipple:
	func rock_fraction_at(x: float,_z: float) -> float: return 1.0 if x>0.0 else 0.0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)

static func rider(model, field, kmh: float = 120.0):
	var sim = model.new()
	sim.reset(Vector3(0,field.sample(0,0).height,0)); sim.prime_contacts(field)
	sim.velocity = sim.support_basis().z*kmh/3.6
	return sim

static func measure(model, field, fixture: Dictionary) -> Dictionary:
	var sim = rider(model,field,fixture.kmh)
	var intent = RiderInput.new()
	intent.tuck = 1.0; sim.effective_tuck = 1.0
	var launches = 0; var reach = 0.0; var foot = 0.0; var grip = 0.0; var min_load = INF
	var correction = 0.0; var causes = {}; var reasons = {}; var max_flight = 0.0
	var timings: Array[float] = []; var impact = 0.0
	for tick in roundi(fixture.get("seconds",4.0)/DT):
		intent.steer = Probe.steering(fixture,tick*DT)
		var supported: bool = sim.grounded
		var start = Time.get_ticks_usec()
		sim.step(DT,intent,field)
		timings.append(Time.get_ticks_usec()-start)
		if supported and not sim.grounded:
			launches += 1; causes[sim.takeoff_reason] = causes.get(sim.takeoff_reason,0)+1
		max_flight = maxf(max_flight,sim.airtime)
		impact = maxf(impact,sim.landing_force)
		if "snow_contact_assist" in sim:
			correction = maxf(correction,sim.snow_contact_assist.correction_m_s)
			var reason: String = sim.snow_contact_assist.release_reason
			reasons[reason] = reasons.get(reason,0)+1
		for ski in sim.skis:
			min_load = minf(min_load,ski.load_n)
			if ski.grounded:
				reach = maxf(reach,absf(sim.position.y-ski.height_reference))
				foot = maxf(foot,absf(ski.position.y+ski.crush_vertical_m-field.sample(ski.position.x,ski.position.z).height))
			else: grip = maxf(grip,absf(ski.grip_n))
		if sim.crashed: break
	return {"fixture":fixture,"airtime_s":sim.total_airtime,"launches":launches,"longest_flight_s":max_flight,
		"crash":sim.crash_reason,"duration_s":sim.ticks*DT,"exit_kmh":sim.speed_kmh(),"reach_m":reach,
		"foot_error_m":foot,"unsupported_grip_n":grip,"min_load_n":min_load,"max_correction_m_s":correction,
		"takeoff_reasons":causes,"assist_reasons":reasons,"peak_impact_m_s":impact,"solver_us":stats(timings)}

static func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted = values.duplicate(); sorted.sort()
	var total = 0.0
	for value in values: total += value
	return {"mean":total/values.size(),"p95":sorted[mini(sorted.size()-1,int(sorted.size()*.95))],"p99":sorted[mini(sorted.size()-1,int(sorted.size()*.99))]}

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var baseline = "--baseline" in args
	var quick = "--quick" in args
	var contracts_only = "--contracts" in args
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var reference_path = OUTPUT+"/baseline/"+("quick" if quick else "matrix")+".json"
	var model = load(OUTPUT+"/baseline/core/ski_simulation.gd") if baseline else Sim
	var reference: Dictionary = {}
	if not baseline and not contracts_only:
		if not FileAccess.file_exists(reference_path): printerr("Missing frozen baseline: ",reference_path); quit(1); return
		reference = JSON.parse_string(FileAccess.get_file_as_string(reference_path))
		check(reference.model==27,"Baseline identifies the frozen model 27")
	var air = 0.0; var old_air = 0.0; var launches = 0; var old_launches = 0
	if not contracts_only:
		for shape in ([[.30,32.0],[.60,32.0]] if quick else [[.15,16.0],[.30,16.0],[.30,32.0],[.60,32.0]]):
			for kmh in ([120.0,200.0] if quick else [30.0,60.0,120.0,160.0,200.0]):
				for input in (["glide","reversal"] if quick else ["glide","ripple","carve","reversal"]):
					for angle in ([.35] if quick else [0.0,.35]):
						var fixture = {"amplitude":shape[0],"wavelength":shape[1],"depth":.20,"angle":angle,"kmh":kmh,"input":input,"steer":.75 if input in ["carve","reversal"] else .15,"seconds":4.0}
						var row = measure(model,Probe.SnowRipple.new(shape[0],shape[1],.20,angle),fixture)
						if not baseline:
							var before: Dictionary = reference.rows[rows.size()]
							check(before.fixture==fixture,"Identical comparison fixture %d"%rows.size())
							old_air += before.airtime_s; old_launches += int(before.launches)
							check(row.crash.is_empty() and row.duration_s==4.0,"Complete ordinary crossing %d"%rows.size())
							check(row.reach_m<=.281 and row.foot_error_m<.002,"Reach and physical ski placement %d"%rows.size())
							check(row.unsupported_grip_n==0 and row.min_load_n>=0,"Compressive support and no aerial grip %d"%rows.size())
							check(row.max_correction_m_s<=3.000001,"Bounded snow correction %d"%rows.size())
						air += row.airtime_s; launches += int(row.launches)
						rows.append(row)
						print("SNOW_GROUND_ROW ",rows.size()-1," air=",row.airtime_s," launches=",row.launches," reasons=",row.assist_reasons)
		if not baseline:
			check(air<=old_air*.20,"At least 80% less ordinary-bump airtime")
			check(launches<old_launches,"Fewer ordinary-bump takeoffs")
	if not baseline: contracts()
	var report = {"model":model.MODEL_VERSION,"checks":checks,"failures":failures,"rows":rows,"unranked":true,
		"airtime_s":air,"baseline_airtime_s":old_air,"launches":launches,"baseline_launches":old_launches,"timings_are_isolated_performance_evidence":false}
	var path = reference_path if baseline else OUTPUT+"/"+("contracts" if contracts_only else ("quick" if quick else "matrix"))+".json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SNOW_GROUNDING ",path," checks=",checks," failures=",failures.size()," air before/after=",old_air,"/",air," launches=",old_launches,"/",launches)
	quit(0 if failures.is_empty() else 1)

func contracts() -> void:
	check(Sim.MODEL_VERSION==29 and Replay.VERSION==7 and Replay.INPUT_WIDTH==9,"Pole propulsion retains grounded snow with the held-preparation replay field")
	var field = Probe.SnowRipple.new(0,32,.20)
	var sim = rider(Sim,field)
	sim.velocity += sim.support_basis().y*1.0
	var assist = Assist.new()
	var before: Vector3 = sim.velocity
	var load_before: float = sim.normal_load
	var root_before: Vector3 = sim.position
	var delta = assist.advance(DT,sim,field,false)
	check(delta.length()>0 and delta.length()<=3.0,"Reachable separating snow receives a bounded correction")
	check((before+delta).length_squared()<=before.length_squared() and delta.dot(before)<0,"Assist only removes kinetic energy")
	check(sim.position==root_before and sim.velocity==before and sim.normal_load==load_before,"Evaluation does not snap root, write velocity or inflate load")
	check(assist.advance(DT,sim,field,false)==Vector3.ZERO,"Assist can advance only once per physics tick")
	assist.reset(); sim.velocity = before+sim.support_basis().y*8.0
	delta = assist.advance(DT,sim,field,false)
	check(absf(delta.length()-3.0)<.00001 and (sim.velocity+delta).length_squared()<sim.velocity.length_squared(),"Extreme separating velocity saturates at 3 m/s without adding energy")
	sim.velocity = before
	var saved = [sim.snow_contact_assist.last_tick,sim.snow_contact_assist.suppressed,sim.snow_contact_assist.settled_s]
	for i in 4: sim._update_contacts(field,DT,false); sim._support_sample(field,sim.position)
	check(saved==[sim.snow_contact_assist.last_tick,sim.snow_contact_assist.suppressed,sim.snow_contact_assist.settled_s],"Read-only support probes do not advance assistance")
	assist.reset(); sim.position += Vector3.UP*.5
	check(assist.advance(DT,sim,field,false)==Vector3.ZERO and assist.release_reason=="reach","Unreachable snow cannot attract the rider")
	sim = rider(Sim,field); sim.velocity += sim.support_basis().y*2
	assist.reset(); check(assist.advance(DT,sim,field,true)==Vector3.ZERO,"Pending jump bypasses retention")
	var a = rider(Sim,field); var b = rider(Sim,field); b.tuning.snow_contact_assist_enabled = false
	var input = RiderInput.new(); input.jump = true
	a.step(DT,input,field); b.step(DT,input,field)
	check(a.jump_executed and not a.grounded and a.position==b.position and a.velocity==b.velocity,"Deliberate hop has identical impulse and departure with assistance enabled")
	input.jump = false
	for tick in 24: a.step(DT,input,field); b.step(DT,input,field)
	check(not a.grounded and a.position==b.position and a.velocity==b.velocity,"Established flight is unchanged")
	# A short jump buffer can be consumed by genuine touchdown, with the same
	# next-tick impulse whether the snow-retention feature is enabled or not.
	a = rider(Sim,field); b = rider(Sim,field); b.tuning.snow_contact_assist_enabled = false
	for falling in [a,b]:
		falling.position.y += .015; falling.velocity = Vector3(0,-2,0)
		falling._begin_flight(falling.support_basis(),"test landing")
		falling.jump_buffer_remaining = .1
	var buffered_hops = 0
	for tick in 6:
		a.step(DT,input,field); b.step(DT,input,field)
		if a.jump_executed: buffered_hops += 1
	check(buffered_hops==1 and a.position==b.position and a.velocity==b.velocity,"Buffered landing hop bypasses retention")
	a = rider(Sim,SnowLedge.new(),72); b = rider(Sim,SnowLedge.new(),72); b.tuning.snow_contact_assist_enabled = false
	for tick in 24: a.step(DT,input,SnowLedge.new()); b.step(DT,input,SnowLedge.new())
	check(not a.grounded and a.position==b.position and a.velocity==b.velocity,"Snow-covered cliff releases without snap or altered trajectory")
	var ramp = Bank.new(1.5,8)
	var ramp_row = measure(Sim,ramp,{"kmh":160.0,"input":"glide","seconds":2.0})
	check(ramp_row.launches>0,"Pronounced snow-covered ramp still gives air")
	field.rock_fraction = 1.0
	a = rider(Sim,field); b = rider(Sim,field); b.tuning.snow_contact_assist_enabled = false
	for tick in 120: a.step(DT,input,field); b.step(DT,input,field)
	check(a.position==b.position and a.velocity==b.velocity,"Rock receives no contact assistance")
	field = Probe.SnowRipple.new(.30,32,.20,.35)
	a = rider(Sim,field); b = rider(Sim,field)
	var replay = Replay.new(); var identity = Replay.key("snow-grounding")
	replay.begin(a,identity)
	var same = true
	for tick in 240:
		input.steer = .5*sin(tick*DT*2)
		a.step(DT,input,field); replay.record(DT,(tick+1)*DT,a,input,1.0 if tick==239 else -1.0)
		b.step(DT,replay.input_at(tick),field)
		same = same and a.position.distance_to(b.position)<.00001 and a.velocity.distance_to(b.velocity)<.00001
	check(same,"Recorded inputs reproduce grounded snow")
	preload("res://tests/ghost_replay_fixture.gd").attach_sample_poses(replay)
	var encoded = replay.to_data()
	check(Replay.decode(encoded,identity,replay.duration)!=null,"Current model recording round-trips with a complete pose envelope")
	encoded.compatibility.physics = 27
	check(Replay.decode(encoded,identity,replay.duration)==null,"Model 27 recordings are incompatible")
	a.snow_contact_assist.suppressed = true; a.snow_contact_assist.settled_s = .1
	a.prime_contacts(field)
	check(not a.snow_contact_assist.suppressed and a.snow_contact_assist.settled_s==0,"Teleport/contact priming clears retained history")
	a.snow_contact_assist.suppressed = true; a.reset(Vector3.ZERO)
	check(not a.snow_contact_assist.suppressed and a.snow_contact_assist.correction_m_s==0,"Restart clears assistance")
	var mixed = Mixed.new(0,32,.20)
	a = rider(Sim,mixed); a.velocity += a.support_basis().y
	assist.reset(); delta = assist.advance(DT,a,mixed,false)
	check(assist.eligible_skis==1 and delta.length()>0 and delta.length()<1.0,"Mixed contact uses only the eligible snow ski's share")
	# A steep plane has no change in slope, so it must not be mistaken for a lip.
	var steep = Probe.SnowRipple.new(0,32,.20)
	for z in steep.NZ:
		for x in steep.NX: steep.heights[z*steep.NX+x] = -(steep.Z_MIN+z*steep.CELL)*1.5
	a = rider(Sim,steep); a.velocity += a.support_basis().y
	assist.reset(); delta = assist.advance(DT,a,steep,false)
	check(delta.length()>.9 and not assist.suppressed,"Absolute steepness does not suppress snow retention")
	# Lip suppression persists over a smooth but still separating contact, then
	# clears only after 150 ms of continuously loaded non-separating support.
	field = Probe.SnowRipple.new(0,32,.20)
	a = rider(Sim,field); a.velocity += a.support_basis().y
	assist.reset(); assist.suppressed = true
	for tick in 24:
		a.ticks += 1; assist.advance(DT,a,field,false)
	check(assist.suppressed and assist.settled_s==0,"Separating contact cannot rearm after a sharp lip")
	a.velocity = a.support_basis().z*30-a.support_basis().y*.1
	for tick in 17:
		a.ticks += 1; assist.advance(DT,a,field,false)
	check(assist.suppressed,"Seventeen loaded ticks are shorter than the lip-recovery interval")
	a.ticks += 1; assist.advance(DT,a,field,false)
	check(not assist.suppressed,"Eighteen loaded ticks rearm retention")
	assist.suppressed = true; field.rock_fraction = 1.0; a.ticks += 1
	assist.advance(DT,a,field,false)
	check(not assist.suppressed and assist.correction_m_s==0,"Leaving snow clears retained suppression")
