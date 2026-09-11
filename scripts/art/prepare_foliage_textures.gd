extends SceneTree
## Offline packing retains authored mip coverage; no runtime mip generation.
func _initialize() -> void:
	var receipt=[]
	for channel in ["color","normal_ao"]:
		var texture: Texture2D=load("res://assets/graphics/trees/textures/foliage_%s.dds" % channel)
		var source=texture.get_image()
		assert(source.get_width()==2048 and source.get_mipmap_count()==11,"Explicit 2048 atlas mip chain")
		for level in 3:
			var skip=2-level
			var size=2048>>skip
			var bytes=source.get_data().slice(source.get_mipmap_offset(skip))
			var img=Image.create_from_data(size,size,true,Image.FORMAT_RGBA8,bytes)
			assert(img.compress(Image.COMPRESS_BPTC)==OK,"BC7 atlas compression")
			var packed=ImageTexture.create_from_image(img)
			var suffix=["_low","_balanced",""][level]
			var path="res://assets/graphics/trees/textures/foliage_%s%s.res" % [channel,suffix]
			assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK,"Save authored atlas")
			receipt.append({"path":path,"size":size,"mips":img.get_mipmap_count(),"bytes":img.get_data_size(),"sha256":FileAccess.get_sha256(path)})
	DirAccess.make_dir_recursive_absolute("res://artifacts/foliage_v3/atlas")
	FileAccess.open("res://artifacts/foliage_v3/atlas/packed.json",FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	print("FOLIAGE_TEXTURES ",JSON.stringify(receipt)); quit()
