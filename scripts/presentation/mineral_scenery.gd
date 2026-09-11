extends Node3D
var frame_costs
## Shared material-free render meshes, regional batches and quality-only detail.
const ROOT = "res://assets/graphics/geology_v11"
const SHADER = preload("res://assets/graphics/mineral_world.gdshader")
var field
var library
var quality
var batches: Array[MultiMeshInstance3D] = []
var materials: Dictionary = {}
var rows: Dictionary = {}
var mesh_cache: Dictionary = {}
var grass_material: ShaderMaterial
var support_height: ImageTexture
var exposure: ImageTexture
var stream_macro_textures=false
var macro_bounds: Dictionary={}
var high_macros: Dictionary={}
var pending_macros: Array=[]
var macro_ready=false
var macro_timer=0.0

func build(source, assets, profile, checkpoint: Callable = Callable(), preparation = null) -> void:
	field=source; library=assets; quality=profile
	if not "geology" in field: return
	stream_macro_textures="GENERATOR_VERSION" in field and field.GENERATOR_VERSION>=13
	rows=field.geology.catalog.records
	support_height=ImageTexture.create_from_image(Image.create_from_data(field.NX,field.NZ,false,Image.FORMAT_RF,field.heights.to_byte_array()))
	exposure=ImageTexture.create_from_image(field.exposure_image)
	if preparation:
		macro_bounds = preparation.macro_bounds
		await _prepared_batches(preparation,checkpoint)
		if not field.job.is_cancelled(): apply_quality(profile); macro_ready = true
		return
	var groups: Dictionary={}
	for placed in field.geology.placements:
		var origin: Vector3=placed.pose.origin
		if stream_macro_textures and rows[placed.asset].category in ["cliffs","huge_boulders"]:
			if not macro_bounds.has(placed.asset): macro_bounds[placed.asset]=[]
			macro_bounds[placed.asset].append(placed.pose*rows[placed.asset].aabb)
		var region=256 if rows[placed.asset].category in ["cliffs","huge_boulders"] else 128
		var key="%s:%d:%d" % [placed.asset,floori(origin.x/region),floori(origin.z/region)]
		if not groups.has(key): groups[key]={"asset":placed.asset,"items":[]}
		groups[key].items.append(placed)
	var index=0
	for group in groups.values():
		var id: String=group.asset
		if not mesh_cache.has(id):
			mesh_cache[id]=load(rows[id].mesh)
			assert(mesh_cache[id]!=null,"Missing runtime geology mesh: "+id)
			materials[id]=_material(rows[id])
		_batch(group.items,mesh_cache[id],materials[id],rows[id].category)
		if not rows[id].grass.is_empty():
			var grassy: Array=[]
			for placed in group.items:
				if placed.grass: grassy.append(placed)
			if not grassy.is_empty():
				if not grass_material:
					grass_material=ShaderMaterial.new()
					grass_material.shader=preload("res://assets/graphics/mineral_grass.gdshader")
					grass_material.set_shader_parameter("grass_texture",load(ROOT+"/textures/grass.png"))
					library.lighting.register(grass_material)
				_batch(grassy,load(rows[id].grass),grass_material,"grass")
		index+=1
		if checkpoint.is_valid() and index%12==0:
			await checkpoint.call("Seating mineral scenery · %d / %d regions" % [index,groups.size()],100.0*index/groups.size())
	apply_quality(profile)
	macro_ready=true

func _material(row: Dictionary) -> ShaderMaterial:
	var material=ShaderMaterial.new()
	material.shader=SHADER
	material.set_shader_parameter("glacier",row.family=="glacier")
	material.set_shader_parameter("color_saturation",.60 if row.family=="sedimentary" else .35)
	# Match the weathered terrain's value range while keeping authored strata
	# and fracture detail. Untinted bakes read as pale cut-outs on the scarp.
	material.set_shader_parameter("rock_tint",Color(.46,.49,.52))
	material.set_shader_parameter("support_height",support_height)
	material.set_shader_parameter("support_exposure",exposure)
	material.set_shader_parameter("support_origin",field.MASK_ORIGIN)
	material.set_shader_parameter("support_size",Vector2(field.MASK_SIZE))
	material.set_shader_parameter("mineral_detail",load(ROOT+"/textures/rock_detail.jpg"))
	library.lighting.register(material)
	_set_textures(material,row,quality)
	return material

func _set_textures(material: ShaderMaterial, row: Dictionary, profile) -> void:
	var level: String=["low","balanced","high"][profile.level]
	if stream_macro_textures and profile.level==2 and macro_bounds.has(row.id) and not high_macros.has(row.id): level="balanced"
	for channel in ["albedo","normal","roughness"]:
		material.set_shader_parameter(channel+"_map",load(row.textures[level][channel]))
	material.set_shader_parameter("snow_albedo",library.texture("snow","albedo"))
	material.set_shader_parameter("snow_normal",library.texture("snow","normal"))
	material.set_shader_parameter("terrain_rock",library.texture("rock","albedo"))
	material.set_shader_parameter("detail_depth",.009 if profile.level==2 else .005)

func _batch(items: Array, mesh: Mesh, material: Material, category: String) -> void:
	var mm=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_custom_data=true
	mm.mesh=mesh
	mm.instance_count=items.size()
	var bounds=AABB()
	for i in items.size():
		var placed: Dictionary=items[i]
		mm.set_instance_transform(i,placed.pose)
		mm.set_instance_custom_data(i,Color(placed.snow,placed.moss,1.0 if placed.solid else 0.0,float(placed.id%251)/251.0))
		var box: AABB=placed.pose*mesh.get_aabb()
		bounds=box if i==0 else bounds.merge(box)
	mm.custom_aabb=bounds.grow(.15)
	_instance(mm,material,category)

func _instance(mm: MultiMesh, material: Material, category: String) -> void:
	var instance=MultiMeshInstance3D.new()
	instance.multimesh=mm
	instance.material_override=material
	instance.gi_mode=GeometryInstance3D.GI_MODE_STATIC if category not in ["small","grass"] else GeometryInstance3D.GI_MODE_DISABLED
	instance.set_meta("category",category)
	instance.name="Minerals_"+category
	add_child(instance)
	batches.append(instance)

func apply_quality(profile) -> void:
	quality=profile
	high_macros.clear(); pending_macros.clear(); macro_timer=0.0
	for id in materials: _set_textures(materials[id],rows[id],profile)
	for batch in batches:
		var category: String=batch.get_meta("category")
		batch.lod_bias=[.35,.6,1.0][profile.level]
		batch.visibility_range_end=180.0 if category=="small" else (1000.0 if category=="medium" else (3500.0 if category=="large" else 0.0))
		batch.visibility_range_end_margin=16.0
		batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if category in ["small","grass"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if category=="grass":
			batch.visible=profile.level>0
			batch.visibility_range_end=60.0 if profile.level==2 else 35.0

func _process(dt: float) -> void:
	if not macro_ready or not stream_macro_textures or quality.level!=2: return
	var camera=get_viewport().get_camera_3d()
	if camera==null: return
	var started = frame_costs.begin() if frame_costs else 0
	macro_timer-=dt
	if macro_timer<=0:
		macro_timer=.5
		pending_macros.clear()
		for id in macro_bounds:
			var nearest=INF
			for box: AABB in macro_bounds[id]:
				var p=camera.global_position
				var closest=Vector3(clampf(p.x,box.position.x,box.end.x),clampf(p.y,box.position.y,box.end.y),clampf(p.z,box.position.z,box.end.z))
				nearest=minf(nearest,p.distance_squared_to(closest))
			var want_high=nearest<pow(420.0 if high_macros.has(id) else 280.0,2)
			if want_high!=high_macros.has(id): pending_macros.append({"id":id,"high":want_high,"distance":nearest})
		pending_macros.sort_custom(func(a,b): return a.distance<b.distance)
	# Shared source textures change at most twice per frame. Geometry and all
	# collision remain resident; distant macro formations use their authored mips.
	for i in mini(2,pending_macros.size()):
		var item: Dictionary=pending_macros.pop_front()
		if item.high: high_macros[item.id]=true
		else: high_macros.erase(item.id)
		_set_textures(materials[item.id],rows[item.id],quality)
	if frame_costs: frame_costs.end(&"mineral_streaming",started)

func _prepared_batches(preparation, checkpoint: Callable) -> void:
	var index = 0
	for group in preparation.minerals:
		if field.job.is_cancelled(): return
		var id: String = group.asset
		if not mesh_cache.has(id):
			mesh_cache[id] = load(rows[id].mesh)
			materials[id] = _material(rows[id])
		var mm = MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_custom_data = true
		mm.mesh = mesh_cache[id]; mm.instance_count = group.buffer.size()/16
		mm.custom_aabb = group.bounds; mm.buffer = group.buffer
		_instance(mm,materials[id],group.category)
		if not group.grass.is_empty() and not rows[id].grass.is_empty():
			if not grass_material:
				grass_material = ShaderMaterial.new(); grass_material.shader = preload("res://assets/graphics/mineral_grass.gdshader")
				grass_material.set_shader_parameter("grass_texture",load(ROOT+"/textures/grass.png")); library.lighting.register(grass_material)
			var grassy: Array = []
			for placed_id in group.grass: grassy.append(field.geology.placements[placed_id])
			_batch(grassy,load(rows[id].grass),grass_material,"grass")
		index += 1
		field.job.advance()
		if checkpoint.is_valid() and index%12==0: await checkpoint.call("Placing mineral scenery · %d / %d regions" % [index,preparation.minerals.size()],100.0*index/preparation.minerals.size())
	preparation.minerals.clear()
