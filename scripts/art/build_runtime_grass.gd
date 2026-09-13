extends SceneTree
## Additive, material-free runtime meshes from the sealed vegetation-only pack.
const SOURCE = "res://art_source/foliage/grass_v1"
const TARGET = "res://assets/graphics/grass"
const SHAPES = ["alpine_tuft_02","forest_fan_02","meadow_clump_02"]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE+"/manifest.json"))
	if FileAccess.file_exists(TARGET+"/manifest.json"):
		var previous: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(TARGET+"/manifest.json"))
		for record in previous.assets:
			assert(FileAccess.get_sha256(record.path)==record.sha256,"Refusing to overwrite edited runtime grass: "+record.path)
	var receipt = {"schema":1,"source_manifest_sha256":FileAccess.get_sha256(SOURCE+"/manifest.json"),"vegetation_only":true,"assets":[]}
	DirAccess.make_dir_recursive_absolute(TARGET)
	for record in source.assets:
		if record.shape not in SHAPES: continue
		for model in record.models:
			if model.lod==0: continue
			var path: String = SOURCE+"/models/"+model.file
			assert(FileAccess.get_sha256(path)==model.sha256,"Prepared source changed: "+path)
			var doc = GLTFDocument.new(); var state = GLTFState.new()
			assert(doc.append_from_file(path,state)==OK)
			var node = doc.generate_scene(state)
			var nodes = node.find_children("*","MeshInstance3D",true,false)
			assert(nodes.size()==1 and node.find_children("*","CollisionObject3D",true,false).is_empty())
			var mesh: ArrayMesh = nodes[0].mesh.duplicate()
			assert(mesh.get_surface_count()==1 and mesh.get_faces().size()/3==int(model.triangles))
			mesh.surface_set_material(0,null)
			var destination: String = TARGET+"/"+model.file.get_basename()+".res"
			assert(ResourceSaver.save(mesh,destination,ResourceSaver.FLAG_COMPRESS)==OK)
			receipt.assets.append({"id":record.id,"shape":record.shape,"finish":record.finish,"lod":model.lod,"path":destination,"source":path,"source_sha256":model.sha256,"sha256":FileAccess.get_sha256(destination),"height":mesh.get_aabb().size.y,"triangles":model.triangles})
			node.free()
	FileAccess.open(TARGET+"/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t")+"\n")
	print("RUNTIME_GRASS_ASSETS ",receipt.assets.size()," vegetation-only meshes")
	quit()
