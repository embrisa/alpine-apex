extends SceneTree
func _initialize() -> void:
	var model = load("res://assets/graphics/models/skier.glb").instantiate()
	root.add_child(model)
	print_tree(model)
	quit()
func print_tree(node: Node) -> void:
	if node is Node3D:
		print(node.name," ",node.get_class()," ",node.transform)
	if node is Skeleton3D:
		for i in range(node.get_bone_count()):
			var name_value = node.get_bone_name(i)
			if not name_value.contains("Hand") or name_value in ["LeftHand","RightHand"]:
				print("BONE ",i," ",name_value," p=",node.get_bone_parent(i)," rest=",node.get_bone_global_rest(i).origin)
	for child in node.get_children(): print_tree(child)
