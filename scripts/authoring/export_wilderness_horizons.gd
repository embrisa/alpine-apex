extends SceneTree
## Explicit offline extraction of actual rendered geometry; never rebuilds it.
func _initialize() -> void:
	var asset = load("res://assets/graphics/scenery/alpine_valleys_01.res")
	assert(asset.presentation_version==3)
	var out = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out=arg.get_slice("=",1)
	assert(not out.is_empty(),"Specify an explicit --output directory")
	DirAccess.make_dir_recursive_absolute(out)
	var metadata = {"asset_id":asset.asset_id,"presentation_version":asset.presentation_version,"footprint_revision":asset.metadata.footprint_revision,"cell_m":32.0,"apron_origin":[-4128,-4128],"apron_side":259,"tiers":[],"source":"assets/graphics/scenery/alpine_valleys_01.res"}
	FileAccess.open(out+"/apron.f32",FileAccess.WRITE).store_buffer(asset.apron_heights.to_byte_array())
	for tier in 3:
		var vertices = PackedVector3Array(); var indices = PackedInt32Array()
		for arrays in asset.levels[tier].terrain:
			var offset = vertices.size()
			vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
			for index in arrays[Mesh.ARRAY_INDEX]: indices.append(index+offset)
		var raw = vertices.to_byte_array(); assert(raw.size()==vertices.size()*12)
		FileAccess.open(out+"/vertices_%d.f32" % tier,FileAccess.WRITE).store_buffer(raw)
		FileAccess.open(out+"/indices_%d.i32" % tier,FileAccess.WRITE).store_buffer(indices.to_byte_array())
		metadata.tiers.append({"vertices":vertices.size(),"triangles":indices.size()/3})
	FileAccess.open(out+"/metadata.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"\t"))
	print("HORIZON_SOURCE ",JSON.stringify(metadata)); quit()
