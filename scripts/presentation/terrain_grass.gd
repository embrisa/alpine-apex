extends Node3D
## Camera-resident, deterministic grass cells. Scene-owned and never persisted.
const Placement = preload("res://scripts/presentation/grass_placement.gd")
const Motion = preload("res://scripts/presentation/grass_motion.gd")
const MANIFEST = "res://assets/graphics/grass/manifest.json"
const MAX_CELLS = 625
const CELLS_PER_FRAME = 3
var field
var assets
var quality
var placement
var motion = Motion.new()
var cells: Dictionary = {}
var pending: Array[Vector2i] = []
var mesh_cache: Dictionary = {}
var materials: Array[ShaderMaterial] = []
var last_cell = Vector2i(2147483647,2147483647)
var distance_m = 85.0
var density = 1.0
var built = false
var stream_time = 0.0
func build(surface, library, profile) -> void:
	field=surface; assets=library
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var heights = {}
	for record in catalog.assets:
		mesh_cache[record.id+"_lod"+str(int(record.lod))]=load(record.path)
		heights[record.id]=record.height
	placement=Placement.new(field,heights)
	for lod in 2:
		var material=ShaderMaterial.new()
		material.shader=preload("res://assets/graphics/terrain_grass.gdshader")
		material.set_shader_parameter("lod_near",1.0 if lod==0 else 0.0)
		assets.lighting.register(material); assets.wind_receivers.append(material)
		motion.register(material); materials.append(material)
	assets.wind_ready=false
	built=true; apply_quality(profile)
func bind_minerals(minerals) -> void:
	if minerals and minerals.grass_material: motion.register(minerals.grass_material)
func apply_quality(profile) -> void:
	quality=profile; distance_m=clampf(profile.scrub_distance_m,20,200); density=clampf(profile.scrub_density,0,1)
	for material in materials: material.set_shader_parameter("grass_distance",distance_m)
	# Rebuild bounded resident cells using the same ordered candidates.
	_clear_cells(); last_cell=Vector2i(2147483647,2147483647)
	if density==0: motion.reset()
func reset() -> void: motion.reset()
func update_actor(actor: Vector3, velocity: Vector3, dt: float, active: bool) -> void:
	if density>0: motion.update(actor,velocity,dt,active)
func _process(dt: float) -> void:
	if not built or density<=0: return
	if "job" in field and field.job and field.job.is_cancelled(): _clear_cells(); return
	# Residency may change while wind/interaction is paused (menus or camera
	# review). Fade newly submitted cells without advancing either animation.
	stream_time+=maxf(0,dt)
	for material in materials: material.set_shader_parameter("grass_stream_time",stream_time)
	var camera=get_viewport().get_camera_3d()
	if camera: stream(camera.global_position)
func stream(camera_position: Vector3, budget: int = CELLS_PER_FRAME) -> void:
	if density<=0 or not built: return
	var key=Vector2i(floori(camera_position.x/Placement.CELL),floori(camera_position.z/Placement.CELL))
	if key!=last_cell:
		last_cell=key; pending.clear()
		var wanted: Dictionary = {}
		var reach=ceili(distance_m/Placement.CELL)+1
		var keys: Array[Vector2i] = []
		for z in range(-reach,reach+1):
			for x in range(-reach,reach+1):
				var at=key+Vector2i(x,z)
				if Vector2(x,z).length()*Placement.CELL>distance_m+Placement.CELL: continue
				if not field.bounds().intersects(Rect2(Vector2(at)*Placement.CELL,Vector2.ONE*Placement.CELL)): continue
				keys.append(at)
		keys.sort_custom(func(a,b): return a.distance_squared_to(key)<b.distance_squared_to(key) if a.distance_squared_to(key)!=b.distance_squared_to(key) else (a.y<b.y if a.y!=b.y else a.x<b.x))
		for at in keys.slice(0,MAX_CELLS):
			wanted[at]=true
			if not cells.has(at): pending.append(at)
		for at in cells.keys():
			if not wanted.has(at):
				for batch in cells[at]: batch.free()
				cells.erase(at)
	for i in mini(budget,pending.size()): _create_cell(pending.pop_front())
func _create_cell(key: Vector2i) -> void:
	var groups: Dictionary = {}
	for item in placement.cell(key):
		if item.rank>=density: continue
		if not groups.has(item.asset): groups[item.asset]=[]
		groups[item.asset].append(item)
	var batches: Array = []
	for id in groups:
		for lod in 2:
			var mesh: Mesh=mesh_cache[id+"_lod"+str(lod+1)]
			var mm=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.use_custom_data=true
			mm.mesh=mesh; mm.instance_count=groups[id].size()
			var bounds=AABB()
			for i in groups[id].size():
				var item: Dictionary=groups[id][i]
				mm.set_instance_transform(i,item.pose)
				mm.set_instance_custom_data(i,Color(item.phase,item.height,item.coverage,1))
				var box: AABB=item.pose*mesh.get_aabb()
				bounds=box if i==0 else bounds.merge(box)
			mm.custom_aabb=bounds.grow(.65) # > maximum blade sway + swept bend.
			var batch=MultiMeshInstance3D.new(); batch.multimesh=mm; batch.material_override=materials[lod]
			batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
			batch.visibility_range_end=distance_m+Placement.CELL*2
			batch.set_instance_shader_parameter("grass_birth",stream_time)
			add_child(batch); batches.append(batch)
	cells[key]=batches
func _clear_cells() -> void:
	for batches in cells.values():
		for batch in batches: batch.free()
	cells.clear(); pending.clear()
func population() -> int:
	var count=0
	for batches in cells.values():
		for batch in batches: count+=batch.multimesh.instance_count
	return count/2
func _exit_tree() -> void:
	motion.reset()
	if assets:
		for material in materials:
			assets.wind_receivers.erase(material); assets.lighting.materials.erase(material)
	motion.receivers.clear()
