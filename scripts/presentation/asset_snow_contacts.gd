extends Node3D
## Static, terrain-fitted snow at asset feet. Cosmetic only: never edits the
## heightfield, obstacle dictionaries, collision bodies or simulation snow depth.
const ANGLES = 24
const RINGS = 6
const CELL_M = 64.0
const ROOT_CLEARANCE_M = .09
var footprints: Dictionary = {}
var chunks: Dictionary = {}
var patches: Array[MeshInstance3D] = []
var contact_count = 0

func root_footprint(id: String, library) -> PackedVector3Array:
	if footprints.has(id): return footprints[id]
	var points = PackedVector3Array()
	# Include both woody LODs: decimation may alter the bottom ring slightly.
	# A tree is normalized to 10.5 m in AlpineScenery. Restrict this sample to
	# that normalized trunk/root disc, rather than treating a snow-laden low
	# bough as a root on steep terrain. The full crown still remains in render
	# bounds, wind, shadows and collision-owned obstacle identity.
	var height_m := float(library.tree_record(id).height_m)
	var normalized_root_radius := .65 * height_m / 10.5
	for lod in 2:
		var mesh: Mesh = library.mesh(id+"_lod%d" % lod)
		var box = mesh.get_aabb()
		var unique: Dictionary = {}
		for p in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			if p.y > box.position.y + maxf(.025,box.size.y*.008): continue
			if Vector2(p.x,p.z).length() > normalized_root_radius: continue
			var key = Vector3i((p*10000).round())
			if not unique.has(key): points.append(p); unique[key] = true
	footprints[id] = points
	return points

static func seat_tree(field, original: Transform3D, footprint: PackedVector3Array) -> Transform3D:
	var seated = original
	var shift = 0.0
	for local in footprint:
		var p = original*local
		shift = minf(shift,float(field.sample(p.x,p.z).height)-p.y-ROOT_CLEARANCE_M)
	seated.origin.y += shift
	return seated

static func root_radius(footprint: PackedVector3Array, scale_value: float) -> float:
	var radius = .05
	for p in footprint: radius = maxf(radius,Vector2(p.x,p.z).length()*scale_value)
	return radius

static func terrain_render_normal(field, p: Vector3, cache: Dictionary) -> Vector3:
	# Interpolate the same 4 m vertex normals as AlpineWorld's terrain mesh.
	# Sampling a single triangle's face normal would reveal the drift boundary
	# beside smoothly shaded, curved terrain.
	var gx = clampf((p.x-field.X_MIN)/4.0,0.0,field.NX-1.001)
	var gz = clampf((p.z-field.Z_MIN)/4.0,0.0,field.NZ-1.001)
	var cell = Vector2i(int(gx),int(gz)); var u = gx-cell.x; var v = gz-cell.y
	var n: Array[Vector3] = []
	for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:
		var key: Vector2i = cell+offset
		if not cache.has(key):
			var x: float = field.X_MIN+key.x*4.0; var z: float = field.Z_MIN+key.y*4.0
			cache[key] = field.render_normal(x,z) if field.has_method("render_normal") and field.GENERATOR_ID=="alpine-drainage" else field.contact_normal(x,z)
		n.append(cache[key])
	return (n[0]*(1-u-v)+n[1]*u+n[2]*v).normalized() if u+v<=1 else (n[3]*(u+v-1)+n[1]*(1-v)+n[2]*(1-u)).normalized()

func add_contact(field, anchor: Vector3, radii: Vector2, yaw: float, depth: float) -> void:
	# Accumulate only where snow can settle. Bare rock/ice receives no white halo.
	var normal: Vector3 = field.sample(anchor.x,anchor.z).normal
	if depth <= .055 or normal.y < .64: return
	var key = Vector2i(floori(anchor.x/CELL_M),floori(anchor.z/CELL_M))
	if not chunks.has(key): chunks[key] = []
	var spread = clampf(.40+depth*.8,.45,.85)
	var size = radii+Vector2.ONE*spread
	var height_m = clampf(depth*.65,.06,.24)
	var phase = fposmod(anchor.x*.73+anchor.z*.39,TAU)
	chunks[key].append(contact_arrays(field,anchor,size,yaw,height_m,phase))
	contact_count += 1

static func contact_arrays(field, anchor: Vector3, size: Vector2, yaw: float, height_m: float, phase: float) -> Array:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	var edge_blend = PackedFloat32Array([0.0])
	# A soft asymmetric hill, not a torus: the asset hides its inner surface.
	# An outer skirt sinks into the real 4 m triangles; every point samples that
	# surface rather than extrapolating the slope at the trunk centre.
	vertices.append(Vector3(anchor.x,float(field.sample(anchor.x,anchor.z).height)+height_m,anchor.z))
	normals.append(Vector3.ZERO)
	for ring in range(1,RINGS+1):
		var t = float(ring)/RINGS
		for a in ANGLES:
			var angle = float(a)*TAU/ANGLES
			var shape = 1.0+.09*sin(angle*3.0+phase)+.06*cos(angle-phase)
			var offset = Vector2(cos(angle)*size.x,sin(angle)*size.y)*t*shape
			offset = offset.rotated(-yaw) # Match Basis(Vector3.UP,yaw) in X/Z.
			var p = anchor+Vector3(offset.x,0,offset.y)
			var bump = height_m*pow(1.0-t*t,2.0)*(1.0+.18*t*cos(angle-phase))
			p.y = float(field.sample(p.x,p.z).height)+bump-.035*smoothstep(.65,1.0,t)
			vertices.append(p); normals.append(Vector3.ZERO)
			edge_blend.append(smoothstep(.48,.80,t))
	for a in ANGLES: indices.append_array(PackedInt32Array([0,1+a,1+(a+1)%ANGLES]))
	for ring in range(RINGS-1):
		for a in ANGLES:
			var i = 1+ring*ANGLES+a
			var j = 1+ring*ANGLES+(a+1)%ANGLES
			indices.append_array(PackedInt32Array([i,i+ANGLES,j,j,i+ANGLES,j+ANGLES]))
	for i in range(0,indices.size(),3):
		var a = indices[i]; var b = indices[i+1]; var c = indices[i+2]
		var n = (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		normals[a] += n; normals[b] += n; normals[c] += n
	var normal_cache: Dictionary = {}
	for i in normals.size():
		var p = vertices[i]
		var terrain_normal = terrain_render_normal(field,p,normal_cache)
		# Match the terrain's lighting before the skirt intersects it. A low
		# mound should not leave a conspicuous circular shading seam in snow.
		normals[i] = normals[i].normalized().lerp(terrain_normal,edge_blend[i]).normalized()
	var arrays = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_INDEX] = indices
	return arrays

func finish(material: Material, profile, checkpoint: Callable = Callable()) -> void:
	var keys = chunks.keys()
	var completed = 0
	for key in keys:
		var vertices = PackedVector3Array(); var normals = PackedVector3Array(); var indices = PackedInt32Array()
		var origin = Vector3(key.x*CELL_M,0,key.y*CELL_M)
		for arrays in chunks[key]:
			var start = vertices.size()
			for p in arrays[Mesh.ARRAY_VERTEX]: vertices.append(p-origin)
			normals.append_array(arrays[Mesh.ARRAY_NORMAL])
			for index in arrays[Mesh.ARRAY_INDEX]: indices.append(start+index)
		var combined = []; combined.resize(Mesh.ARRAY_MAX)
		combined[Mesh.ARRAY_VERTEX] = vertices; combined[Mesh.ARRAY_NORMAL] = normals; combined[Mesh.ARRAY_INDEX] = indices
		var mesh = ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,combined)
		mesh.surface_set_material(0,material)
		var node = MeshInstance3D.new(); node.mesh = mesh; node.position = origin
		node.name = "ContactSnow_%d_%d" % [key.x,key.y]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(node); patches.append(node)
		# Release each construction batch after upload. Keeping every source
		# array until the end doubles its residency during a full-mountain build.
		chunks.erase(key)
		completed += 1
		if checkpoint.is_valid() and completed%8 == 0:
			await checkpoint.call("Settling snow around trees · %d / %d sections" % [completed,keys.size()],100.0*completed/keys.size())
	chunks.clear()
	apply_quality(profile)

func apply_quality(profile) -> void:
	for node in patches:
		node.visibility_range_end = [65.0,90.0,115.0][profile.level]
		node.visibility_range_end_margin = 8.0
