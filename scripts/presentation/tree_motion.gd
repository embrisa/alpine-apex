extends RefCounted
## Spatially bounded canopy springs. Four trees / 48 clusters, no per-tree Nodes.
const Dynamics = preload("res://scripts/core/tree_dynamics.gd")
const CELL = 16.0
const SLOTS = 4
var grid: Dictionary = {}
var trees: Array = []
var prepared
var physical_trees
var slots: Array = [null,null,null,null]
var assets
var definitions: Dictionary
var previous = Vector3.ZERO
var initialized = false
var accumulator = 0.0
var anchors = PackedVector4Array()
var angles = PackedVector4Array()
var tick_count = 0
var uploaded_anchors = PackedVector4Array()
var uploaded_angles = PackedVector4Array()
var uploaded_materials: Dictionary = {}
var uploaded_active = false
var material_ids: Array[String] = ["TD_Conifer","FC_Tree","FC_Broadleaf","FC_Tree_Mid","FC_Broadleaf_Mid"]

func _init(library = null, definition_path: String = "res://assets/graphics/treedesigner_branches.json") -> void:
	assets = library
	anchors.resize(SLOTS)
	angles.resize(SLOTS*Dynamics.COUNT)
	definitions = {} if definition_path.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(definition_path))

func add_tree(transform_value: Transform3D, variant) -> void:
	var id = trees.size()
	trees.append({"transform":transform_value,"variant":variant})
	var key = Vector2i(floori(transform_value.origin.x/CELL),floori(transform_value.origin.z/CELL))
	if not grid.has(key): grid[key] = []
	grid[key].append(id)

func reset() -> void:
	slots = [null,null,null,null]
	anchors.fill(Vector4.ZERO)
	angles.fill(Vector4.ZERO)
	accumulator = 0.0
	initialized = false
	_upload()

func update(actor: Vector3, velocity: Vector3, dt: float, active: bool) -> void:
	if not initialized or previous.distance_to(actor)>30.0:
		reset()
		previous = actor
		initialized = true
	if not active:
		previous = actor
		return
	var key = Vector2i(floori(actor.x/CELL),floori(actor.z/CELL))
	var candidates: Array = []
	var nearby = PackedInt32Array()
	if prepared: nearby = physical_trees.nearby(actor,12.0)
	else:
		for x in range(-1,2):
			for z in range(-1,2): nearby.append_array(PackedInt32Array(grid.get(key+Vector2i(x,z),[])))
	for id in nearby:
		var distance = _position(id).distance_squared_to(actor)
		if distance<144.0: candidates.append({"id":id,"distance":distance})
	candidates.sort_custom(func(a,b): return a.distance<b.distance)
	var wanted: Array = []
	for c in candidates.slice(0,SLOTS): wanted.append(c.id)
	for s in SLOTS:
		if slots[s]!=null and not slots[s].id in wanted:
			slots[s] = null
	for id in wanted:
		var present = false
		for slot in slots:
			if slot!=null and slot.id==id: present = true
		if present: continue
		for s in SLOTS:
			if slots[s]==null:
				slots[s] = {"id":id,"inverse":_transform(id).affine_inverse(),"dynamics":Dynamics.new(definitions[str(_variant(id))].branches)}
				break
	accumulator += minf(maxf(dt,0),.1)
	var steps = int((accumulator+.0000001)/Dynamics.DT)
	for tick in steps:
		var a = previous.lerp(actor,float(tick)/maxi(1,steps))+Vector3.UP*.95
		var b = previous.lerp(actor,float(tick+1)/maxi(1,steps))+Vector3.UP*.95
		for slot in slots:
			if slot==null: continue
			var inv: Transform3D = slot.inverse
			slot.dynamics.step(inv*a,inv*b,inv.basis*velocity,.55*inv.basis.get_scale().x)
		tick_count += 1
	accumulator -= steps*Dynamics.DT
	if steps>0: previous = actor
	anchors.fill(Vector4.ZERO)
	angles.fill(Vector4.ZERO)
	for s in SLOTS:
		if slots[s]==null: continue
		var p: Vector3 = _position(slots[s].id)
		anchors[s] = Vector4(p.x,p.y,p.z,1)
		for i in Dynamics.COUNT:
			var a: Vector3 = slots[s].dynamics.angles[i]
			angles[s*Dynamics.COUNT+i] = Vector4(a.x,a.y,a.z,0)
	_upload()

func _upload() -> void:
	if not assets: return
	var anchors_changed = anchors!=uploaded_anchors
	var angles_changed = angles!=uploaded_angles
	if angles_changed:
		uploaded_active = false
		for value in angles:
			if value!=Vector4.ZERO:
				uploaded_active = true
				break
	for id in material_ids:
		if not assets.named_materials.has(id):
			uploaded_materials.erase(id)
			continue
		var material: ShaderMaterial = assets.named_materials[id]
		var new_material = uploaded_materials.get(id)!=material
		if anchors_changed or new_material: material.set_shader_parameter("contact_anchors",anchors)
		if angles_changed or new_material:
			material.set_shader_parameter("contact_angles",angles)
			material.set_shader_parameter("contact_active",uploaded_active)
		uploaded_materials[id] = material
	# Keep independent snapshots: script-side packed arrays share assignments.
	if anchors_changed: uploaded_anchors = anchors.duplicate()
	if angles_changed: uploaded_angles = angles.duplicate()

func bind_prepared(placement_data, tree_data) -> void:
	prepared = placement_data; physical_trees = tree_data

func _position(id: int) -> Vector3:
	return prepared.positions[id] if prepared else trees[id].transform.origin

func _transform(id: int) -> Transform3D:
	return prepared.pose_at(id) if prepared else trees[id].transform

func _variant(id: int):
	return prepared.assets[prepared.asset_indices[id]] if prepared else trees[id].variant
