extends RefCounted
## Shared seated poses: rendering and nearby tree motion consume these buffers.
const Contacts = preload("res://scripts/presentation/asset_snow_contacts.gd")
const CELL = 32.0
# Two-triangle cards tolerate coarser grouping; per-tree shader distances stay unchanged.
const FAR_CELL = 384.0
const FAMILY = {"spruce":"spruce","fir":"fir","pine":"pine","birch":"birch","snag":"dead","split_snag":"broken"}
var assets = PackedStringArray()
var asset_indices = PackedInt32Array()
var poses = PackedFloat32Array()
var positions = PackedVector3Array()
var regions: Dictionary = {}
var far_groups: Dictionary = {}
var family_counts: Dictionary = {}

static func metadata(library) -> Dictionary:
	var contacts = Contacts.new()
	var result: Dictionary = {}
	for family in FAMILY.values():
		for variant in range(1,5):
			var asset = "forest_%s_%02d" % [family,variant]
			result[asset] = {"height_m":float(library.tree_record(asset).height_m),"footprint":contacts.root_footprint(asset,library),"render_bounds":library.tree_render_bounds(asset)}
	contacts.free()
	return result

static func metadata_async(library, checkpoint: Callable, job) -> Dictionary:
	var contacts = Contacts.new(); var result: Dictionary = {}
	for family in FAMILY.values():
		for variant in range(1,5):
			if job.is_cancelled(): contacts.free(); return {}
			var asset = "forest_%s_%02d" % [family,variant]
			result[asset] = {"height_m":float(library.tree_record(asset).height_m),"footprint":contacts.root_footprint(asset,library),"render_bounds":library.tree_render_bounds(asset)}
			job.advance()
			if checkpoint.is_valid(): await checkpoint.call("Preparing tree roots · %d / 24" % result.size(),100.0*result.size()/24)
	contacts.free()
	return result

func build(field, metadata_values: Dictionary, job) -> void:
	assets = PackedStringArray(metadata_values.keys()); assets.sort()
	var lookup: Dictionary = {}
	for i in assets.size(): lookup[assets[i]] = i
	var result = job.map_tiles(ceili(float(field.tree_data.size())/2048),func(i): return _trees(field,metadata_values,lookup,i*2048,mini(field.tree_data.size(),(i+1)*2048),job))
	if job.is_cancelled(): return
	for tile in result:
		asset_indices.append_array(tile.assets); poses.append_array(tile.poses); positions.append_array(tile.positions)
	result.clear()
	var near_ids: Dictionary = {}; var far_ids: Dictionary = {}
	for i in positions.size():
		if i%2048==0 and job.is_cancelled(): return
		var p = positions[i]; var asset = assets[asset_indices[i]]
		var key = Vector2i(floori(p.x/CELL),floori(p.z/CELL))
		var far_key = Vector2i(floori(p.x/FAR_CELL),floori(p.z/FAR_CELL))
		var family = asset.get_slice("_",1); family_counts[family] = int(family_counts.get(family,0))+1
		for pair in [[near_ids,key],[far_ids,far_key]]:
			if not pair[0].has(pair[1]): pair[0][pair[1]] = {}
			if not pair[0][pair[1]].has(asset): pair[0][pair[1]][asset] = PackedInt32Array()
			# Keep the growing packed member buffer explicit in its owning group.
			var ids: PackedInt32Array = pair[0][pair[1]][asset]; ids.append(i); pair[0][pair[1]][asset] = ids
	regions = _groups(near_ids,field,job,metadata_values)
	var far = _groups(far_ids,field,job,metadata_values)
	for key in far:
		for asset in far[key]: far_groups["%d:%d:%s" % [key.x,key.y,asset]] = far[key][asset]

func _trees(field, metadata_values: Dictionary, lookup: Dictionary, first: int, last: int, job) -> Dictionary:
	var values = PackedFloat32Array(); values.resize((last-first)*12)
	var indices = PackedInt32Array(); indices.resize(last-first)
	var seated = PackedVector3Array(); seated.resize(last-first)
	for i in range(first,last):
		if i%128==0 and job.is_cancelled(): break
		var p: Vector3 = field.tree_data.positions[i]
		var region = hash("%d:%d:%d" % [field.seed_value,floori(p.x/256),floori(p.z/256)])
		var mixed = 1 if posmod(hash(Vector2(p.x,p.z)),5)==0 else 0
		var family: String = ["spruce","fir","pine"][posmod(region+mixed,3)]
		if posmod(hash(Vector2(p.x,p.z)),7)==0: family = ["birch","snag","split_snag"][posmod(region,3)]
		var variant = 1+posmod(hash("%s_%d_%d_%d" % [family,floori(p.x/48),floori(p.z/48),field.seed_value]),4)
		var asset = "forest_%s_%02d" % [FAMILY[family],variant]
		var scale_value: float = field.tree_data.dimensions[i].z*10.5/metadata_values[asset].height_m
		var pose = Transform3D(Basis(Vector3.UP,field.tree_data.yaws[i]).scaled(Vector3.ONE*scale_value),p)
		var shift = 0.0
		for local in metadata_values[asset].footprint:
			var at: Vector3 = pose*local
			shift = minf(shift,field.height_at(at.x,at.z)-at.y-Contacts.ROOT_CLEARANCE_M)
		pose.origin.y += shift
		put_pose(values,(i-first)*12,pose)
		indices[i-first] = lookup[asset]; seated[i-first] = pose.origin
	job.advance(last-first)
	return {"poses":values,"assets":indices,"positions":seated}

func _groups(ids: Dictionary, field, job, metadata_values: Dictionary) -> Dictionary:
	var groups: Dictionary = {}
	for key in ids:
		if job.is_cancelled(): return {}
		groups[key] = {}
		for asset in ids[key]:
			var members: PackedInt32Array = ids[key][asset]
			var buffer = PackedFloat32Array(); buffer.resize(members.size()*12)
			var bounds = AABB(positions[members[0]],Vector3.ZERO); var height_m = 19.0
			for i in members.size():
				var id = members[i]
				for j in 12: buffer[i*12+j] = poses[id*12+j]
				var tree_box: AABB = pose_at(id)*metadata_values[asset].render_bounds
				bounds = tree_box if i==0 else bounds.merge(tree_box)
				height_m = maxf(height_m,field.tree_data.dimensions[id].y+2)
			groups[key][asset] = {"asset":asset,"transforms":[],"height_m":height_m,"prepared":{"buffer":buffer,"bounds":bounds,"multimeshes":{}}}
	return groups

func pose_at(id: int) -> Transform3D:
	var i = id*12
	return Transform3D(Basis(Vector3(poses[i],poses[i+4],poses[i+8]),Vector3(poses[i+1],poses[i+5],poses[i+9]),Vector3(poses[i+2],poses[i+6],poses[i+10])),Vector3(poses[i+3],poses[i+7],poses[i+11]))

static func put_pose(values: PackedFloat32Array, i: int, pose: Transform3D) -> void:
	# Godot packed arrays are passed by reference; fill the shared output slice.
	values[i] = pose.basis.x.x; values[i+1] = pose.basis.y.x; values[i+2] = pose.basis.z.x; values[i+3] = pose.origin.x
	values[i+4] = pose.basis.x.y; values[i+5] = pose.basis.y.y; values[i+6] = pose.basis.z.y; values[i+7] = pose.origin.y
	values[i+8] = pose.basis.x.z; values[i+9] = pose.basis.y.z; values[i+10] = pose.basis.z.z; values[i+11] = pose.origin.z
