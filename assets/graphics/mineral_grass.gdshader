shader_type spatial;
render_mode cull_disabled;
#include "res://assets/cloud_field.gdshaderinc"
uniform sampler2D grass_texture : source_color,filter_linear_mipmap_anisotropic;
#include "res://assets/cloud_light.gdshaderinc"
void vertex() {
	vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	cloud_direct_transmission=sample_cloud_light(p);
}
void fragment() {
	vec4 sample_color=texture(grass_texture,UV);
	ALBEDO=sample_color.rgb*COLOR.rgb*vec3(.75,.70,.53);
	ALPHA=sample_color.a;
	ALPHA_SCISSOR_THRESHOLD=.55;
	ROUGHNESS=.95;
}
