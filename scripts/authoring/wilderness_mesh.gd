extends RefCounted
const Data = preload("res://scripts/authoring/wilderness_recipe.gd")
static func sector(data, band: int, sector: int, rows: int, quality_level: int) -> Array:
	var stride: int = 2 if quality_level==2 else 4
	var columns: int = Data.EDGE_SEGMENTS/Data.SECTORS/stride
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()
	for row in rows+1:
		for column in columns+1:
			var p = data.ring_point((sector*columns+column)*stride,band,float(row)/rows)
			var h = data.height_at(p)
			var n = data.normal_at(p)
			vertices.append(Vector3(p.x,h,p.y))
			normals.append(n)
			colors.append(data.sample_at(p).mask)
	for row in rows:
		for column in columns:
			var a = row*(columns+1)+column
			var b = a+columns+1
			if band==0 and row==0:
				# Only the seam needs 32 m spacing. Retain every apron vertex while
				# allocating most triangles to the long radial slopes and valleys.
				var previous = a
				for j in range(1,stride+1):
					var next = a+1
					if j<stride:
						var p = data.edge_point((sector*columns+column)*stride+j)
						var h = data.height_at(p)
						var n = data.normal_at(p)
						next = vertices.size()
						vertices.append(Vector3(p.x,h,p.y))
						normals.append(n)
						colors.append(data.sample_at(p).mask)
					indices.append_array(PackedInt32Array([previous,b,next]))
					previous = next
				indices.append_array(PackedInt32Array([a+1,b,b+1]))
			else:
				indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays
