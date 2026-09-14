shader_type spatial;
render_mode cull_back, world_vertex_coords;
#include "res://assets/cloud_field.gdshaderinc"
#include "res://assets/cloud_light.gdshaderinc"
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_map : filter_linear_mipmap_anisotropic;
uniform sampler2D grass_mask : filter_linear, repeat_enable;
uniform sampler2D support_height : filter_nearest, repeat_disable;
uniform vec2 support_origin;
uniform vec2 support_size;
uniform float gravel_distance=16.0;
uniform float stream_time=0.0;
uniform bool near_lod=true;
instance uniform float birth=-1.0;
varying float visibility;
varying float near_weight;
float random(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
// Same diagonal and 4 m triangles as HeightfieldSurface.sample; no bilinear proxy.
vec4 support(vec2 point) {
	vec2 grid=clamp((point-support_origin)/4.0,vec2(0),support_size-vec2(1.001));
	ivec2 cell=ivec2(floor(grid)); vec2 f=fract(grid);
	float h00=texelFetch(support_height,cell,0).r, h10=texelFetch(support_height,cell+ivec2(1,0),0).r;
	float h01=texelFetch(support_height,cell+ivec2(0,1),0).r, h11=texelFetch(support_height,cell+ivec2(1,1),0).r;
	vec2 gradient=f.x+f.y<=1.0 ? vec2(h10-h00,h01-h00)/4.0 : vec2(h11-h01,h11-h10)/4.0;
	float height=f.x+f.y<=1.0 ? h00+(h10-h00)*f.x+(h01-h00)*f.y : h11+(h01-h11)*(1.0-f.x)+(h10-h11)*(1.0-f.y);
	return vec4(normalize(vec3(-gradient.x,1.0,-gradient.y)),height);
}
void vertex() {
	vec3 root=(MODEL_MATRIX*vec4(UV2.x,0.0,UV2.y,1.0)).xyz;
	vec4 ground=support(root.xz);
	vec3 right=normalize(vec3(1.0,-ground.x/ground.y,0.0));
	mat3 seat=mat3(right,ground.xyz,cross(right,ground.xyz));
	VERTEX=vec3(root.x,ground.w,root.z)+seat*(VERTEX-root);
	// At a triangle crease, keep even a 10 cm chip below the 1 cm exposure cap.
	vec4 edge=support(VERTEX.xz);
	VERTEX.y=min(VERTEX.y,edge.w+.01/edge.y);
	NORMAL=seat*NORMAL; TANGENT=seat*TANGENT; BINORMAL=seat*BINORMAL;
	float d=distance(CAMERA_POSITION_WORLD,vec3(root.x,ground.w,root.z));
	near_weight=1.0-smoothstep(3.5,5.5,d);
	visibility=(1.0-smoothstep(gravel_distance*.72,gravel_distance,d))*smoothstep(0.0,.4,stream_time-birth);
	if(INSTANCE_CUSTOM.a>.5) {
		vec2 offset=root.xz-INSTANCE_CUSTOM.rg;
		float edge_noise=sin(root.x*3.7+sin(root.z*2.1))*.13+sin(root.z*4.3)*.10;
		float cover=1.0-smoothstep(INSTANCE_CUSTOM.b*.64,INSTANCE_CUSTOM.b,length(offset)+edge_noise);
		visibility*=step(random(root.xz),cover);
	}
	visibility*=step(random(root.xz+vec2(413.7,829.1)),textureLod(grass_mask,root.xz/64.0,0.0).r);
	cloud_direct_transmission=sample_cloud_light(VERTEX);
}
void fragment() {
	float threshold=fract(52.9829189*fract(dot(FRAGCOORD.xy,vec2(.06711056,.00583715))));
	if(visibility<threshold) discard;
	float lod_threshold=fract(threshold+.5);
	if(near_lod && lod_threshold>=near_weight) discard;
	if(!near_lod && lod_threshold<near_weight) discard;
	vec3 stone=texture(albedo_map,UV).rgb*COLOR.rgb;
	ALBEDO=mix(vec3(dot(stone,vec3(.2126,.7152,.0722))),stone,.3)*vec3(.55,.59,.64);
	NORMAL_MAP=texture(normal_map,UV).rgb;
	NORMAL_MAP_DEPTH=.22;
	ROUGHNESS=clamp(texture(roughness_map,UV).g,.55,.96);
	METALLIC=0.0; SPECULAR=.3;
}
