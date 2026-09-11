@tool
extends EditorScenePostImport
## Drag-and-drop imports receive the same shared shader as the mountain.
static var shared_assets
func _post_import(scene: Node) -> Object:
	# Keep shared textures resident during one import batch; repeated reloads
	# otherwise repeatedly request the editor's 3D texture detection imports.
	if shared_assets==null:
		shared_assets = load("res://scripts/presentation/alpine_assets.gd").new(load("res://scripts/presentation/cloud_lighting.gd").new(),load("res://scripts/presentation/graphics_quality.gd").preset(2))
	configure(scene,shared_assets)
	return scene
func configure(node: Node, assets) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			node.mesh.surface_set_material(i,assets.material_for(node.mesh.surface_get_material(i)))
	for child in node.get_children(): configure(child,assets)
