extends RefCounted
## Shared imported meshes and materials. All assets stay local and work offline.
const TEXTURED = preload("res://assets/graphics/textured_lit.gdshader")
const EQUIPMENT = preload("res://assets/graphics/equipment_lit.gdshader")
const FOLIAGE = preload("res://assets/graphics/foliage.gdshader")
const SURFACE = preload("res://assets/graphics/alpine_surface.gdshader")
# Linear needle-only palette, shared by visible geometry and distant atlases.
const NEEDLE_COLOR_GRADE = Vector3(.62,.72,.88)
var lighting
var mountain
var environment_texture: Texture2D
var quality
var meshes: Dictionary = {}
var named_materials: Dictionary = {}
var imported_materials: Dictionary = {}
var surface_materials: Array[ShaderMaterial] = []
var wind_time: float = 0.0
var wind_receivers: Array[ShaderMaterial] = []
var wind_ready = false
var last_wind_time = 0.0
var last_wind_direction = Vector2.INF # No wind state has been observed yet.
var last_wind_strength = 0.0
var tree_collection: Dictionary = {}
var foliage_sight = preload("res://scripts/presentation/foliage_sight.gd").new()
var sight_receivers: Array[ShaderMaterial] = []
var sight_parameters_sent = Vector4.ZERO

func _init(clouds, profile) -> void:
	lighting = clouds
	quality = profile

func texture(id: String, channel: String) -> Texture2D:
	var suffix: String = quality.surface_texture_suffix if id in ["snow","rock","bark"] else quality.texture_suffix
	return load("res://assets/graphics/textures/%s_%s%s.jpg" % [id,channel,suffix])

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
	quality.apply_snow_material(mat)
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
	wind_ready = false
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
		if id in ["PC_Conifer","TD_Conifer","FC_Tree","FC_Broadleaf","FC_Tree_Mid","FC_Broadleaf_Mid"]:
			named_materials[id].set_shader_parameter("bark_texture",texture("bark","albedo"))
			if id in ["FC_Tree","FC_Broadleaf","FC_Tree_Mid","FC_Broadleaf_Mid"]:
				named_materials[id].set_shader_parameter("bark_normal",texture("bark","normal"))
				if id.begins_with("FC_Broadleaf"): _set_broadleaf(named_materials[id])
				else: _set_foliage(named_materials[id])
		elif id.begins_with("FC_Impostor_"):
			_set_collection_impostor(named_materials[id],id)
		elif id.begins_with("TD_Impostor_"):
			named_materials[id].set_shader_parameter("albedo_texture",load("res://assets/graphics/textures/td_%s_atlas%s.png" % [id.trim_prefix("TD_Impostor_"),quality.texture_suffix]))
		elif id.begins_with("PC_Impostor_"):
			named_materials[id].set_shader_parameter("albedo_texture",load("res://assets/graphics/textures/pc_%s_atlas%s.png" % [id.trim_prefix("PC_Impostor_"),quality.texture_suffix]))
		elif id.begins_with("Impostor_"):
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
	if name_value.begins_with("FC_"):
		var id = name_value.get_slice(".",0)
		if not named_materials.has(id):
			var mat = ShaderMaterial.new()
			mat.resource_name = id
			if id in ["FC_Tree","FC_Broadleaf","FC_Tree_Mid","FC_Broadleaf_Mid"]:
				mat.shader = preload("res://assets/graphics/pc_forest_tree.gdshader")
				mat.set_shader_parameter("bark_texture",texture("bark","albedo"))
				mat.set_shader_parameter("bark_normal",texture("bark","normal"))
				if id.begins_with("FC_Broadleaf"): _set_broadleaf(mat)
				else: _set_foliage(mat)
			else:
				mat.shader = preload("res://assets/graphics/pc_tree_impostor.gdshader")
				_set_collection_impostor(mat,id)
				mat.set_shader_parameter("card_crop",1.0)
				if id.begins_with("FC_Impostor_spruce_") or id.begins_with("FC_Impostor_fir_") or id.begins_with("FC_Impostor_pine_"):
					mat.set_shader_parameter("foliage_color_grade",NEEDLE_COLOR_GRADE)
			_remember_material(id,lighting.register(mat))
		return named_materials[id]
	if name_value.begins_with("TD_"):
		var id = name_value.get_slice(".",0)
		if not named_materials.has(id):
			var mat = ShaderMaterial.new()
			if id=="TD_Conifer":
				mat.shader = preload("res://assets/graphics/pc_td_conifer.gdshader")
				mat.set_shader_parameter("bark_texture",texture("bark","albedo"))
				mat.set_shader_parameter("needle_mask",load("res://assets/graphics/textures/td_spruce_mask.png"))
			else:
				mat.shader = preload("res://assets/graphics/pc_tree_impostor.gdshader")
				mat.set_shader_parameter("albedo_texture",load("res://assets/graphics/textures/td_%s_atlas%s.png" % [id.trim_prefix("TD_Impostor_"),quality.texture_suffix]))
			_remember_material(id,lighting.register(mat))
		return named_materials[id]
	if name_value.begins_with("PC_"):
		var id = name_value.get_slice(".",0)
		if not named_materials.has(id):
			var mat = ShaderMaterial.new()
			if id=="PC_Conifer":
				mat.shader = preload("res://assets/graphics/pc_conifer.gdshader")
				mat.set_shader_parameter("bark_texture",texture("bark","albedo"))
			else:
				mat.shader = preload("res://assets/graphics/pc_tree_impostor.gdshader")
				mat.set_shader_parameter("albedo_texture",load("res://assets/graphics/textures/pc_%s_atlas%s.png" % [id.trim_prefix("PC_Impostor_"),quality.texture_suffix]))
			_remember_material(id,lighting.register(mat))
		return named_materials[id]
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
			_remember_material(id,lighting.register(mat))
		return named_materials[id]
	if name_value.begins_with("Impostor"):
		var id = name_value.get_slice(".",0)
		if not named_materials.has(id):
			var impostor = ShaderMaterial.new()
			impostor.shader = preload("res://assets/graphics/tree_impostor.gdshader")
			impostor.set_shader_parameter("albedo_texture",load("res://assets/graphics/textures/spruce_impostor_%s%s.png" % [id.trim_prefix("Impostor"),quality.texture_suffix]))
			_remember_material(id,lighting.register(impostor))
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
			_remember_material(known,special)
			return special
	var key = source.get_instance_id()
	if imported_materials.has(key):
		return imported_materials[key]
	var mat = ShaderMaterial.new()
	mat.shader = EQUIPMENT if name_value.begins_with("EquipmentV1") else TEXTURED
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
	var directory = "trees/models" if id.begins_with("forest_") else "models"
	var path="res://assets/graphics/%s/%s.glb" % [directory,id]
	if id.begins_with("forest_"):
		var record=tree_record(id.get_slice("_lod",0).trim_suffix("_shadow"))
		path="res://"+(record.shadow.path if id.ends_with("_shadow") else record.models[int(id.get_slice("_lod",1))].path)
	var resource=load(path)
	var root: Node
	var result: Mesh
	if resource is Mesh: result=resource.duplicate()
	else:
		root=resource.instantiate()
		var node=_find_mesh(root)
		assert(node!=null,"Asset has no mesh: "+id)
		result=node.mesh.duplicate()
	# The left ski has baked mirrored geometry/UV placement but shares the
	# right ski's materials, avoiding a second resident set of PBR textures.
	var shared: Mesh = mesh("ski_detailed_v1") if id=="ski_detailed_v1_left" else null
	for i in range(result.get_surface_count()):
		if shared:
			result.surface_set_material(i,shared.surface_get_material(i))
			continue
		var source = result.surface_get_material(i)
		if source:
			var material=material_for(source)
			if id.begins_with("forest_") and id.ends_with("_lod1") and material.resource_name in ["FC_Tree","FC_Broadleaf"]:
				material=_forest_mid_material(material)
			result.surface_set_material(i,material)
	if id.begins_with("forest_"):
		result.set_meta("forest_asset",id.get_slice("_lod",0).trim_suffix("_shadow"))
	if root: root.free()
	meshes[id] = result
	return result

func _forest_mid_material(source: ShaderMaterial) -> ShaderMaterial:
	var id=source.resource_name+"_Mid"
	if not named_materials.has(id):
		var mat:ShaderMaterial=source.duplicate()
		mat.resource_name=id
		mat.shader=preload("res://assets/graphics/pc_forest_tree_mid.gdshader")
		_remember_material(id,lighting.register(mat))
	return named_materials[id]

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh(child)
		if found:
			return found
	return null

func _set_foliage(mat: ShaderMaterial) -> void:
	var suffix: String = ["_low","_balanced",""][quality.texture_tier]
	mat.set_shader_parameter("foliage_color_grade",NEEDLE_COLOR_GRADE)
	mat.set_shader_parameter("foliage_texture",load("res://assets/graphics/trees/textures/foliage_color%s.res" % suffix))
	mat.set_shader_parameter("foliage_normal_ao",load("res://assets/graphics/trees/textures/foliage_normal_ao%s.res" % suffix))

func _set_broadleaf(mat: ShaderMaterial) -> void:
	var suffix: String=["_low","_balanced",""][quality.texture_tier]
	mat.set_shader_parameter("broadleaf",true)
	mat.set_shader_parameter("foliage_texture",load("res://assets/graphics/trees/textures/broadleaf_albedo%s.res" % suffix))
	mat.set_shader_parameter("foliage_normal_ao",load("res://assets/graphics/trees/textures/broadleaf_normal%s.res" % suffix))
	mat.set_shader_parameter("leaf_roughness",load("res://assets/graphics/trees/textures/broadleaf_roughness%s.res" % suffix))

func _set_collection_impostor(mat: ShaderMaterial,id: String) -> void:
	var stem="forest_"+id.trim_prefix("FC_Impostor_")
	var colorful=tree_record(stem).has("foliage_type")
	var suffix: String=["_low","_balanced",""][quality.texture_tier] if colorful else quality.texture_suffix
	mat.set_shader_parameter("albedo_texture",load("res://assets/graphics/trees/textures/%s_atlas%s.%s" % [stem,suffix,"res" if colorful else "png"]))
	if colorful:
		mat.set_shader_parameter("authored_canopy",true)
		mat.set_shader_parameter("canopy_texture",load("res://assets/graphics/trees/textures/%s_canopy%s.res" % [stem,suffix]))

func tree_shadow(id: String) -> Mesh:
	return mesh(id+"_shadow") if tree_record(id).has("shadow") else mesh(id+"_lod1")

func tree_render_bounds(id: String) -> AABB:
	var box: AABB = mesh(id+"_lod0").get_aabb().merge(mesh(id+"_lod1").get_aabb())
	var card: AABB = mesh(id+"_lod2").get_aabb()
	var half_width: float = maxf(absf(card.position.x),absf(card.end.x))
	box = box.merge(AABB(Vector3(-half_width,card.position.y,-half_width),Vector3(half_width*2,card.size.y,half_width*2)))
	# Conservative swept displacement for the existing .32-radian canopy spring.
	return box.grow(float(tree_record(id).height_m)*.34)

func _load_tree_catalog() -> void:
	if tree_collection.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/trees/manifest.json"))
		for record in manifest.assets: tree_collection[record.id] = record

func tree_record(id: String) -> Dictionary:
	_load_tree_catalog()
	return tree_collection[id]

func tree_ids() -> PackedStringArray:
	_load_tree_catalog()
	return PackedStringArray(tree_collection.keys())

func update_wind(state, dt: float, animate: bool) -> void:
	if animate:
		wind_time += dt
	var wind = Vector2(state.wind_velocity.x,state.wind_velocity.z)
	var direction = wind.normalized()
	var strength = minf(wind.length(),7.0) if state.enabled else 0.0
	var changed_time = not wind_ready or wind_time!=last_wind_time
	var changed_direction = not wind_ready or direction!=last_wind_direction
	var changed_strength = not wind_ready or strength!=last_wind_strength
	for mat in wind_receivers:
		if changed_time: mat.set_shader_parameter("wind_time",wind_time)
		if changed_direction: mat.set_shader_parameter("wind_direction",direction)
		if changed_strength: mat.set_shader_parameter("wind_strength",strength)
	last_wind_time = wind_time
	last_wind_direction = direction
	last_wind_strength = strength
	wind_ready = true

func _remember_material(id: String, mat: ShaderMaterial) -> void:
	named_materials[id] = mat
	if id in ["FC_Tree","FC_Broadleaf","FC_Tree_Mid","FC_Broadleaf_Mid"] or (id.begins_with("FC_Impostor_") and tree_record("forest_"+id.trim_prefix("FC_Impostor_")).has("foliage_type")) or id.begins_with("FC_Impostor_spruce_") or id.begins_with("FC_Impostor_fir_") or id.begins_with("FC_Impostor_pine_"):
		if not sight_receivers.has(mat): sight_receivers.append(mat)
		mat.set_shader_parameter("foliage_sight_parameters",foliage_sight.parameters)
	if id in ["Needles","Spruce","PC_Conifer","TD_Conifer","FC_Tree","FC_Broadleaf","FC_Tree_Mid","FC_Broadleaf_Mid"] or (id.begins_with("Tree_") and not id.ends_with("snag")):
		if not wind_receivers.has(mat): wind_receivers.append(mat)
		# Quality invalidates submissions, but the last observed state is still
		# valid for a material registered before the next normal update.
		if last_wind_direction.is_finite():
			mat.set_shader_parameter("wind_time",last_wind_time)
			mat.set_shader_parameter("wind_direction",last_wind_direction)
			mat.set_shader_parameter("wind_strength",last_wind_strength)

func update_foliage_sight(camera: Camera3D, actor: Vector3, dt: float, riding: bool, reach_percent: float = 60.0, transparency_percent: float = 100.0) -> void:
	foliage_sight.update(camera,actor,dt,riding,reach_percent,transparency_percent)
	if foliage_sight.parameters==sight_parameters_sent: return
	for mat in sight_receivers:
		mat.set_shader_parameter("foliage_sight_parameters",foliage_sight.parameters)
	sight_parameters_sent = foliage_sight.parameters
