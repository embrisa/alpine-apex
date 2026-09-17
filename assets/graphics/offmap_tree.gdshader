shader_type spatial;
render_mode cull_disabled,skip_vertex_transform,diffuse_lambert,specular_disabled,shadows_disabled;
#include "res://assets/graphics/offmap_fog.gdshaderinc"
#include "res://assets/graphics/offmap_horizon.gdshaderinc"
uniform sampler2D albedo_texture : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform float cloud_shade=1.0;
uniform float range_end=6000.0;
uniform float tree_near_end=600.0;
varying vec3 prop_world;
varying float atlas_view;
varying flat float coverage;
void vertex() {
 vec3 center=MODEL_MATRIX[3].xyz;
 float d=distance(MAIN_CAM_INV_VIEW_MATRIX[3].xyz,center);
 // Only trees beside the physical mountain have a matching geometry batch.
 float near=offmap_edge_distance(center.xz)<900.0?smoothstep(tree_near_end-120.0,tree_near_end,d):1.0;
 coverage=near*(1.0-smoothstep(range_end-800.0,range_end,d));
 vec2 delta=INV_VIEW_MATRIX[3].xz-center.xz;
 vec2 direction=delta/max(length(delta),.001);
 vec3 eye=vec3(direction.x,0.0,direction.y);
 vec2 local=vec2(dot(eye,normalize(MODEL_MATRIX[0].xyz)),dot(eye,normalize(MODEL_MATRIX[2].xyz)));
 atlas_view=mod(atan(local.x,local.y)+TAU,TAU)*1.273239545;
 vec3 right=vec3(direction.y,0.0,-direction.x);
 prop_world=center+right*VERTEX.x*.64*length(MODEL_MATRIX[0].xyz)+vec3(0.0,VERTEX.y*length(MODEL_MATRIX[1].xyz),0.0);
 VERTEX=(VIEW_MATRIX*vec4(coverage<=0.0?center:prop_world,1.0)).xyz;
 NORMAL=normalize(mat3(VIEW_MATRIX)*vec3(direction.x,.6,direction.y));
}
void fragment() {
 float threshold=fract(52.9829189*fract(dot(FRAGCOORD.xy,vec2(.06711056,.00583715))));
 if(coverage<1.0-threshold) discard;
 float a=floor(atlas_view);
 vec2 uv=vec2(mix(.18,.82,UV.x),UV.y);
 vec4 first=texture(albedo_texture,vec2((uv.x+a)/8.0,uv.y));
 vec4 second=texture(albedo_texture,vec2((uv.x+mod(a+1.0,8.0))/8.0,uv.y));
 vec4 tex=mix(first,second,smoothstep(.15,.85,fract(atlas_view)));
 float needles=smoothstep(.006,.045,tex.g-max(tex.r,tex.b));
 ALBEDO=tex.rgb*mix(vec3(1.0),vec3(.62,.72,.88),needles);
 ALPHA=tex.a; ALPHA_SCISSOR_THRESHOLD=.35;
 ROUGHNESS=1.0; SPECULAR=0.0;
 FOG=offmap_fog(prop_world,CAMERA_POSITION_WORLD);
}
void light() { DIFFUSE_LIGHT+=LIGHT_COLOR*max(dot(NORMAL,LIGHT),0.0)*cloud_shade*(LIGHT_IS_DIRECTIONAL ? offmap_horizon_visibility(prop_world) : 1.0)/PI; }
