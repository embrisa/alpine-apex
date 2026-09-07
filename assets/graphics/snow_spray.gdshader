shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
#include "res://assets/cloud_light.gdshaderinc"
uniform int kind = 0;
varying float camera_fade;
varying vec3 snow_up;
void vertex() {
 vec3 world=(MODEL_MATRIX*vec4(0,0,0,1)).xyz;
 cloud_direct_transmission=sample_cloud_light(world);
 float scale=length(MODEL_MATRIX[0].xyz);
 // Preserve GPU particle size while orienting the puff toward the camera.
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*scale,INV_VIEW_MATRIX[1]*scale,INV_VIEW_MATRIX[2]*scale,MODEL_MATRIX[3]);
 MODELVIEW_NORMAL_MATRIX=mat3(1.0);
 camera_fade=smoothstep(.35,1.4,-MODELVIEW_MATRIX[3].z);
 snow_up=normalize((VIEW_MATRIX*vec4(0,1,0,0)).xyz);
}
void fragment() {
 vec2 p=UV*2.0-1.0;
 float radius=length(p);
 float puff=exp(-radius*radius*3.8)*(1.0-smoothstep(.65,1.0,radius));
 float grain=1.0-smoothstep(.35,.95,abs(p.x)+abs(p.y));
 ALBEDO=vec3(.97,.98,1.0);
 ALPHA=(kind==0 ? puff*.65 : grain)*COLOR.a*camera_fade;
 ROUGHNESS=kind==0 ? .86 : .28;
 SPECULAR=.5;
 // Powder scatters sunlight through its volume; it must not turn into dark
 // camera-facing squares when the camera looks away from the sun.
 NORMAL=normalize(snow_up+vec3(p*.12,.08));
}
