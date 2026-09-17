extends SceneTree
## Explicit packaging after export_wilderness_horizons.gd and the Python bake.
const Asset = preload("res://scripts/world/wilderness_horizon_asset.gd")
func _initialize() -> void:
	var input=""; var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="): input=arg.get_slice("=",1)
		if arg.begins_with("--output="): output=arg.get_slice("=",1)
	assert(not input.is_empty() and not output.is_empty(),"Explicit --input and --output required")
	DirAccess.make_dir_recursive_absolute(output)
	var source=load("res://assets/graphics/scenery/alpine_valleys_01.res")
	var manifest={"schema":1,"source":"assets/graphics/scenery/alpine_valleys_01.res","source_version":source.presentation_version,"asset_id":source.asset_id,"variants":[],"ownership":"Optional presentation only. No runtime bake or gameplay cache payload.","connector":"Exclude all occluders within 3900 m; receiver fade 3900-4300 m. Variable mountain cast shadows are deliberately omitted."}
	for tier in 3:
		for quality in [1,2]:
			var directory=input+"/t%d_q%d" % [tier,quality]
			var receipt=JSON.parse_string(FileAccess.get_file_as_string(directory+"/bake.json"))
			assert(receipt.schema==1 and receipt.geometry_tier==tier and receipt.quality==quality)
			var asset=Asset.new()
			asset.source_asset_id=receipt.source.asset_id; asset.source_version=int(receipt.source.presentation_version)
			asset.footprint_revision=int(receipt.source.footprint_revision)
			asset.geometry_tier=tier; asset.quality=quality; asset.size=int(receipt.size); asset.directions=int(receipt.directions)
			asset.provenance={"source":receipt.source.source,"mesh":receipt.source.tiers[tier],"producer":"scripts/authoring/bake_wilderness_horizons.py","height_bias_m":8.0,"excluded_radius_m":receipt.excluded_radius_m,"full_radius_m":receipt.receiver_full_radius_m,"extent_m":receipt.extent_m,"valid_texels":receipt.valid_texels,"max_angle_degrees":receipt.max_angle_degrees}
			var images: Array[Image]=[]
			for layer in asset.directions/4:
				var bytes=FileAccess.get_file_as_bytes(directory+"/angles_%d.rgba16f" % layer)
				assert(bytes.size()==asset.size*asset.size*8)
				images.append(Image.create_from_data(asset.size,asset.size,false,Image.FORMAT_RGBAH,bytes))
			# Retain CPU images explicitly. A headless Texture2DArray can report its
			# dimensions yet serialize no layer data through the dummy renderer.
			asset.layers=images
			assert(asset.valid_for(source,tier,quality))
			var name="%s_t%d_q%d.res" % [asset.source_asset_id,tier,quality]
			assert(ResourceSaver.save(asset,output+"/"+name,ResourceSaver.FLAG_COMPRESS)==OK)
			var reloaded=ResourceLoader.load(output+"/"+name,"",ResourceLoader.CACHE_MODE_IGNORE)
			assert(reloaded.valid_for(source,tier,quality),"Saved companion lost its image data")
			manifest.variants.append({"path":output.trim_prefix("res://")+"/"+name,"geometry_tier":tier,"quality":quality,"size":asset.size,"directions":asset.directions,"payload_bytes":asset.payload_bytes(),"file_bytes":FileAccess.open(output+"/"+name,FileAccess.READ).get_length()})
	FileAccess.open(output+"/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t")+"\n")
	print("HORIZON_PACKED ",JSON.stringify(manifest)); quit()
