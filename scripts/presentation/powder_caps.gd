extends RefCounted
## Rounded, closed snow crowns fitted to six imported rock envelopes.
const ANGLES = 64
const RINGS = 24
const RADIUS = 1.33
const BURIAL = .48
var meshes: Dictionary = {}
var material: ShaderMaterial

func _init(lighting) -> void:
	material = ShaderMaterial.new()
	material.shader = preload("res://assets/graphics/powder_cap.gdshader")
	lighting.register(material)

func _top(p: Vector2, faces: PackedVector3Array) -> float:
	var top = -10.0
	for i in range(0,faces.size(),3):
		var a = faces[i]
		var b = faces[i+1]
		var c = faces[i+2]
		var ab = Vector2(b.x-a.x,b.z-a.z)
		var ac = Vector2(c.x-a.x,c.z-a.z)
		var ap = p-Vector2(a.x,a.z)
		var determinant = ab.cross(ac)
		if absf(determinant)<.00001: continue
		var u = ap.cross(ac)/determinant
		var v = ab.cross(ap)/determinant
		if u>=-.00001 and v>=-.00001 and u+v<=1.00001:
			top = maxf(top,a.y+u*(b.y-a.y)+v*(c.y-a.y))
	return top

func mesh_for(id: String, rock: Mesh) -> Mesh:
	if meshes.has(id): return meshes[id]
	var faces = rock.get_faces()
	var radius = PackedFloat32Array()
	radius.resize(ANGLES)
	for angle in ANGLES:
		var direction = Vector2.from_angle(angle*TAU/ANGLES)
		var extent = .35
		for step in range(18,66):
			var r = step*.02
			if _top(direction*r,faces)>.70: extent = r
		radius[angle] = minf(extent-.025,1.28)
	for iteration in 4:
		var next = radius.duplicate()
		for angle in ANGLES:
			next[angle] = (radius[posmod(angle-1,ANGLES)]+radius[angle]*2+radius[(angle+1)%ANGLES])*.25
		radius = next
	var vertices = PackedVector3Array()
	vertices.append(Vector3(0,_top(Vector2.ZERO,faces),0))
	var raw = PackedFloat32Array()
	raw.append(vertices[0].y)
	for ring in range(1,RINGS+1):
		var t = float(ring)/RINGS
		for angle in ANGLES:
			var p = Vector2.from_angle(angle*TAU/ANGLES)*radius[angle]*t
			var top = _top(p,faces)
			if top<.3: top = raw[1+(ring-2)*ANGLES+angle]-.15 if ring>1 else raw[0]
			raw.append(top)
			vertices.append(Vector3(p.x,top,p.y))
	# Smooth only the deposit. A lower bound keeps it outside the source rock.
	for iteration in 6:
		var next = vertices.duplicate()
		for ring in range(1,RINGS+1):
			for angle in ANGLES:
				var index = 1+(ring-1)*ANGLES+angle
				var left = 1+(ring-1)*ANGLES+posmod(angle-1,ANGLES)
				var right = 1+(ring-1)*ANGLES+(angle+1)%ANGLES
				var inner = index-ANGLES if ring>1 else 0
				var outer = index+ANGLES if ring<RINGS else index
				next[index].y = (vertices[index].y*2+vertices[left].y+vertices[right].y+vertices[inner].y+vertices[outer].y)/6.0
		vertices = next
	vertices[0].y = minf(2.46,raw[0]+.43)
	for ring in range(1,RINGS+1):
		var t = float(ring)/RINGS
		for angle in ANGLES:
			var index = 1+(ring-1)*ANGLES+angle
			var thickness = .20+.23*(1-t*t)
			# A low-LOD triangle spans several samples. Enclose the source ledge
			# throughout that footprint, not just directly below each vertex.
			var roof = raw[index]
			for dr in range(-4,2):
				var rr = clampi(ring+dr,1,RINGS)
				for da in range(-4,5): roof = maxf(roof,raw[1+(rr-1)*ANGLES+posmod(angle+da,ANGLES)])
			vertices[index].y = minf(2.46,maxf(roof+.20,vertices[index].y+thickness))
	# Continuous rings turn the edge into the stone, avoiding grid-shaped teeth.
	for lip in 2:
		for angle in ANGLES:
			var p = vertices[1+(RINGS-1)*ANGLES+angle]
			var radial = Vector3(p.x,0,p.z).normalized()
			p += radial*(.035 if lip==0 else -.035)
			p.y = p.y-.10 if lip==0 else minf(p.y-.31,raw[1+(RINGS-1)*ANGLES+angle]-.025)
			vertices.append(p)
	var indices = _indices(1)
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0,indices.size(),3):
		var a = indices[i]
		var b = indices[i+1]
		var c = indices[i+2]
		var n = (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		for index in [a,b,c]: normals[index] += n
	for i in normals.size(): normals[i] = normals[i].normalized()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var result = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{.10:_indices(2),.4:_indices(4)})
	result.surface_set_material(0,material)
	meshes[id] = result
	return result

func _indices(step: int) -> PackedInt32Array:
	var indices = PackedInt32Array()
	var rings: Array[int] = []
	for r in range(step,RINGS+1,step): rings.append(r)
	rings.append(RINGS+1)
	rings.append(RINGS+2)
	var previous = 0
	for ring in rings:
		for a in range(0,ANGLES,step):
			var b = (a+step)%ANGLES
			var outer_a = 1+(ring-1)*ANGLES+a
			var outer_b = 1+(ring-1)*ANGLES+b
			if previous==0: indices.append_array(PackedInt32Array([0,outer_a,outer_b]))
			else:
				var inner_a = 1+(previous-1)*ANGLES+a
				var inner_b = 1+(previous-1)*ANGLES+b
				indices.append_array(PackedInt32Array([inner_a,outer_a,inner_b,outer_a,outer_b,inner_b]))
		previous = ring
	return indices
