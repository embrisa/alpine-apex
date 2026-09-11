extends SceneTree
## Optional Godot scene variants share the imported mesh and texture resources.

func _initialize() -> void:
	call_deferred("run")

func apply_moss(node: Node) -> void:
	if node is MeshInstance3D and node.has_meta("optional_moss_material"):
		node.set_surface_override_material(0,node.get_meta("optional_moss_material") as Material)
	for child in node.get_children(): apply_moss(child)

func find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var found := find_mesh(child)
		if found: return found
	return null

func add_grass(instance: Node3D, row: Dictionary) -> MeshInstance3D:
	var rock := find_mesh(instance)
	var arrays := rock.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var eligible: Array[int] = []
	var cumulative: Array[float] = []
	var area := 0.0
	for i in range(0,indices.size(),3):
		var a := indices[i]
		var b := indices[i+1]
		var c := indices[i+2]
		var normal := (normals[a]+normals[b]+normals[c]).normalized()
		if normal.y < .66: continue
		area += (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).length()*.5
		eligible.append(i)
		cumulative.append(area)
	if eligible.is_empty(): return null
	var rng := RandomNumberGenerator.new()
	rng.seed = int(row.seed)
	var count := clampi(int(area*36),8,1200)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span := maxf(float(row.dimensions_godot_xyz_m[0]),maxf(float(row.dimensions_godot_xyz_m[1]),float(row.dimensions_godot_xyz_m[2])))
	for tuft in range(count):
		var chosen := clampi(cumulative.bsearch(rng.randf()*area),0,eligible.size()-1)
		var i := eligible[chosen]
		var u := sqrt(rng.randf())
		var v := rng.randf()
		var p := vertices[indices[i]]*(1.0-u)+vertices[indices[i+1]]*u*(1.0-v)+vertices[indices[i+2]]*u*v
		# Small tufts follow ledges; clustered omissions leave substantial bare rock.
		if sin(p.x*3.7+sin(p.z*2.9))+cos(p.z*4.1-p.y) < -.15: continue
		var height := minf(.14,span*.08)*rng.randf_range(.65,1.2)
		var width := height*.8
		for card in range(3):
			var angle := float(card)*PI/3.0+rng.randf_range(-.3,.3)
			var side := Vector3(cos(angle),0,sin(angle))*width*.5
			var quad: Array[Vector3] = [p-side,p+side,p+side+Vector3.UP*height,p-side+Vector3.UP*height]
			var uv: Array[Vector2] = [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
			for k in [0,1,2,0,2,3]:
				st.set_normal(Vector3.UP)
				st.set_color(Color(.52,.62,.40) if k < 2 else Color(.80,.85,.63))
				st.set_uv(uv[k])
				st.add_vertex(quad[k])
	var mesh := st.commit()
	if mesh == null: return null
	var material := StandardMaterial3D.new()
	material.resource_name = "Optional grass from supplied generator"
	material.albedo_texture = load("res://assets/graphics/minerals_v3/textures/grass.png")
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = .5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mesh.surface_set_material(0,material)
	var grass := MeshInstance3D.new()
	grass.name = "Optional grass tufts"
	grass.mesh = mesh
	grass.transform = rock.transform
	grass.visibility_range_end = 60.0
	instance.add_child(grass)
	grass.owner = instance
	return grass

func write_variant(path: String, source: String, name: String, grass: String = "", transform := Transform3D.IDENTITY) -> void:
	var text := "[gd_scene load_steps=%s format=3]\n\n" % (4 if not grass.is_empty() else 3)
	text += '[ext_resource type="PackedScene" path="%s" id="1"]\n' % source
	text += '[ext_resource type="Script" path="res://scripts/art/mineral_vegetation_variant.gd" id="2"]\n'
	if not grass.is_empty(): text += '[ext_resource type="ArrayMesh" path="%s" id="3"]\n' % grass
	text += '\n[node name="%s" instance=ExtResource("1")]\nscript = ExtResource("2")\n' % name
	if not grass.is_empty():
		text += '\n[node name="OptionalGrass" type="MeshInstance3D" parent="."]\nmesh = ExtResource("3")\nvisibility_range_end = 60.0\n'
		text += 'transform = %s\n' % var_to_str(transform)
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file != null)
	file.store_string(text)

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/minerals_v3/manifest.json"))
	var count := 0
	var grass_count := 0
	var asset_filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--asset="): asset_filter = arg.trim_prefix("--asset=")
	for row: Dictionary in manifest.assets:
		if not asset_filter.is_empty() and row.asset != asset_filter: continue
		if row.family == "glacier": continue
		var source := load("res://"+row.path) as PackedScene
		var instance := source.instantiate()
		apply_moss(instance)
		var folder: String = "res://assets/graphics/minerals_v3/moss/"+row.category
		DirAccess.make_dir_recursive_absolute(folder)
		write_variant(folder+"/"+row.asset+"_moss.tscn","res://"+row.path,row.asset+"_moss")
		if row.category in ["small","medium","large"]:
			var grass := add_grass(instance, row)
			assert(grass != null)
			var grass_folder: String = "res://assets/graphics/minerals_v3/moss_grass/"+row.category
			DirAccess.make_dir_recursive_absolute(grass_folder+"/geometry")
			var mesh_path: String = grass_folder+"/geometry/"+row.asset+"_grass.res"
			assert(ResourceSaver.save(grass.mesh,mesh_path,ResourceSaver.FLAG_COMPRESS) == OK)
			write_variant(grass_folder+"/"+row.asset+"_moss_grass.tscn","res://"+row.path,row.asset+"_moss_grass",mesh_path,grass.transform)
			grass_count += 1
		instance.free()
		count += 1
	print("MINERAL_MOSS_VARIANTS ",count,"; MOSS_GRASS_VARIANTS ",grass_count)
	quit()
