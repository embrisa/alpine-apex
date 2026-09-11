shader_type spatial;
render_mode cull_disabled,diffuse_lambert,specular_disabled,shadows_disabled;
#include "res://assets/graphics/offmap_fog.gdshaderinc"
uniform sampler2D rock_texture : source_color,filter_linear_mipmap,repeat_enable;
uniform bool tree_geometry = false;
uniform float cloud_shade = 1.0;
uniform float range_end = 6000.0;
uniform float tree_near_end = 600.0;
varying vec3 prop_world;
varying vec3 prop_normal;
varying vec4 prop_data;
varying flat float coverage;
void vertex() {
 prop_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 prop_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 prop_data=INSTANCE_CUSTOM;
 float d=distance(MAIN_CAM_INV_VIEW_MATRIX[3].xyz,MODEL_MATRIX[3].xyz);
 coverage=1.0-smoothstep(tree_geometry?tree_near_end-120.0:range_end-800.0,tree_geometry?tree_near_end:range_end,d);
 if(coverage<=0.0) VERTEX=vec3(0.0);
}
void fragment() {
 float threshold=fract(52.9829189*fract(dot(FRAGCOORD.xy,vec2(.06711056,.00583715))));
 if(coverage<threshold) discard;
 vec3 n=normalize(prop_normal);
 vec3 rock=texture(rock_texture,(prop_world.xz+vec2(prop_world.y*.43,-prop_world.y*.29))*.08).rgb;
 vec3 base=tree_geometry?mix(vec3(.025,.052,.035),vec3(.047,.079,.052),prop_data.y):rock*vec3(.42,.46,.51);
 float snow=smoothstep(.48,.9,n.y)*mix(.18,.95,prop_data.x);
 if(tree_geometry) snow*=.65;
 ALBEDO=mix(base,vec3(.80,.86,.91),snow);
 ROUGHNESS=1.0; SPECULAR=0.0;
 FOG=offmap_fog(prop_world,CAMERA_POSITION_WORLD);
 if(!FRONT_FACING) NORMAL=-NORMAL;
}
void light() { DIFFUSE_LIGHT+=LIGHT_COLOR*max(dot(NORMAL,LIGHT),0.0)*cloud_shade/PI; }
