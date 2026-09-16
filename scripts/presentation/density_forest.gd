extends Node3D
var frame_costs
## Presentation-only residency. Immutable transforms cover the complete forest;
## coarse distant cards and a bounded nearby detail window share per-tree LOD.
const CELL = 32.0
const DETAIL_CELL = 16.0
const FAR_CELL = preload("res://scripts/presentation/forest_placement.gd").FAR_CELL
const LOAD_RADIUS = 128.0
const KEEP_RADIUS = 192.0
const UPLOAD_BUDGET_US = 1000
var host
var job
var regions: Dictionary = {}
var far_groups: Dictionary = {}
var resident: Dictionary = {}
var pending: Array = []
var last_camera = Vector3.INF
var ready_for_updates = false
var residency_image: Image
var residency_texture: ImageTexture
var prepared_bytes = 0
var prepared_meshes: Dictionary = {}

func add_tree(asset: String, pose: Transform3D, height_m: float) -> void:
	var p=pose.origin
	var key=Vector2i(floori(p.x/CELL),floori(p.z/CELL))
	if not regions.has(key): regions[key]={}
	if not regions[key].has(asset): regions[key][asset]={"transforms":[],"height_m":height_m}
	regions[key][asset].transforms.append(pose)
	regions[key][asset].height_m=maxf(regions[key][asset].height_m,height_m)
	var far_key="%d:%d:%s" % [floori(p.x/FAR_CELL),floori(p.z/FAR_CELL),asset]
	if not far_groups.has(far_key): far_groups[far_key]={"asset":asset,"transforms":[],"height_m":height_m}
	far_groups[far_key].transforms.append(pose)
	far_groups[far_key].height_m=maxf(far_groups[far_key].height_m,height_m)

func finish(owner_scenery, checkpoint: Callable) -> void:
	host=owner_scenery
	var track_upload = job!=null and job.snapshot().stage=="forest_uploads"
	if track_upload: job.set_total(far_groups.size()+regions.size())
	residency_image=Image.create(192,192,false,Image.FORMAT_R8)
	residency_image.fill(Color(0,0,0,1))
	residency_texture=ImageTexture.create_from_image(residency_image)
	var count=0
	for group in far_groups.values():
		if job and job.is_cancelled(): return
		_make_batch(group.asset,group,2)
		count+=1
		if track_upload: job.advance()
		if checkpoint.is_valid() and count%24==0:
			await checkpoint.call("Building distant woodland · %d / %d" % [count,far_groups.size()],100.0*count/far_groups.size())
	far_groups.clear()
	# Immutable placement metadata is prepared once, before skiing. The same
	# upload and conservative bounds serve near, mid and shadow geometry.
	count = 0
	for region in regions.values():
		if job and job.is_cancelled(): return
		for asset in region:
			var group: Dictionary = region[asset]
			# Prepare the exact same immutable meshes before their first skiing
			# frame; lazy derivative loading previously stalled forest entry.
			for lod in [0,1,5]: _mesh_for(asset,lod)
			if not group.has("prepared"): group.prepared = host.prepare_tree_batch(group.transforms,group.height_m,host.assets.tree_render_bounds(asset))
			group.coverage_padding = _coverage_padding(group,host.assets.tree_record(asset))
			group.detail_groups = _detail_groups(group,asset)
			prepared_bytes += group.prepared.buffer.size()*4
			if group.detail_groups.size()>1:
				for child in group.detail_groups: prepared_bytes+=child.prepared.buffer.size()*4
		count+=1
		if track_upload: job.advance()
		if checkpoint.is_valid() and count%64==0:
			await checkpoint.call("Preparing woodland detail · %d / %d" % [count,regions.size()],100.0*count/regions.size())
	ready_for_updates=true

func _detail_groups(group: Dictionary, asset: String) -> Array:
	# Split immutable render groups once; residency and shadow ownership stay
	# on the original 32 m cells. No per-frame instance traversal or uploads.
	var values: PackedFloat32Array = group.prepared.buffer
	var cells: Dictionary = {}
	for i in range(0,values.size(),12):
		var pose = Transform3D(Basis(Vector3(values[i],values[i+4],values[i+8]),Vector3(values[i+1],values[i+5],values[i+9]),Vector3(values[i+2],values[i+6],values[i+10])),Vector3(values[i+3],values[i+7],values[i+11]))
		var key=Vector2i(floori(pose.origin.x/DETAIL_CELL),floori(pose.origin.z/DETAIL_CELL))
		if not cells.has(key): cells[key]=[]
		cells[key].append(pose)
	var result: Array=[]
	if cells.size()==1:
		return [{"transforms":[],"height_m":group.height_m,"prepared":group.prepared,"coverage_padding":group.coverage_padding}]
	for poses in cells.values():
		var child={"transforms":[],"height_m":group.height_m,"prepared":host.prepare_tree_batch(poses,group.height_m,host.assets.tree_render_bounds(asset))}
		child.coverage_padding=_coverage_padding(child,host.assets.tree_record(asset))
		result.append(child)
	return result

func _coverage_padding(group: Dictionary, record: Dictionary) -> float:
	# Distance culling uses the batch AABB centre. Enclose the exact crown
	# spheres used by pc_lod_coverage, including bare-tree anchor fallback.
	var center: Vector3 = group.prepared.bounds.get_center()
	var crown = Vector3.ZERO
	var radius = float(record.get("crown_radius",0.0))
	if radius>0.0:
		var c: Array = record.crown_center
		crown=Vector3(c[0],c[1],c[2])
	var padding = 0.0
	# Prepared production groups have no Transform3D array. The uploaded
	# row-major buffer is authoritative for both prepared and direct groups.
	var values: PackedFloat32Array = group.prepared.buffer
	for i in range(0,values.size(),12):
		var pose = Transform3D(Basis(Vector3(values[i],values[i+4],values[i+8]),Vector3(values[i+1],values[i+5],values[i+9]),Vector3(values[i+2],values[i+6],values[i+10])),Vector3(values[i+3],values[i+7],values[i+11]))
		var scale_m = maxf(pose.basis.x.length(),maxf(pose.basis.y.length(),pose.basis.z.length()))
		var anchor = pose*crown if radius>0.0 else pose.origin
		padding=maxf(padding,center.distance_to(anchor)+maxf(0.0,radius)*scale_m)
	return padding+.05

func _mesh_for(asset: String, lod: int) -> Mesh:
	var key = "%s:%d" % [asset,lod]
	if prepared_meshes.has(key): return prepared_meshes[key]
	var mesh: Mesh = host.assets.tree_shadow(asset) if lod==5 else host.assets.mesh("%s_lod%d" % [asset,lod])
	prepared_meshes[key] = mesh
	return mesh

func _make_batch(asset: String, group: Dictionary, lod: int) -> MultiMeshInstance3D:
	var mesh = _mesh_for(asset,lod)
	host._batch(mesh,group.transforms,lod,group.height_m,group.get("prepared",{}))
	var node: MultiMeshInstance3D=host.batches[-1]
	node.set_meta("density_tree",true)
	if lod in [0,1] and group.has("coverage_padding"):
		node.set_meta("coverage_padding",group.coverage_padding)
	node.set_instance_shader_parameter("pc_lod_individual",true)
	node.set_instance_shader_parameter("pc_streamed",true)
	if lod==2:
		var material: ShaderMaterial=node.multimesh.mesh.surface_get_material(0)
		material.set_shader_parameter("pc_detail_residency",residency_texture)
	return node

func _process(_dt: float) -> void:
	if not ready_for_updates: return
	var camera=get_viewport().get_camera_3d()
	if camera==null: return
	var started = frame_costs.begin() if frame_costs else 0
	update_residency(camera.global_position)
	if frame_costs: frame_costs.end(&"forest_residency",started)

func update_residency(camera: Vector3) -> void:
	var dirty=false
	if camera.distance_to(last_camera)>8.0:
		var scan_started = frame_costs.begin() if frame_costs else 0
		last_camera=camera
		pending.clear()
		var p=Vector2(camera.x,camera.z)
		for key in resident.keys():
			var centre=(Vector2(key)+Vector2.ONE*.5)*CELL
			if centre.distance_to(p)>KEEP_RADIUS:
				for node in resident[key]:
					host.remove_batch(node)
					node.queue_free()
				# Keep GPU placement residency identical to the original window.
				for group in regions[key].values():
					group.prepared.multimeshes.clear()
					for child in group.detail_groups: child.prepared.multimeshes.clear()
				resident.erase(key)
				residency_image.set_pixel(key.x+96,key.y+96,Color(0,0,0,1))
				dirty=true
		for z in range(floori((p.y-LOAD_RADIUS)/CELL),floori((p.y+LOAD_RADIUS)/CELL)+1):
			for x in range(floori((p.x-LOAD_RADIUS)/CELL),floori((p.x+LOAD_RADIUS)/CELL)+1):
				var key=Vector2i(x,z)
				if regions.has(key) and not resident.has(key): pending.append(key)
		pending.sort_custom(func(a,b): return ((Vector2(a)+Vector2.ONE*.5)*CELL-p).length_squared()<((Vector2(b)+Vector2.ONE*.5)*CELL-p).length_squared())
		if frame_costs: frame_costs.end(&"stream_forest_scan_evict",scan_started)
	# Preload beyond the visible 64 m detail range. Bounded work per frame keeps
	# region upload independent of the total tree count.
	var new_nodes: Array=[]
	var slice_started = Time.get_ticks_usec()
	for i in mini(3,pending.size()):
		var upload_started = frame_costs.begin() if frame_costs else 0
		var key: Vector2i=pending.pop_front()
		var nodes: Array=[]
		for asset in regions[key]:
			var group: Dictionary=regions[key][asset]
			for child in group.detail_groups:
				for lod in [0,1]: nodes.append(_make_batch(asset,child,lod))
			nodes.append(_make_batch(asset,group,5))
		resident[key]=nodes
		residency_image.set_pixel(key.x+96,key.y+96,Color(1,0,0,1))
		dirty=true
		new_nodes.append_array(nodes)
		if frame_costs: frame_costs.end(&"stream_forest_region",upload_started)
		# Publish a complete region atomically; defer subsequent regions once
		# this frame has spent its preload budget. Far fallback stays intact.
		if Time.get_ticks_usec()-slice_started>=UPLOAD_BUDGET_US: break
	var publish_started = frame_costs.begin() if frame_costs else 0
	if not new_nodes.is_empty(): host.configure_batches(host.quality,new_nodes)
	if dirty: residency_texture.update(residency_image)
	if dirty and frame_costs: frame_costs.end(&"stream_forest_publish",publish_started)

func report() -> Dictionary:
	return {"regions":regions.size(),"resident_regions":resident.size(),"pending_regions":pending.size(),"render_batches":host.batches.size(),"prepared_bytes":prepared_bytes}

func use_prepared(data) -> void:
	regions = data.regions
	far_groups = data.far_groups
