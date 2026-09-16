extends Node3D
## Camera-resident, deterministic grass cells. Scene-owned and never persisted.
const Placement = preload("res://scripts/presentation/grass_placement.gd")
const Motion = preload("res://scripts/presentation/grass_motion.gd")
const MANIFEST = "res://assets/graphics/grass/manifest.json"
const MAX_CELLS = 625
const CELLS_PER_FRAME = 3
class CellWork extends RefCounted:
	var id: int
	var key: Vector2i
	var source
	var density: float
	var mesh_bounds: Dictionary
	var batches: Array = []
	var milliseconds = 0.0
	func run() -> void:
		var started=Time.get_ticks_usec()
		batches=source.prepare_cell(key,density,mesh_bounds)
		milliseconds=(Time.get_ticks_usec()-started)/1000.0

var field
var assets
var quality
var placement
var motion = Motion.new()
var cells: Dictionary = {}
var pending: Array[Vector2i] = []
var mesh_cache: Dictionary = {}
var mesh_bounds: Dictionary = {}
var materials: Array[ShaderMaterial] = []
var last_cell = Vector2i(2147483647,2147483647)
var distance_m = 85.0
var density = 1.0
var built = false
var stream_time = 0.0
var wanted: Dictionary = {}
var work: Dictionary = {}
var frame_costs
var preparation_samples = PackedFloat64Array()
func build(surface, library, profile) -> void:
	field=surface; assets=library
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var heights = {}
	for record in catalog.assets:
		var mesh_id=record.id+"_lod"+str(int(record.lod))
		mesh_cache[mesh_id]=load(record.path)
		mesh_bounds[mesh_id]=mesh_cache[mesh_id].get_aabb()
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
	var started=frame_costs.begin() if frame_costs else 0
	for material in materials: material.set_shader_parameter("grass_stream_time",stream_time)
	var camera=get_viewport().get_camera_3d()
	if camera: stream(camera.global_position,CELLS_PER_FRAME,true)
	if frame_costs: frame_costs.end("stream_grass",started)
func stream(camera_position: Vector3, budget: int = CELLS_PER_FRAME, asynchronous: bool = false) -> void:
	if density<=0 or not built: return
	var key=Vector2i(floori(camera_position.x/Placement.CELL),floori(camera_position.z/Placement.CELL))
	if key!=last_cell:
		last_cell=key; pending.clear()
		wanted.clear()
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
			if not cells.has(at) and not work.has(at): pending.append(at)
		for at in cells.keys():
			if not wanted.has(at):
				for batch in cells[at]: batch.free()
				cells.erase(at)
	var submitted=0
	for at in work.keys():
		var job: CellWork=work[at]
		if not WorkerThreadPool.is_task_completed(job.id): continue
		WorkerThreadPool.wait_for_task_completion(job.id)
		work.erase(at)
		if frame_costs and frame_costs.enabled and preparation_samples.size()<200000: preparation_samples.append(job.milliseconds)
		if wanted.has(at) and not cells.has(at):
			_publish_cell(at,job.batches); submitted+=1
	var admission=budget-work.size() if asynchronous else budget-submitted
	for i in mini(maxi(0,admission),pending.size()):
		var at: Vector2i=pending.pop_front()
		if asynchronous:
			# Each job owns its RNG/noise and output; only frozen terrain/ecology
			# and collision broad-phase bounds are read. No scene/GPU work here.
			var job=CellWork.new(); job.key=at
			job.source=Placement.new(field,placement.heights)
			job.density=density; job.mesh_bounds=mesh_bounds
			job.id=WorkerThreadPool.add_task(job.run,false,"Grass cell")
			work[at]=job
		else: _publish_cell(at,placement.prepare_cell(at,density,mesh_bounds))
func _publish_cell(key: Vector2i, prepared: Array) -> void:
	var batches: Array = []
	for group in prepared:
		for lod in 2:
			var mesh: Mesh=mesh_cache[group.asset+"_lod"+str(lod+1)]
			var mm=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.use_custom_data=true
			mm.mesh=mesh; mm.instance_count=group.buffer.size()/16
			mm.buffer=group.buffer
			mm.custom_aabb=group.bounds[lod] # Includes blade sway + swept bend.
			var batch=MultiMeshInstance3D.new(); batch.multimesh=mm; batch.material_override=materials[lod]
			batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
			batch.visibility_range_end=distance_m+Placement.CELL*2
			# The near shader is fully discarded beyond 26 m. Include the entire
			# root envelope when culling a batch, preserving the 18-26 m blend.
			if lod==0: batch.visibility_range_end=26.0+mm.custom_aabb.size.length()*.5
			batch.set_instance_shader_parameter("grass_birth",stream_time)
			add_child(batch); batches.append(batch)
	cells[key]=batches
func _clear_cells() -> void:
	# Quality/cancellation/teardown are boundaries. Retire every task before
	# releasing its frozen inputs; normal frames only collect completed tasks.
	for job in work.values(): WorkerThreadPool.wait_for_task_completion(job.id)
	work.clear(); wanted.clear()
	for batches in cells.values():
		for batch in batches: batch.free()
	cells.clear(); pending.clear()
func population() -> int:
	var count=0
	for batches in cells.values():
		for batch in batches: count+=batch.multimesh.instance_count
	return count/2
func _exit_tree() -> void:
	_clear_cells()
	motion.reset()
	if assets:
		for material in materials:
			assets.wind_receivers.erase(material); assets.lighting.materials.erase(material)
	motion.receivers.clear()
