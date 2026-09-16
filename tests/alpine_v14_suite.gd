extends SceneTree
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Terrain = preload("res://scripts/world/generators/alpine_massif_v14.gd")
const Survey = preload("res://tests/alpine_v13_route_survey.gd")
const OUTPUT = "res://artifacts/planted_snow"
var checks = 0
var failures: Array = []
var report = {"unranked":true}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func run() -> void:
	var args = OS.get_cmdline_user_args()
	var seed_value = 849205174
	for arg in args:
		if arg.begins_with("--seed="): seed_value = int(arg.trim_prefix("--seed="))
	var field = Definition.generate(seed_value,14)
	report.seed = seed_value; report.height_sha256 = field.height_checksum; report.obstacle_sha256 = field.obstacle_checksum
	report.exposure_sha256 = Terrain._digest(field.exposure_image.get_data())
	report.generation_ms = field.generation_ms; report.cache_hit = field.cache_hit; report.stages = field.generation_stages
	report.tree_snow = field.tree_snow_statistics
	report.snow_revision = field.SNOW_REVISION
	print("V14_BAKED ",seed_value," ",field.height_checksum," cache=",field.cache_hit)
	check(Definition.CURRENT_VERSION==14 and Definition.parse_seed(str(seed_value)).version==14,"Default and bare seeds select v14")
	check(Definition.parse_seed("%d / v13"%seed_value).version==13,"Explicit v13 recipes remain available")
	check(field.heights.size()==1537*1537,"One authoritative 4 m support grid")
	check(field.faces.size()==6,"Six original mountain faces")
	var forms: Array = []
	for face in field.faces:
		var kinds = [0,0,0]; var active = [0,0,0]
		for form in face.snow_forms:
			kinds[form.kind] += 1
			if face.snow_relief_weight(form.position.x,form.position.y)>.15: active[form.kind] += 1
		check(kinds==[96,100,32],"Bounded varied snow formations on face %d"%face.index)
		check(active[0]>0 and active[1]>0 and active[2]>0,"Waves, mounds and banks survive terrain fades on face %d"%face.index)
		forms.append({"face":face.index,"counts":kinds,"active":active})
	report.forms = forms
	var bad_seats = 0
	for ob in field.obstacles:
		if ob.tree and absf(ob.position.y-field.sample(ob.position.x,ob.position.z).height)>.002: bad_seats += 1
	check(bad_seats==0,"Trees seated on final snow support")
	report.trees = field.obstacles.filter(func(ob): return ob.tree).size(); report.obstacles = field.obstacles.size()
	var identity = Definition.from_field(field,"Default Mountain")
	check(Definition.decode(identity.share_text()).get("error","").is_empty(),"V14 recipe round trip")
	if seed_value==849205174:
		preload("res://tests/test_report.gd").write("res://examples/mountains/alpine-v14.apexmountain",identity.share_text())
	if "--routes" in args:
		var routes: Array = []
		for face in 6:
			var route = Survey.survey(field,face)
			var exits: Array = route.paths
			check(not exits[0].is_empty() and not exits[1].is_empty(),"Two reachable snow exits on face %d"%face)
			if not exits[0].is_empty() and not exits[1].is_empty(): check(exits[0][-1].distance_to(exits[1][-1])>=500,"Separated exits on face %d"%face)
			routes.append(route)
			print("V14_ROUTE ",face," lengths=",[exits[0].size(),exits[1].size()])
		report.routes = routes
	var expected_height: String = field.height_checksum; var expected_obstacles: String = field.obstacle_checksum
	field = null
	var warm = Definition.generate(seed_value,14)
	check(warm.cache_hit and warm.height_checksum==expected_height and warm.obstacle_checksum==expected_obstacles,"Validated cache reconstructs exact v14")
	check(Terrain._digest(warm.exposure_image.get_data())==report.exposure_sha256,"Validated cache reconstructs the same physical snow and rock mask")
	report.warm_ms = warm.generation_ms; warm = null
	if "--repeat" in args:
		var repeated = Terrain.new(seed_value)
		check(repeated.height_checksum==expected_height and repeated.obstacle_checksum==expected_obstacles,"Independent cold generation is deterministic")
		check(Terrain._digest(repeated.exposure_image.get_data())==report.exposure_sha256,"Independent cold generation repeats final snow and rock materials")
		report.repeat_ms = repeated.generation_ms; repeated = null
	if seed_value==849205174:
		var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"/baseline/mountain.json"))
		var previous = Definition.generate(seed_value,13)
		check(previous.height_checksum==baseline.height_sha256 and previous.obstacle_checksum==baseline.obstacle_sha256,"Archived v13 terrain and obstacles unchanged")
		check(previous.height_checksum!=expected_height,"New physical snow has its own terrain identity")
	report.checks = checks; report.failures = failures
	preload("res://tests/test_report.gd").write(OUTPUT+"/v14_%d.json"%seed_value,JSON.stringify(report,"\t"))
	print("V14_COMPLETE checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
