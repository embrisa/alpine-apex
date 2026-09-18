uniform sampler2D mesh_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D mesh_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D mesh_roughness : filter_linear_mipmap_anisotropic,repeat_disable;
uniform int roughness_channel=0;
void fragment() {
 float threshold=pc_lod_threshold(FRAGCOORD.xy);
 if(pc_lod_ranges.w==1.0) threshold=1.0-threshold;
 if(lod_coverage<threshold) discard;
 bool wood=COLOR.a<.4;
 bool snow=COLOR.a>.9;
 if(!wood && foliage_sight_parameters.x*foliage_sight_parameters.w>0.0 && !IN_SHADOW_PASS) {
  if(foliage_sight_removal(-VERTEX.z)>foliage_sight_threshold(FRAGCOORD.xy)) discard;
 }
 vec3 tint=texture(mesh_albedo,UV).rgb;
 float needles=smoothstep(.006,.045,tint.g-max(tint.r,tint.b));
 ALBEDO=tint*mix(vec3(1.0),leaf_variation,needles);
 vec4 roughness=texture(mesh_roughness,UV);
 ROUGHNESS=max(.78,roughness[roughness_channel]);
 SPECULAR=.16;
 needle_transmission=(!wood && !snow)?.12:0.0;
#ifndef ALPINE_FOREST_MID
 NORMAL_MAP=texture(mesh_normal,UV).rgb;
 NORMAL_MAP_DEPTH=.35;
#endif
 if(!FRONT_FACING) NORMAL=-NORMAL;
}
