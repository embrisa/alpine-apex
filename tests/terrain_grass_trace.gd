extends SceneTree
## Bounded local launch, then only ordinary inputs through the production solver.
const Trace = preload("res://tests/performance_trace.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output = "res://artifacts/terrain_grass_performance_20260913/pilot_traces"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.get_slice("=",1)
	if not output.is_absolute_path(): output="res://"+output
	DirAccess.make_dir_recursive_absolute(output)
	var field=preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: quit(2); return
	field.build_material_map()
	for habitat in {"forest":Vector2(1608,1416),"transition":Vector2(-244,-2224)}:
		var origin: Vector2={"forest":Vector2(1608,1416),"transition":Vector2(-244,-2224)}[habitat]
		var attempts=[]; var accepted=false
		for offset in [Vector2.ZERO,Vector2(16,0),Vector2(-16,0),Vector2(0,16),Vector2(0,-16),Vector2(32,32),Vector2(-32,-32)]:
			var at=origin+offset
			var start=Vector3(at.x,field.sample(at.x,at.y).height,at.y)
			var downhill=Vector3.DOWN.slide(field.contact_normal(at.x,at.y))
			var heading=atan2(downhill.x,downhill.z)
			for steering in [0.0,-.12,.12,-.3,.3]:
				var sim=Trace.Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
				sim.reset(start,heading); sim.prime_contacts(field)
				var initial=Trace.Inputs.state(sim)
				var face=field.faces[3]
				var target=at+Vector2(sin(heading+steering),cos(heading+steering))*500.0
				var a: Vector2=face.to_local(at); var b: Vector2=face.to_local(target)
				var path=[[a.x,a.y],[b.x,b.y]]
				var command=RiderInput.new(); command.steer=steering; command.tuck=.7
				var commands=[]; var checkpoints=[]; var coverage=[]; var travelled=0.0; var contacts=0
				for tick in 1800:
					if tick%12==0:
						command=Trace.Pilot.intent(sim,field,3,path)
						commands.append(Trace.Inputs.encode(command))
					var previous=sim.position
					sim.step(1.0/120.0,command,field)
					travelled+=sim.position.distance_to(previous)
					if not sim.obstacle_contact.is_empty(): contacts+=1
					if sim.ticks%120==0:
						checkpoints.append(Trace.Inputs.state(sim))
						coverage.append({"tick":sim.ticks,"position":[sim.position.x,sim.position.y,sim.position.z],"speed_kmh":sim.speed_kmh(),"trees_175m":field.nearby_obstacle_indices(sim.position,175).size()})
					if sim.crashed or contacts>0 or field.reached_base(sim.position): break
				attempts.append({"origin":[at.x,at.y],"steer":steering,"ticks":sim.ticks,"crash":sim.crash_reason,"travelled_m":travelled,"obstacle_contacts":contacts})
				if sim.crashed or sim.ticks!=1800 or travelled<35 or contacts>0: continue
				var data={"identity":Trace.identity(field),"input_fields":Trace.Inputs.FIELDS,"seed":849205174,"face":3,"heading":heading,
					"scenario_origin":[at.x,at.y],"command_ticks":12,"commands":commands,"initial_state":initial,"checkpoints":checkpoints,
					"coverage":coverage,"travelled_m":travelled,"obstacle_contacts":contacts,"producer_sha256":FileAccess.get_sha256("res://tests/terrain_grass_trace.gd"),
					"result":{"side":0,"ticks":sim.ticks,"seconds":15,"finished":false,"crash":"","position":[sim.position.x,sim.position.y,sim.position.z]}}
				FileAccess.open(output+"/"+habitat+".json",FileAccess.WRITE).store_string(JSON.stringify(Trace.Inputs.storage(data),"",true,true))
				print("GRASS_TRACE ",habitat," ",JSON.stringify(attempts[-1]))
				accepted=true; break
			if accepted: break
		FileAccess.open(output+"/"+habitat+"_attempts.json",FileAccess.WRITE).store_string(JSON.stringify(attempts))
		if not accepted: printerr("No successful ordinary trace for ",habitat); quit(1); return
	quit()
