extends MeshInstance3D
var lines = ImmediateMesh.new()

func _ready() -> void:
	mesh = lines
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func update_vectors(sim) -> void:
	lines.clear_surfaces()
	if not visible:
		return
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var p: Vector3 = sim.position + Vector3.UP * 0.35
	_arrow(p,sim.velocity.normalized()*5.0,Color("bae85e"))
	_arrow(p,sim.fall_line*4.0,Color("ff9a59"))
	_arrow(p,sim.surface_normal*3.0,Color("7ccfff"))
	_arrow(p,sim.gravity_vector.normalized()*3.0,Color("d492eb"))
	_arrow(p,sim.ski_forward*3.5,Color.WHITE)
	lines.surface_end()

func _arrow(p: Vector3, vector: Vector3, color: Color) -> void:
	lines.surface_set_color(color)
	lines.surface_add_vertex(p)
	lines.surface_add_vertex(p+vector)
	var back = vector.normalized() * 0.5
	var side = back.cross(Vector3.UP)
	if side.length() < 0.01:
		side = back.cross(Vector3.FORWARD)
	for sign_value in [-1,1]:
		lines.surface_add_vertex(p+vector)
		lines.surface_add_vertex(p+vector-back+side*0.5*sign_value)
