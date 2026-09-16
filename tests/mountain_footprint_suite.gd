extends SceneTree
const Footprint = preload("res://scripts/world/mountain_footprint.gd")
const Terrain = preload("res://scripts/world/terrain_preparation.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Zone = preload("res://scripts/world/mountain_zone.gd")
var checks=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
func run() -> void:
	var field=Definition.generate(849205174,15)
	var zone=Zone.new(field)
	var riding_retained=true; var minimum_margin=INF
	for i in 3600:
		var p=Vector2.from_angle(TAU*i/3600.0)*zone.radius_m
		riding_retained=riding_retained and Footprint.owns_cell(p)
		minimum_margin=minf(minimum_margin,Footprint.radius(p)-p.length()-24.0)
	check(riding_retained and minimum_margin>80,"Every summit-return bearing retains the physical support grid plus a guard margin")
	check(not Footprint.owns_cell(Vector2(3000,3000)) and not Footprint.owns_cell(Vector2(-3000,-3000)),"Unused square corners are omitted")
	var job=preload("res://scripts/world/generation_job.gd").new()
	var terrain=Terrain.new(); terrain.build(field,job)
	var triangles=0; var partial=0; var indexed_support=true
	for chunk in terrain.chunks:
		var indices: PackedInt32Array=chunk.get("indices",terrain.indices)
		triangles+=indices.size()/3
		if chunk.has("indices"):
			partial+=1
			indexed_support=indexed_support and chunk.lods.is_empty()
			for index in indices:
				var v: Vector3=chunk.vertices[index]
				indexed_support=indexed_support and absf(v.y-field.sample(v.x,v.z).height)<.001
	check(triangles>3000000 and triangles<4000000 and terrain.chunks.size()<576,"Trimming reduces terrain triangles and submitted sections")
	check(partial>0 and indexed_support,"Partial perimeter chunks retain exact 4 m support and seam vertices")
	check(field.height_checksum=="e12569ae88d5c3c564e66ad6e3e5ed3744baa71398a914db6c954c6eba24e40e" and field.obstacle_checksum=="b84df994471e299e83aebbb114ad3d156f6f6a0306dbf44d8f8e08824c0d4159","Physical v15 heights and obstacle fingerprints remain unchanged")
	var reference=Definition.from_field(field).to_reference()
	check(reference.scenery_version==3 and reference.version==15,"Mountain identity advances scenery independently of the physical generator")
	var legacy=reference.duplicate(); legacy.scenery_version=2
	check(not Definition.reference_error(legacy).is_empty(),"Old scenery identities are rejected instead of mixed into current maps")
	var preview=preload("res://scripts/ui/mountain_preview.gd").build_image(field)
	check(preview.get_pixel(0,0).a==0 and preview.get_pixel(preview.get_width()/2,preview.get_height()/2).a==1,"Map preview omits cut corners and retains an opaque summit")
	var result={"checks":checks,"failures":failures,"triangles":triangles,"chunks":terrain.chunks.size(),"partial_chunks":partial,"minimum_playable_guard_m":minimum_margin}
	preload("res://tests/test_report.gd").write("res://artifacts/offmap_v3/footprint.json",JSON.stringify(result,"\t"))
	print("FOOTPRINT_RESULTS ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
