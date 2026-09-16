extends SceneTree
## Verify that optional scenes share the base rock and keep vegetation optional.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var found := find_mesh(child)
		if found: return found
	return null

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/minerals_v3/manifest.json"))
	var moss_count := 0
	var grass_count := 0
	var grass_triangles := 0
	for row: Dictionary in manifest.assets:
		if row.family == "glacier": continue
		var base := (load("res://"+row.path) as PackedScene).instantiate()
		root.add_child(base)
		var base_mesh := find_mesh(base)
		for kind in ["moss","moss_grass"]:
			if kind == "moss_grass" and row.category not in ["small","medium","large"]: continue
			var path: String = "res://assets/graphics/minerals_v3/"+kind+"/"+row.category+"/"+row.asset+"_"+kind+".tscn"
			var packed := load(path) as PackedScene
			require(packed != null, row.asset+": "+kind+" scene")
			if packed == null: continue
			var variant := packed.instantiate()
			root.add_child(variant)
			var rock := find_mesh(variant)
			require(rock.mesh == base_mesh.mesh, row.asset+": shared base mesh")
			var material := rock.get_active_material(0) as ShaderMaterial
			require(material != null, row.asset+": moss shader")
			if material:
				var coverage: Variant = material.get_shader_parameter("moss_coverage")
				require(coverage != null and float(coverage) > 0.0, row.asset+": moss enabled")
			require(base_mesh.get_surface_override_material(0) == null,row.asset+": base instance stays bare")
			if kind == "moss_grass":
				var grass := variant.get_node_or_null("OptionalGrass") as MeshInstance3D
				require(grass != null,row.asset+": grass geometry")
				if grass:
					var count: int = grass.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()/3
					require(count > 0 and count <= 7200,row.asset+": bounded grass triangles")
					grass_triangles += count
					require(is_equal_approx(grass.visibility_range_end,60.0),row.asset+": grass draw distance")
					var mat := grass.get_active_material(0) as StandardMaterial3D
					require(mat != null and mat.albedo_texture != null,row.asset+": grass texture")
				grass_count += 1
			else:
				moss_count += 1
			variant.free()
		base.free()
		require(FileAccess.file_exists("res://"+row.path),row.asset+": base preserved")
	require(moss_count == 108,"108 optional moss scenes")
	require(grass_count == 60,"60 optional moss and grass scenes")
	var file := preload("res://tests/test_report.gd").open_write("res://artifacts/minerals_v3/vegetation_validation.json")
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"moss_scenes":moss_count,"grass_scenes":grass_count,"total_grass_triangles":grass_triangles,"failures":failures},"\t"))
	print("MINERAL_VEGETATION_SUITE ",moss_count," moss; ",grass_count," grass; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
