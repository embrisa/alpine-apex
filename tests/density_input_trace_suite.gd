extends SceneTree
## Test-fixture replay only; never writes personal records or changes live input.
const Cache=preload("res://scripts/world/mountain_cache_v13.gd")
const Simulation=preload("res://scripts/core/ski_simulation.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var trace=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/alpine_v13/inputs_3_0.json"))
	var field=Cache.generate(849205174)
	field.build_material_map()
	if trace.model!=Simulation.MODEL_VERSION or trace.height_sha256!=field.height_checksum or trace.obstacle_sha256!=field.obstacle_checksum or trace.simulation_sha256!=FileAccess.get_sha256("res://scripts/core/ski_simulation.gd") or trace.tuning_sha256!=FileAccess.get_sha256("res://config/ski_default.tres"):
		printerr("FAIL Native benchmark trace must match current physical source and mountain"); quit(1); return
	var sim=Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
	sim.reset(field.launch_point(field.faces[3].heading),field.faces[3].heading)
	sim.prime_contacts(field)
	var input=RiderInput.new()
	for tick in roundi(trace.result.seconds*120):
		if tick%12==0:
			var command=trace.commands[tick/12]
			input=RiderInput.new()
			input.steer=command[0]; input.tuck=command[1]; input.brake=command[2]; input.jump=command[3]
		sim.step(1.0/120,input,field)
	var ok=field.reached_base(sim.position) and not sim.crashed and str(sim.position)==trace.result.position
	print("DENSITY_INPUT_TRACE ","PASS" if ok else "FAIL"," exact ordinary-input replay; position=",sim.position," crash=",sim.crash_reason)
	quit(0 if ok else 1)
