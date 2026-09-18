#include "res://assets/graphics/pc_forest_vertex.gdshaderinc"
void fragment() {
 float threshold=pc_lod_threshold(FRAGCOORD.xy);
 if(pc_lod_ranges.w==1.0) threshold=1.0-threshold;
 if(lod_coverage<threshold) discard;
 float mask=COLOR.a;
 bool wood=mask<.4;
 bool snow=mask>.9;
 if(!wood && foliage_sight_parameters.x*foliage_sight_parameters.w>0.0 && !IN_SHADOW_PASS) {
  if(foliage_sight_removal(-VERTEX.z)>foliage_sight_threshold(FRAGCOORD.xy)) discard;
 }
 if(snow && snow_coverage<.5) discard;
 vec3 tint=COLOR.rgb;
 // One alpha test: the explicit needle discard. No ALPHA/scissor write, so the
 // material stays opaque with identical cutout coverage and shadow cutouts.
 if(mask>.65 && mask<.8) {
  vec4 needles=texture(foliage_texture,UV);
  if(needles.a<.5) discard;
  tint*=needles.rgb*foliage_color_grade*leaf_variation;
#ifdef ALPINE_FOREST_MID
  // At medium distance retain authored mesh normals and a restrained ambient
  // foliage shade. Geometry, color, cutout coverage and wind are unchanged.
  AO=broadleaf?1.0:.90;
#else
  vec4 detail=texture(foliage_normal_ao,UV);
  NORMAL_MAP=detail.rgb;
  NORMAL_MAP_DEPTH=broadleaf?.24:.4;
  AO=broadleaf?1.0:mix(.60,1.0,detail.a);
#endif
  AO_LIGHT_AFFECT=.15;
 }
 if(wood) {
  vec3 bark=texture(bark_texture,UV).rgb;
  if(mask>.05 && mask<.16) {
   float gray=dot(bark,vec3(.2126,.7152,.0722));
   tint=mix(bark,vec3(gray)*vec3(1.16,1.10,1.0),.78)*COLOR.rgb;
  } else if(mask>.16 && mask<.25) {
   float band=sin(local_position.y*23.0+sin(local_position.x*31.0+local_position.z*27.0)*.7);
   float scar=smoothstep(.80,.97,band)*smoothstep(-.3,.5,sin(local_position.x*37.0+local_position.z*29.0+local_position.y*3.0));
   tint=mix(vec3(.57,.56,.51),vec3(.055,.050,.045),scar);
  } else if(mask<.05) tint=bark*COLOR.rgb;
  else if(mask>.25) {
   // Longitudinal grain on the torn interior, separate from bark scales.
   float grain=.5+.5*sin(local_position.x*580.0+local_position.z*410.0+sin(local_position.y*7.0)*.35);
   tint=COLOR.rgb*mix(.72,1.14,grain);
  }
#ifndef ALPINE_FOREST_MID
  NORMAL_MAP=texture(bark_normal,UV).rgb;
  NORMAL_MAP_DEPTH=mask>.25?.08:.55;
#endif
 }
 float dust=smoothstep(.72,.97,world_normal.y)*snow_coverage*.08;
 if(mask>.65 && mask<.8) dust*=.15;
 ALBEDO=mix(tint,vec3(.75,.81,.86),dust*(snow?0.0:1.0));
 ROUGHNESS=snow?.83:((broadleaf && !wood)?mix(.62,.97,texture(leaf_roughness,UV).r):.91);
 SPECULAR=.16;
 needle_transmission=(!wood && !snow)?.12:0.0;
 if(!FRONT_FACING) NORMAL=-NORMAL;
}
