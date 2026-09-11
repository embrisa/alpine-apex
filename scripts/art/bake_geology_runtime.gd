extends SceneTree
## Offline, additive export. Does not change the source GLBs or their imports.
const OUT = "res://assets/graphics/geology_v11"
var records: Array = []
func _initialize() -> void: call_deferred("run")

func find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var found = find_mesh(child)
		if found: return found
	return null

func run() -> void:
	for folder in ["meshes","collision","textures"]: DirAccess.make_dir_recursive_absolute(OUT+"/"+folder)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/minerals_v3/manifest.json"))
	var selected = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--asset="): selected = arg.trim_prefix("--asset=")
	for row: Dictionary in manifest.assets:
		if not selected.is_empty() and row.asset!=selected: continue
		var record_path = OUT+"/collision/"+row.asset+".json"
		if FileAccess.file_exists(record_path) and not "--force" in OS.get_cmdline_user_args() and not "--textures-only" in OS.get_cmdline_user_args() and not "--collision-only" in OS.get_cmdline_user_args():
			var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(record_path))
			if previous.get("source_sha256")==row.sha256 and previous.get("bake_version")==1:
				records.append(previous); continue
		print("BAKE_GEOLOGY ",row.asset)
		var scene: Node3D = (load("res://"+row.path) as PackedScene).instantiate()
		var source = find_mesh(scene)
		assert(source and source.transform.is_equal_approx(Transform3D.IDENTITY))
		var mesh: ArrayMesh = source.mesh.duplicate()
		var material: ShaderMaterial = mesh.surface_get_material(0)
		if "--textures-only" in OS.get_cmdline_user_args():
			_textures_for(row,material)
			records.append(JSON.parse_string(FileAccess.get_file_as_string(record_path)))
			scene.free()
			continue
		mesh.surface_set_material(0,null)
		var mesh_path = OUT+"/meshes/"+row.asset+".res"
		assert(ResourceSaver.save(mesh,mesh_path,ResourceSaver.FLAG_COMPRESS)==OK)
		var box = mesh.get_aabb()
		var footprint = _footprint(mesh)
		var settings = MeshConvexDecompositionSettings.new()
		settings.max_convex_hulls = 12 if row.category in ["small","medium"] else 128
		settings.max_num_vertices_per_convex_hull = 64
		settings.resolution = 100000 if row.category in ["small","medium"] else 1000000
		settings.max_concavity = .0001
		settings.min_volume_per_convex_hull = .00001
		settings.normalize_mesh = true
		var temporary = MeshInstance3D.new()
		temporary.mesh = mesh
		temporary.create_multiple_convex_collisions(settings)
		var hulls: Array = []
		for body in temporary.get_children():
			for child in body.get_children():
				if child is CollisionShape3D and child.shape is ConvexPolygonShape3D:
					var points: Array = []
					for p in child.shape.points: points.append([p.x,p.y,p.z])
					hulls.append(points)
		assert(not hulls.is_empty(),"Missing convex decomposition: "+row.asset)
		temporary.free()
		if "--collision-only" in OS.get_cmdline_user_args():
			var previous: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(record_path))
			previous.hulls=hulls
			previous.collision_bake_version=2
			FileAccess.open(record_path,FileAccess.WRITE).store_string(JSON.stringify(previous,"",true,true))
			records.append(previous)
			scene.free()
			continue
		var textures = _textures_for(row,material)
		var grass_path = "res://assets/graphics/minerals_v3/moss_grass/"+row.category+"/geometry/"+row.asset+"_grass.res"
		var grass = ""
		if ResourceLoader.exists(grass_path):
			var grass_mesh: ArrayMesh = load(grass_path).duplicate()
			grass_mesh.surface_set_material(0,null)
			grass = OUT+"/meshes/"+row.asset+"_grass.res"
			assert(ResourceSaver.save(grass_mesh,grass,ResourceSaver.FLAG_COMPRESS)==OK)
		var record = {"id":row.asset,"category":row.category,"family":row.family,"variant":row.variant,
			"source_sha256":row.sha256,"bake_version":1,"mesh":mesh_path,"grass":grass,"textures":textures,
			"bounds_min":[box.position.x,box.position.y,box.position.z],"size":[box.size.x,box.size.y,box.size.z],
			"footprint":footprint,"hulls":hulls,"triangles":row.triangles}
		record.collision_sha256 = JSON.stringify(hulls,"",true,true).sha256_text()
		FileAccess.open(record_path,FileAccess.WRITE).store_string(JSON.stringify(record,"",true,true))
		records.append(record)
		scene.free()
		await process_frame
	# A partial bake never replaces the full manifest.
	if selected.is_empty():
		FileAccess.open(OUT+"/catalog.json",FileAccess.WRITE).store_string(JSON.stringify({"version":1,"assets":records},"",true,true))
	print("GEOLOGY_BAKE_COMPLETE ",records.size())
	quit()

func _footprint(mesh: Mesh) -> Array:
	# Lowest mesh vertex in each 9x9 footprint cell, retaining gaps between parts.
	var box = mesh.get_aabb()
	var cells: Dictionary = {}
	for point in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var key = Vector2i(clampi(int((point.x-box.position.x)/box.size.x*8),0,8),clampi(int((point.z-box.position.z)/box.size.z*8),0,8))
		if not cells.has(key) or point.y<cells[key].y: cells[key] = point
	var result: Array = []
	for key in cells:
		var p: Vector3 = cells[key]
		result.append([p.x,p.y,p.z])
	return result

func _textures_for(row: Dictionary, material: ShaderMaterial) -> Dictionary:
	var textures: Dictionary = {}
	for level in ["low","balanced","high"]:
		textures[level] = {}
		for channel in ["albedo","normal","roughness"]:
			var image: Image = material.get_shader_parameter(channel+"_map").get_image().duplicate()
			if image.is_compressed(): image.decompress()
			image.clear_mipmaps()
			var divisor = 4 if level=="low" else (2 if level=="balanced" else 1)
			if divisor>1: image.resize(maxi(128,image.get_width()/divisor),maxi(128,image.get_height()/divisor),Image.INTERPOLATE_LANCZOS)
			var path = OUT+"/textures/"+row.asset+"_"+level+"_"+channel+".png"
			assert(image.save_png(path)==OK)
			textures[level][channel] = path
	return textures
