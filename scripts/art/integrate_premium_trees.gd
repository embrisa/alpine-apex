extends SceneTree
## Convert the sealed premium source family into the existing production forest
## contract. This is presentation-only: placements, collision, and world data
## continue to come from the current physical tree records.

const SOURCE := "res://art_source/trees/premium_lod_v1/"
const DEST := "res://assets/graphics/trees/"

var receipts: Array = []

func _initialize() -> void:
	call_deferred("run")

func read_json(path: String):
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func write_json(path: String, data) -> void:
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(data, "\t", true, true) + "\n")

func save(resource: Resource, path: String) -> void:
	var uid := ResourceLoader.get_resource_uid(path) if FileAccess.file_exists(path) else -1
	# Windows can keep a previous imported .res handle open in the editor while
	# permitting new files beside it. Serialize a complete sibling first, then
	# swap the exact target only after that write and UID assignment succeed.
	var staging := path.trim_suffix(".res") + ".premium-staging.res"
	if FileAccess.file_exists(staging):
		assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(staging)) == OK, staging)
	assert(ResourceSaver.save(resource, staging, ResourceSaver.FLAG_COMPRESS) == OK, staging)
	if uid != -1:
		assert(ResourceSaver.set_uid(staging, uid) == OK, staging)
	if FileAccess.file_exists(path):
		assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, path)
	assert(DirAccess.rename_absolute(ProjectSettings.globalize_path(staging), ProjectSettings.globalize_path(path)) == OK, path)
	receipts.append({"path": path, "sha256": FileAccess.get_sha256(path)})

func copy_file(source: String, destination: String) -> void:
	var input := FileAccess.open(source, FileAccess.READ)
	assert(input != null, "Missing premium sidecar: " + source)
	var output := FileAccess.open(destination, FileAccess.WRITE)
	assert(output != null, "Cannot write production sidecar: " + destination)
	output.store_buffer(input.get_buffer(input.get_length()))
	output.close()
	input.close()
	assert(FileAccess.get_sha256(source) == FileAccess.get_sha256(destination), "Sidecar copy changed: " + destination)
	receipts.append({"path": destination, "sha256": FileAccess.get_sha256(destination)})

func texture_levels(source_path: String, stem: String) -> void:
	# Mirror the existing High/Balanced/Low production texture contract. The
	# source PNG remains beside these immutable runtime resources for audit; game
	# rendering binds only the selected compressed tier.
	var source := Image.load_from_file(source_path)
	assert(source != null and not source.is_empty(), "Cannot load premium atlas: " + source_path)
	for level in 3:
		var image := source.duplicate()
		image.clear_mipmaps()
		var divisor := 1 << (2 - level)
		image.resize(source.get_width() / divisor, source.get_height() / divisor, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		assert(image.compress(Image.COMPRESS_BPTC) == OK, "BC7 packing: " + stem)
		save(ImageTexture.create_from_image(image), DEST + "textures/" + stem + ["_low", "_balanced", ""][level] + ".res")

func model_record(record: Dictionary, lod: int) -> Dictionary:
	if lod == -1:
		return record.shadow
	for model in record.models:
		if int(model.lod) == lod:
			return model
	assert(false, "Premium source has no LOD %d for %s" % [lod, record.id])
	return {}

func import_tree(record: Dictionary, lod: int) -> Node3D:
	var model := model_record(record, lod)
	var path := SOURCE + str(model.path)
	assert(FileAccess.get_sha256(path) == str(model.sha256), "Premium source changed: " + path)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(path, state) == OK, "Cannot read premium GLB: " + path)
	return document.generate_scene(state)

func material_name(record: Dictionary) -> String:
	return "FC_Broadleaf" if str(record.family) in ["golden", "maple"] else "FC_Tree"

func role_alpha(role: String) -> float:
	assert(role in ["Wood", "Foliage", "Snow"], "Unexpected premium material role: " + role)
	return {"Wood": 0.0, "Foliage": 0.7, "Snow": 1.0}[role]

func pack(node: Node3D, destination_material: String) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var pose: Transform3D = child.transform
		var parent := child.get_parent()
		while parent is Node3D and parent != node:
			pose = parent.transform * pose
			parent = parent.get_parent()
		for index in child.mesh.get_surface_count():
			var source: Material = child.mesh.surface_get_material(index)
			var role := source.resource_name.trim_prefix("PremiumTree_")
			var arrays: Array = child.mesh.surface_get_arrays(index)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			assert(not colors.is_empty() and not tags.is_empty(), "Premium detail mesh lost vertex color or branch tags")
			for vertex in colors.size():
				var color := colors[vertex]
				color.a = role_alpha(role)
				colors[vertex] = color
				# Blender stores 1 - pivot / 32 in UV1, and Godot's GLTF import
				# converts the V coordinate back to pivot / 32. Preserve that imported
				# value so wind and player-contact springs bend at the source root.
			arrays[Mesh.ARRAY_COLOR] = colors
			arrays[Mesh.ARRAY_TEX_UV2] = tags
			var part := ArrayMesh.new()
			part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			surface.append_from(part, 0, pose)
	surface.index()
	var material := StandardMaterial3D.new()
	material.resource_name = destination_material
	surface.set_material(material)
	return surface.commit()

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null

func far_mesh(node: Node3D, id: String) -> ArrayMesh:
	var source := _find_mesh(node)
	assert(source != null and source.mesh.get_surface_count() == 1, "Premium far card is not a single mesh")
	var arrays: Array = source.mesh.surface_get_arrays(0)
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.resource_name = "FC_Impostor_" + id.trim_prefix("forest_")
	result.surface_set_material(0, material)
	return result

func match_vertical_envelope(reference: ArrayMesh, candidate: ArrayMesh) -> ArrayMesh:
	# The source's reduced tier preserves its crown plan but can lose the highest
	# tiny twig during decimation. Match the detailed envelope exactly so the
	# production dither transition neither sinks nor pops at its top.
	var reference_box := reference.get_aabb()
	var candidate_box := candidate.get_aabb()
	if is_equal_approx(reference_box.position.y, candidate_box.position.y) and is_equal_approx(reference_box.end.y, candidate_box.end.y):
		return candidate
	var scale := reference_box.size.y / candidate_box.size.y
	var arrays: Array = candidate.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	for index in vertices.size():
		var point := vertices[index]
		point.y = reference_box.position.y + (point.y - candidate_box.position.y) * scale
		vertices[index] = point
		var tag := tags[index]
		tag.y = (reference_box.position.y + (tag.y * 32.0 - candidate_box.position.y) * scale) / 32.0
		tags[index] = tag
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV2] = tags
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	result.surface_set_material(0, candidate.surface_get_material(0))
	return result

func motion_padding(mesh: ArrayMesh) -> float:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var maximum_radius := 0.0
	for index in vertices.size():
		maximum_radius = maxf(maximum_radius, vertices[index].distance_to(Vector3(0.0, tags[index].y * 32.0, 0.0)))
	var maximum_angle := sqrt(3.0) * .32 + sqrt(2.0) * 7.0 * .005 * 1.35
	# Grow by a small numeric margin after converting the source's exact branch
	# pivots. This affects culling only; it neither changes tree population nor
	# moves visual or physical tree transforms.
	return 2.0 * sin(maximum_angle * .5) * maximum_radius * 1.01

func branches(mesh: ArrayMesh) -> Array:
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var result: Array = []
	for cluster in 12:
		var members: Array[Vector3] = []
		var center := Vector3.ZERO
		var pivot := 0.0
		for index in points.size():
			if roundi(tags[index].x * 16.0) != cluster:
				continue
			members.append(points[index])
			center += points[index]
			pivot = tags[index].y * 32.0
		if not members.is_empty():
			center /= members.size()
		var radius := 0.1
		for point in members:
			radius = maxf(radius, point.distance_to(center))
		result.append({"center": [center.x, center.y, center.z], "radius": radius, "pivot_y": pivot})
	return result

func saved_model(mesh: ArrayMesh, path: String) -> Dictionary:
	save(mesh, path)
	return {"path": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path),
		"triangles": mesh.get_faces().size() / 3, "bytes": FileAccess.get_file_as_bytes(path).size()}

func production_entry(record: Dictionary) -> Dictionary:
	var id := str(record.id)
	var detailed_material := material_name(record)
	var near_node := import_tree(record, 0)
	var mid_node := import_tree(record, 1)
	var far_node := import_tree(record, 2)
	var shadow_node := import_tree(record, -1)
	var near := pack(near_node, detailed_material)
	var mid := match_vertical_envelope(near, pack(mid_node, detailed_material))
	var far := far_mesh(far_node, id)
	var shadow := pack(shadow_node, detailed_material)
	var models: Array = []
	for pair in [[near, 0], [mid, 1], [far, 2]]:
		models.append(saved_model(pair[0], DEST + "models/%s_lod%d.res" % [id, pair[1]]))
	var shadow_model := saved_model(shadow, DEST + "models/%s_shadow.res" % id)
	for channel in ["color", "normal", "canopy"]:
		var source := SOURCE + str(record.impostor[channel].path)
		assert(FileAccess.get_sha256(source) == str(record.impostor[channel].sha256), "Premium impostor changed: " + source)
		copy_file(source, DEST + "textures/%s_%s.png" % [id, channel])
		texture_levels(source, "%s_%s" % [id, "atlas" if channel == "color" else channel])
	var box := near.get_aabb()
	var center := box.get_center()
	var bounds := {"min": [box.position.x, box.position.y, box.position.z],
		"max": [box.end.x, box.end.y, box.end.z]}
	near_node.free()
	mid_node.free()
	far_node.free()
	shadow_node.free()
	return {
		"id": id, "family": record.family, "variant": record.variant, "seed": record.seed,
		"height_m": box.size.y, "models": models, "shadow": shadow_model,
		"branches": branches(near), "crown_center": [center.x, center.y, center.z],
		"crown_radius": box.size.length() * 0.5, "normalization_bounds": bounds,
		"foliage_revision": 3 if str(record.family) in ["spruce", "fir", "pine"] else 0,
		"motion_padding_m": maxf(motion_padding(near), motion_padding(mid)), "premium_tree": true,
		"premium_source": {"manifest_sha256": FileAccess.get_sha256(SOURCE + "manifest.json"),
			"asset": id, "source_blend": record.source_blend.path,
			"source_blend_sha256": record.source_blend.sha256,
			"baseline_triangles": record.baseline_triangles,
			"source_triangles": [record.models[0].triangles, record.models[1].triangles, record.models[2].triangles]},
		"impostor": {"views": record.impostor.views, "tile_size": record.impostor.tile_size,
			"color": "assets/graphics/trees/textures/%s_color.png" % id,
			"normal": "assets/graphics/trees/textures/%s_normal.png" % id,
			"canopy": "assets/graphics/trees/textures/%s_canopy.png" % id}
	}

func run() -> void:
	assert(OS.get_environment("ALPINE_VALIDATION_MODE") == "Exclusive", "Premium tree packing requires Exclusive admission")
	var catalog: Dictionary = read_json(SOURCE + "manifest.json")
	assert(catalog.assets.size() == 30, "Premium catalog must cover every live tree ID")
	var update := {"assets": [], "branches": {}}
	for record in catalog.assets:
		var entry := production_entry(record)
		update.assets.append(entry)
		# tree_motion owns an explicit definition record.  Preserve its established
		# object shape rather than substituting a bare branch array, because live
		# downhill processing reads definition.branches for nearby trees.
		update.branches[entry.id] = {"branches": entry.branches}
		print("PREMIUM_TREE_PACKED %s triangles %d / %d / %d shadow %d" % [entry.id, entry.models[0].triangles, entry.models[1].triangles, entry.models[2].triangles, entry.shadow.triangles])
	DirAccess.make_dir_recursive_absolute("res://artifacts/premium_forest_integration")
	write_json("res://artifacts/premium_forest_integration/catalog_update.json", update)
	write_json("res://artifacts/premium_forest_integration/packing.json", receipts)
	print("PREMIUM_TREE_PACK_COMPLETE ", update.assets.size())
	quit()
