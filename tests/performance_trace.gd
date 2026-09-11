extends SceneTree
## Offline ordinary-input fixture. No presentation, records or solver changes.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Survey = preload("res://tests/alpine_v13_route_survey.gd")
const Pilot = preload("res://tests/alpine_v13_pilot.gd")
const OUTPUT = "res://artifacts/fps_optimization"
func _initialize() -> void: call_deferred("run")
static func identity(field) -> Dictionary:
	var sources = {}
	for folder in ["res://scripts/core", "res://scripts/world/generators"]:
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".gd"): sources[folder+"/"+file] = FileAccess.get_sha256(folder+"/"+file)
	for file in ["res://scripts/world/heightfield_surface.gd", "res://scripts/world/mountain_definition.gd", "res://config/ski_default.tres"]:
		sources[file] = FileAccess.get_sha256(file)
	return {"model":Simulation.MODEL_VERSION,"generator":field.GENERATOR_VERSION,"height":field.height_checksum,"obstacles":field.obstacle_checksum,"sources":sources}
static func matches(field, expected: Dictionary) -> bool:
	var current = identity(field)
	return int(expected.get("model",-1))==current.model and int(expected.get("generator",-1))==current.generator and expected.get("height")==current.height and expected.get("obstacles")==current.obstacles and expected.get("sources")==current.sources
func run() -> void:
	var version = Definition.CURRENT_VERSION
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var faces = [3,0,1,2,4,5]
	var trace_output = OUTPUT+"/descent_input.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--version="): version = int(arg.get_slice("=",1))
		if arg.begins_with("--face="): faces = [int(arg.get_slice("=",1))]
		if arg.begins_with("--trace-output="): trace_output = arg.get_slice("=",1)
	if not trace_output.ends_with(".json"):
		printerr("Trace output must be a .json path. Use --trace-output=artifacts/... with PowerShell; an inline res:// URI can be split at the colon.")
		quit(2); return
	if not trace_output.is_absolute_path(): trace_output = "res://"+trace_output
	print("TRACE_OUTPUT ",trace_output)
	var output_error = DirAccess.make_dir_recursive_absolute(trace_output.get_base_dir())
	if output_error!=OK: printerr("Cannot create trace directory: ",trace_output," error=",output_error); quit(2); return
	var field = Definition.generate(849205174,version)
	field.build_material_map()
	var attempts = []
	for face_index in faces:
		print("TRACE_SURVEY face=",face_index)
		var survey_path = OUTPUT+"/survey_%d.json" % face_index
		var survey
		if FileAccess.file_exists(survey_path):
			var saved = JSON.parse_string(FileAccess.get_file_as_string(survey_path))
			if matches(field,saved.identity): survey = saved.paths
		if survey==null:
			var result = Survey.survey(field,face_index)
			survey = []
			for path in result.paths: survey.append(path.map(func(p): return [p.x,p.y]))
			FileAccess.open(survey_path,FileAccess.WRITE).store_string(JSON.stringify({"identity":identity(field),"paths":survey}))
		for side in range(survey.size()):
			if survey[side].is_empty(): continue
			var sim = Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
			var heading: float = field.faces[face_index].heading
			sim.reset(field.launch_point(heading),heading); sim.prime_contacts(field)
			var commands = []
			var input = RiderInput.new()
			var ticks = 0
			for tick in 96000:
				if tick%12==0:
					input = Pilot.intent(sim,field,face_index,survey[side])
					commands.append([input.steer,input.tuck,input.brake,input.jump,input.jump_held,input.air_pitch,input.air_yaw,input.grab])
				sim.step(1.0/120,input,field); ticks+=1
				if tick%12000==0: print("TRACE_PROGRESS face=",face_index," side=",side," tick=",tick," radius=",Vector2(sim.position.x,sim.position.z).length())
				if sim.crashed or field.reached_base(sim.position): break
			var result = {"face":face_index,"side":side,"ticks":ticks,"seconds":ticks/120.0,"finished":field.reached_base(sim.position),"crash":sim.crash_reason,"position":[sim.position.x,sim.position.y,sim.position.z]}
			attempts.append(result)
			FileAccess.open(OUTPUT+"/trace_attempts.json",FileAccess.WRITE).store_string(JSON.stringify(attempts,"\t"))
			print("TRACE_RESULT ",JSON.stringify(result))
			if result.finished and not sim.crashed:
				var trace_file = FileAccess.open(trace_output,FileAccess.WRITE)
				if trace_file==null: printerr("Cannot write trace: ",trace_output," error=",FileAccess.get_open_error()); quit(2); return
				trace_file.store_string(JSON.stringify({"identity":identity(field),"seed":849205174,"face":face_index,"heading":heading,"command_ticks":12,"commands":commands,"result":result}))
				quit(0); return
	quit(1)
