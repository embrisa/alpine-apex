extends SceneTree
const Probe = preload("res://tests/planted_snow_probe.gd")
const Sim = preload("res://artifacts/planted_snow/baseline/core/ski_simulation.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const OUTPUT = "res://artifacts/planted_snow/baseline"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var field = Definition.generate(849205174,13)
	var fixtures: Array = []; var rejected: Array = []
	if FileAccess.file_exists(OUTPUT+"/mountain.json"):
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"/mountain.json"))
		fixtures = saved.fixtures; rejected = saved.rejected
	# Lock selection using ONLY v22. First clean candidate in each elevation band,
	# independent of whether it favors the later response. Both sides of every face.
	for face in field.faces:
		for band in 3:
			if fixtures.any(func(f): return f.face==face.index and f.band==band): continue
			var found = false
			for z in [[560.0,720.0,880.0],[1180.0,1350.0,1530.0,1010.0,1100.0,1270.0,1440.0,1620.0,1710.0],[1850.0,2090.0,2330.0]][band]:
				for offset in [-.25,.25,-.12,.12,0.0,-.4,.4,-.32,.32,-.06,.06]:
					var p: Vector2 = face.to_world(Vector2(z*offset,z))
					var fixture = {"name":"face_%d_band_%d" % [face.index,band],"face":face.index,"band":band,"origin":[p.x,field.sample(p.x,p.y).height,p.y],"heading":face.heading+(.22 if band==1 else 0.0),"kmh":160.0 if band==0 else 120.0,"seconds":6.0,"input":"glide" if band==2 else "ripple","steer":.15}
					var row = Probe.measure(Sim,field,fixture)
					if row.crash.is_empty() and row.rock_s==0.0:
						fixture.baseline = row; fixtures.append(fixture); found = true
						print("FROZEN ",fixture.name," short=",row.short_events," air=",row.airtime_s)
						break
					else: rejected.append({"fixture":fixture,"crash":row.crash,"rock_s":row.rock_s})
				if found: break
			if not found: printerr("NO FIXTURE face ",face.index," band ",band)
	var report = {"model":Sim.MODEL_VERSION,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"fixtures":fixtures,"rejected":rejected,"cache_hit":field.cache_hit,"unranked":true}
	preload("res://tests/test_report.gd").write(OUTPUT+"/mountain.json",JSON.stringify(report,"\t"))
	print("BASELINE_COMPLETE fixtures=",fixtures.size())
	quit(0 if fixtures.size()==18 else 1)
