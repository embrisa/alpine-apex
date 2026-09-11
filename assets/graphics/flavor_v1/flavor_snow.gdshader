shader_type spatial;
render_mode cull_disabled;
#include "res://assets/cloud_light.gdshaderinc"
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D metallic_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool has_albedo = false;
uniform bool has_roughness = false;
uniform bool has_metallic = false;
uniform float roughness_value = 0.8;
uniform float metallic_value = 0.0;
uniform int roughness_channel = 1;
uniform int metallic_channel = 2;
uniform float normal_strength = 0.0;
uniform float snow_amount = 0.7;
uniform float asset_height = 1.0;
varying vec3 object_point;
varying vec3 world_normal;
float channel(vec4 value, int index) {
	if(index==0) return value.r;
	if(index==1) return value.g;
	if(index==2) return value.b;
	if(index==3) return value.a;
	return dot(value.rgb,vec3(0.333333));
}
void vertex() {
	cloud_direct_transmission=sample_cloud_light((MODEL_MATRIX*vec4(VERTEX,1.0)).xyz);
	object_point=VERTEX;
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	vec3 color=base_color.rgb;
	if(has_albedo) color*=texture(albedo_tex,UV).rgb;
	float broad=sin(object_point.x*7.3+sin(object_point.z*3.1))*sin(object_point.z*5.7+object_point.y*4.3);
	float height_mask=smoothstep(0.03,0.20,object_point.y/max(asset_height,0.01));
	float snow=smoothstep(0.35+broad*0.09,0.85,world_normal.y)*snow_amount*height_mask;
	ALBEDO=mix(color,vec3(0.87,0.93,0.98)*(0.97+broad*0.03),snow);
	ROUGHNESS=mix(roughness_value*(has_roughness?channel(texture(roughness_tex,UV),roughness_channel):1.0),0.96,snow);
	METALLIC=metallic_value*(has_metallic?channel(texture(metallic_tex,UV),metallic_channel):1.0)*(1.0-snow);
	NORMAL_MAP=texture(normal_tex,UV).rgb;
	NORMAL_MAP_DEPTH=normal_strength*(1.0-snow*0.85);
}
