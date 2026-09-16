extends SceneTree
## Headless Standard-terrain timing and sampled state comparison.
## Matching position/velocity/heading/support digests do not cover all solver
## state. Inspect crashed_at before using a pass as ordinary riding evidence.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Props = preload("res://scripts/world/prop_collision_surface.gd")
var ticks = 3000
var label = "solver"
func _initialize() -> void: call_deferred("run")
func input_at(tick: int) -> RiderInput:
	var intent = RiderInput.new()
	intent.tuck = 1.0 if (tick/600)%2==0 else 0.0
	intent.steer = sin(tick*0.011)*0.6
	intent.brake = 0.5 if (tick%900)>820 else 0.0
	return intent
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ticks="): ticks = int(arg.get_slice("=",1))
		if arg.begins_with("--label="): label = arg.get_slice("=",1)
	var field = preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: printerr("standard mountain unavailable"); quit(2); return
	var surface = Props.new(field)
	var results = {}
	for pass_index in 3:
		var sim = Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
		var heading: float = field.spawn_heading()
		sim.reset(field.launch_point(heading) if field.has_method("launch_point") else field.spawn_point(),heading)
		sim.prime_contacts(surface)
		var hasher = HashingContext.new(); hasher.start(HashingContext.HASH_SHA256)
		var started = Time.get_ticks_usec()
		var crashed_at = -1
		for tick in ticks:
			sim.step(1.0/120.0,input_at(tick),surface)
			hasher.update(var_to_bytes([sim.position,sim.velocity,sim.heading,sim.grounded]))
			if sim.crashed and crashed_at<0: crashed_at = tick
		var elapsed = Time.get_ticks_usec()-started
		results["pass_%d" % pass_index] = {"us_per_tick":float(elapsed)/ticks,"state_sha256":hasher.finish().hex_encode(),"final_position":str(sim.position),"crashed_at":crashed_at,"peak_kmh":sim.peak_speed*3.6}
	var out = {"label":label,"ticks":ticks,"engine":Engine.get_version_info().string,"platform":OS.get_name(),"results":results}
	DirAccess.make_dir_recursive_absolute("res://artifacts/solver_tick")
	var f = preload("res://tests/test_report.gd").open_write("res://artifacts/solver_tick/%s.json" % label); f.store_string(JSON.stringify(out,"\t")); f.close()
	print("SOLVER_TICK_BENCHMARK ",JSON.stringify(out))
	quit(0)
