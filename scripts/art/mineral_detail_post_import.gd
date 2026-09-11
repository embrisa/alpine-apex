@tool
extends EditorScenePostImport
## Preserve per-asset PBR bakes; add reusable close detail and optional moss.

func _post_import(scene: Node) -> Object:
	configure(scene)
	return scene

func configure(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node.mesh as ArrayMesh
		var original := mesh.surface_get_material(0) as StandardMaterial3D
		var material := ShaderMaterial.new()
		material.shader = load("res://assets/graphics/minerals_v3/rock_surface.gdshader")
		material.resource_name = "Bare rock PBR" if not get_source_file().contains("_glacier_") else "Glacial ice PBR"
		material.set_shader_parameter("albedo_map", original.albedo_texture)
		material.set_shader_parameter("normal_map", original.normal_texture)
		material.set_shader_parameter("roughness_map", original.roughness_texture)
		material.set_shader_parameter("mineral_detail", load("res://assets/graphics/minerals_v3/textures/rock_detail.jpg"))
		var ice := get_source_file().contains("_glacier_")
		material.set_shader_parameter("glacier", ice)
		var variant := get_source_file().get_basename().right(2).to_int()-1
		var palette := [Color(.83,.88,.94),Color(.90,.85,.77),Color(.62,.68,.73),Color(.96,.93,.87)]
		material.set_shader_parameter("rock_tint",palette[clampi(variant,0,3)])
		material.set_shader_parameter("color_saturation", .9 if get_source_file().contains("sedimentary") else .35)
		mesh.surface_set_material(0, material)
		node.set_surface_override_material(0, null)
		if not ice:
			var moss := material.duplicate() as ShaderMaterial
			moss.resource_name = "Optional patchy moss"
			moss.set_shader_parameter("moss_coverage", .88)
			node.set_meta("optional_moss_material", moss)
	for child in node.get_children(): configure(child)
