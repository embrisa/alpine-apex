extends Node3D
## One central beacon per gate. Presentation only; no collision or race timing.
const START_HEIGHT_M: float = 800.0
const FINISH_HEIGHT_M: float = 2000.0
const RADIUS_M: float = 6.0
const BASE_BURY_M: float = 8.0
const START_COLOR = Color("c2e76b")
const FINISH_COLOR = Color("ffa96b")
const SHADER = preload("res://assets/graphics/race_beam.gdshader")
const BASE_SHADER = preload("res://assets/graphics/race_beam_base.gdshader")
const MAX_VERTICAL_SEGMENT_M: float = 25.25
var applied_style: Dictionary = {}
var material: ShaderMaterial
var base_material: ShaderMaterial
var visual_time: float = 0.0
var motion_reduced: bool = false

static func marker_color(finish: bool) -> Color:
	return FINISH_COLOR if finish else START_COLOR

func build(center: Vector3, finish: bool, support_surface) -> void:
	build_styled(center,visual_style(finish),support_surface)

static func visual_style(finish: bool) -> Dictionary:
	# A fresh value dictionary is safe to specialize for personal navigation.
	return {"height_m":FINISH_HEIGHT_M if finish else START_HEIGHT_M,
		"radius_m":RADIUS_M,"base_bury_m":BASE_BURY_M,
		"fade_start_m":1600.0 if finish else 600.0,"color":marker_color(finish),
		"brightness":1.2 if finish else 1.0,"base_enabled":true}

func build_styled(center: Vector3, style: Dictionary, support_surface) -> void:
	# Trusted presentation callers supply metre dimensions, never change the mesh
	# after building. Each beacon owns geometry, material and true culling bounds.
	var values = visual_style(false)
	values.merge(style,true)
	var height_m: float = values.height_m
	var bury_m: float = values.base_bury_m
	assert(is_finite(height_m) and height_m>0.0)
	assert(is_finite(bury_m) and bury_m>0.0)
	assert(is_finite(values.radius_m) and values.radius_m>0.0)
	assert(is_finite(values.fade_start_m) and values.fade_start_m>=0.0 and values.fade_start_m<height_m)
	applied_style = values.duplicate()
	var mesh = CylinderMesh.new()
	# Extend below the snow so sloping terrain naturally clips the entire base.
	mesh.height = height_m+bury_m
	mesh.top_radius = values.radius_m
	mesh.bottom_radius = values.radius_m
	mesh.radial_segments = 24
	# Preserve the original fog sampling density along the taller shaft.
	mesh.rings = maxi(1,ceili(mesh.height/MAX_VERTICAL_SEGMENT_M)-1)
	mesh.cap_top = false
	mesh.cap_bottom = false
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("beam_color",values.color)
	material.set_shader_parameter("brightness",values.brightness)
	material.set_shader_parameter("height_above_anchor_m",height_m)
	material.set_shader_parameter("base_bury_m",bury_m)
	material.set_shader_parameter("top_fade_start_m",values.fade_start_m)
	base_material = null
	visual_time = 0.0
	motion_reduced = false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var beam = MeshInstance3D.new()
	beam.name = "CentralSkyBeam"
	beam.mesh = mesh
	beam.material_override = material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# The tall mesh supplies its real culling bounds. Never inherit prop LODs.
	add_child(beam)
	beam.global_transform = Transform3D(Basis.IDENTITY,center+Vector3.UP*(height_m-bury_m)*.5)
	if values.base_enabled: _build_base(center,values.color,support_surface)
	if not is_in_group("race_beam_vfx"): add_to_group("race_beam_vfx")

func _build_base(center: Vector3, color: Color, support_surface) -> void:
	# A small, static snow-fitted grid supports the rotating halo on steep ground.
	var vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	const STEPS = 40
	const HALF_SIZE = 10.0
	for z in range(STEPS+1):
		for x in range(STEPS+1):
			var p = center+Vector3(float(x)/STEPS*HALF_SIZE*2.0-HALF_SIZE,0,float(z)/STEPS*HALF_SIZE*2.0-HALF_SIZE)
			p.y = support_surface.sample(p.x,p.z).height+0.12
			vertices.append(p-center)
			uvs.append(Vector2(float(x)/STEPS,float(z)/STEPS))
	for z in STEPS:
		for x in STEPS:
			var a = z*(STEPS+1)+x
			indices.append_array(PackedInt32Array([a,a+1,a+STEPS+1,a+1,a+STEPS+2,a+STEPS+1]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var base = MeshInstance3D.new()
	base.name = "RotatingSnowHalo"
	base.mesh = ArrayMesh.new()
	base.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	base_material = ShaderMaterial.new()
	base_material.shader = BASE_SHADER
	base_material.set_shader_parameter("beam_color",color)
	base.material_override = base_material
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	base.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(base)
	base.global_transform = Transform3D(Basis.IDENTITY,center)

func update_effect(dt: float, animate: bool, reduced_motion: bool) -> void:
	if material==null or not is_visible_in_tree(): return
	if reduced_motion!=motion_reduced:
		motion_reduced = reduced_motion
		material.set_shader_parameter("vfx_strength",0.0 if reduced_motion else 1.0)
		if base_material!=null: base_material.set_shader_parameter("vfx_strength",0.0 if reduced_motion else 1.0)
	if animate and not reduced_motion:
		visual_time += maxf(dt,0.0)
		material.set_shader_parameter("visual_time",visual_time)
		if base_material!=null: base_material.set_shader_parameter("visual_time",visual_time)
