extends Node3D
## Shared centimetre meshes in bounded camera cells. No persistent/physical data.
const Placement=preload("res://scripts/presentation/gravel_placement.gd")
const ROOT="res://assets/graphics/gravel/"
const MAX_CELLS=49
const WORKERS=2
const RETIRE_PER_FRAME=8
class CellWork extends RefCounted:
	var id: int
	var key: Vector2i
	var placement
	var groups=[]
	func run() -> void: groups=placement.pack(placement.cell(key))
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
var frame_costs
var retiring: Array=[]
## Candidate offsets sorted once per reach: (distance, dy, dx) order equals the
## former per-change lambda sort of absolute keys.
static var sorted_offsets: Dictionary={}
static func offsets_for(reach: int) -> Array:
	if sorted_offsets.has(reach): return sorted_offsets[reach]
	var rows: Array=[]
	for z in range(-reach,reach+1):
		for x in range(-reach,reach+1): rows.append([x*x+z*z,z,x])
	rows.sort()
	var result: Array=[]
	for row in rows: result.append(Vector2i(row[2],row[1]))
	sorted_offsets[reach]=result
	return result
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
	var started=frame_costs.begin() if frame_costs else 0
	if camera: stream(camera.global_position,WORKERS,true)
	if frame_costs: frame_costs.end(&"stream_gravel",started)
func stream(camera: Vector3,budget: int=WORKERS,asynchronous: bool=false) -> void:
	if not built or mode=="off": return
	var key=Vector2i(floori(camera.x/Placement.CELL),floori(camera.z/Placement.CELL))
	if key!=last_cell:
		last_cell=key; pending.clear(); wanted.clear()
		var keys: Array[Vector2i]=[]
		var reach=ceili(distance_m/Placement.CELL)+1
		var bounds: Rect2=field.bounds()
		for offset in offsets_for(reach):
			if Vector2(offset).length()*Placement.CELL>distance_m+Placement.CELL: continue
			var at=key+offset
			if bounds.intersects(Rect2(Vector2(at)*Placement.CELL,Vector2.ONE*Placement.CELL)): keys.append(at)
		for at in keys.slice(0,MAX_CELLS):
			wanted[at]=true
			if not cells.has(at) and not work.has(at): pending.append(at)
		for at in cells.keys():
			if not wanted.has(at):
				# Leaving cells sit beyond gravel_distance; free them a few per frame.
				retiring.append_array(cells[at])
				cells.erase(at)
	for i in mini(RETIRE_PER_FRAME,retiring.size()): retiring.pop_back().free()
	var published=0
	for at in work.keys():
		var job: CellWork=work[at]
		if not WorkerThreadPool.is_task_completed(job.id): continue
		WorkerThreadPool.wait_for_task_completion(job.id); work.erase(at)
		if wanted.has(at) and not cells.has(at): create_cell(at,job.groups,job.placement.mask); published+=1
	var available=budget-work.size() if asynchronous else budget-published
	for i in mini(maxi(0,available),pending.size()):
		var at: Vector2i=pending.pop_front()
		if asynchronous:
			var job=CellWork.new(); job.key=at; job.placement=Placement.new(field,mode)
			job.id=WorkerThreadPool.add_task(job.run,false,"Gravel cell"); work[at]=job
		else:
			create_cell(at,placement.pack(placement.cell(at)),placement.mask)
func create_cell(key: Vector2i,groups: Array,mask: Image) -> void:
	if groups.is_empty(): cells[key]=[]; return
	_blit_mask(key*16-Vector2i.ONE,mask)
	grass_texture.update(grass_mask)
	var batches=[]
	for group in groups:
		var id: String=group.asset
		var box: AABB=group.bounds
		for lod in 2:
			var mm=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.use_custom_data=true
			mm.mesh=meshes[id+"_lod"+str(lod*2)]; mm.instance_count=group.count
			mm.buffer=group.buffer # Packed on the worker; one upload per batch.
			mm.custom_aabb=box
			var batch=MultiMeshInstance3D.new(); batch.multimesh=mm; batch.material_override=materials[lod]
			batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; batch.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
			batch.visibility_range_end=(5.5 if lod==0 else distance_m)+box.size.length()*.5
			batch.set_instance_shader_parameter("birth",stream_time)
			batch.set_meta("stones",group.count*(275 if id.begins_with("dense") else 2))
			add_child(batch); batches.append(batch)
	cells[key]=batches
func _blit_mask(offset: Vector2i,mask: Image) -> void:
	# The 18x18 cell mask wraps inside the 128x128 shared mask: at most four
	# rectangle copies replace 324 pixel writes with identical R8 values.
	var start=Vector2i(posmod(offset.x,128),posmod(offset.y,128))
	var width_a=mini(18,128-start.x); var height_a=mini(18,128-start.y)
	grass_mask.blit_rect(mask,Rect2i(0,0,width_a,height_a),start)
	if width_a<18: grass_mask.blit_rect(mask,Rect2i(width_a,0,18-width_a,height_a),Vector2i(0,start.y))
	if height_a<18: grass_mask.blit_rect(mask,Rect2i(0,height_a,width_a,18-height_a),Vector2i(start.x,0))
	if width_a<18 and height_a<18: grass_mask.blit_rect(mask,Rect2i(width_a,height_a,18-width_a,18-height_a),Vector2i.ZERO)
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
	for batch in retiring: batch.free()
	retiring.clear()
	cells.clear(); last_cell=Vector2i(2147483647,2147483647)
func _exit_tree() -> void:
	clear_cells()
	if library:
		for material in materials: library.lighting.materials.erase(material)
