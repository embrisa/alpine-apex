extends Node3D
## Shared centimetre meshes in bounded camera cells. No persistent/physical data.
const Placement=preload("res://scripts/presentation/gravel_placement.gd")
const ROOT="res://assets/graphics/gravel/"
const MAX_CELLS=49
const WORKERS=2
class CellWork extends RefCounted:
	var id: int
	var key: Vector2i
	var placement
	var items=[]
	func run() -> void: items=placement.cell(key)
var field
var library
var quality
var placement
var materials: Array[ShaderMaterial]=[]
var meshes={}
var cells={}
var work={}
var pending: Array[Vector2i]=[]
var wanted={}
var last_cell=Vector2i(2147483647,2147483647)
var mode="all"
var distance_m=16.0
var stream_time=0.0
var grass_mask=Image.create(128,128,false,Image.FORMAT_R8)
var grass_texture: ImageTexture
var built=false
func build(source,assets,profile,height_texture: Texture2D) -> void:
	field=source; library=assets
	grass_mask.fill(Color.WHITE); grass_texture=ImageTexture.create_from_image(grass_mask)
	placement=Placement.new(field)
	for kind in ["dense","sparse"]:
		for variant in 4:
			for lod in [0,2]:
				var id="%s_%d_lod%d" % [kind,variant,lod]
				meshes[id]=load(ROOT+id+".res")
	for lod in 2:
		var material=ShaderMaterial.new(); material.shader=preload("res://assets/graphics/rock_gravel.gdshader")
		material.set_shader_parameter("near_lod",lod==0)
		material.set_shader_parameter("albedo_map",load(ROOT+"albedo.res"))
		material.set_shader_parameter("normal_map",load(ROOT+"normal.res"))
		material.set_shader_parameter("roughness_map",load(ROOT+"metallic_roughness.res"))
		material.set_shader_parameter("support_height",height_texture)
		material.set_shader_parameter("grass_mask",grass_texture)
		material.set_shader_parameter("support_origin",Vector2(field.X_MIN,field.Z_MIN))
		material.set_shader_parameter("support_size",Vector2(field.NX,field.NZ))
		library.lighting.register(material); materials.append(material)
	built=true; apply_quality(profile)
func apply_quality(profile) -> void:
	quality=profile; distance_m=[8.0,12.0,16.0][profile.level]
	for material in materials: material.set_shader_parameter("gravel_distance",distance_m)
	clear_cells()
func set_mode(selected: String) -> void:
	assert(selected in ["all","off","dense","sparse"])
	mode=selected
	if placement: placement.mode=mode
	clear_cells()
func _process(dt: float) -> void:
	if not built or mode=="off": return
	if "job" in field and field.job and field.job.is_cancelled(): clear_cells(); return
	stream_time+=maxf(0,dt)
	for material in materials: material.set_shader_parameter("stream_time",stream_time)
	var camera=get_viewport().get_camera_3d()
	if camera: stream(camera.global_position,WORKERS,true)
func stream(camera: Vector3,budget: int=WORKERS,asynchronous: bool=false) -> void:
	if not built or mode=="off": return
	var key=Vector2i(floori(camera.x/Placement.CELL),floori(camera.z/Placement.CELL))
	if key!=last_cell:
		last_cell=key; pending.clear(); wanted.clear()
		var keys: Array[Vector2i]=[]
		var reach=ceili(distance_m/Placement.CELL)+1
		for z in range(-reach,reach+1):
			for x in range(-reach,reach+1):
				var at=key+Vector2i(x,z)
				if Vector2(x,z).length()*Placement.CELL>distance_m+Placement.CELL: continue
				if field.bounds().intersects(Rect2(Vector2(at)*Placement.CELL,Vector2.ONE*Placement.CELL)): keys.append(at)
		keys.sort_custom(func(a,b): return a.distance_squared_to(key)<b.distance_squared_to(key) if a.distance_squared_to(key)!=b.distance_squared_to(key) else (a.y<b.y if a.y!=b.y else a.x<b.x))
		for at in keys.slice(0,MAX_CELLS):
			wanted[at]=true
			if not cells.has(at) and not work.has(at): pending.append(at)
		for at in cells.keys():
			if not wanted.has(at):
				for batch in cells[at]: batch.free()
				cells.erase(at)
	var published=0
	for at in work.keys():
		var job: CellWork=work[at]
		if not WorkerThreadPool.is_task_completed(job.id): continue
		WorkerThreadPool.wait_for_task_completion(job.id); work.erase(at)
		if wanted.has(at) and not cells.has(at): create_cell(at,job.items,job.placement.mask); published+=1
	var available=budget-work.size() if asynchronous else budget-published
	for i in mini(maxi(0,available),pending.size()):
		var at: Vector2i=pending.pop_front()
		if asynchronous:
			var job=CellWork.new(); job.key=at; job.placement=Placement.new(field,mode)
			job.id=WorkerThreadPool.add_task(job.run,false,"Gravel cell"); work[at]=job
		else:
			var items=placement.cell(at)
			create_cell(at,items,placement.mask)
func create_cell(key: Vector2i,items: Array,mask: Image) -> void:
	if items.is_empty(): cells[key]=[]; return
	var offset=key*16-Vector2i.ONE
	for y in 18:
		for x in 18: grass_mask.set_pixel(posmod(offset.x+x,128),posmod(offset.y+y,128),mask.get_pixel(x,y))
	grass_texture.update(grass_mask)
	var groups={}; var batches=[]
	for item in items:
		if not groups.has(item.asset): groups[item.asset]=[]
		groups[item.asset].append(item)
	for id in groups:
		for lod in 2:
			var mm=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.use_custom_data=true
			mm.mesh=meshes[id+"_lod"+str(lod*2)]; mm.instance_count=groups[id].size()
			var box=AABB()
			for i in groups[id].size():
				var item: Dictionary=groups[id][i]
				mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,item.origin)); mm.set_instance_custom_data(i,item.patch)
				var bounds=AABB(item.origin-Vector3(0,.6,0),Vector3(.5,1.2,.5))
				box=bounds if i==0 else box.merge(bounds)
			mm.custom_aabb=box
			var batch=MultiMeshInstance3D.new(); batch.multimesh=mm; batch.material_override=materials[lod]
			batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; batch.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
			batch.visibility_range_end=(5.5 if lod==0 else distance_m)+box.size.length()*.5
			batch.set_instance_shader_parameter("birth",stream_time)
			batch.set_meta("stones",groups[id].size()*(275 if id.begins_with("dense") else 2))
			add_child(batch); batches.append(batch)
	cells[key]=batches
func population() -> Dictionary:
	var totals={"dense":0,"sparse":0,"batches":0,"cells":cells.size(),"jobs":work.size()}
	for batches in cells.values():
		for i in range(0,batches.size(),2):
			var count=int(batches[i].get_meta("stones")); var dense=count/batches[i].multimesh.instance_count==275
			totals["dense" if dense else "sparse"]+=count
			totals.batches+=2
	return totals
func clear_cells() -> void:
	for job in work.values(): WorkerThreadPool.wait_for_task_completion(job.id)
	work.clear(); wanted.clear(); pending.clear()
	for batches in cells.values():
		for batch in batches: batch.free()
	cells.clear(); last_cell=Vector2i(2147483647,2147483647)
func _exit_tree() -> void:
	clear_cells()
	if library:
		for material in materials: library.lighting.materials.erase(material)
