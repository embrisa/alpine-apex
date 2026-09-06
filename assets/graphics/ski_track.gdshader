shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
#include "res://assets/cloud_light.gdshaderinc"
varying vec3 track_across;
varying vec3 track_up;
varying float imprint_depth;
varying float track_distance;
varying vec3 imprint_world;
float snow_grain(vec2 p) {
 return sin(p.x*17.0+p.y*9.0)*sin(p.x*23.0-p.y*11.0);
}
void vertex() {
 vec2 t=VERTEX.xz+0.5;
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 float irregular=snow_grain(world.xz);
 float h=mix(mix(INSTANCE_CUSTOM.r,INSTANCE_CUSTOM.g,t.x),mix(INSTANCE_CUSTOM.b,INSTANCE_CUSTOM.a,t.x),t.y);
 float x=VERTEX.x*2.0;
 float berm=exp(-pow((abs(x)-0.70+irregular*.045)*7.0,2.0));
 imprint_depth=COLOR.r;
 VERTEX.y=h+0.010+berm*imprint_depth*(0.32+irregular*.10);
 imprint_world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 vec3 along=normalize(vec3(MODEL_MATRIX[2].x,(INSTANCE_CUSTOM.b+INSTANCE_CUSTOM.a-INSTANCE_CUSTOM.r-INSTANCE_CUSTOM.g)*0.5,MODEL_MATRIX[2].z));
 track_across=normalize(MODEL_MATRIX[0].xyz);
 track_up=normalize(cross(along,track_across));
 cloud_direct_transmission=sample_cloud_light((MODEL_MATRIX*vec4(VERTEX,1)).xyz);
 track_distance=length((MODELVIEW_MATRIX*vec4(VERTEX,1)).xyz);
}
void fragment() {
 float x=UV.x*2.0-1.0;
 float grain=snow_grain(imprint_world.xz);
 float broken_x=x+grain*.045;
 float groove=1.0-smoothstep(.26,.66,abs(broken_x));
 ALBEDO=mix(vec3(.86,.91,.96),vec3(.55,.66,.77),groove*.34);
 ALBEDO*=1.0+grain*.035;
 ROUGHNESS=mix(.88,.58,groove);
 AO=1.0-groove*.13;
 SPECULAR=.45;
 // Optical recess at the unchanged contact surface, with actual raised lips.
 float wall=-sign(x)*exp(-pow((abs(broken_x)-.48)*7.0,2.0))*imprint_depth*7.0;
 wall+=grain*.06;
 vec3 n=normalize(track_up+track_across*wall);
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0)).xyz);
 ALPHA=(1.0-smoothstep(.65,.98,abs(broken_x)))*(1.0-smoothstep(100.0,180.0,track_distance))*.86;
}
