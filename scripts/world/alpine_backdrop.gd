extends Node3D
## Built-in mesh renderer for the shared decorative mountain data.
## The skiable rectangle is explicitly omitted. This has no collision contract.
const STEP = 32.0
var triangles: int = 0
var physical_bounds: Rect2

func build(surface, assets, mountain) -> void:
	physical_bounds = surface.bounds()
	var mat = assets.terrain_material() if surface.GENERATOR_ID=="alpine-drainage" else assets.terrain_material(.06,.035)
	var nx = 257
	var nz = 257
	var points = PackedVector3Array()
	points.resize(nx*nz)
	for z in range(nz):
		for x in range(nx):
			var wx = mountain.ORIGIN.x+x*STEP
			var wz = mountain.ORIGIN.y+z*STEP
			points[z*nx+x] = Vector3(wx,mountain.sample_height(Vector2(wx,wz)),wz)
	for cz in range(0,nz-1,32):
		for cx in range(0,nx-1,32):
			var vertices = PackedVector3Array()
			var normals = PackedVector3Array()
			var indices = PackedInt32Array()
			for z in range(33):
				for x in range(33):
					var gx = cx+x
					var gz = cz+z
					vertices.append(points[gz*nx+gx])
					var dx = points[gz*nx+mini(gx+1,nx-1)].y-points[gz*nx+maxi(gx-1,0)].y
					var dz = points[mini(gz+1,nz-1)*nx+gx].y-points[maxi(gz-1,0)*nx+gx].y
					normals.append(Vector3(-dx,STEP*2.0,-dz).normalized())
			for z in range(32):
				for x in range(32):
					var p: Vector3 = vertices[z*33+x]
					if physical_bounds.has_point(Vector2(p.x,p.z)): continue
					if surface.GENERATOR_ID=="alpine-drainage" and _touches_surface(p):
						_stitch_quad(vertices,normals,indices,p,mountain,surface)
						continue
					var a = z*33+x
					indices.append_array(PackedInt32Array([a,a+1,a+33,a+1,a+34,a+33]))
			if indices.is_empty(): continue
			var arrays = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_INDEX] = indices
			var mesh = ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var node = MeshInstance3D.new()
			node.mesh = mesh
			node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
			node.material_override = mat
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			triangles += indices.size()/3

func _touches_surface(p: Vector3) -> bool:
	return ((p.x==physical_bounds.position.x-STEP or p.x==physical_bounds.end.x) and p.z>=physical_bounds.position.y and p.z<physical_bounds.end.y) or ((p.z==physical_bounds.position.y-STEP or p.z==physical_bounds.end.y) and p.x>=physical_bounds.position.x and p.x<physical_bounds.end.x)

func _on_surface_edge(p: Vector2) -> bool:
	return ((p.x==physical_bounds.position.x or p.x==physical_bounds.end.x) and p.y>=physical_bounds.position.y and p.y<=physical_bounds.end.y) or ((p.y==physical_bounds.position.y or p.y==physical_bounds.end.y) and p.x>=physical_bounds.position.x and p.x<=physical_bounds.end.x)

func _stitch_quad(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, p: Vector3, mountain, surface) -> void:
	# Match every 4 m physical edge vertex, retaining the adjacent 32 m outer
	# edges. A fan closes the T-junction without changing any ski contact.
	var origin = Vector2(p.x,p.z)
	var corners = [origin,origin+Vector2(STEP,0),origin+Vector2(STEP,STEP),origin+Vector2(0,STEP)]
	var center = vertices.size()
	_backdrop_vertex(vertices,normals,origin+Vector2.ONE*STEP*.5,mountain,surface)
	var first = vertices.size()
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i+1)%4]
		var divisions = 8 if _on_surface_edge(a) and _on_surface_edge(b) else 1
		for j in divisions: _backdrop_vertex(vertices,normals,a.lerp(b,float(j)/divisions),mountain,surface)
	var count = vertices.size()-first
	for i in count: indices.append_array(PackedInt32Array([center,first+i,first+(i+1)%count]))

func _backdrop_vertex(vertices: PackedVector3Array, normals: PackedVector3Array, p: Vector2, mountain, surface) -> void:
	var edge = _on_surface_edge(p)
	var h: float = surface.sample(p.x,p.y).height if edge else mountain.sample_height(p)
	vertices.append(Vector3(p.x,h,p.y))
	if edge:
		normals.append(surface.render_normal(p.x,p.y))
	else:
		var dx: float = mountain.sample_height(p+Vector2(2,0))-mountain.sample_height(p-Vector2(2,0))
		var dz: float = mountain.sample_height(p+Vector2(0,2))-mountain.sample_height(p-Vector2(0,2))
		normals.append(Vector3(-dx,4,-dz).normalized())
