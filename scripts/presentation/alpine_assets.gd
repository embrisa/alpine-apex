extends RefCounted
## Shared imported meshes and materials. All assets stay local and work offline.
const TEXTURED = preload("res://assets/graphics/textured_lit.gdshader")
const FOLIAGE = preload("res://assets/graphics/foliage.gdshader")
const SURFACE = preload("res://assets/graphics/alpine_surface.gdshader")
var lighting
var mountain
var environment_texture: Texture2D
var quality
var meshes: Dictionary = {}
var named_materials: Dictionary = {}
var imported_materials: Dictionary = {}
var surface_materials: Array[ShaderMaterial] = []
var wind_time: float = 0.0

func _init(clouds, profile) -> void:
	lighting = clouds
	quality = profile

func texture(id: String, channel: String) -> Texture2D:
	return load("res://assets/graphics/textures/%s_%s%s.jpg" % [id,channel,quality.texture_suffix])

func terrain_material(bias: float = 0.0, scale_value: float = 0.075) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = SURFACE
	mat.set_shader_parameter("rock_bias",bias)
	mat.set_shader_parameter("rock_scale",scale_value)
	mat.set_shader_parameter("material_specular",0.35)
	surface_materials.append(mat)
	lighting.register(mat)
	_update_surface(mat)
	return mat

func _update_surface(mat: ShaderMaterial) -> void:
	for id in ["snow","rock"]:
		mat.set_shader_parameter(id+"_albedo",texture(id,"albedo"))
		mat.set_shader_parameter(id+"_normal_tex",texture(id,"normal"))
		mat.set_shader_parameter(id+"_orm",texture(id,"orm"))
	mat.set_shader_parameter("detail_strength",quality.normal_strength)
	if mountain and float(mat.get_shader_parameter("rock_bias"))<.1:
		if not environment_texture:
			var img: Image = mountain.environment_image.duplicate()
			img.generate_mipmaps()
			environment_texture = ImageTexture.create_from_image(img)
		mat.set_shader_parameter("use_environment",true)
		mat.set_shader_parameter("environment_mask",environment_texture)
		mat.set_shader_parameter("environment_origin",mountain.ORIGIN)
		mat.set_shader_parameter("environment_extent",mountain.EXTENT)

func apply_quality(profile) -> void:
	quality = profile
	for mat in surface_materials:
		_update_surface(mat)
	for id in ["Bark","DeadBark"]:
		if named_materials.has(id): _set_bark(named_materials[id])
	if named_materials.has("Needles"):
		named_materials.Needles.set_shader_parameter("albedo_texture",load("res://assets/graphics/textures/spruce_needles%s.png" % quality.texture_suffix))
	if named_materials.has("Spruce"):
		_set_spruce(named_materials.Spruce)
	for i in range(1,4):
		var id = "Impostor%d" % i
		if named_materials.has(id):
			named_materials[id].set_shader_parameter("albedo_texture",load("res://assets/graphics/textures/spruce_impostor_%d%s.png" % [i,quality.texture_suffix]))
	for id in named_materials:
		if id.begins_with("Impostor_"):
			_set_impostor(named_materials[id],id)
		elif id.begins_with("Tree_"):
			_set_tree(named_materials[id],id.trim_prefix("Tree_"))

func _set_impostor(mat: ShaderMaterial, id: String) -> void:
	mat.set_shader_parameter("albedo_texture",load("res://assets/graphics/textures/impostor_%s%s.png" % [id.trim_prefix("Impostor_"),quality.texture_suffix]))
	mat.set_shader_parameter("foliage_tint",id.begins_with("Impostor_scots_pine_") or id.begins_with("Impostor_wind_pine_"))

func _set_tree(mat: ShaderMaterial, family: String) -> void:
	mat.set_shader_parameter("has_albedo",true)
	mat.set_shader_parameter("albedo_texture",texture(family+"_model","albedo"))
	mat.set_shader_parameter("has_normal",true)
	mat.set_shader_parameter("normal_texture",texture(family+"_model","normal"))
	mat.set_shader_parameter("has_roughness",true)
	mat.set_shader_parameter("roughness_texture",texture(family+"_model","roughness"))
	mat.set_shader_parameter("foliage_tint",family in ["scots_pine","wind_pine"])
	mat.set_shader_parameter("tree_wind",not family.ends_with("snag"))

func _set_spruce(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("has_albedo",true)
	mat.set_shader_parameter("albedo_texture",texture("spruce_model","albedo"))
	mat.set_shader_parameter("has_normal",true)
	mat.set_shader_parameter("normal_texture",texture("spruce_model","normal"))
	mat.set_shader_parameter("has_roughness",true)
	mat.set_shader_parameter("roughness_texture",texture("spruce_model","roughness"))
	mat.set_shader_parameter("foliage_tint",true)
	mat.set_shader_parameter("tree_wind",true)

func _set_bark(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("has_albedo",true)
	mat.set_shader_parameter("albedo_texture",texture("bark","albedo"))
	mat.set_shader_parameter("has_normal",true)
	mat.set_shader_parameter("normal_texture",texture("bark","normal"))
	mat.set_shader_parameter("has_orm",true)
	mat.set_shader_parameter("orm_texture",texture("bark","orm"))

func material_for(source: Material) -> ShaderMaterial:
	var name_value = source.resource_name
	var skier_id = name_value.get_slice(".",0)
	if skier_id.begins_with("SkierV7") and named_materials.has(skier_id): return named_materials[skier_id]
	# Body and separately exported boots use the same verified texture atlas.
	if name_value.begins_with("SkierV7Shell") and named_materials.has("SkierV7Shell"):
		return named_materials.SkierV7Shell
	if name_value.begins_with("Tree_") or name_value.begins_with("Impostor_"):
		var id = name_value.get_slice(".",0)
		if not named_materials.has(id):
			var mat = ShaderMaterial.new()
			mat.shader = preload("res://assets/graphics/tree_impostor.gdshader") if id.begins_with("Impostor_") else TEXTURED
			if id.begins_with("Impostor_"): _set_impostor(mat,id)
			else: _set_tree(mat,id.trim_prefix("Tree_"))
			named_materials[id] = lighting.register(mat)
		return named_materials[id]
	if name_value.begins_with("Impostor"):
		var id = name_value.get_slice(".",0)
		if not named_materials.has(id):
			var impostor = ShaderMaterial.new()
			impostor.shader = preload("res://assets/graphics/tree_impostor.gdshader")
			impostor.set_shader_parameter("albedo_texture",load("res://assets/graphics/textures/spruce_impostor_%s%s.png" % [id.trim_prefix("Impostor"),quality.texture_suffix]))
			named_materials[id] = lighting.register(impostor)
		return named_materials[id]
	for known in ["Bark","DeadBark","Needles","Snow","Rock","Spruce"]:
		if name_value.begins_with(known):
			if named_materials.has(known):
				return named_materials[known]
			var special: ShaderMaterial
			if known=="Rock":
				special = terrain_material(0.13,0.6)
			else:
				special = ShaderMaterial.new()
				special.shader = FOLIAGE if known=="Needles" else TEXTURED
				lighting.register(special)
				if known=="Needles":
					special.set_shader_parameter("albedo_texture",load("res://assets/graphics/textures/spruce_needles%s.png" % quality.texture_suffix))
				elif known in ["Bark","DeadBark"]:
					_set_bark(special)
					if known=="DeadBark": special.set_shader_parameter("base_color",Color(1.18,1.12,1.02))
				elif known=="Spruce":
					_set_spruce(special)
				else:
					special.set_shader_parameter("base_color",Color(0.82,0.88,0.93))
					special.set_shader_parameter("surface_roughness",0.84)
			named_materials[known] = special
			return special
	var key = source.get_instance_id()
	if imported_materials.has(key):
		return imported_materials[key]
	var mat = ShaderMaterial.new()
	mat.shader = TEXTURED
	if source is BaseMaterial3D:
		mat.set_shader_parameter("base_color",source.albedo_color)
		mat.set_shader_parameter("surface_roughness",source.roughness)
		mat.set_shader_parameter("surface_metallic",source.metallic)
		if source.albedo_texture:
			mat.set_shader_parameter("has_albedo",true)
			mat.set_shader_parameter("albedo_texture",source.albedo_texture)
		if source.normal_enabled and source.normal_texture:
			mat.set_shader_parameter("has_normal",true)
			mat.set_shader_parameter("normal_texture",source.normal_texture)
			mat.set_shader_parameter("normal_strength",0.5)
		if source is StandardMaterial3D and source.roughness_texture:
			mat.set_shader_parameter("has_roughness",true)
			mat.set_shader_parameter("roughness_texture",source.roughness_texture)
			var channels = [Vector4(1,0,0,0),Vector4(0,1,0,0),Vector4(0,0,1,0),Vector4(0,0,0,1),Vector4(.333,.333,.333,0)]
			mat.set_shader_parameter("roughness_channel",channels[source.roughness_texture_channel])
		if source is StandardMaterial3D and source.metallic_texture:
			mat.set_shader_parameter("has_metallic",true)
			mat.set_shader_parameter("metallic_texture",source.metallic_texture)
			var channels = [Vector4(1,0,0,0),Vector4(0,1,0,0),Vector4(0,0,1,0),Vector4(0,0,0,1),Vector4(.333,.333,.333,0)]
			mat.set_shader_parameter("metallic_channel",channels[source.metallic_texture_channel])
	imported_materials[key] = lighting.register(mat)
	if skier_id.begins_with("SkierV7"):
		mat.resource_name = skier_id
		named_materials[skier_id] = mat
	return mat

func convert_node(node: Node) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var source = node.get_active_material(i)
			if source:
				node.set_surface_override_material(i,material_for(source))
	for child in node.get_children():
		convert_node(child)

func mesh(id: String) -> Mesh:
	if meshes.has(id):
		return meshes[id]
	var scene: PackedScene = load("res://assets/graphics/models/%s.glb" % id)
	var root = scene.instantiate()
	var node = _find_mesh(root)
	assert(node!=null,"Asset has no mesh: "+id)
	var result: Mesh = node.mesh.duplicate()
	for i in range(result.get_surface_count()):
		var source = result.surface_get_material(i)
		if source:
			result.surface_set_material(i,material_for(source))
	root.free()
	meshes[id] = result
	return result

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh(child)
		if found:
			return found
	return null

func update_wind(state, dt: float, animate: bool) -> void:
	if animate:
		wind_time += dt
	for id in named_materials:
		if id in ["Needles","Spruce"] or (id.begins_with("Tree_") and not id.ends_with("snag")):
			var wind = Vector2(state.wind_velocity.x,state.wind_velocity.z)
			var mat: ShaderMaterial = named_materials[id]
			mat.set_shader_parameter("wind_time",wind_time)
			mat.set_shader_parameter("wind_direction",wind.normalized())
			mat.set_shader_parameter("wind_strength",minf(wind.length(),7.0) if state.enabled else 0.0)
