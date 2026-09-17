extends RefCounted
## Shared immutable production meshes; every ghost owns only its materials.
var source
var lighting
var named_materials: Dictionary = {}
var materials: Dictionary = {}
var color = Color.WHITE
var jacket_materials: Array[ShaderMaterial] = []

func _init(shared = null, tint: Color = Color.WHITE) -> void:
	source = shared; color = tint
	if shared: lighting = shared.lighting

func mesh(id: String) -> Mesh:
	return source.mesh(id)

func convert_node(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var original = node.get_active_material(i)
			if original: node.set_surface_override_material(i,material_for(original))
	for child in node.get_children(): convert_node(child)

func material_for(original: Material) -> ShaderMaterial:
	var key = original.get_instance_id()
	if materials.has(key): return materials[key]
	var converted = original if original is ShaderMaterial else source.material_for(original)
	var mat: ShaderMaterial = converted.duplicate()
	# The clothing surface also contains trousers. Its shader recolors only
	# orange jacket texels; every other surface keeps its production shader.
	if original.resource_name.get_slice(".",0)=="SkierV7Clothing":
		mat.shader = preload("res://assets/graphics/ghost_skier.gdshader")
		mat.set_shader_parameter("ghost_tint",color)
		jacket_materials.append(mat)
	materials[key] = mat
	named_materials[original.resource_name.get_slice(".",0)] = mat
	lighting.register(mat)
	return mat

func tint(value: Color) -> void:
	if color==value: return
	color = value
	for mat in jacket_materials: mat.set_shader_parameter("ghost_tint",color)

func dispose() -> void:
	# The world registry holds strong refs; release only this ghost's instances.
	for mat in materials.values(): lighting.materials.erase(mat)
	materials.clear(); named_materials.clear(); jacket_materials.clear()
