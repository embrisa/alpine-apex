extends "res://art_source/trees/meshy_snow_v1/bough_library.gd"
## Offline catalogue sizing. Summer/autumn share geometry and source textures.
const PACK="res://artifacts/meshy_seasons_20260918/pack"
const DEST="res://assets/graphics/trees/seasons"
var saved={}

func export_pack():
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Exclusive")
	assets=preload("res://scripts/presentation/alpine_assets.gd").new(preload("res://scripts/presentation/cloud_lighting.gd").new(),preload("res://scripts/presentation/graphics_quality.gd").preset(2))
	var appearances:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PACK+"/appearances.json"))
	var heavy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/trees/winter/manifest.json"))
	DirAccess.make_dir_recursive_absolute(DEST+"/models")
	var manifest={"schema":1,"source":"art_source/trees/meshy_seasons_v1/README.md","styles":{},"materials":{}}
	for appearance in appearances.values():
		var species:String=appearance.source
		if source.has(species):continue
		source[species]={"lods":[],"far":null}
		for lod in 2:source[species].lods.append({"mesh":load(PACK+"/"+species+"_%d.res"%lod),"mat":null})
	for season in ["autumn","winter","summer"]:
		var entries={}
		for id in assets.tree_ids():
			var record:Dictionary=assets.tree_record(id);var family:String=record.family
			var evergreen=family in ["spruce","fir","pine"]
			var appearance=family
			if family in ["birch","golden"]:appearance="birch_bare" if season=="winter" else "birch_"+season
			elif family=="maple":appearance="maple_bare" if season=="winter" else "maple_"+season
			elif family=="dead":appearance="dead_snag"
			elif family=="broken":appearance="broken_tree"
			elif season=="winter":appearance+="_light"
			var heavy_snow=evergreen and season=="winter" and int(id.get_slice("_",2))%2==1
			var config:Dictionary=appearances[appearance]
			var species:String=config.source
			var box: AABB=assets.mesh(id+"_lod0").get_aabb()
			var source_box: AABB=source[species].lods[0].mesh.get_aabb()
			# Uniform horizontal scale keeps the eight-view card and geometry equal.
			var horizontal=minf(box.size.x/source_box.size.x,box.size.z/source_box.size.z)
			var scale_m=Vector3(horizontal,box.size.y/12.0,horizontal)
			for lod in 3:
				var key=id+"_lod%d"%lod
				if heavy_snow:
					var old:Dictionary=heavy.models[key]
					var mat_id:String=old.material
					var heavy_species=mat_id.trim_prefix("FC_Impostor_Winter_") if lod==2 else mat_id.trim_prefix("FC_Winter_").left(-2)
					manifest.materials[mat_id]={"lod":lod,"heavy":true,"texture_root":"res://assets/graphics/trees/winter/textures/","texture":heavy_species+"_atlas" if lod==2 else "bough_albedo","card_crop":.64}
					entries[key]={"path":old.path,"material":mat_id,"source":"meshy_snow_v1/"+heavy_species,"snow":"heavy"}
					continue
				var mat_id="FC_Season_%s_%s_%d"%[appearance,id if not evergreen and lod<2 else "shared",lod]
				if lod==2:mat_id="FC_Impostor_Season_"+appearance
				var params=config.duplicate(true)
				params.merge({"lod":lod,"heavy":false,"texture_root":DEST+"/textures/","texture":appearance+"_atlas" if lod==2 else species+"_albedo","continuous_crown":not evergreen})
				if lod<2 and config.get("light_texture",false):params.texture=species+"_light_albedo"
				params.branches=record.branches
				if evergreen and lod<2:params.normal=species+"_normal"
				if lod==2 and not evergreen:params.canopy=species+"_canopy"
				manifest.materials[mat_id]=params
				var mesh_key=id+"_"+(appearance if lod==2 else species)+"_lod%d"%lod
				var path=DEST+"/models/"+mesh_key+".res"
				if not saved.has(mesh_key):
					var mesh:Mesh
					if lod==2:mesh=card(species,scale_m,box.position.y)
					elif evergreen:mesh=detail(id,record,species,lod,scale_m,box.position.y)
					else:mesh=whole_detail(species,lod,scale_m,box.position.y)
					mesh.set_meta("forest_asset",id)
					assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
					saved[mesh_key]=true
				entries[key]={"path":path,"material":mat_id,"source":"meshy_seasons_v1/"+species,"snow":"light" if appearance.ends_with("light") else "none"}
		manifest.styles[season]=entries
	FileAccess.open(DEST+"/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t")+"\n")
	print("SEASONAL_EXPORT styles=",manifest.styles.size()," meshes=",saved.size())

func whole_detail(species:String,lod:int,scale_m:Vector3,bottom:float)->Mesh:
	var arrays:Array=source[species].lods[lod].mesh.surface_get_arrays(0).duplicate(true)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
	for i in vertices.size():
		vertices[i]=vertices[i]*scale_m+Vector3(0,bottom,0);normals[i]=(normals[i]/scale_m).normalized()
		var tangent=(Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])*scale_m).normalized()
		tangents[i*4]=tangent.x;tangents[i*4+1]=tangent.y;tangents[i*4+2]=tangent.z
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TANGENT]=tangents
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
