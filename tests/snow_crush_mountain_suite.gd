extends SceneTree
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Probe = preload("res://tests/planted_snow_probe.gd")
const Sim = preload("res://scripts/core/ski_simulation.gd")
const OUTPUT = "res://artifacts/snow_crush_v26/mountain.json"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var field = Definition.generate(849205174,Definition.CURRENT_VERSION)
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/planted_snow_v22.json")).fixtures
	var chosen: Array = []; var failures: Array = []; var attempts = 0
	for original in fixtures:
		if chosen.size()>=2: break
		var p = Vector3(original.origin[0],0,original.origin[2])
		var found = false
		for along in [-40.0,0.0,40.0,80.0]:
			if found: break
			for side in [0.0,-24.0,24.0,-48.0,48.0]:
				var q = p+Vector3(side,0,along)
				if field.rock_fraction_at(q.x,q.z)>.1: continue
				var n: Vector3 = field.contact_normal(q.x,q.z)
				if n.y<.75: continue
				var fixture = {"name":"snowbank_"+str(chosen.size()),"origin":[q.x,field.sample(q.x,q.z).height,q.z],"heading":atan2(n.x,n.z),"kmh":160.0,"seconds":2.5,"input":"glide","steer":0.0}
				attempts += 1
				var after = Probe.measure(Sim,field,fixture)
				if not after.crash.is_empty() or after.rock_s>0 or after.peak_crush_m<.03 or after.airtime_s>.10 or after.exit_kmh<90.0: continue
				var before = Probe.measure(Sim,field,fixture,{"snow_crush_max_m":0.0})
				if not before.crash.is_empty() or before.rock_s>0 or before.exit_kmh<90.0: continue
				if after.reach_m>.281 or after.foot_error_m>.002 or after.unsupported_grip_n!=0 or after.min_load_n<0: failures.append("Contact bounds: "+fixture.name)
				chosen.append({"fixture":fixture,"before":before,"after":after})
				print("CRUSH_MOUNTAIN_FIXTURE ",JSON.stringify(fixture)," air before/after=",before.airtime_s,"/",after.airtime_s)
				found = true; break
	if chosen.size()<2: failures.append("Could not find two clear real-terrain crushing fixtures")
	DirAccess.make_dir_recursive_absolute("res://artifacts/snow_crush_v26")
	FileAccess.open(OUTPUT,FileAccess.WRITE).store_string(JSON.stringify({"model":Sim.MODEL_VERSION,"version":14,"seed":849205174,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"selection_attempts":attempts,"cases":chosen,"failures":failures},"\t"))
	print("CRUSH_MOUNTAIN failures=",failures)
	quit(0 if failures.is_empty() else 1)
