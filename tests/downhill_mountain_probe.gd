extends SceneTree
## Identical initial snow-section fixtures through the game's v11 contact adapter.
const ContactSuite=preload("res://tests/downhill_contact_suite.gd")
const Sim=preload("res://scripts/core/ski_simulation.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var reference=load("res://artifacts/handling_v15/reference/ski_simulation.gd")
	if reference==null: printerr("Capture the v14 reference core before running this A/B probe."); quit(2); return
	var field=preload("res://scripts/world/mountain_cache_v11.gd").generate(849205174)
	field.build_material_map()
	var surface=preload("res://scripts/world/prop_collision_surface.gd").new(field)
	var rows=[]
	for face in field.faces:
		for z in [800.0,2150.0]:
			var x: float = face.gully_x(z,-1) if z<1850 else face.glade_x(z,-1)
			var p: Vector2 = face.to_world(Vector2(x,z))
			for speed in [60.0,120.0,160.0]:
				var before=ContactSuite.measure(reference,surface,speed,3.0,0.0,{},Vector3(p.x,0,p.y),face.heading)
				var after=ContactSuite.measure(Sim,surface,speed,3.0,0.0,{},Vector3(p.x,0,p.y),face.heading)
				rows.append({"face":face.index,"section_m":z,"kmh":speed,"before":before,"after":after})
		print("MOUNTAIN_CONTACT_FACE ",face.index)
	preload("res://tests/test_report.gd").write("res://artifacts/handling_v15/mountain_contact.json",JSON.stringify({"seed":849205174,"generator":11,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"fixtures":rows,"unranked":true},"\t"))
	print("MOUNTAIN_CONTACT_PROBE_COMPLETE ",rows.size())
	quit()
