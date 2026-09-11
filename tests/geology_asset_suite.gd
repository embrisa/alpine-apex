extends SceneTree
const Catalog=preload("res://scripts/world/mineral_catalog.gd")
var failures: Array=[]
var checks=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr(label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/geology_v11")
	var catalog=Catalog.new()
	check(catalog.packed_data!=null,"Runtime catalog uses its source-validated packed resource")
	check(catalog.records.size()==120,"All 120 base assets have runtime records")
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/minerals_v3/manifest.json"))
	for source: Dictionary in original.assets:
		check(FileAccess.get_sha256("res://"+source.path)==source.sha256,"Source GLB preserved: "+source.asset)
		var row: Dictionary=catalog.records[source.asset]
		var mesh: ArrayMesh=load(row.mesh)
		check(mesh!=null,"Runtime mesh: "+source.asset)
		if mesh:
			check(mesh.surface_get_material(0)==null,"Mesh does not retain source textures")
			check(not mesh.get("_surfaces")[0].get("lods",{}).is_empty(),"Runtime LODs: "+source.asset)
			check(mesh.get_aabb().size.distance_to(row.size_m)<.01,"Metre bounds: "+source.asset)
		check(row.hull_points.size()>0 and row.hull_axes.size()==row.hull_points.size(),"Convex collision pieces: "+source.asset)
		for level in ["low","balanced","high"]:
			for channel in ["albedo","normal","roughness"]:
				var texture: Texture2D=load(row.textures[level][channel])
				check(texture!=null,"Runtime texture: %s/%s/%s" % [source.asset,level,channel])
				var config=ConfigFile.new()
				config.load(row.textures[level][channel]+".import")
				check(config.get_value("params","compress/mode",0)==2 and config.get_value("params","mipmaps/generate",false),"Compressed mipmaps: "+source.asset)
				if texture and level=="high" and channel=="normal": check(texture.get_width()==int(source.texture_sizes.normal),"High retains source normal resolution")
	check(FileAccess.get_sha256("res://art_source/blender/rock_generator.blend")==original.source_sha256,"Original Blender generator preserved")
	FileAccess.open("res://artifacts/geology_v11/assets.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"assets":catalog.records.size(),"collision_catalog_sha256":catalog.fingerprint},"\t"))
	print("GEOLOGY_ASSETS ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
