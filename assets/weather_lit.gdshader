shader_type spatial;
render_mode cull_disabled;
#include "res://assets/cloud_light.gdshaderinc"
uniform vec4 base_color : source_color = vec4(1.0);
uniform float surface_roughness = 0.65;
uniform bool use_vertex_color = false;
uniform vec3 emission_color : source_color = vec3(0.0);
void vertex() {
	cloud_direct_transmission = sample_cloud_light((MODEL_MATRIX*vec4(VERTEX,1.0)).xyz);
}
void fragment() {
	ALBEDO = base_color.rgb * (use_vertex_color ? COLOR.rgb : vec3(1.0));
	ROUGHNESS = surface_roughness;
	SPECULAR = material_specular;
	EMISSION = emission_color;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
