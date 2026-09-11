@tool
extends Node3D
## Scene variants reuse the base GLB; only the instance material is overridden.

func _ready() -> void:
	apply_variant(self)

func apply_variant(node: Node) -> void:
	if node is MeshInstance3D and node.has_meta("optional_moss_material"):
		node.set_surface_override_material(0,node.get_meta("optional_moss_material") as Material)
	for child in node.get_children(): apply_variant(child)
