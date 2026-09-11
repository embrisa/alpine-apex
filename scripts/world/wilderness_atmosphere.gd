extends RefCounted
## Shared background uniforms. Global fog and nearby shafts remain world-owned.
static func configure(material: ShaderMaterial, data) -> void:
	material.set_shader_parameter("offmap_bounds",Vector4(data.physical_bounds.position.x,data.physical_bounds.position.y,data.physical_bounds.end.x,data.physical_bounds.end.y))
	material.set_shader_parameter("offmap_valley_height",data.valley_height)

static func apply(material: ShaderMaterial, state) -> void:
	var day = smoothstep(0.0,.16,state.sun_direction.y)
	var clear = 1.0-smoothstep(.20,.98,state.cloud_coverage)
	var golden = day*clear
	var color: Color = state.fog_color.srgb_to_linear()*lerpf(.75,.85,golden)
	material.set_shader_parameter("offmap_fog_color",Vector3(color.r,color.g,color.b))
	material.set_shader_parameter("offmap_depth_density",state.fog_density)
	material.set_shader_parameter("offmap_valley_density",lerpf(.000035,.000085,state.cloud_coverage) if state.enabled else 0.0)
	var sun: Color = state.sun_color.srgb_to_linear()*state.sun_energy
	material.set_shader_parameter("offmap_sun_color",Vector3(sun.r,sun.g,sun.b))
	material.set_shader_parameter("offmap_sun_direction",state.sun_direction)
	material.set_shader_parameter("offmap_fog_scatter",.08*golden)
	material.set_shader_parameter("cloud_shade",lerpf(1.0,.65,state.cloud_coverage) if state.enabled else 1.0)
