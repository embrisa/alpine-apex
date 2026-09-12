extends SceneTree
## Current-terrain bounded stress fixture; full tuck, no braking, no saved run.
const Trace = preload("res://tests/performance_trace.gd")
const Stress = preload("res://tests/performance_stress.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var speed = 170.0
	var seconds = 15
	var origin = Vector2.ZERO
	var custom_origin = false
	var output = "res://artifacts/high_speed_stress/open.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stress-speed-kmh="): speed = float(arg.get_slice("=",1))
		if arg.begins_with("--seconds="): seconds = int(arg.get_slice("=",1))
		if arg.begins_with("--trace-output="): output = arg.get_slice("=",1)
		if arg.begins_with("--origin="):
			var values = arg.get_slice("=",1).split(",")
			if values.size()!=2: printerr("Origin needs x,z"); quit(2); return
			origin = Vector2(float(values[0]),float(values[1])); custom_origin = true
	if not is_finite(speed) or speed<=0 or speed>Stress.MAX_SPEED_KMH or seconds<1 or seconds>30 or not origin.is_finite():
		printerr("Choose a finite speed in (0,300] km/h and a 1-30 second trial"); quit(2); return
	if not output.is_absolute_path(): output = "res://"+output
	var field = preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: quit(2); return
	field.build_material_map()
	var start: Vector3 = field.launch_point(field.faces[3].heading)
	if custom_origin: start = Vector3(origin.x,field.sample(origin.x,origin.y).height,origin.y)
	var downhill = Vector3.DOWN.slide(field.contact_normal(start.x,start.z))
	var heading = atan2(downhill.x,downhill.z) if downhill.length_squared()>.0001 else float(field.faces[3].heading)
	var sim = Stress.create(preload("res://config/ski_default.tres").duplicate(true),speed)
	sim.reset(start,heading); sim.prime_contacts(field)
	var initial_state = Trace.Inputs.state(sim)
	var command = RiderInput.new(); command.tuck = 1.0
	var commands = []; var checkpoints = []; var coverage = []
	for tick in seconds*120:
		if tick%12==0: commands.append(Trace.Inputs.encode(command))
		sim.step(1.0/120.0,command,field)
		if not sim.position.is_finite() or not sim.velocity.is_finite(): printerr("Nonfinite stress trajectory"); quit(2); return
		if sim.ticks%120==0:
			checkpoints.append(Trace.Inputs.state(sim))
			coverage.append({"tick":sim.ticks,"position":[sim.position.x,sim.position.y,sim.position.z],
				"trees_175m":field.nearby_obstacle_indices(sim.position,175).size(),"grounded":sim.grounded,"speed_kmh":sim.speed_kmh()})
		if field.reached_base(sim.position): printerr("Stress section leaves the mountain; select an earlier/shorter section"); quit(2); return
	var data = {"identity":Trace.identity(field),"input_fields":Trace.Inputs.FIELDS,"seed":849205174,"face":3,"heading":heading,
		"command_ticks":12,"commands":commands,"initial_state":initial_state,"checkpoints":checkpoints,"stress":Stress.metadata(speed,start),
		"stress_observations":sim.report(),"coverage":coverage,
		"result":{"side":0,"ticks":sim.ticks,"seconds":seconds,"finished":false,"crash":"","position":[sim.position.x,sim.position.y,sim.position.z]}}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(Trace.Inputs.storage(data),"",true,true))
	print("STRESS_TRACE ",output," ",JSON.stringify(sim.report())); quit()
