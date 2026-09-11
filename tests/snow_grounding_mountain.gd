extends SceneTree
## Current v15 terrain, frozen model 27, actual obstacles and equal tick inputs.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Probe = preload("res://tests/planted_snow_probe.gd")
const Sim = preload("res://scripts/core/ski_simulation.gd")
const OUTPUT = "res://artifacts/snow_grounding_v28"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var sources = source_hashes()
	var field = Definition.generate(849205174,15)
	var original: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/planted_snow_v22.json")).fixtures
	var baseline = load(OUTPUT+"/baseline/core/ski_simulation.gd")
	var rows: Array = []; var chosen: Array = []; var failures: Array = []
	for entry in original:
		var p = Vector3(entry.origin[0],0,entry.origin[2])
		var n: Vector3 = field.contact_normal(p.x,p.z)
		var fixture = {"name":entry.name,"origin":[p.x,field.sample(p.x,p.z).height,p.z],"heading":atan2(n.x,n.z),"kmh":160.0,"seconds":6.0,"input":"glide","steer":0.0}
		var before = Probe.measure(baseline,field,fixture)
		var after = Probe.measure(Sim,field,fixture)
		var row = {"fixture":fixture,"before":before,"after":after}
		rows.append(row)
		if after.reach_m>.281 or after.foot_error_m>.002 or after.unsupported_grip_n!=0 or after.min_load_n<0: failures.append("Contact bounds: "+fixture.name)
		# Select illustrations from baseline behavior, before judging the new
		# handling. Never hide a new crash or choose only cases that hit a target.
		if before.crash.is_empty() and before.rock_s==0 and before.airtime_s>.10:
			chosen.append(row)
		print("SNOW_MOUNTAIN ",fixture.name," air before/after=",before.airtime_s,"/",after.airtime_s," crashes=",before.crash,"/",after.crash)
	if chosen.size()<2: failures.append("Fewer than two baseline snow crossings exercise unwanted air")
	if sources!=source_hashes(): failures.append("Source changed during mountain comparison")
	var report = {"model":Sim.MODEL_VERSION,"baseline_model":baseline.MODEL_VERSION,"generator":15,"seed":849205174,"settings":field.generation_settings,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"sources":sources,"rows":rows,"render_cases":chosen.slice(0,3),"render_selection":"First three baseline crossings with no crash/rock and more than 0.1 s airtime; independent of candidate results","failures":failures,"unranked":true}
	FileAccess.open(OUTPUT+"/mountain.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SNOW_MOUNTAIN_COMPLETE rows=",rows.size()," render candidates=",chosen.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)

static func source_hashes() -> Dictionary:
	var result = {}
	for path in ["scripts/core/ski_simulation.gd","scripts/core/ski_contact.gd","scripts/core/snow_contact_assist.gd","scripts/core/snow_contact_response.gd","scripts/core/snow_crush_contact.gd","scripts/core/ski_tuning.gd","scripts/core/rider_body.gd","config/ski_default.tres","tests/planted_snow_probe.gd","tests/snow_grounding_mountain.gd"]:
		result[path] = FileAccess.get_sha256("res://"+path)
	return result
