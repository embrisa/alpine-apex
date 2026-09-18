shader_type spatial;
render_mode cull_disabled,diffuse_lambert,specular_disabled,shadows_disabled;
#include "res://assets/graphics/offmap_fog.gdshaderinc"
#include "res://assets/graphics/offmap_horizon.gdshaderinc"
uniform sampler2D rock_texture : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D bark_texture : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D foliage_texture : source_color,filter_linear_mipmap,repeat_disable;
uniform bool tree_geometry = false;
uniform bool seasonal_geometry = false;
#include "res://assets/graphics/pc_season_color.gdshaderinc"
uniform sampler2D mesh_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D mesh_normal : hint_normal,filter_linear_mipmap,repeat_disable;
uniform bool has_mesh_normal=false;
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
 vec3 base;
 float snow;
 if(tree_geometry) {
  // The normal forest's LOD1 encodes wood, needles and modeled snow in
  // vertex alpha. Retain that asset contract rather than tinting the trunk.
  base=COLOR.rgb;
  if(seasonal_geometry) {
   vec4 sample_color=texture(mesh_albedo,UV);
   if(COLOR.a>=.4 && sample_color.a<.35) discard;
   vec3 tex=(source_textured || COLOR.a>=.4)?sample_color.rgb:texture(bark_texture,UV).rgb;
   base*=season_color(tex,n);
   if(COLOR.a>=.4 && has_mesh_normal) { NORMAL_MAP=texture(mesh_normal,UV).rgb; NORMAL_MAP_DEPTH=1.0; }
  } else if(COLOR.a<.4) base*=texture(bark_texture,UV).rgb;
  if(!seasonal_geometry && COLOR.a>.65 && COLOR.a<.8) {
   vec4 needles=texture(foliage_texture,UV);
   if(needles.a<.5) discard;
   base*=needles.rgb*vec3(.62,.72,.88);
  }
  snow=seasonal_geometry?0.0:(COLOR.a>.9?1.0:smoothstep(.72,.97,n.y)*.035*prop_data.x);
 } else {
  vec3 rock=texture(rock_texture,(prop_world.xz+vec2(prop_world.y*.43,-prop_world.y*.29))*.08).rgb;
  float gray=dot(rock,vec3(.2126,.7152,.0722));
  base=mix(vec3(gray),rock,.22)*vec3(.42,.46,.51);
  snow=smoothstep(.48,.9,n.y)*mix(.18,.95,prop_data.x);
 }
 ALBEDO=mix(base,vec3(.91,.94,.97),snow);
 ROUGHNESS=1.0; SPECULAR=0.0;
 FOG=offmap_fog(prop_world,CAMERA_POSITION_WORLD);
 if(!FRONT_FACING) NORMAL=-NORMAL;
}
void light() { DIFFUSE_LIGHT+=LIGHT_COLOR*max(dot(NORMAL,LIGHT),0.0)*cloud_shade*(LIGHT_IS_DIRECTIONAL ? offmap_horizon_visibility(prop_world) : 1.0)/PI; }
