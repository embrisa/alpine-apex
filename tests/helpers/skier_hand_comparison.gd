extends RefCounted
## Test-only original glove swap. Production files and the rig are untouched.
const BASELINE = "res://art_source/meshy/hands_v1/baseline/skier_v7.glb"

static func body_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.skin != null: return node
	for child in node.get_children():
		var found = body_mesh(child)
		if found: return found
	return null

static func bind_name(skin: Skin, skeleton: Skeleton3D, index: int) -> String:
	var named = String(skin.get_bind_name(index))
	return named if not named.is_empty() else skeleton.get_bone_name(skin.get_bind_bone(index))

static func apply(skier, original: bool) -> Dictionary:
	var target = body_mesh(skier.character)
	assert(target != null)
	var source: MeshInstance3D = target
	var imported: Node
	if original:
		var document = GLTFDocument.new()
		var state = GLTFState.new()
		assert(document.append_from_file(BASELINE,state)==OK)
		imported = document.generate_scene(state)
		source = body_mesh(imported)
		assert(source != null and source.skin.get_bind_count()==target.skin.get_bind_count())
		for bind in target.skin.get_bind_count():
			assert(source.skin.get_bind_pose(bind).is_equal_approx(target.skin.get_bind_pose(bind)))
			assert(bind_name(source.skin,skier._find_skeleton(imported),bind)==bind_name(target.skin,skier.skeleton,bind))
	var original_slot = -1
	for slot in source.mesh.get_surface_count():
		if source.mesh.surface_get_material(slot).resource_name.begins_with("SkierV7Gloves"): original_slot = slot
	assert(original_slot >= 0)
	# Rebuild both variants identically; keep every non-glove surface from the
	# current imported runtime mesh. Close skier views use the full geometry.
	var mesh = ArrayMesh.new()
	var triangles = 0
	for slot in target.mesh.get_surface_count():
		var glove = target.mesh.surface_get_material(slot).resource_name.begins_with("SkierV7Gloves")
		var input_mesh: Mesh = source.mesh if glove else target.mesh
		var input_slot = original_slot if glove else slot
		var arrays = input_mesh.surface_get_arrays(input_slot)
		mesh.add_surface_from_arrays(input_mesh.surface_get_primitive_type(input_slot),arrays)
		mesh.surface_set_material(slot,input_mesh.surface_get_material(input_slot))
		if glove:
			triangles = arrays[Mesh.ARRAY_INDEX].size()/3
			if original: skier.assets.named_materials.erase("SkierV7Gloves")
			target.set_surface_override_material(slot,skier.assets.material_for(input_mesh.surface_get_material(input_slot)))
	target.mesh = mesh
	if imported: imported.free()
	assert(triangles==(3272 if original else 5644))
	return {"original_gloves":original,"glove_triangles":triangles,"other_surfaces_from_current_asset":true,"matching_full_geometry":true}
