shader_type spatial;
#include "res://assets/cloud_light.gdshaderinc"
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 point;
varying vec3 facing;
void vertex() {
	point=VERTEX;
	facing=NORMAL;
	cloud_direct_transmission=sample_cloud_light((MODEL_MATRIX*vec4(VERTEX,1.0)).xyz);
}
void fragment() {
	// Metre-scaled, staggered stone courses on the upright sides of the plinth.
	vec2 uv=abs(facing.z)>0.5?point.xy:point.zy;
	if(abs(facing.y)>0.5) uv=point.xz;
	float row=floor(uv.y/0.27);
	vec2 tile=fract(vec2(uv.x/0.65+mod(row,2.0)*0.5,uv.y/0.27));
	float edge=min(min(tile.x,1.0-tile.x),min(tile.y,1.0-tile.y));
	float mortar=1.0-smoothstep(0.015,0.045,edge);
	vec3 stone=texture(rock_albedo,uv*0.75).rgb*vec3(0.8,0.84,0.88);
	stone=mix(stone,stone*0.65,mortar*0.65);
	ALBEDO=mix(stone,vec3(0.87,0.93,0.98),smoothstep(0.6,0.9,facing.y)*0.85);
	ROUGHNESS=0.95;
}
