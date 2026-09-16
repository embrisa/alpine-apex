extends SceneTree
## Bounded analytic fixtures; no game/session/PB/preferences or render clocks.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Tuning = preload("res://scripts/core/ski_tuning.gd")
const Pole = preload("res://scripts/core/pole_propulsion.gd")
const Replay = preload("res://scripts/racing/run_replay.gd")
const DT = 1.0/120.0
var checks = 0
var failures: Array = []
var rows: Array = []
var cap_rows: Array = []
var output = "res://artifacts/orchestration_20260912/poles/validation/physics.json"

class SlopePlane:
	extends RefCounted
	var grade = 0.0
	var cross_grade = 0.0
	var rock = false
	var depth = .12
	func _init(degrees: float = 0.0, cross_degrees: float = 0.0) -> void:
		grade = tan(deg_to_rad(degrees)); cross_grade = tan(deg_to_rad(cross_degrees))
	func sample(x: float,z: float) -> Dictionary:
		return {"height":x*cross_grade+z*grade,"normal":Vector3(-cross_grade,1,-grade).normalized()}
	func snow_depth_at(_x: float,_z: float) -> float: return depth
	func rock_fraction_at(_x: float,_z: float) -> float: return 1.0 if rock else 0.0
	func sweep_obstacle(_a: Vector3,_b: Vector3) -> String: return ""

class Crest:
	extends SlopePlane
	func sample(_x: float,z: float) -> Dictionary:
		# Smooth 4 m-scale convex crest (plus matching analytic normal).
		return {"height":1.2*sin(z/8.0),"normal":Vector3(0,1,-.15*cos(z/8.0)).normalized()}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

static func make_sim(surface, speed: float = 0.0, enabled: bool = true, yaw: float = 0.0):
	var tuning = Tuning.new(); tuning.pole_push_enabled = enabled
	var sim = Sim.new(tuning)
	sim.reset(Vector3.ZERO,yaw); sim.prime_contacts(surface)
	sim.velocity = sim.support_basis().z*speed
	sim.reset_pose_history()
	return sim

func run() -> void:
	var cap_only = false
	var output_override = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output="); output_override = true
		if arg=="--cap-only": cap_only = true
	if cap_only and not output_override:
		output = "res://artifacts/orchestration_20260912/poles/validation/cap.json"
	var start = Time.get_ticks_usec()
	curve_checks()
	cap_checks()
	exclusion_checks()
	if not cap_only:
		for angle in [0.0,9.9,10.0,10.1,19.9,20.0,20.1,27.9,28.0,28.1,33.9,34.0,34.1,41.9,42.0,42.1,46.0,-12.0]:
			measure_ascent(angle)
		momentum_and_lifecycle()
		traverse_and_crest()
		replay_repeatability()
	var receipt = {"engine":Engine.get_version_info(),"model":Sim.MODEL_VERSION,"tuning_sha256":FileAccess.get_sha256("res://config/ski_default.tres"),
		"checks":checks,"failures":failures,"cases":rows,"cap_cases":cap_rows,"cpu_total_us":Time.get_ticks_usec()-start,
		"scope":"Cap precision, incoming/completed tick boundaries and exclusions only; no ascent measurement" if cap_only else "30-second analytic descents and matched no-push controls; timing is contended test CPU, not gameplay FPS"}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	preload("res://tests/test_report.gd").write(output,JSON.stringify(receipt,"\t"))
	print("POLE_PUSH_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"output":output}))
	quit(0 if failures.is_empty() else 1)

func curve_checks() -> void:
	var tuning = Tuning.new()
	var previous = INF; var continuous = true; var monotonic = true
	for i in 4201:
		var cap = Pole.speed_limit(float(i)/100.0,tuning)
		monotonic = monotonic and cap<=previous+.000001
		if i>0: continuous = continuous and absf(cap-previous)<.012
		previous = cap
	check(monotonic and continuous,"uphill curve is smooth and monotonic including all knots")
	check(is_equal_approx(Pole.speed_limit(0,tuning)*3.6,40) and Pole.speed_limit(42,tuning)==0,"40 km/h flat force limit and zero 42-degree assistance")
	check(Pole.stroke_power(.02)==0 and Pole.stroke_power(.4)==1 and Pole.stroke_power(.9)==0,"source plant/power/recovery landmarks match actuator")

func measure_ascent(angle: float) -> void:
	var surface = SlopePlane.new(angle)
	var sim = make_sim(surface); var baseline = make_sim(surface,0,false)
	var intent = RiderInput.new(); intent.tuck = 1.0
	var power_ticks = 0; var unsupported_power = false; var peak = 0.0
	var speed_sum = 0.0; var minimum = INF; var maximum = -INF
	var cpu = Time.get_ticks_usec()
	for tick in 3600:
		sim.step(DT,intent,surface); baseline.step(DT,intent,surface)
		if sim.pole_push_acceleration>0: power_ticks += 1
		unsupported_power = unsupported_power or (not sim.grounded and sim.pole_push_acceleration>0)
		peak = maxf(peak,sim.speed_kmh())
		if tick>=3000:
			# Measure ascent in the original slope direction even after switch.
			var uphill = Vector3(0,tan(deg_to_rad(angle)),1).normalized()
			var speed: float = sim.velocity.dot(uphill)*3.6
			speed_sum += speed/600.0; minimum = minf(minimum,speed); maximum = maxf(maximum,speed)
	rows.append({"grade_degrees":angle,"steady_mean_kmh":speed_sum,"steady_min_kmh":minimum,"steady_max_kmh":maximum,
		"peak_kmh":peak,"power_ticks":power_ticks,"cycles":sim.pole_push.cycles,"crashed":sim.crashed,
		"progress_m":sim.position.z,"baseline_progress_m":baseline.position.z,"baseline_speed_kmh":baseline.speed_kmh(),"paired_cpu_us":Time.get_ticks_usec()-cpu})
	check(not unsupported_power,"%s degrees: no completed unsupported force"%angle)
	if angle==0:
		check(not sim.crashed and power_ticks>100 and sim.pole_push.cycles>5 and sim.position.z>baseline.position.z+50,"flat repeated pushes depart rest")
		check(speed_sum>=35 and peak<=40.01,"flat approaches 40 km/h without propulsion overshoot")
	if angle in [20.0,28.0,34.0]:
		var target = 15.0 if angle==20.0 else 10.0 if angle==28.0 else 5.0
		check(not sim.crashed and absf(speed_sum-target)<=3.0,"%s-degree steep ascent near %s km/h (3 km/h tolerance)"%[angle,target])
	if angle>=42: check(power_ticks==0 and sim.position.z<=.01,"%s-degree cutoff cannot sustain a climb"%angle)
	if angle==-12: check(peak>40.0,"downhill gravity remains free above flat pole limit")

func exclusion_checks() -> void:
	for why in ["release","brake","prepare","jump","switch","strong turn","rock","air","rough","sideways","rollback","cap"]:
		var surface = SlopePlane.new(); var sim = make_sim(surface)
		var intent = RiderInput.new(); intent.tuck = 1.0
		match why:
			"release": intent.tuck = 0
			"brake": intent.brake = .05
			"prepare": intent.jump_held = true
			"jump": intent.jump = true
			"switch": sim.facing_backward = true
			"strong turn": intent.steer = .9
			"rock":
				for ski in sim.skis: ski.material_kind = preload("res://scripts/core/terrain_material.gd").Kind.ROCK
			"air": sim._begin_flight(sim.support_basis())
			"rough": sim.snow_contact_assist.suppressed = true
			"sideways": sim.velocity = Vector3.RIGHT*12
			"rollback": sim.velocity = Vector3(0,0,-.9)
			"cap": sim.velocity = Vector3(0,0,40.0/3.6)
		var impulse = 0.0
		var incoming_speed = sim.velocity.slide(sim.surface_normal).length()
		for tick in 120: impulse += sim.pole_push.advance(DT,sim,intent,incoming_speed).length()*DT
		check(impulse==0,"no propulsion: "+why)
	var surface = SlopePlane.new(); var sim = make_sim(surface,-.2)
	var held = RiderInput.new(); held.tuck = 1
	for tick in 120: sim.step(DT,held,surface)
	check(sim.velocity.z>0 and not sim.facing_backward,"slow rollback is arrested without heading assignment")
	# Ordinary low-speed steering remains available.
	sim = make_sim(surface)
	held.steer = .25
	for tick in 120: sim.step(DT,held,surface)
	check(absf(sim.heading)>.02 and sim.position.length()>.1,"ordinary pushing preserves steering")

func cap_checks() -> void:
	var held = RiderInput.new(); held.tuck = 1
	# Freeze completed velocity while the actuator traverses several strokes.
	# Nominal scalar limits must still mean exactly zero force after Vector3
	# conversion, support projection and rotated uphill/traverse headings.
	for angle in [0.0,10.0,20.0,28.0,34.0]:
		for yaw in [0.0,.37,1.17,-.57]:
			var surface = SlopePlane.new(angle)
			var sim = make_sim(surface,0.0,true,yaw)
			var forward: Vector3 = sim.support_basis().z.slide(sim.surface_normal).normalized()
			var grade = rad_to_deg(asin(clampf(forward.y,-1.0,1.0)))
			var cap = Pole.speed_limit(maxf(0.0,grade),sim.tuning)
			var zero_force = true; var zero_power = true; var immutable = true
			var impulse = 0.0
			for excess in [0.0,.1,10.0]:
				sim.velocity = forward*(cap+excess)
				var incoming: Vector3 = sim.velocity
				var incoming_speed = incoming.slide(sim.surface_normal).length()
				for tick in 120:
					var force: Vector3 = sim.pole_push.advance(DT,sim,held,incoming_speed)
					zero_force = zero_force and force==Vector3.ZERO and sim.pole_push_acceleration==0.0
					zero_power = zero_power and sim.pole_push_power==0.0
					immutable = immutable and sim.velocity==incoming
					impulse += force.length()*DT
			check(zero_force and zero_power and immutable,"exact zero force/power without velocity change at/above cap: slope %s yaw %s"%[angle,yaw])
			# A real speed deficit must retain propulsion; the numerical guard is
			# not a lower gameplay cap or a blanket high-speed disable.
			sim.velocity = forward*(cap-.01)
			sim.pole_push.active = true; sim.pole_push.cycle_phase = .1
			var resumed: Vector3 = sim.pole_push.advance(DT,sim,held,sim.velocity.slide(sim.surface_normal).length())
			check(resumed.dot(forward)>0.0 and sim.pole_push_power>0.0,"positive loaded stroke 0.01 m/s below cap: slope %s yaw %s"%[angle,yaw])
			cap_rows.append({"slope_degrees":angle,"yaw":yaw,"travel_grade_degrees":grade,"cap_mps":cap,"at_or_above_impulse_mps":impulse,"below_cap_acceleration":sim.pole_push_acceleration})
	var surface = SlopePlane.new()
	var cap = 40.0/3.6
	var sim = make_sim(surface,cap-.05)
	sim.pole_push.active = true; sim.pole_push.cycle_phase = .1
	var incoming_cap = Vector3(0,0,cap).length()
	var force: Vector3 = sim.pole_push.advance(DT,sim,held,incoming_cap)
	check(force==Vector3.ZERO and sim.pole_push_power==0.0,"contact slowdown cannot enable force when incoming completed speed was at cap")
	# A fresh completed tick below the cap may resume; do not assert that a
	# rider naturally slowed by drag remains ineligible for the next second.
	force = sim.pole_push.advance(DT,sim,held,sim.velocity.length())
	check(force.z>0.0 and sim.pole_push_power>0.0,"new completed speed below cap permits the continuing stroke")
	# Conversely a current speed raised to the cap cannot use a slower input.
	sim.velocity = Vector3(0,0,cap)
	force = sim.pole_push.advance(DT,sim,held,cap-.05)
	check(force==Vector3.ZERO and sim.pole_push_power==0.0,"current speed at cap also blocks an older below-cap input")
	# Exercise the real solver order with an already loaded stroke. Compare the
	# incoming speed to eligibility, and the outgoing speed to a no-push twin.
	for entry in [cap,cap+.001,60.0/3.6]:
		sim = make_sim(surface,entry)
		var control = make_sim(surface,entry,false)
		sim.pole_push.active = true; sim.pole_push.cycle_phase = .1
		var incoming_speed = sim.velocity.slide(sim.surface_normal).length()
		sim.step(DT,held,surface); control.step(DT,held,surface)
		check(sim.pole_push_acceleration==0.0 and sim.pole_push_power==0.0,"incoming capped solver tick adds exactly no force: %s m/s"%entry)
		check(sim.velocity==control.velocity and sim.position==control.position,"capped solver tick matches natural resistance without clamp/brake: %s m/s"%entry)
		var outgoing_speed = sim.velocity.slide(sim.surface_normal).length()
		cap_rows.append({"solver_entry_mps":entry,"incoming_mps":incoming_speed,"outgoing_mps":outgoing_speed,"acceleration":sim.pole_push_acceleration,"control_velocity_equal":sim.velocity==control.velocity})
		if entry==cap:
			check(outgoing_speed<cap-.00001,"cap-entry tick completes below cap through natural resistance")
			sim.step(DT,held,surface)
			check(sim.pole_push_acceleration>0.0 and sim.pole_push_power>0.0,"following solver tick resumes from its now below-cap completed state")

func momentum_and_lifecycle() -> void:
	var surface = SlopePlane.new(28)
	var sim = make_sim(surface,12.0); var control = make_sim(surface,12.0,false)
	var held = RiderInput.new(); held.tuck = 1
	var equal = true
	for tick in 60:
		sim.step(DT,held,surface); control.step(DT,held,surface)
		equal = equal and sim.velocity.distance_to(control.velocity)<.000001 and sim.pole_push_acceleration==0
	check(equal and sim.velocity.length()>8,"high momentum enters uphill without a cap clamp or extra brake")
	surface = SlopePlane.new(); sim = make_sim(surface)
	for tick in 240: sim.step(DT,held,surface)
	var released = RiderInput.new()
	sim.step(DT,released,surface)
	check(sim.pole_push_acceleration==0,"release stops force on its first tick")
	for tick in 60: sim.step(DT,held,surface)
	held.brake = .1; sim.step(DT,held,surface)
	check(sim.pole_push_acceleration==0,"brake stops force on its first tick")
	sim.clear_input_buffer()
	check(sim.pole_push_phase==0 and sim.pole_push_intensity==0,"pause/input lifecycle clears pending stroke")
	sim.crash("fixture")
	check(sim.pole_push_acceleration==0 and sim.pole_push_intensity==0,"crash clears action")
	sim.reset(Vector3.ZERO); sim.prime_contacts(surface)
	check(sim.pole_push_phase==0 and sim.pole_push.cycles==0,"restart/recovery reset clears cycle history")
	# Flight starts with identical translation and tuck: compare every tick.
	control = make_sim(surface,7,false); sim = make_sim(surface,7,true)
	for model in [sim,control]:
		model.position.y = 50; model._begin_flight(model.support_basis()); model.velocity.y = 3
	held.brake = 0
	equal = true
	for tick in 120:
		sim.step(DT,held,surface); control.step(DT,held,surface)
		equal = equal and sim.position==control.position and sim.velocity==control.velocity and sim.pole_push_acceleration==0
	check(equal,"identical initial flight/tuck keeps unchanged airborne trajectory")

func traverse_and_crest() -> void:
	var surface = SlopePlane.new(0,30)
	var sim = make_sim(surface); var held = RiderInput.new(); held.tuck = 1
	sim.pole_push.advance(DT,sim,held,sim.velocity.slide(sim.surface_normal).length())
	check(absf(sim.pole_push_grade_degrees)<.01 and is_equal_approx(sim.pole_push_limit_mps,40.0/3.6),"cross-slope traverse uses travelled grade, not steepest gradient")
	sim = make_sim(surface,0,true,PI*.5)
	sim.pole_push.advance(DT,sim,held,sim.velocity.slide(sim.surface_normal).length())
	check(absf(sim.pole_push_grade_degrees-30)<.01 and sim.pole_push_limit_mps<12.0/3.6,"same slope uphill heading receives uphill limit")
	var crest = Crest.new(); sim = make_sim(crest,5)
	var safe = true; var impulse_peak = 0.0
	for tick in 1800:
		var before: Vector3 = sim.velocity
		sim.step(DT,held,crest)
		impulse_peak = maxf(impulse_peak,sim.velocity.distance_to(before))
		safe = safe and sim.position.is_finite() and (sim.grounded or sim.pole_push_acceleration==0)
	check(safe and not sim.crashed and impulse_peak<1,"bounded convex-crest transitions retain finite support/impulses")

func replay_repeatability() -> void:
	var surface = SlopePlane.new(10)
	var a = make_sim(surface); var b = make_sim(surface)
	var replay = Replay.new(); replay.begin(a,Replay.key("pole-fixture"))
	var equal = true
	for tick in 480:
		var intent = RiderInput.new(); intent.tuck = 1
		intent.jump_held = tick>=200 and tick<240
		intent.brake = .2 if tick>=350 and tick<370 else 0.0
		a.step(DT,intent,surface)
		replay.record(DT,(tick+1)*DT,a,intent,1.0 if tick==479 else -1.0)
		var recorded = replay.input_at(tick)
		b.step(DT,recorded,surface)
		equal = equal and a.position==b.position and a.velocity==b.velocity and a.pole_push_phase==b.pole_push_phase
	check(Replay.INPUT_WIDTH==9 and replay.input_at(210).jump_held,"replay preserves newly physical held-preparation flag")
	check(equal,"recorded tick inputs reproduce propulsion and phase exactly")
	check(not replay.has_presentation(),"physics-only recording cannot masquerade as a production-pose replay")
