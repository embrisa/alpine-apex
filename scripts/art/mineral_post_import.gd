@tool
extends EditorScenePostImport
## Assign shared materials and preserve the pack's authored vertex colours.

func _post_import(scene: Node) -> Object:
	var family_is_ice := get_source_file().get_file().contains("_glacier_")
	var path := "res://assets/graphics/minerals/materials/" + ("glacier.tres" if family_is_ice else "stone.tres")
	if get_source_file().contains("/huge_boulders/") or get_source_file().contains("/cliffs/"):
		path = "res://assets/graphics/minerals/materials/formation_stone.tres"
	apply_material(scene, load(path) as StandardMaterial3D)
	return scene

func apply_material(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mesh := node.mesh as ArrayMesh
		for surface in range(mesh.get_surface_count()):
			mesh.surface_set_material(surface, material)
			node.set_surface_override_material(surface, null)
		node.material_override = null
	for child in node.get_children(): apply_material(child, material)
