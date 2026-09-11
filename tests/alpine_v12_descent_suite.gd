extends SceneTree
const Cache = preload("res://scripts/world/mountain_cache_v12.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Pilot = preload("res://tests/alpine_v12_pilot.gd")
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var field = Cache.generate(849205174)
	field.build_material_map()
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/alpine_v12/survey_849205174.json"))
	if data==null or data.height_sha256!=field.height_checksum or data.obstacle_sha256!=field.obstacle_checksum:
		printerr("Run the v12 generation suite on this source before the descent suite."); quit(1); return
	var reports: Array = []
	var faces: Array = range(6) if "--all-faces" in OS.get_cmdline_user_args() else [0,3]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--face="): faces = [clampi(int(arg.get_slice("=",1)),0,5)]
	for face_index in faces:
		for side in (1 if "--one-side" in OS.get_cmdline_user_args() else 2):
			var path: Array = data.surveys[face_index].paths[side]
			if path.is_empty(): failures.append("No surveyed path"); continue
			var face = field.faces[face_index]
			var sim = Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
			sim.reset(field.launch_point(face.heading),face.heading)
			sim.prime_contacts(field)
			var input = RiderInput.new()
			var ticks = 0
			for tick in 70000:
				if tick%12==0: input = Pilot.intent(sim,field,face_index,path)
				sim.step(Pilot.DT,input,field)
				ticks = tick+1
				if tick%6000==0: print("ALPINE_SKI_PROGRESS ",face_index," ",side," ",snappedf(Vector2(sim.position.x,sim.position.z).length(),1))
				if sim.crashed or field.reached_base(sim.position): break
			var result = {"face":face_index,"side":side,"finished":field.reached_base(sim.position),"crash":sim.crash_reason,"seconds":ticks*Pilot.DT,"peak_kmh":sim.peak_speed*3.6,"position":str(sim.position),"airtime_s":sim.total_airtime}
			reports.append(result)
			if not result.finished or sim.crashed: failures.append(result)
			print("ALPINE_SKI_RESULT ",JSON.stringify(result))
	FileAccess.open("res://artifacts/alpine_v12/descents.json",FileAccess.WRITE).store_string(JSON.stringify({"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"pilot_version":Pilot.VERSION,"runs":reports,"failures":failures,"unranked":true},"\t"))
	quit(0 if failures.is_empty() else 1)
