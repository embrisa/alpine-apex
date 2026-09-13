shader_type spatial;
render_mode cull_disabled;
#include "res://assets/cloud_field.gdshaderinc"
#include "res://assets/cloud_light.gdshaderinc"
#include "res://assets/graphics/grass_motion.gdshaderinc"
uniform float grass_distance = 85.0;
uniform float lod_near = 1.0;
uniform float grass_stream_time = 0.0;
instance uniform float grass_birth = -1.0;
varying float grass_visibility;
varying float grass_near;
void vertex() {
	vec3 blade_root=vec3(UV2.x-.5,0.0,-(UV2.y-.5));
	vec3 root=(MODEL_MATRIX*vec4(blade_root,1.0)).xyz;
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	float height=INSTANCE_CUSTOM.g;
	vec3 displacement=grass_displacement(root,UV.y,height,INSTANCE_CUSTOM.r);
	// Transform displacement back to local space, retaining the original root.
	VERTEX+=inverse(mat3(MODEL_MATRIX))*displacement;
	float distance_m=distance(CAMERA_POSITION_WORLD,root);
	float near_weight=1.0-smoothstep(18.0,26.0,distance_m);
	grass_visibility=(1.0-smoothstep(grass_distance*.78,grass_distance,distance_m))*smoothstep(0.0,.35,grass_stream_time-grass_birth);
	grass_near=near_weight;
	cloud_direct_transmission=sample_cloud_light(world+displacement);
}
void fragment() {
	// Opaque geometry with spatial dither only at LOD/residency/distance edges.
	float threshold=fract(52.9829189*fract(dot(FRAGCOORD.xy,vec2(.06711056,.00583715))));
	if(grass_visibility<threshold) discard;
	float lod_threshold=fract(threshold+.5);
	if(lod_near>.5 && lod_threshold>=grass_near) discard;
	if(lod_near<.5 && lod_threshold<grass_near) discard;
	ALBEDO=COLOR.rgb;
	ROUGHNESS=.91;
	if(!FRONT_FACING) NORMAL=-NORMAL;
}
