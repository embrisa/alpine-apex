shader_type spatial;
render_mode cull_disabled,skip_vertex_transform;
#include "res://assets/cloud_light.gdshaderinc"
#include "res://assets/graphics/pc_lod.gdshaderinc"
#include "res://assets/graphics/foliage_sight.gdshaderinc"
uniform sampler2D albedo_texture : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform vec3 foliage_color_grade = vec3(1.0);
uniform float card_crop = .64;
varying float atlas_view;
varying flat float lod_coverage;
void vertex() {
 lod_coverage=pc_lod_coverage(MAIN_CAM_INV_VIEW_MATRIX[3].xyz,MODEL_MATRIX[3].xyz,MODEL_MATRIX);
 vec3 center=MODEL_MATRIX[3].xyz;
 if(pc_lod_individual && lod_coverage<=0.0) {
  VERTEX=(VIEW_MATRIX*vec4(center,1.0)).xyz;
  NORMAL=vec3(0.0,1.0,0.0);
  atlas_view=0.0;
  cloud_direct_transmission=1.0;
 } else {
 vec2 direction=normalize(INV_VIEW_MATRIX[3].xz-center.xz);
 vec3 eye=vec3(direction.x,0,direction.y);
 vec2 local=vec2(dot(eye,normalize(MODEL_MATRIX[0].xyz)),dot(eye,normalize(MODEL_MATRIX[2].xyz)));
 atlas_view=mod(atan(local.x,local.y)+6.283185307,6.283185307)*1.273239545;
 vec3 right=vec3(direction.y,0,-direction.x);
 // Crop empty atlas sides without changing the photographed silhouette.
 vec3 p=center+right*VERTEX.x*card_crop*length(MODEL_MATRIX[0].xyz)+vec3(0,VERTEX.y*length(MODEL_MATRIX[1].xyz),0);
 VERTEX=(VIEW_MATRIX*vec4(p,1)).xyz;
 NORMAL=normalize(mat3(VIEW_MATRIX)*vec3(direction.x,.6,direction.y));
 cloud_direct_transmission=sample_cloud_light(p);
 }
}
void fragment() {
 float coverage=lod_coverage;
 if(coverage<pc_lod_threshold(FRAGCOORD.xy)) discard;
 float a=floor(atlas_view);
 vec2 uv=vec2(mix(.5-card_crop*.5,.5+card_crop*.5,UV.x),UV.y);
 vec4 first=texture(albedo_texture,vec2((uv.x+a)/8.0,uv.y));
 vec4 second=texture(albedo_texture,vec2((uv.x+mod(a+1.0,8.0))/8.0,uv.y));
 vec4 tex=mix(first,second,smoothstep(.15,.85,fract(atlas_view)));
 // Grade green needles only; baked white snow and brown wood stay neutral.
 float needles=smoothstep(.006,.045,tex.g-max(tex.r,tex.b));
 if(foliage_sight_parameters.x*foliage_sight_parameters.w>0.0 && !IN_SHADOW_PASS) {
  // White branch snow follows needles; brown collision trunks stay opaque.
  float canopy=max(needles,smoothstep(.16,.30,min(tex.r,min(tex.g,tex.b))));
  if(foliage_sight_removal(-VERTEX.z)*canopy>foliage_sight_threshold(FRAGCOORD.xy)) discard;
 }
 ALBEDO=tex.rgb*mix(vec3(1.0),foliage_color_grade,needles);
 ALPHA=tex.a;
 ALPHA_SCISSOR_THRESHOLD=.35;
 ROUGHNESS=.90;
 SPECULAR=.18;
}
