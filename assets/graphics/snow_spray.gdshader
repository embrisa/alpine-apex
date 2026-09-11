shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
#include "res://assets/cloud_light.gdshaderinc"
uniform int kind = 0;
uniform bool soft_intersection = true;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
varying float camera_fade;
varying vec3 snow_up;
varying float seed;
void vertex() {
 vec3 world=(MODEL_MATRIX*vec4(0,0,0,1)).xyz;
 cloud_direct_transmission=sample_cloud_light(world);
 float scale=length(MODEL_MATRIX[0].xyz);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*scale,INV_VIEW_MATRIX[1]*scale,INV_VIEW_MATRIX[2]*scale,MODEL_MATRIX[3]);
 MODELVIEW_NORMAL_MATRIX=mat3(1.0);
 camera_fade=smoothstep(.7,2.8,-MODELVIEW_MATRIX[3].z);
 snow_up=normalize((VIEW_MATRIX*vec4(0,1,0,0)).xyz);
 seed=INSTANCE_CUSTOM.y;
}
void fragment() {
 vec2 p=UV*2.0-1.0;
 float irregular=sin(p.x*8.0+seed*31.0)*sin(p.y*7.0-seed*17.0);
 float radius=length(p)+irregular*.09;
 float puff=exp(-radius*radius*3.0)*(1.0-smoothstep(.65,1.0,radius));
 float grain=1.0-smoothstep(.20,.85,abs(p.x)+abs(p.y)*.85);
 float alpha=kind==1 ? grain : puff*(kind==2 ? .18 : .62);
 if(soft_intersection && kind!=1) {
  float depth=textureLod(scene_depth,SCREEN_UV,0.0).r;
  vec4 ground=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,depth,1);
  float gap=-ground.z/ground.w+VERTEX.z;
  alpha*=smoothstep(0.0,kind==2 ? .6 : .18,gap);
 }
 // Restrained central fade protects the route in chase and first person.
 float route=mix(.55,1.0,smoothstep(.06,.24,length(SCREEN_UV-vec2(.5))));
 ALBEDO=vec3(.94,.97,1.0);
 ALPHA=alpha*COLOR.a*camera_fade*route;
 ROUGHNESS=kind==1 ? .34 : .88;
 SPECULAR=.35;
 NORMAL=normalize(snow_up+vec3(p*.12,.08));
}
