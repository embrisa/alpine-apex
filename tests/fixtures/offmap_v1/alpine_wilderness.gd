extends Node3D
## 24 static, culled batches and one opaque shader. No physics or GI contribution.
const Data = preload("res://tests/fixtures/offmap_v1/wilderness_data.gd")
const FAR_M = 32000.0
const TRIANGLE_LIMITS = [20000,40000,80000]
var data = Data.new()
var material = ShaderMaterial.new()
var triangles: int = 0
var build_ms: float = 0.0
var level: int = -1
var enabled: bool = true

func build(field, mountain, profile) -> void:
	name = "AlpineWilderness"
	data.configure(mountain,field)
	material.shader = preload("res://tests/fixtures/offmap_v1/alpine_wilderness.gdshader")
	enabled = "--wilderness=off" not in OS.get_cmdline_user_args()
	apply_quality(profile)
	visible = enabled

func apply_quality(profile) -> void:
	if not enabled: return
	if level==profile.level: return
	level = profile.level
	var begin = Time.get_ticks_usec()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	triangles = 0
	var rows: int = [12,24,24][level]
	for band in 3:
		for sector in Data.SECTORS: _sector(band,sector,rows)
	build_ms = (Time.get_ticks_usec()-begin)/1000.0

func _sector(band: int, sector: int, rows: int) -> void:
	var stride: int = 2 if level==2 else 4
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
			colors.append(data.color_at(p,h,n))
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
						colors.append(data.color_at(p,h,n))
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
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node = MeshInstance3D.new()
	node.name = "Ridge_%d_%d" % [band,sector]
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(node)
	triangles += indices.size()/3

func update_weather(state) -> void:
	material.set_shader_parameter("cloud_shade",lerpf(1.0,0.65,state.cloud_coverage) if state.enabled else 1.0)

func report() -> Dictionary:
	return {"version":Data.VERSION,"seed":data.seed_value,"enabled":visible,"triangles":triangles,
		"batches":get_child_count(),"build_ms":build_ms,"radius_m":Data.OUTER_RADIUS_M,"quality":level}
