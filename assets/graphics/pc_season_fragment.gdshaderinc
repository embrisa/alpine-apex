uniform sampler2D mesh_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D mesh_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_disable;
uniform bool has_mesh_normal=false;
#include "res://assets/graphics/pc_season_color.gdshaderinc"
void fragment() {
 float threshold=pc_lod_threshold(FRAGCOORD.xy);
 if(pc_lod_ranges.w==1.0) threshold=1.0-threshold;
 if(lod_coverage<threshold) discard;
 bool wood=COLOR.a<.4;
 if(!wood && foliage_sight_parameters.x*foliage_sight_parameters.w>0.0 && !IN_SHADOW_PASS) {
  if(foliage_sight_removal(-VERTEX.z)>foliage_sight_threshold(FRAGCOORD.xy)) discard;
 }
 vec4 source=texture(mesh_albedo,UV);
 if(!wood && source.a<.35) discard;
 vec3 tint=source.rgb;
 if(wood && !source_textured) tint=texture(bark_texture,UV).rgb;
 float needles=smoothstep(.006,.045,tint.g-max(tint.r,tint.b));
 ALBEDO=season_color(tint,normalize(world_normal))*COLOR.rgb*mix(vec3(1.0),leaf_variation,wood?0.0:needles);
 ROUGHNESS=.88;
 SPECULAR=.16;
 needle_transmission=wood?0.0:needles*.12;
 if(!wood && has_mesh_normal) {
  NORMAL_MAP=texture(mesh_normal,UV).rgb;
  NORMAL_MAP_DEPTH=1.0;
 }
#ifndef ALPINE_FOREST_MID
 if(wood && !source_textured) {
  NORMAL_MAP=texture(bark_normal,UV).rgb;
  NORMAL_MAP_DEPTH=.45;
 }
#endif
 if(!FRONT_FACING) NORMAL=-NORMAL;
}
