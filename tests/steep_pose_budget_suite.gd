extends SceneTree
## Instrumented copies count work without adding counters to shipping physics.
## The copies differ only by counters and the body dependency; no timing claims.
const OUTPUT = "res://artifacts/steep_animation_physics_upgrade/pose_budget"
const DT = 1.0/120.0
class CountedSurface extends RefCounted:
	var queries = 0
	func sample(_x: float,z: float) -> Dictionary:
		queries += 1
		return {"height":-z*.46,"normal":Vector3(0,1,.46).normalized()}
	func sweep_obstacle(_a: Vector3,_b: Vector3) -> String: return ""

func _initialize(): call_deferred("run")
func run():
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var body = FileAccess.get_file_as_string("res://scripts/core/rider_body.gd")
	body = body.replace("extends RefCounted","extends RefCounted\nstatic var metered_ik_iterations = 0\nstatic var metered_ik_calls = 0")
	body = body.replace("\tfor iteration in range(16):","\tmetered_ik_calls += 1\n\tfor iteration in range(16):\n\t\tmetered_ik_iterations += 1")
	preload("res://tests/test_report.gd").write(OUTPUT+"/rider_body.gd",body)
	var source = FileAccess.get_file_as_string("res://scripts/core/ski_simulation.gd")
	source = source.replace("class_name SkiSimulation\n","").replace("res://scripts/core/rider_body.gd",OUTPUT+"/rider_body.gd")
	preload("res://tests/test_report.gd").write(OUTPUT+"/ski_simulation.gd",source)
	var model = load(OUTPUT+"/ski_simulation.gd")
	var sim = model.new()
	var physical = preload("res://scripts/core/ski_simulation.gd").new()
	var surface = CountedSurface.new()
	var control_surface = CountedSurface.new()
	# Mirror the presentation dependency chain too: anatomy calls the same
	# pure body fitter directly, so instrumenting only sim.Body misses its cost.
	var copies = {"skier_anatomy":"res://scripts/presentation/skier_anatomy.gd","skier_full_motion":"res://scripts/presentation/skier_full_motion.gd","skier_animation":"res://scripts/presentation/skier_animation.gd","skier_visual":"res://scripts/presentation/skier_visual.gd"}
	for id in copies:
		var copy = FileAccess.get_file_as_string(copies[id]).replace("res://scripts/core/rider_body.gd",OUTPUT+"/rider_body.gd")
		for dependency in copies: copy = copy.replace(copies[dependency],OUTPUT+"/"+dependency+".gd")
		preload("res://tests/test_report.gd").write(OUTPUT+"/"+id+".gd",copy)
	var skier = load(OUTPUT+"/skier_visual.gd").new()
	root.add_child(skier); await process_frame
	var peak_tick_queries = 0; var peak_pose_queries = 0
	var peak_tick_ik = 0; var peak_pose_ik = 0; var peak_pose_calls = 0
	var failures = []; var checks = 0
	for airborne in [false,true]:
		for rider in [sim,physical]:
			rider.reset(Vector3(0,100.0 if airborne else 0.0,0)); rider.prime_contacts(surface)
			rider.velocity = rider.support_basis().z*33.333
			if airborne: rider._begin_flight(rider.support_basis())
		skier.reset_animation(sim)
		var intent = RiderInput.new()
		for tick in 480:
			intent.steer = 1.0 if tick<240 else -1.0
			intent.tuck = 1.0; intent.jump_held = tick>400
			intent.grab = airborne and tick>60 and tick<180
			surface.queries = 0; sim.Body.metered_ik_iterations = 0
			sim.step(DT,intent,surface); skier.step_animation(DT,sim,intent,surface)
			peak_tick_queries = maxi(peak_tick_queries,surface.queries)
			peak_tick_ik = maxi(peak_tick_ik,sim.Body.metered_ik_iterations)
			physical.step(DT,intent,control_surface)
			surface.queries = 0; sim.Body.metered_ik_iterations = 0; sim.Body.metered_ik_calls = 0
			skier.pose(sim,.5)
			peak_pose_queries = maxi(peak_pose_queries,surface.queries)
			peak_pose_ik = maxi(peak_pose_ik,sim.Body.metered_ik_iterations)
			peak_pose_calls = maxi(peak_pose_calls,sim.Body.metered_ik_calls)
			checks += 1
			if sim.position!=physical.position or sim.velocity!=physical.velocity or sim.body.joints!=physical.body.joints: failures.append("Instrumentation changed physical state"); break
	checks += 2
	if peak_pose_queries>20: failures.append("Exceeded four five-point clearance passes")
	if peak_pose_ik>192: failures.append("Exceeded four passes of three 16-iteration fits")
	var report = {"checks":checks,"failures":failures,"max_surface_samples_per_tick":peak_tick_queries,"max_clearance_samples_per_pose":peak_pose_queries,
		"max_ik_iterations_per_tick":peak_tick_ik,"max_ik_iterations_per_pose":peak_pose_ik,"max_ik_calls_per_pose":peak_pose_calls,
		"scope":"Instrumented 960-tick 25-degree plane/flight fixture, 120 km/h entry, turns, reversals, tuck, preparation and grab. Counters cannot be used as timings."}
	preload("res://tests/test_report.gd").write(OUTPUT+"/results.json",JSON.stringify(report,"\t"))
	print("POSE_BUDGET ",JSON.stringify(report))
	skier.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
