extends SceneTree
## Offline ordinary-input fixture. No presentation, records or solver changes.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Survey = preload("res://tests/alpine_v13_route_survey.gd")
const Pilot = preload("res://tests/alpine_v13_pilot.gd")
const Inputs = preload("res://tests/performance_input.gd")
const OUTPUT = "res://artifacts/fps_optimization"
func _initialize() -> void: call_deferred("run")
static func source_identity() -> Dictionary:
	var sources = {}
	for folder in ["res://scripts/core", "res://scripts/world/generators"]:
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".gd"): sources[folder+"/"+file] = FileAccess.get_sha256(folder+"/"+file)
	for file in ["res://scripts/world/heightfield_surface.gd", "res://scripts/world/mountain_definition.gd", "res://config/ski_default.tres"]:
		sources[file] = FileAccess.get_sha256(file)
	return sources
static func preflight_error(data, version: int, require_complete: bool = true) -> String:
	if not data is Dictionary: return "Input trace must be a JSON object"
	var decode_error = Inputs.expand(data)
	if not decode_error.is_empty(): return decode_error
	var expected = data.get("identity")
	if not expected is Dictionary: return "Input trace has no identity"
	if expected.get("sources") != source_identity() or int(expected.get("model",-1)) != Simulation.MODEL_VERSION or int(expected.get("generator",-1)) != version:
		return "Benchmark rejects stale input trace sources before mountain setup"
	var result = data.get("result")
	if not result is Dictionary or (require_complete and (result.get("finished") != true or result.get("crash") != "")):
		return "Benchmark requires a successful complete input trace"
	if not data.get("recording_error","").is_empty(): return "Recording has an unresolved capture error"
	if not data.get("commands") is Array or data.commands.is_empty(): return "Input trace has no commands"
	if data.get("input_fields")!=Inputs.FIELDS: return "Regenerate the trace with the current complete benchmark input format"
	var interval = data.get("command_ticks")
	if not (interval is float or interval is int) or not (float(interval)==1.0 or float(interval)==12.0) or not (result.get("ticks") is float or result.get("ticks") is int): return "Invalid input timing"
	if not is_finite(float(result.ticks)) or result.ticks!=floorf(result.ticks) or result.ticks<1 or result.ticks>96000 or data.commands.size()!=ceili(float(result.ticks)/data.command_ticks): return "Incomplete input coverage"
	for command in data.commands:
		if not Inputs.valid(command): return "Invalid benchmark input command"
	if data.has("camera_samples"):
		if not data.camera_samples is Array or data.camera_samples.size()!=data.commands.size(): return "Incomplete camera coverage"
		for sample in data.camera_samples:
			if not sample is Array or sample.size()!=4 or not sample[0] is bool: return "Invalid camera sample"
			for i in range(1,4):
				if not (sample[i] is int or sample[i] is float) or not is_finite(float(sample[i])): return "Invalid camera sample"
	if data.has("checkpoints"):
		if not data.checkpoints is Array: return "Invalid checkpoints"
		var previous_tick = 0
		for sample in data.checkpoints:
			if not sample is Array or sample.size()!=8: return "Invalid checkpoint"
			for value in sample:
				if not (value is int or value is float) or not is_finite(float(value)): return "Invalid checkpoint"
			if sample[0]<=previous_tick or sample[0]>result.ticks or sample[0]!=floorf(sample[0]): return "Invalid checkpoint tick"
			previous_tick = int(sample[0])
	return ""
static func identity(field) -> Dictionary:
	return {"model":Simulation.MODEL_VERSION,"generator":field.GENERATOR_VERSION,"height":field.height_checksum,"obstacles":field.obstacle_checksum,"sources":source_identity()}
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
	var field = preload("res://tests/validation_mountain.gd").load_standard() if version == 15 else Definition.generate(849205174,version)
	if field == null: quit(2); return
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
					commands.append(Inputs.encode(input))
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
				trace_file.store_string(JSON.stringify(Inputs.storage({"identity":identity(field),"input_fields":Inputs.FIELDS,"seed":849205174,"face":face_index,"heading":heading,"command_ticks":12,"commands":commands,"result":result}),"",true,true))
				quit(0); return
	quit(1)
