extends SceneTree
## Bounded ordinary-input routes, refreshed by actual solver replay after generation changes.
const Trace=preload("res://tests/performance_trace.gd")
const Definition=preload("res://scripts/world/mountain_definition.gd")
const OUT="res://artifacts/natural_openings_20260917"
var baseline=false
var last_failure={}
func _initialize()->void:run.call_deferred()
func run()->void:
	baseline="--baseline" in OS.get_cmdline_user_args()
	var habitats=["lower","upper","mixed"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--habitat="):
			var habitat=arg.get_slice("=",1)
			assert(habitat in habitats)
			habitats=[habitat]
	var field=Definition.Cache.generate(Definition.DEFAULT_SEED)
	if field==null:quit(2);return
	field.build_material_map()
	var surface=preload("res://scripts/world/prop_collision_surface.gd").new(field)
	var output=OUT+("/old_traces" if baseline else "/new_traces")
	DirAccess.make_dir_recursive_absolute(output)
	for habitat in habitats:
		var source=OUT+"/old_traces/"+habitat+".json"
		if baseline and habitat=="lower":source="res://artifacts/collision_heightfield_20260917/forest.json"
		var accepted={}
		if not baseline or habitat=="lower":
			var old=JSON.parse_string(FileAccess.get_file_as_string(source))
			assert(Trace.Inputs.expand(old).is_empty())
			accepted=ride(field,surface,Vector2(old.scenario_origin[0],old.scenario_origin[1]),old.heading,old.commands,int(old.command_ticks))
			var preserved_inputs=true
			var preserved_failure=last_failure.duplicate(true)
			if accepted.is_empty() and not baseline:
				# A new physical world may place a trunk in the old input path. Generate
				# actual ordinary controls through the same area; never relabel old states.
				preserved_inputs=false
				for offset in [Vector2.ZERO,Vector2(8,0),Vector2(-8,0),Vector2(0,8),Vector2(0,-8)]:
					accepted=ride(field,surface,Vector2(old.scenario_origin[0],old.scenario_origin[1])+offset,old.heading)
					if not accepted.is_empty():break
			if not accepted.is_empty():
				accepted.presentation=old.presentation
				accepted.comparison={"source":source,"inputs_preserved":preserved_inputs,"old_origin":old.scenario_origin,"preserved_input_failure":preserved_failure,"old_endpoint":old.result.position,"endpoint_delta_m":Vector3(old.result.position[0],old.result.position[1],old.result.position[2]).distance_to(Vector3(accepted.result.position[0],accepted.result.position[1],accepted.result.position[2]))}
		else:
			var warm=preload("res://scripts/presentation/forest_placement.gd").warm_noise(field.seed_value)
			var candidates=[]
			for z in range(-2400,2401,48):
				for x in range(-2400,2401,48):
					var h:float=field.height_at(x,z)
					if habitat=="upper" and (h<3380 or h>3480):continue
					if habitat=="mixed" and (h<2600 or h>2900 or warm.get_noise_2d(x,z)<.18):continue
					var p=Vector3(x,h,z);var normal:Vector3=field.contact_normal(x,z)
					if normal.y<.85 or field.rock_fraction_at(x,z)>.15 or not field.geology.clear(p,4):continue
					var count:int=field.tree_data.nearby(p,175).size()
					if count<(15 if habitat=="upper" else 250) or not field.tree_data.nearby(p,5).is_empty():continue
					candidates.append({"position":Vector2(x,z),"score":absf(h-3430) if habitat=="upper" else -warm.get_noise_2d(x,z)})
			candidates.sort_custom(func(a,b):return a.score<b.score)
			var attempts=0
			for candidate in candidates.slice(0,12):
				var p:Vector2=candidate.position
				var downhill=Vector3.DOWN.slide(field.contact_normal(p.x,p.y))
				for offset in [0.0,-.25,.25]:
					attempts+=1
					accepted=ride(field,surface,p,atan2(downhill.x,downhill.z)+offset)
					if not accepted.is_empty():break
				if not accepted.is_empty():break
			print("FOREST_ROUTE_SEARCH ",habitat," attempts=",attempts)
		if accepted.is_empty():printerr("No complete contact-free route for ",habitat);quit(1);return
		accepted.habitat=habitat
		assert(Trace.preflight_error(accepted,Definition.CURRENT_VERSION,false).is_empty())
		FileAccess.open(output+"/"+habitat+".json",FileAccess.WRITE).store_string(JSON.stringify(Trace.Inputs.storage(accepted)))
		print("FOREST_ROUTE ",habitat," ",JSON.stringify({"origin":accepted.scenario_origin,"result":accepted.result,"travelled_m":accepted.travelled_m,"coverage":accepted.coverage,"comparison":accepted.get("comparison",{})}))
	quit()
func ride(field,surface,at:Vector2,heading:float,preserved:Array=[],interval:int=12)->Dictionary:
	last_failure={}
	var sim=Trace.Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
	sim.reset(Vector3(at.x,field.height_at(at.x,at.y),at.y),heading);sim.prime_contacts(surface)
	var initial=Trace.Inputs.state(sim);var commands=[];var checkpoints=[];var coverage=[];var travelled=0.0
	var face=field.adjacent_faces(at)[0]
	var a:Vector2=face.to_local(at);var b:Vector2=face.to_local(at+Vector2(sin(heading),cos(heading))*500)
	var path=[[a.x,a.y],[b.x,b.y]];var command=RiderInput.new()
	for tick in 1800:
		if tick%interval==0:
			command=Trace.Inputs.decode(preserved[tick/interval]) if not preserved.is_empty() else Trace.Pilot.intent(sim,field,face.index,path)
			commands.append(Trace.Inputs.encode(command))
		var before=sim.position;sim.step(1.0/120,command,surface);travelled+=sim.position.distance_to(before)
		if sim.crashed or not sim.obstacle_contact.is_empty():
			last_failure={"tick":sim.ticks,"crash":sim.crash_reason,"position":str(sim.position),"obstacle_contact":str(sim.obstacle_contact)}
			return {}
		if sim.ticks%120==0:
			checkpoints.append(Trace.Inputs.state(sim))
			coverage.append({"tick":sim.ticks,"position":[sim.position.x,sim.position.y,sim.position.z],"trees_175m":field.tree_data.nearby(sim.position,175).size(),"speed_kmh":sim.speed_kmh()})
	if travelled<35:last_failure={"travelled_m":travelled};return {}
	var settings=preload("res://scripts/presentation/camera_settings.gd").new()
	preload("res://tests/scenery_camera.gd").configure(settings)
	return {"identity":Trace.identity(field),"seed":field.seed_value,"face":face.index,"heading":heading,"scenario_origin":[at.x,at.y],"input_fields":Trace.Inputs.FIELDS,"commands":commands,"command_ticks":interval,"initial_state":initial,"checkpoints":checkpoints,"coverage":coverage,"travelled_m":travelled,"obstacle_contacts":0,"presentation":{"camera":settings.snapshot(),"camera_effects_enabled":true},"result":{"side":0,"ticks":1800,"seconds":15,"finished":false,"crash":"","position":[sim.position.x,sim.position.y,sim.position.z]}}
