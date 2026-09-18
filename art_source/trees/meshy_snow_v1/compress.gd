extends SceneTree
## Run with the editor binary, whose offline texture compressors are available.
const PREP="res://artifacts/meshy_snow_20260918/prepared"
func _initialize():call_deferred("run")
func save_image(image:Image,path:String):
	if image.is_compressed():assert(image.decompress()==OK)
	image.generate_mipmaps();assert(image.compress(Image.COMPRESS_BPTC)==OK)
	assert(ResourceSaver.save(ImageTexture.create_from_image(image),path)==OK)
func run():
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Exclusive")
	for species in ["spruce","fir","stone_pine","winter_birch_v2"]:
		var mesh:Mesh=load(PREP+"/"+species+"_0.res")
		var material:StandardMaterial3D=mesh.surface_get_material(0)
		for channel in ["albedo","roughness","normal"]:
			var texture:Texture2D=material.get(channel+"_texture")
			assert(texture!=null)
			save_image(texture.get_image(),PREP+"/"+species+"_"+channel+".res")
		save_image(Image.load_from_file(PREP+"/"+species+"_atlas.png"),PREP+"/"+species+"_atlas.res")
		print("MESHY_TEXTURES_READY ",species)
	quit()
