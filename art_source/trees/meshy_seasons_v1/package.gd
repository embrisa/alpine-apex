extends SceneTree
## Stock editor binary supplies the offline BC7 compressor.
const PACK="res://artifacts/meshy_seasons_20260918/pack"
const DEST="res://assets/graphics/trees/seasons"
func _initialize():call_deferred("run")
func run():
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Exclusive")
	DirAccess.make_dir_recursive_absolute(DEST+"/textures")
	for file in DirAccess.get_files_at(PACK):
		if not file.ends_with(".png"):continue
		if file in ["spruce_canopy.png","fir_canopy.png","pine_canopy.png"]:continue
		var source=Image.load_from_file(PACK+"/"+file)
		for tier in 3:
			var image=source.duplicate()
			var divisor=[4,2,1][tier]
			image.resize(image.get_width()/divisor,image.get_height()/divisor,Image.INTERPOLATE_LANCZOS)
			image.generate_mipmaps();assert(image.compress(Image.COMPRESS_BPTC)==OK)
			assert(ResourceSaver.save(ImageTexture.create_from_image(image),DEST+"/textures/"+file.get_basename()+"_"+["low","balanced","high"][tier]+".res")==OK)
		print("SEASONAL_COMPRESS ",file)
	preload("res://art_source/trees/meshy_seasons_v1/export.gd").new().export_pack()
	quit()
