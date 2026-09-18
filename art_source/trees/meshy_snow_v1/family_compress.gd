extends "res://art_source/trees/meshy_snow_v1/compress.gd"
const DEST="res://artifacts/meshy_snow_20260918/winter_family"
func run():
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Exclusive")
	for name in ["bough_albedo","spruce_atlas","spruce_open_atlas","fir_atlas","stone_pine_atlas"]:
		var source=Image.load_from_file(DEST+"/"+name+".png")
		for tier in ["high","balanced","low"]:
			var im=source.duplicate();var size=1 if tier=="high" else 2 if tier=="balanced" else 4
			if size>1:im.resize(im.get_width()/size,im.get_height()/size,Image.INTERPOLATE_LANCZOS)
			save_image(im,DEST+"/"+name+"_"+tier+".res")
		print("FAMILY_COMPRESSED ",name)
	quit()
