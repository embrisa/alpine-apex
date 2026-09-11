extends RefCounted
## Packed CPU arrays only. ArrayMesh/scene creation belongs to AlpineWorld.
const CHUNK = 64
const Footprint = preload("res://scripts/world/mountain_footprint.gd")
var chunks: Array = []
var indices = PackedInt32Array()
var lods: Dictionary = {}

func build(field, job) -> void:
	indices = base_indices(CHUNK)
	lods = {0.7:lod_indices(CHUNK,4),3.0:lod_indices(CHUNK,8)}
	var columns = (field.NX-1)/CHUNK; var rows = (field.NZ-1)/CHUNK
	chunks = job.map_tiles(columns*rows,func(i): return chunk_arrays(field,(i%columns)*CHUNK,(i/columns)*CHUNK,job)).filter(func(row): return not row.is_empty())

static func chunk_arrays(field, cx: int, cz: int, job, keep_inside: bool = true) -> Dictionary:
	var clip = footprint_indices(Vector2(field.X_MIN+cx*4,field.Z_MIN+cz*4),keep_inside) if Footprint.enabled(field) else {"mode":1}
	if clip.mode==0:
		job.advance(); return {}
	var vertices = PackedVector3Array(); vertices.resize((CHUNK+1)*(CHUNK+1))
	var normals = PackedVector3Array(); normals.resize(vertices.size())
	for z in CHUNK+1:
		if job.is_cancelled(): return {}
		for x in CHUNK+1:
			var index = (cz+z)*field.NX+cx+x; var at = z*(CHUNK+1)+x
			vertices[at] = Vector3(field.X_MIN+(cx+x)*4,field.heights[index],field.Z_MIN+(cz+z)*4)
			normals[at] = field.final_normals[index]
	job.advance()
	var result = {"vertices":vertices,"normals":normals,"center":Vector2(field.X_MIN+(cx+CHUNK*.5)*4,field.Z_MIN+(cz+CHUNK*.5)*4)}
	if clip.mode==2:
		result.indices=clip.indices
		# The new internal perimeter must retain every 4 m join vertex. Full
		# interior chunks still use the existing shared LOD buffers.
		result.lods={}
	return result

static func footprint_indices(origin: Vector2, keep_inside: bool = true) -> Dictionary:
	var mask = PackedByteArray(); var kept = 0
	for z in 8:
		for x in 8:
			var keep = Footprint.owns_cell(origin+Vector2(x,z)*32+Vector2.ONE*16)==keep_inside
			mask.append(int(keep)); kept+=int(keep)
	if kept==0 or kept==64: return {"mode":0 if kept==0 else 1}
	var clipped = PackedInt32Array()
	for z in CHUNK:
		for x in CHUNK:
			if not mask[(z/8)*8+x/8]: continue
			var a = z*(CHUNK+1)+x
			clipped.append_array(PackedInt32Array([a,a+1,a+CHUNK+1,a+1,a+CHUNK+2,a+CHUNK+1]))
	return {"mode":2,"indices":clipped}

static func base_indices(chunk: int) -> PackedInt32Array:
	var indices = PackedInt32Array(); indices.resize(chunk*chunk*6)
	for z in chunk:
		for x in chunk:
			var a = z*(chunk+1)+x; var b = a+1; var c = a+chunk+1; var d = c+1; var at = (z*chunk+x)*6
			indices[at] = a; indices[at+1] = b; indices[at+2] = c; indices[at+3] = b; indices[at+4] = d; indices[at+5] = c
	return indices

static func lod_indices(chunk: int, step: int) -> PackedInt32Array:
	var indices = PackedInt32Array(); var stride = chunk+1
	for z in range(0,chunk,step):
		for x in range(0,chunk,step):
			var corners = [Vector2i(x,z),Vector2i(x+step,z),Vector2i(x+step,z+step),Vector2i(x,z+step)]
			var edge = x==0 or z==0 or x+step==chunk or z+step==chunk
			if not edge:
				var a = z*stride+x
				indices.append_array(PackedInt32Array([a,a+step,a+step*stride,a+step,a+step*(stride+1),a+step*stride])); continue
			var perimeter = PackedInt32Array()
			for side in 4:
				var a: Vector2i = corners[side]; var b: Vector2i = corners[(side+1)%4]
				var boundary = (a.x==b.x and (a.x==0 or a.x==chunk)) or (a.y==b.y and (a.y==0 or a.y==chunk))
				var divisions = step if boundary else 1
				for i in divisions:
					var p = Vector2i(Vector2(a).lerp(Vector2(b),float(i)/divisions)); perimeter.append(p.y*stride+p.x)
			var center = (z+step/2)*stride+x+step/2
			for i in perimeter.size(): indices.append_array(PackedInt32Array([center,perimeter[i],perimeter[(i+1)%perimeter.size()]]))
	return indices
