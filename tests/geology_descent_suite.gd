extends SceneTree
## Full default-face routes through the same v11 contact adapter used by the game.
const Terrain=preload("res://scripts/world/generators/alpine_massif_v11.gd")
const Pilot=preload("res://tests/massif_pilot.gd")
var failures: Array=[]
var results: Array=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var data: Dictionary=FileAccess.open("res://artifacts/geology_v11/field_849205174.bin",FileAccess.READ).get_var(false)
	var field=Terrain.new(849205174,false)
	field.heights=data.heights
	field.exposure_image=Image.create_from_data(field.NX,field.NZ,false,Image.FORMAT_RGBA8,data.exposure)
	field.build_material_map()
	for ob in data.obstacles: field.add_obstacle(ob)
	field.geology.restore(data.placements,data.stats)
	var adapter=preload("res://scripts/world/prop_collision_surface.gd").new(field)
	for face in field.faces:
		print("GEOLOGY_DESCENT_START ",face.index)
		var sim=preload("res://scripts/core/ski_simulation.gd").new(preload("res://config/ski_default.tres").duplicate(true))
		sim.reset(field.launch_point(face.heading),face.heading)
		sim.prime_contacts(adapter)
		var ticks=0
		var intent=RiderInput.new()
		for i in 100000:
			ticks=i+1
			if i%12==0: intent=Pilot.intent(sim,field,face.index,-1)
			sim.step(1.0/120,intent,adapter)
			if sim.crashed or field.reached_base(sim.position): break
		var result={"face":face.index,"finished":field.reached_base(sim.position),"crash":sim.crash_reason,
			"seconds":ticks/120.0,"peak_kmh":sim.peak_speed*3.6,"position":str(sim.position),"unranked":true}
		results.append(result)
		if sim.crashed or not result.finished: failures.append(result)
		print("GEOLOGY_DESCENT ",JSON.stringify(result))
	preload("res://tests/test_report.gd").write("res://artifacts/geology_v11/descents.json",JSON.stringify({"pilot_version":Pilot.VERSION,"failures":failures,"results":results,"height_sha256":data.height_sha256,"obstacle_sha256":data.obstacle_sha256,"collision_catalog_sha256":field.geology.catalog.fingerprint},"\t"))
	quit(0 if failures.is_empty() else 1)
