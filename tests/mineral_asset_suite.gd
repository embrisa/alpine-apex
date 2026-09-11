extends SceneTree
## Verify the delivered GLBs through Godot's real scene importer.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/minerals/manifest.json"))
	var counts := {"small": 0, "medium": 0, "large": 0, "huge_boulders": 0, "cliffs": 0}
	var family_counts := {}
	var hashes := {}
	var results: Array[Dictionary] = []
	for row: Dictionary in manifest.assets:
		var family_key: String = row.category + "/" + row.family
		family_counts[family_key] = int(family_counts.get(family_key, 0)) + 1
		var path: String = "res://" + row.path
		require(FileAccess.get_sha256(path) == row.sha256, row.asset + ": file hash")
		require(not hashes.has(row.sha256), row.asset + ": duplicate export")
		hashes[row.sha256] = true
		var packed := load(path) as PackedScene
		require(packed != null, row.asset + ": imported scene")
		if packed == null: continue
		var instance := packed.instantiate()
		root.add_child(instance)
		var meshes: Array[MeshInstance3D] = []
		find_meshes(instance, meshes)
		require(meshes.size() == 1, row.asset + ": one mesh")
		if meshes.size() != 1:
			instance.free()
			continue
		var mesh := meshes[0].mesh as ArrayMesh
		require(mesh.get_surface_count() == 1, row.asset + ": one material surface")
		var arrays: Array = mesh.surface_get_arrays(0)
		var tri_count: int = arrays[Mesh.ARRAY_INDEX].size() / 3
		require(tri_count == int(row.triangles), row.asset + ": triangle fidelity")
		require(arrays[Mesh.ARRAY_TEX_UV].size() > 0, row.asset + ": UV coordinates")
		require(arrays[Mesh.ARRAY_COLOR].size() > 0, row.asset + ": vertex colors")
		var material := meshes[0].get_active_material(0) as StandardMaterial3D
		require(material != null, row.asset + ": PBR material")
		if material:
			require(material.vertex_color_use_as_albedo, row.asset + ": color variation enabled")
			if row.category in ["huge_boulders", "cliffs"]:
				require(material.uv1_triplanar, row.asset + ": metre-scale formation material")
			if row.family != "glacier":
				require(material.albedo_texture != null and material.normal_enabled, row.asset + ": embedded maps")
		var bounds: AABB = meshes[0].global_transform * mesh.get_aabb()
		var expected: Array = row.dimensions_godot_xyz_m
		for axis in range(3):
			require(absf(bounds.size[axis]-float(expected[axis])) < .01, row.asset + ": metre bounds axis " + str(axis))
		require(absf(bounds.position.y) < .01, row.asset + ": ground origin")
		# ArrayMesh serialization exposes importer-generated simplification levels.
		var serialized_surfaces: Array = mesh.get("_surfaces")
		var lods: Variant = serialized_surfaces[0].get("lods", {})
		require(not lods.is_empty(), row.asset + ": generated mesh LODs")
		# Godot serializes alternating [distance, index_buffer] pairs.
		var lod_count: int = lods.size()/2 if lods is Array else lods.size()
		results.append({"asset":row.asset,"triangles":tri_count,"lod_count":lod_count,"bounds_m":str(bounds)})
		counts[row.category] += 1
		instance.free()
	for category in counts:
		require(counts[category] == 24, category + ": 24 assets")
		for family: String in manifest.category_families[category]:
			require(int(family_counts.get(category+"/"+family,0)) == 4, category+"/"+family+": four shapes")
	require(results.size() == 120, "120 total mineral assets")
	var output := {"passed":failures.is_empty(),"asset_count":results.size(),"categories":counts,"failures":failures,"assets":results}
	var file := FileAccess.open("res://artifacts/minerals/godot_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	print("MINERAL_ASSET_SUITE ", results.size(), " assets; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func find_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: output.append(node)
	for child in node.get_children(): find_meshes(child, output)
