extends RefCounted
## Frozen metadata only; loading this catalog does not load meshes or textures.
const PATH = "res://assets/graphics/geology_v11/catalog.json"
const PACKED_PATH = "res://assets/graphics/geology_v11/catalog.res"
var records: Dictionary = {}
var families: Dictionary = {}
var fingerprint: String = ""
var packed_data: Resource

func _init(force_json: bool = false) -> void:
	if not force_json and ResourceLoader.exists(PACKED_PATH):
		var packed=load(PACKED_PATH)
		if not FileAccess.file_exists(PATH) or packed.source_sha256==FileAccess.get_sha256(PATH):
			packed_data=packed
			records=packed.records; families=packed.families; fingerprint=packed.fingerprint
			return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert(data.get("assets",[]).size()==120,"Prepare the complete geology runtime library first.")
	var physical: Array = []
	for row: Dictionary in data.assets:
		row.size_m = Vector3(row.size[0],row.size[1],row.size[2])
		row.aabb = AABB(Vector3(row.bounds_min[0],row.bounds_min[1],row.bounds_min[2]),row.size_m)
		var points = PackedVector3Array()
		for p in row.footprint: points.append(Vector3(p[0],p[1],p[2]))
		row.seating = points
		var hull_points: Array[PackedVector3Array] = []
		for hull in row.hulls:
			var vertices = PackedVector3Array()
			for p in hull: vertices.append(Vector3(p[0],p[1],p[2]))
			hull_points.append(vertices)
		row.hull_points = hull_points
		var packed_axes: Array=[]
		for hull: Dictionary in row.hull_axes:
			var normals=PackedVector3Array(); var edges=PackedVector3Array()
			for n in hull.normals: normals.append(Vector3(n[0],n[1],n[2]))
			for e in hull.edges: edges.append(Vector3(e[0],e[1],e[2]))
			packed_axes.append({"normals":normals,"edges":edges})
		row.hull_axes=packed_axes
		# Discard JSON's nested arrays after packing. Large formations otherwise
		# retain two copies of every point and thousands of tiny axis arrays.
		row.erase("hulls"); row.erase("footprint")
		records[row.id] = row
		var key: String = row.category+"/"+row.family
		if not families.has(key): families[key] = []
		families[key].append(row.id)
		physical.append([row.id,row.collision_sha256])
	fingerprint = JSON.stringify(physical,"",true,true).sha256_text()

func choose(category: String, family: String, rng: RandomNumberGenerator, max_variant: int = 4) -> String:
	var choices: Array = families[category+"/"+family]
	return choices[rng.randi_range(0,mini(choices.size(),max_variant)-1)]
