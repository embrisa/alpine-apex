extends RefCounted
## A single packed population. Dictionaries exist only for a requested record.
const LIMIT = 2000000 # bounded placement workspace; published recipes request <=1M
var positions = PackedVector3Array()
var dimensions = PackedVector3Array() # trunk radius, height, scale
var yaws = PackedFloat32Array()
var candidate_ids = PackedInt64Array()
var ecology = PackedByteArray() # 0 woodland / 1 scattered
var heads = PackedInt32Array()
var links = PackedInt32Array()
var cell: float = 48.0
var side: int = 128
var origin = Vector2(-3072,-3072)
var max_radius: float = 0.0

func size() -> int: return positions.size()
func is_empty() -> bool: return positions.is_empty()
func append(p: Vector3, radius: float, height_m: float, scale_value: float, yaw: float, id: int, scattered: bool = false) -> void:
	positions.append(p); dimensions.append(Vector3(radius,height_m,scale_value)); yaws.append(yaw); candidate_ids.append(id); ecology.append(1 if scattered else 0)
	max_radius = maxf(max_radius,radius)

func record(id: int) -> Dictionary:
	return {"position":positions[id],"radius":dimensions[id].x,"height":dimensions[id].y,"scale":dimensions[id].z,"yaw":yaws[id],"tree":true,"powder_cap":false,"ecology":"scattered" if ecology[id]==1 else "woodland","candidate_id":candidate_ids[id]}

func build_index(cell_m: float = 48.0, job = null) -> void:
	cell = cell_m; side = ceili(6144.0/cell)
	heads.resize(side*side); heads.fill(-1); links.resize(size()); links.fill(-1)
	for i in size():
		if i%4096==0 and job and job.is_cancelled(): return
		insert_index(i)

func insert_index(id: int) -> void:
	var p = positions[id]
	var x = clampi(floori((p.x-origin.x)/cell),0,side-1)
	var z = clampi(floori((p.z-origin.y)/cell),0,side-1)
	links[id] = heads[z*side+x]; heads[z*side+x] = id

func nearby(center: Vector3, radius: float) -> PackedInt32Array:
	var ids = PackedInt32Array()
	if heads.is_empty(): return ids
	var r2 = radius*radius
	for z in range(maxi(0,floori((center.z-radius-origin.y)/cell)),mini(side-1,floori((center.z+radius-origin.y)/cell))+1):
		for x in range(maxi(0,floori((center.x-radius-origin.x)/cell)),mini(side-1,floori((center.x+radius-origin.x)/cell))+1):
			var id = heads[z*side+x]
			while id>=0:
				var p = positions[id]
				if Vector2(p.x-center.x,p.z-center.z).length_squared()<=r2: ids.append(id)
				id = links[id]
	ids.sort()
	return ids

func clear_at(p: Vector2, radius: float, spacing_factor: float) -> bool:
	var separation = maxf(4.2*spacing_factor,radius+max_radius+2*spacing_factor)
	for z in range(maxi(0,floori((p.y-separation-origin.y)/cell)),mini(side-1,floori((p.y+separation-origin.y)/cell))+1):
		for x in range(maxi(0,floori((p.x-separation-origin.x)/cell)),mini(side-1,floori((p.x+separation-origin.x)/cell))+1):
			var id = heads[z*side+x]
			while id>=0:
				var other = positions[id]
				var required = maxf(4.2*spacing_factor,radius+dimensions[id].x+2*spacing_factor)
				if p.distance_squared_to(Vector2(other.x,other.z))<required*required: return false
				id = links[id]
	return true

func thin(target: int, seed_number: int) -> void:
	if size()<=target: return
	var rng = RandomNumberGenerator.new(); rng.seed = seed_number
	var remaining = size(); var wanted = target; var at = 0
	for i in size():
		if rng.randi_range(0,remaining-1)<wanted:
			positions[at] = positions[i]; dimensions[at] = dimensions[i]; yaws[at] = yaws[i]; candidate_ids[at] = candidate_ids[i]; ecology[at] = ecology[i]
			at += 1; wanted -= 1
		remaining -= 1
	positions.resize(at); dimensions.resize(at); yaws.resize(at); candidate_ids.resize(at); ecology.resize(at)
	heads.clear(); links.clear()

func fingerprint(context: HashingContext, job = null) -> void:
	# Stream bounded slices; never build another whole tree payload.
	for first in range(0,size(),8192):
		if job and job.is_cancelled(): return
		context.update(positions.slice(first,first+8192).to_byte_array())
		context.update(dimensions.slice(first,first+8192).to_byte_array())
		context.update(yaws.slice(first,first+8192).to_byte_array())
		context.update(candidate_ids.slice(first,first+8192).to_byte_array())
		context.update(ecology.slice(first,first+8192))

func valid() -> bool:
	var count = size()
	return count<=LIMIT and dimensions.size()==count and yaws.size()==count and candidate_ids.size()==count and ecology.size()==count and links.size()==count and heads.size()==side*side
