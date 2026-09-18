extends Node3D
## A few shared assets in spatially culled batches. No per-object Nodes.
const Placement = preload("res://scripts/world/wilderness_instances.gd")
const Fog = preload("res://scripts/world/wilderness_atmosphere.gd")
var materials: Array[ShaderMaterial] = []
var meshes: Dictionary = {}
var original_forest:Dictionary={}
var seasonal_forest:Dictionary={}
var current_profile
var triangles = 0
var instances = 0
var upload_ms = 0.0
var bounds_valid = true
var bounds_corners_checked = 0

func build(placement, landscape, profile, checkpoint: Callable = Callable(), job = null) -> void:
	var started = Time.get_ticks_usec()
	name = "BackgroundProps"
	for index in placement.groups.size():
		if job and job.is_cancelled(): return
		var group: Dictionary = placement.groups[index]
		var key: String = group.kind+str(group.asset)
		if not meshes.has(key):
			var tree: bool = group.kind!="rock"
			var id: String = Placement.TREE_IDS[group.asset] if tree else Placement.ROCK_IDS[group.asset]
			var suffix = ("_lod1" if group.kind=="near" else "_lod2") if tree else ""
			var path = "res://assets/graphics/%s/%s%s.glb" % ["trees/models" if tree else "models",id,suffix]
			var root: Node = load(path).instantiate()
			var source = _find_mesh(root)
			assert(source!=null,"Missing background mesh: "+path)
			var mesh: Mesh = source.mesh.duplicate()
			var mat = ShaderMaterial.new()
			mat.shader = preload("res://assets/graphics/offmap_tree.gdshader") if group.kind=="tree" else preload("res://assets/graphics/offmap_prop.gdshader")
			mat.set_shader_parameter("range_end",minf(profile.offmap_tree_distance_m,3200.0) if group.kind=="rock" else profile.offmap_tree_distance_m)
			mat.set_shader_parameter("tree_near_end",600.0)
			if group.kind=="tree":
				mat.set_shader_parameter("albedo_texture",load("res://assets/graphics/trees/textures/%s_atlas_low.png" % id))
			else:
				mat.set_shader_parameter("tree_geometry",group.kind=="near")
				mat.set_shader_parameter("rock_texture",load("res://assets/graphics/textures/rock_albedo_low.jpg"))
				if group.kind=="near":
					mat.set_shader_parameter("bark_texture",load("res://assets/graphics/textures/bark_albedo_low.jpg"))
					mat.set_shader_parameter("foliage_texture",load("res://assets/graphics/trees/textures/foliage_color_low.res"))
			Fog.configure(mat,landscape)
			materials.append(mat)
			for i in mesh.get_surface_count(): mesh.surface_set_material(i,mat)
			meshes[key] = mesh
			root.free()
		var mesh: Mesh = meshes[key]
		var buffer: PackedFloat32Array = group.buffer.duplicate()
		var count = buffer.size()/16
		var box = AABB()
		var local_box = mesh.get_aabb()
		# Billboard cards rotate about Y; their bound must cover every bearing.
		if group.kind=="tree":
			var radius = maxf(absf(local_box.position.x),absf(local_box.end.x))*.64
			local_box = AABB(Vector3(-radius,local_box.position.y,-radius),Vector3(radius*2,local_box.size.y,radius*2))
		for i in count:
			var offset = i*16
			var pose = pose_at(buffer,offset)
			var footprint = Transform3D(pose.basis,Vector3.ZERO)*local_box
			# Base contact uses the rendered surface hit; bury rock bottoms slightly
			# so an inclined footprint cannot reveal a thin daylight crack.
			pose.origin.y -= footprint.position.y+(footprint.size.y*.18 if group.kind=="rock" else .08)
			buffer[offset+7] = pose.origin.y
			var placed = pose*local_box
			box = placed if i==0 else box.merge(placed)
		var multi = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D; multi.use_custom_data = true
		multi.mesh = mesh; multi.instance_count = count; multi.buffer = buffer
		multi.custom_aabb = box.grow(2.0)
		# Verify the actual packed upload, including base offsets. Headless
		# Godot cannot read transforms back from its dummy RenderingServer.
		for sample_index in [0,count-1]:
			var packed_pose=pose_at(buffer,sample_index*16)
			for corner in 8:
				bounds_valid=bounds_valid and multi.custom_aabb.has_point(packed_pose*local_box.get_endpoint(corner))
				bounds_corners_checked+=1
		var node = MultiMeshInstance3D.new()
		node.name = "Batch_%s_%d" % [key,index]; node.multimesh = multi
		node.set_meta("kind",group.kind)
		if group.kind!="rock":node.set_meta("forest_key",Placement.TREE_IDS[group.asset]+("_lod1" if group.kind=="near" else "_lod2"))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		# Node culling is deliberately conservative; per-instance shader ranges
		# make the final fade continuous within each spatial batch.
		var distance_limit=600.0 if group.kind=="near" else (minf(profile.offmap_tree_distance_m,3200.0) if group.kind=="rock" else profile.offmap_tree_distance_m)
		# Godot measures from the transformed AABB center. Half its diagonal
		# encloses every point; a full diagonal needlessly submits hidden props.
		node.visibility_range_end = distance_limit+box.size.length()*.5+2.0
		add_child(node)
		instances += count
		for surface in mesh.get_surface_count(): triangles += mesh.surface_get_array_index_len(surface)/3*count
		bounds_valid = bounds_valid and box.position.is_finite() and box.size.is_finite()
		if checkpoint.is_valid() and index%16==15: await checkpoint.call("Loading authored forests and stone…",100.0*(index+1)/placement.groups.size())
	apply_quality(profile)
	upload_ms = (Time.get_ticks_usec()-started)/1000.0

static func pose_at(buffer: PackedFloat32Array, i: int) -> Transform3D:
	return Transform3D(Basis(Vector3(buffer[i],buffer[i+4],buffer[i+8]),Vector3(buffer[i+1],buffer[i+5],buffer[i+9]),Vector3(buffer[i+2],buffer[i+6],buffer[i+10])),Vector3(buffer[i+3],buffer[i+7],buffer[i+11]))

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var found = _find_mesh(child)
		if found: return found
	return null

func apply_quality(profile) -> void:
	current_profile=profile
	# Reuse uploaded geometry for same-tier changes; no ridge rebuild or seating.
	for node in get_children():
		if not node is MultiMeshInstance3D: continue
		var kind = node.get_meta("kind", "tree")
		var distance = 600.0 if kind=="near" else minf(profile.offmap_tree_distance_m,3200.0) if kind=="rock" else profile.offmap_tree_distance_m
		node.visibility_range_end = distance+node.multimesh.custom_aabb.size.length()*.5+2.0
		node.multimesh.visible_instance_count = roundi(node.multimesh.instance_count*profile.offmap_prop_density)
		var material = node.multimesh.mesh.surface_get_material(0)
		material.set_shader_parameter("range_end",distance)

func apply_forest_appearance(models:Dictionary,style:int)->void:
	triangles=0
	for node in get_children():
		if not node is MultiMeshInstance3D:continue
		var key:String=node.get_meta("forest_key","")
		if models.has(key):
			if not original_forest.has(key):original_forest[key]=node.multimesh.mesh
			var cache_key=str(style)+":"+key
			if not seasonal_forest.has(cache_key):
				var mesh:Mesh=models[key].duplicate()
				var mat:ShaderMaterial=original_forest[key].surface_get_material(0).duplicate()
				var source:ShaderMaterial=models[key].surface_get_material(0)
				var config:Dictionary=source.get_meta("forest_appearance")
				var parameter="albedo_texture" if key.ends_with("lod2") else "mesh_albedo"
				mat.set_shader_parameter(parameter,load(str(source.get_meta("forest_texture"))+"_low.res"))
				mat.set_shader_parameter("seasonal_geometry",true)
				if parameter=="mesh_albedo":
					if source.has_meta("forest_normal_texture"):
						mat.set_shader_parameter("mesh_normal",load(str(source.get_meta("forest_normal_texture"))+"_low.res"))
						mat.set_shader_parameter("has_mesh_normal",true)
					mat.set_shader_parameter("source_textured",config.get("source_textured",false))
					mat.set_shader_parameter("autumn_amount",config.get("autumn_amount",0))
					mat.set_shader_parameter("snow_dusting",config.get("snow_dusting",0))
					if config.has("autumn_color"):mat.set_shader_parameter("autumn_color",Color(config.autumn_color[0],config.autumn_color[1],config.autumn_color[2]))
				else:mat.set_shader_parameter("card_crop",config.card_crop)
				mesh.surface_set_material(0,mat);seasonal_forest[cache_key]=mesh;materials.append(mat)
			node.multimesh.mesh=seasonal_forest[cache_key]
			# Union with the old bound covers both crowns and every card bearing.
			var local=node.multimesh.mesh.get_aabb()
			if key.ends_with("lod2"):
				var crop=float(node.multimesh.mesh.surface_get_material(0).get_shader_parameter("card_crop"))
				var radius=maxf(absf(local.position.x),absf(local.end.x))*crop
				local=AABB(Vector3(-radius,local.position.y,-radius),Vector3(radius*2,local.size.y,radius*2))
			if not node.has_meta("original_forest_bound"):node.set_meta("original_forest_bound",node.multimesh.custom_aabb)
			var box:AABB=node.get_meta("original_forest_bound")
			var buffer:PackedFloat32Array=node.multimesh.buffer
			# The headless dummy server cannot return uploaded MultiMesh buffers.
			assert(buffer.size()==node.multimesh.instance_count*16 or DisplayServer.get_name()=="headless")
			if not buffer.is_empty():
				for i in node.multimesh.instance_count:box=box.merge(pose_at(buffer,i*16)*local)
			node.multimesh.custom_aabb=box
		var mesh:Mesh=node.multimesh.mesh
		for surface in mesh.get_surface_count():triangles+=mesh.surface_get_array_index_len(surface)/3*node.multimesh.instance_count
	if current_profile:apply_quality(current_profile)
