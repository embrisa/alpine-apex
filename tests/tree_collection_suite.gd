extends SceneTree
const Assets = preload("res://scripts/presentation/alpine_assets.gd")
const Lighting = preload("res://scripts/presentation/cloud_lighting.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var checks=0
var failures: Array=[]
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func _initialize() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/trees/manifest.json"))
	var assets=Assets.new(Lighting.new(),Quality.preset(2))
	check(manifest.assets.size()==30,"24 preserved trees plus six colorful variants")
	for family in manifest.families:
		check(manifest.assets.filter(func(a): return a.family==family).size()==(3 if family in ["golden","maple"] else 4),"Catalog variants for "+family)
	for record in manifest.assets:
		var previous=0
		for lod in 3:
			var mesh: Mesh=assets.mesh(record.id+"_lod%d" % lod)
			var triangles=mesh.get_faces().size()/3
			check(mesh.get_surface_count()==1,record.id+" one surface")
			check(triangles==int(record.models[lod].triangles),record.id+" exported triangle count")
			check(mesh.surface_get_material(0) is ShaderMaterial,record.id+" production shader")
			if lod<2:
				var living=record.family in ["spruce","fir","pine","golden","maple"]
				check(triangles<=([30000,8000 if record.has("foliage_type") else 6000][lod] if living else 140000),record.id+" authored visible budget")
				var array=mesh.surface_get_arrays(0)
				var positions: PackedVector3Array=array[Mesh.ARRAY_VERTEX]
				var colors: PackedColorArray=array[Mesh.ARRAY_COLOR]
				var pivots: PackedVector2Array=array[Mesh.ARRAY_TEX_UV2]
				var has_foliage=false
				var valid=true
				var radius=0.0
				var bark_positions: Dictionary={}
				var fracture_positions: Dictionary={}
				for i in positions.size():
					valid=valid and positions[i].is_finite() and pivots[i].x>=-.001 and pivots[i].x<.69 and pivots[i].y>=0 and pivots[i].y<=1
					has_foliage=has_foliage or (colors[i].a>.5 and colors[i].a<.8)
					if positions[i].y<float(record.height_m)*.05: radius=maxf(radius,Vector2(positions[i].x,positions[i].z).length()*10.5/float(record.height_m))
					if record.family=="broken" and lod==0:
						var key=Vector3i((positions[i]*10000.0).round())
						if colors[i].a>.25 and colors[i].a<.36: fracture_positions[key]=true
						else: bark_positions[key]=true
				check(valid,record.id+" finite geometry and branch tags")
				check(has_foliage==(record.family in ["spruce","fir","pine","golden","maple"]),record.id+" living / bare material separation")
				check(radius<=.48,record.id+" normalized trunk collision envelope")
				check(absf(mesh.get_aabb().size.y-float(record.models[lod].dimensions_blender_xyz_m[2]))<.015,record.id+" actual LOD height metadata")
				if lod==1: check(triangles<previous*.65,record.id+" lower mid-detail budget")
				if record.family=="broken" and lod==0:
					check(fracture_positions.size()>=7,record.id+" irregular fracture boundary")
					var joined=0
					for p in fracture_positions:
						if bark_positions.has(p): joined+=1
					check(joined>=fracture_positions.size()-1,record.id+" exposed wood shares trunk boundary without an added stub")
			else: check(triangles==2,record.id+" two-triangle far atlas")
			previous=triangles
		check(record.branches.size()==12,record.id+" twelve branch regions")
	var before=assets.lighting.materials.size()
	for level in [0,1,2]: assets.apply_quality(Quality.preset(level))
	check(before==assets.lighting.materials.size(),"Quality changes reuse shared materials")
	var scenery=load("res://scripts/world/alpine_scenery.gd").new()
	scenery.assets=assets
	for lod in 3: scenery._batch(assets.mesh("forest_spruce_01_lod%d" % lod),[Transform3D.IDENTITY],lod)
	scenery._batch(assets.tree_shadow("forest_spruce_01"),[Transform3D.IDENTITY],5)
	for level in 3:
		scenery.apply_quality(Quality.preset(level))
		var ranges: Array=[]
		for batch in scenery.batches:
			check(batch.get_meta("forest_tree"),"Collection LOD routing includes the far atlas")
			ranges.append(batch.get_instance_shader_parameter("pc_lod_ranges"))
		check(ranges[0].y==ranges[1].x and ranges[1].y==ranges[2].x,"Complementary collection LOD boundaries remain contiguous")
		check(ranges[0].y<ranges[1].y and ranges[1].y<ranges[2].y,"Collection quality ranges remain ordered")
		check(ranges[3].y<ranges[1].y,"Shadow geometry stays inside detailed forest range")
	scenery.free()
	var result={"checks":checks,"failures":failures,"assets":manifest.assets.size()}
	DirAccess.make_dir_recursive_absolute("res://artifacts/trees_v2")
	FileAccess.open("res://artifacts/trees_v2/godot_validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("TREE_COLLECTION_RESULTS ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
