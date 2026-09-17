extends SceneTree
const Terrain=preload("res://scripts/world/generators/alpine_massif_v17.gd")
var failures=[]
var checks=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures.append(message);printerr("FAIL ",message)
func _initialize():call_deferred("run")
func run():
	var field=Terrain.new(849205174,false);field.job.worker_count=1
	var snow_count=0
	for face in field.faces:snow_count+=face.snow_forms.size()
	check(snow_count==Terrain.Settings.targets(field.generation_settings).snow_features,"Reported snow population matches the generated recipe")
	# Previously observed sharp joins: run the actual landform row producer,
	# including its channel/ridge composition, on four nine-vertex fixtures.
	var join_curvatures=[]
	# Compare known defects with their recorded original curvature; do not impose
	# one arbitrary flatness limit on both skiable hollows and rock shoulders.
	for fixture in [[Vector2(-1496,-560),13.752],[Vector2(-976,836),13.364],[Vector2(352,-1040),7.672],[Vector2(368,-1056),4.748]]:
		var point: Vector2=fixture[0]
		field.X_MIN=point.x-4;field.Z_MIN=point.y-4;field.NX=3;field.NZ=3
		var local_heights: PackedFloat32Array=field._landform_rows(0,3)
		var curvature=maxf(absf(local_heights[3]+local_heights[5]-2*local_heights[4]),absf(local_heights[1]+local_heights[7]-2*local_heights[4]))
		join_curvatures.append({"world":[point.x,point.y],"before_curvature_m":fixture[1],"current_curvature_m":curvature})
		check(curvature<float(fixture[1])*.7,"Confirmed sharp joins reduce four-metre curvature by at least 30 percent at "+str(point))
	# Fixed current-recipe bank. The full terrain authority is cropped to 320 m;
	# all sculpt, normal, material and support functions are production code.
	var review={"world":[84.2401962280273,831.026977539062]}
	field.X_MIN=-76;field.Z_MIN=672;field.NX=81;field.NZ=81
	field.heights=field._landform_rows(0,81)
	field._rebuild_surface("before_snow")
	var before: PackedFloat32Array=field.heights.duplicate()
	field._sculpt_snow()
	var additions: PackedFloat32Array=field._snow_added.duplicate()
	field._build_normals()
	field._rebuild_surface("before_trees",false)
	var final_material: PackedByteArray=field.material_image.get_data()
	var deposited=0;var max_add=0.0;var violations=0
	for i in before.size():
		var lift: float=field.heights[i]-before[i]
		check(is_finite(field.heights[i]) and lift>-.181 and lift<3.86,"Snow support remains finite and bounded")
		max_add=maxf(max_add,lift)
		if additions[i]>.35:
			deposited+=1
			if final_material[i]!=0:violations+=1
	check(deposited>40 and max_add>1.5,"General banks survive actual sculpt and exposure stages")
	check(violations==0,"Fresh substantial deposits remain snow after normals and exposure are rebuilt")
	check(field._snow_added.is_empty() and field._snow_input_material.is_empty(),"Transient sculpt inputs are released")
	var center=40*81+40
	var prominence=additions[center]-(additions[center-8]+additions[center+8]+additions[center-8*81]+additions[center+8*81])*.25
	check(prominence>.5,"Bank has local prominence above surrounding deposited snow")
	# Deliberately exposed normal stencil: new snow must not repaint its slopes
	# as bedrock, while an unrelated rock cell must retain its material.
	field.NX=7;field.NZ=7
	field._snow_added=PackedFloat32Array();field._snow_added.resize(49);field._snow_added[24]=.6
	field._snow_input_material=PackedByteArray();field._snow_input_material.resize(49);field._snow_input_material.fill(0)
	field.exposure_image=Image.create(7,7,false,Image.FORMAT_RGBA8);field.exposure_image.fill(Color(1,0,0,1))
	field._finish_snow_cover()
	check(field.exposure_image.get_pixel(3,3).r==0,"New snow covers its own cell")
	for point in [Vector2i(2,3),Vector2i(4,3),Vector2i(3,2),Vector2i(3,4)]:check(field.exposure_image.get_pixelv(point).r==0,"Changed snow normal stencil remains snow")
	check(field.exposure_image.get_pixel(0,0).r==1,"Unrelated exposed rock is preserved")
	var report={"scope":"Actual terrain sculpt/normal/exposure functions on a 320m local grid centered on the current recipe bank; no mineral/tree placement or full mountain bake.","world_bank":review.world,"join_curvatures":join_curvatures,"checks":checks,"failures":failures,"substantial_deposit_cells":deposited,"max_added_m":max_add,"center_prominence_over_32m_deposits_m":prominence,"snow_material_violations":violations}
	preload("res://tests/test_report.gd").write("res://artifacts/terrain_snow_banks/stages.json",JSON.stringify(report,"\t"))
	print("BANK_STAGES ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
