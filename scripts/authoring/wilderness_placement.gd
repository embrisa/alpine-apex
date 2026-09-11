extends RefCounted
## Immutable render-triangle queries and packed decorative placements. No Nodes,
## physics bodies, physical RNG, or writes to the authoritative mountain.
const TILE_M = 1024.0
const CELL_M = 32.0
const MAX_RADIUS_M = 10000.0
const Footprint = preload("res://scripts/world/mountain_footprint.gd")
const TREE_IDS = ["forest_spruce_03", "forest_fir_02", "forest_pine_03"]
const ROCK_IDS = ["pc_rock_boulder_1", "rock_boulder_2", "rock_gneiss_1"]
var groups: Array[Dictionary] = []
var counts = {"trees":0,"rocks":0,"near_trees":0,"candidates":0}
var fingerprint = ""
var build_ms = 0.0
var ready = false
var seating_error_m = 0.0
var sampler = TriangleMesh.new()
var faces = PackedVector3Array()
var masks = PackedColorArray()
var face_sources = PackedInt32Array()
var noise = FastNoiseLite.new()

func build(sources: Array, bounds: Rect2, center: Vector2, seed_value: int, snowline: float, density: float, job = null) -> void:
	var started = Time.get_ticks_usec()
	groups.clear(); faces.clear(); masks.clear(); ready = false
	counts = {"trees":0,"rocks":0,"near_trees":0,"candidates":0}
	noise.seed = seed_value ^ 0x63A092D; noise.frequency = .0018; noise.fractal_octaves = 2
	# Query precisely the submitted triangle planes, not the smooth height recipe.
	for source_index in sources.size():
		var arrays: Array = sources[source_index]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0,indices.size(),3):
			var a = vertices[indices[i]]; var b = vertices[indices[i+1]]; var c = vertices[indices[i+2]]
			var p = Vector2((a.x+b.x+c.x)/3.0,(a.z+b.z+c.z)/3.0)
			if p.distance_to(center)>MAX_RADIUS_M+1500.0: continue
			face_sources.append_array(PackedInt32Array([source_index,indices[i],indices[i+1],indices[i+2]]))
			for j in 3:
				faces.append(vertices[indices[i+j]]); masks.append(colors[indices[i+j]])
		if job and job.is_cancelled(): return
	if faces.is_empty() or not sampler.create_from_faces(faces): return
	var packed: Dictionary = {}
	var radius = ceili(MAX_RADIUS_M/CELL_M)
	for z in range(-radius,radius+1):
		if job and job.is_cancelled(): return
		for x in range(-radius,radius+1):
			# One reproducible cell stream. Preset density selects a stable subset.
			var rng = RandomNumberGenerator.new()
			rng.seed = (seed_value ^ (x*73856093) ^ (z*19349663) ^ 0x4197C25) & 0x7fffffff
			var p = center+Vector2(x+rng.randf_range(.13,.87),z+rng.randf_range(.13,.87))*CELL_M
			if p.distance_to(center)>MAX_RADIUS_M or Footprint.edge_distance(p)<24.0: continue
			var keep = rng.randf()
			if keep>density: continue
			counts.candidates += 1
			var hit = sample(p)
			if hit.is_empty(): continue
			var mask: Color = hit.mask
			var normal: Vector3 = hit.normal
			var patch = noise.get_noise_2d(p.x,p.y)
			var edge_distance = Footprint.edge_distance(p)
			var forest = mask.g*smoothstep(.65,.88,normal.y)*smoothstep(24,180+patch*160,edge_distance)
			var tree = rng.randf()<forest*.82 and patch>-.30
			var rock = not tree and rng.randf()<(.075+.18*(1.0-normal.y)) and normal.y>.48 and patch<.24
			if not tree and not rock: continue
			var id: int = rng.randi_range(0,2)
			var yaw = rng.randf_range(-PI,PI)
			var scale_value = rng.randf_range(.75,1.45) if tree else rng.randf_range(1.0,2.8)
			if tree: scale_value *= lerpf(.8,1.3,clampf((snowline-hit.position.y)/1200.0,0.0,1.0))
			var basis = Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scale_value)
			if rock:
				var up = Vector3.UP.lerp(normal,.7).normalized()
				var right = Vector3(cos(yaw),0,sin(yaw)).slide(up).normalized()
				basis = Basis(right,up,right.cross(up)).scaled(Vector3(scale_value,scale_value*rng.randf_range(.7,1.1),scale_value))
			var pose = Transform3D(basis,hit.position)
			var cell = Vector2i((p/TILE_M).floor())
			var kind = "tree" if tree else "rock"
			_append(packed,"%d:%d:%s:%d" % [cell.x,cell.y,kind,id],kind,id,pose,mask.r,rng.randf(),hit.anchor)
			counts.trees += int(tree); counts.rocks += int(rock)
			if tree and edge_distance<900.0:
				_append(packed,"%d:%d:near:%d" % [cell.x,cell.y,id],"near",id,pose,mask.r,.5,hit.anchor)
				counts.near_trees += 1
			# Small groves give forests a canopy rhythm instead of a regular
			# one-tree-per-cell sprinkle. Query each extra trunk's actual support.
			if tree and forest>.45:
				for extra in 2:
					var cluster_p=p+Vector2.from_angle(yaw+extra*2.4)*rng.randf_range(8.0,14.0)
					if Footprint.edge_distance(cluster_p)<24.0: continue
					var cluster_hit=sample(cluster_p)
					if cluster_hit.is_empty() or cluster_hit.normal.y<.68: continue
					var cluster_pose=Transform3D(Basis(Vector3.UP,yaw+extra+1).scaled(Vector3.ONE*scale_value*rng.randf_range(.65,.95)),cluster_hit.position)
					_append(packed,"%d:%d:tree:%d" % [cell.x,cell.y,id],"tree",id,cluster_pose,cluster_hit.mask.r,rng.randf(),cluster_hit.anchor)
					counts.trees+=1
					if Footprint.edge_distance(cluster_p)<900.0:
						_append(packed,"%d:%d:near:%d" % [cell.x,cell.y,id],"near",id,cluster_pose,cluster_hit.mask.r,.5,cluster_hit.anchor)
						counts.near_trees+=1
	var keys = packed.keys(); keys.sort()
	var context = HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	for key in keys:
		var group: Dictionary = packed[key]
		context.update(key.to_utf8_buffer()); context.update(group.buffer.to_byte_array())
		groups.append(group)
	fingerprint = context.finish().hex_encode()
	# BVH and triangle copies are construction-only. Keep only packed transforms.
	release_sampler()
	ready = true; build_ms = (Time.get_ticks_usec()-started)/1000.0

func sample(p: Vector2) -> Dictionary:
	var hit = sampler.intersect_ray(Vector3(p.x,30000,p.y),Vector3.DOWN)
	if hit.is_empty(): return {}
	var i: int = hit.face_index*3
	var a = Vector2(faces[i].x,faces[i].z); var b = Vector2(faces[i+1].x,faces[i+1].z); var c = Vector2(faces[i+2].x,faces[i+2].z)
	var denominator = (b-a).cross(c-a)
	if absf(denominator)<.00001: return {}
	var v = (p-a).cross(c-a)/denominator; var w = (b-a).cross(p-a)/denominator
	hit.mask = masks[i]*(1.0-v-w)+masks[i+1]*v+masks[i+2]*w
	hit.normal = hit.normal if hit.normal.y>=0 else -hit.normal
	var source_offset: int = hit.face_index*4
	hit.anchor=PackedFloat32Array([face_sources[source_offset],face_sources[source_offset+1],face_sources[source_offset+2],face_sources[source_offset+3],v,w])
	seating_error_m = maxf(seating_error_m,absf(hit.position.y-(faces[i].y*(1-v-w)+faces[i+1].y*v+faces[i+2].y*w)))
	return hit

func release_sampler() -> void:
	sampler = TriangleMesh.new(); faces.clear(); masks.clear(); face_sources.clear()

func _append(packed: Dictionary, key: String, kind: String, asset: int, pose: Transform3D, snow: float, variation: float, anchor: PackedFloat32Array) -> void:
	if not packed.has(key): packed[key] = {"kind":kind,"asset":asset,"buffer":PackedFloat32Array(),"anchors":PackedFloat32Array()}
	var anchors: PackedFloat32Array = packed[key].anchors
	anchors.append_array(anchor); packed[key].anchors=anchors
	var buffer: PackedFloat32Array = packed[key].buffer
	buffer.append_array(PackedFloat32Array([pose.basis.x.x,pose.basis.y.x,pose.basis.z.x,pose.origin.x,
		pose.basis.x.y,pose.basis.y.y,pose.basis.z.y,pose.origin.y,
		pose.basis.x.z,pose.basis.y.z,pose.basis.z.z,pose.origin.z,snow,variation,0,1]))
	packed[key].buffer = buffer
