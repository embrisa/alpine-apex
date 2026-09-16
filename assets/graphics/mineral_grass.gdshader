shader_type spatial;
render_mode cull_disabled;
#include "res://assets/cloud_field.gdshaderinc"
uniform sampler2D grass_texture : source_color,filter_linear_mipmap_anisotropic;
#include "res://assets/cloud_light.gdshaderinc"
#include "res://assets/graphics/grass_motion.gdshaderinc"
uniform float grass_distance = 85.0;
varying float grass_visibility;
varying float snow_coating;
void vertex() {
	vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	float weight=1.0-UV.y;
	vec3 root=p-vec3(0.0,weight*.14,0.0);
	vec3 displacement=grass_displacement(root,weight,.14,INSTANCE_CUSTOM.a);
	VERTEX+=inverse(mat3(MODEL_MATRIX))*displacement;
	grass_visibility=1.0-smoothstep(grass_distance*.78,grass_distance,distance(CAMERA_POSITION_WORLD,root));
	snow_coating=INSTANCE_CUSTOM.r;
	cloud_direct_transmission=sample_cloud_light(p+displacement);
}
void fragment() {
	vec4 sample_color=texture(grass_texture,UV);
	if(grass_visibility<fract(52.9829189*fract(dot(FRAGCOORD.xy,vec2(.06711056,.00583715))))) discard;
	if(sample_color.a<.55) discard; // Former ALPHA_SCISSOR_THRESHOLD .55, before the shading.
	ALBEDO=sample_color.rgb*COLOR.rgb*vec3(.75,.70,.53);
	float coating=smoothstep(.10,.8,snow_coating)*smoothstep(.10,.65,1.0-UV.y)*smoothstep(.12,.5,sample_color.g);
	ALBEDO=mix(ALBEDO,vec3(.72,.79,.85),coating);
	ROUGHNESS=.95;
}
