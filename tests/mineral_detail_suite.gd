extends SceneTree
## Validate imported geometry, bakes, LODs and optional material availability.

var failures: Array[String] = []
var partial := false

func _initialize() -> void:
	partial = "--partial" in OS.get_cmdline_user_args()
	call_deferred("run")

func require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func find_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: output.append(node)
	for child in node.get_children(): find_meshes(child, output)

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/minerals_v3/manifest.json"))
	var counts := {"small":0,"medium":0,"large":0,"huge_boulders":0,"cliffs":0}
	var family_counts := {}
	var hashes := {}
	var results: Array[Dictionary] = []
	for row: Dictionary in manifest.assets:
		var path: String = "res://"+row.path
		if partial and not ResourceLoader.exists(path): continue
		require(FileAccess.get_sha256(path) == row.sha256, row.asset+": hash")
		require(not hashes.has(row.sha256), row.asset+": unique export")
		hashes[row.sha256] = true
		var packed := load(path) as PackedScene
		require(packed != null, row.asset+": imported scene")
		if not packed: continue
		var instance := packed.instantiate()
		root.add_child(instance)
		var meshes: Array[MeshInstance3D] = []
		find_meshes(instance,meshes)
		require(meshes.size() == 1, row.asset+": one mesh")
		if meshes.size() != 1:
			instance.free()
			continue
		var mesh := meshes[0].mesh as ArrayMesh
		require(mesh.get_surface_count() == 1, row.asset+": one surface")
		var arrays := mesh.surface_get_arrays(0)
		var tri_count: int = arrays[Mesh.ARRAY_INDEX].size()/3
		require(tri_count == int(row.triangles), row.asset+": triangle fidelity")
		require(tri_count <= int(manifest.triangle_budgets[row.category]), row.asset+": triangle budget")
		require(arrays[Mesh.ARRAY_TEX_UV].size() > 0, row.asset+": UVs")
		var material := meshes[0].get_active_material(0) as ShaderMaterial
		require(material != null, row.asset+": detail PBR material")
		if material:
			for map in ["albedo_map","normal_map","roughness_map","mineral_detail"]:
				require(material.get_shader_parameter(map) is Texture2D, row.asset+": "+map)
			var normal := material.get_shader_parameter("normal_map") as Texture2D
			if normal: require(normal.get_width() == int(row.texture_sizes.normal), row.asset+": normal resolution")
			var coverage: Variant = material.get_shader_parameter("moss_coverage")
			require(coverage == null or float(coverage) == 0.0, row.asset+": bare default")
		if row.family != "glacier":
			require(meshes[0].has_meta("optional_moss_material"), row.asset+": optional moss")
			if meshes[0].has_meta("optional_moss_material"):
				var moss := meshes[0].get_meta("optional_moss_material") as ShaderMaterial
				require(moss != null and float(moss.get_shader_parameter("moss_coverage")) > 0.0, row.asset+": enabled moss variant")
		var bounds: AABB = meshes[0].global_transform*mesh.get_aabb()
		for axis in range(3):
			require(absf(bounds.size[axis]-float(row.dimensions_godot_xyz_m[axis])) < .015, row.asset+": bounds")
		require(absf(bounds.position.y) < .015, row.asset+": bottom origin")
		var surfaces: Array = mesh.get("_surfaces")
		var lods: Variant = surfaces[0].get("lods", {})
		require(not lods.is_empty(), row.asset+": LODs")
		var lod_count: int = lods.size()/2 if lods is Array else lods.size()
		results.append({"asset":row.asset,"triangles":tri_count,"lods":lod_count})
		counts[row.category] += 1
		var key: String = row.category+"/"+row.family
		family_counts[key] = int(family_counts.get(key,0))+1
		instance.free()
	if not partial:
		for category in counts:
			require(counts[category] == 24, category+": 24 assets")
			for family: String in manifest.category_families[category]:
				require(int(family_counts.get(category+"/"+family,0)) == 4, category+"/"+family+": four variants")
		require(results.size() == 120, "120 detail assets")
	var report := {"passed":failures.is_empty(),"partial":partial,"asset_count":results.size(),"categories":counts,"failures":failures,"assets":results}
	DirAccess.make_dir_recursive_absolute("res://artifacts/minerals_v3")
	var file := FileAccess.open("res://artifacts/minerals_v3/godot_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("MINERAL_DETAIL_SUITE ",results.size()," assets; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
