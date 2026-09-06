extends RefCounted
## A world-owned material registry: no global render settings or solver state.
const SURFACE_SHADER = preload("res://assets/weather_lit.gdshader")
var materials: Array[ShaderMaterial] = []
var shadow_strength: float = 0.88
var last_sun_direction = Vector3.ZERO
var parameters = Vector4.ZERO

func register(material: ShaderMaterial) -> ShaderMaterial:
	if not materials.has(material):
		materials.append(material)
	return material

func material(color: Color, roughness: float = 0.65, vertex_color: bool = false, emission: bool = false) -> ShaderMaterial:
	var result = ShaderMaterial.new()
	result.shader = SURFACE_SHADER
	result.set_shader_parameter("base_color",color)
	result.set_shader_parameter("surface_roughness",roughness)
	result.set_shader_parameter("use_vertex_color",vertex_color)
	if emission:
		result.set_shader_parameter("emission_color",color*0.25)
	return register(result)

func update(state, offset_m: Vector2, sun_direction: Vector3) -> void:
	parameters = Vector4(offset_m.x,offset_m.y,state.cloud_coverage,shadow_strength if state.enabled else 0.0)
	var changed_direction = not sun_direction.is_equal_approx(last_sun_direction)
	for receiver in materials:
		receiver.set_shader_parameter("cloud_params",parameters)
		if changed_direction:
			receiver.set_shader_parameter("cloud_sun_direction",sun_direction)
	last_sun_direction = sun_direction
