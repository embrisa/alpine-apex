extends SceneTree
## Offline packaging only: bind catalogue-sized geometry once, never at game startup.
const DEST="res://assets/graphics/trees/winter"
func _initialize():call_deferred("run")
func run():
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Exclusive")
	var assets=preload("res://scripts/presentation/alpine_assets.gd").new(preload("res://scripts/presentation/cloud_lighting.gd").new(),preload("res://scripts/presentation/graphics_quality.gd").preset(2))
	var motion=preload("res://scripts/presentation/tree_motion.gd").new(assets,"")
	var library=preload("res://art_source/trees/meshy_snow_v1/family_library.gd").new()
	library.setup({"assets":assets,"scenery":{"density_forest":{"residency_texture":null},"tree_motion":motion}})
	DirAccess.make_dir_recursive_absolute(DEST+"/models")
	DirAccess.make_dir_recursive_absolute(DEST+"/textures")
	var manifest={"schema":1,"models":{},"source":"art_source/trees/meshy_snow_v1/README.md"}
	for key in library.replacement:
		var mesh:Mesh=library.replacement[key]
		var material:Material=mesh.surface_get_material(0)
		var path=DEST+"/models/"+key+".res"
		manifest.models[key]={"path":path,"material":material.resource_name}
		mesh.surface_set_material(0,null)
		assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
	for stem in ["bough_albedo","spruce_atlas","spruce_open_atlas","fir_atlas","stone_pine_atlas"]:
		for tier in ["low","balanced","high"]:
			var name=stem+"_"+tier+".res"
			assert(DirAccess.copy_absolute(library.FAMILY_PREP+"/"+name,DEST+"/textures/"+name)==OK)
	FileAccess.open(DEST+"/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t")+"\n")
	print("WINTER_PACKAGED ",manifest.models.size()," catalogue meshes")
	quit()
