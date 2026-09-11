@tool
extends EditorScenePostImport
## Store shared texture references in the imported scene itself. Embedded
## portable GLB images then do not remain resident behind material overrides.
func _post_import(scene: Node) -> Object:
	var id=get_source_file().get_file().get_basename().rsplit("_lod",true,1)[0]
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/flavor_v1/manifest.json"))
	for record in manifest.assets:
		if record.id==id:
			_replace(scene,record.get("materials",[]))
			break
	return scene

func _replace(node: Node,materials: Array) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat=node.get_active_material(i)
			if not mat is StandardMaterial3D: continue
			for shared in materials:
				if shared.name!=mat.resource_name: continue
				if shared.albedo: mat.albedo_texture=load(shared.albedo)
				if shared.normal: mat.normal_texture=load(shared.normal)
				if shared.orm:
					mat.roughness_texture=load(shared.orm); mat.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_GREEN
					mat.metallic_texture=load(shared.orm); mat.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_BLUE
					if mat.ao_enabled: mat.ao_texture=load(shared.orm)
	for child in node.get_children(): _replace(child,materials)
