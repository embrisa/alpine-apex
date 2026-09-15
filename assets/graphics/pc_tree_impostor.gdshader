shader_type spatial;
render_mode cull_disabled,skip_vertex_transform;
#include "res://assets/cloud_light.gdshaderinc"
#include "res://assets/graphics/pc_lod.gdshaderinc"
#include "res://assets/graphics/foliage_sight.gdshaderinc"
uniform sampler2D albedo_texture : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform vec3 foliage_color_grade = vec3(1.0);
uniform bool authored_canopy = false;
uniform sampler2D canopy_texture : filter_linear_mipmap_anisotropic,repeat_disable;
// Premium directional cards retain object-space normals baked from the live
// detailed mesh. The older atlas contract keeps the inexpensive facing normal.
uniform bool authored_normal = false;
uniform sampler2D normal_texture : filter_linear_mipmap_anisotropic,repeat_disable;
uniform float card_crop = .64;
varying float atlas_view;
varying flat float lod_coverage;
varying flat vec3 leaf_variation;
varying vec3 object_x;
varying vec3 object_y;
varying vec3 object_z;
// Keep this grading identical to pc_forest_tree: LODs share the same anchor.
vec3 tree_leaf_variation(vec2 anchor) {
 float a=fract(sin(dot(anchor,vec2(.1031,.11369)))*43758.5453)*2.0-1.0;
 float b=fract(sin(dot(anchor,vec2(.0717,.0973)))*22578.1459)*2.0-1.0;
 return vec3(1.0+.055*a+.025*b,1.0+.055*a,1.0+.055*a-.025*b);
}
void vertex() {
 leaf_variation=tree_leaf_variation(MODEL_MATRIX[3].xz);
 object_x=normalize(MODEL_MATRIX[0].xyz);
 object_y=normalize(MODEL_MATRIX[1].xyz);
 object_z=normalize(MODEL_MATRIX[2].xyz);
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
 if(tex.a<.35) discard;
 // Grade green needles only; baked white snow and brown wood stay neutral.
 float needles=smoothstep(.006,.045,tex.g-max(tex.r,tex.b));
 float authored_mask=0.0;
 if(authored_canopy) authored_mask=mix(texture(canopy_texture,vec2((uv.x+a)/8.0,uv.y)).r,texture(canopy_texture,vec2((uv.x+mod(a+1.0,8.0))/8.0,uv.y)).r,smoothstep(.15,.85,fract(atlas_view)));
 if(foliage_sight_parameters.x*foliage_sight_parameters.w>0.0 && !IN_SHADOW_PASS) {
  // White branch snow follows needles; brown collision trunks stay opaque.
  float canopy=max(needles,smoothstep(.16,.30,min(tex.r,min(tex.g,tex.b))));
  if(authored_canopy) canopy=authored_mask;
  if(foliage_sight_removal(-VERTEX.z)*canopy>foliage_sight_threshold(FRAGCOORD.xy)) discard;
 }
 float colored_leaf=authored_canopy ? authored_mask*smoothstep(.02,.10,max(tex.r,max(tex.g,tex.b))-min(tex.r,min(tex.g,tex.b))) : needles;
 // The premium color/role atlases are coverage-associated at their filtered
 // edges. Remove that association before lighting; the alpha scissor below
 // still owns the silhouette and avoids a dark halo at every azimuth blend.
 vec3 atlas_color=authored_canopy ? clamp(tex.rgb/max(tex.a,.0001),vec3(0.0),vec3(1.0)) : tex.rgb;
 ALBEDO=atlas_color*mix(vec3(1.0),foliage_color_grade,needles)*mix(vec3(1.0),leaf_variation,colored_leaf);
 ALPHA=tex.a;
 ALPHA_SCISSOR_THRESHOLD=.35;
 if(authored_normal) {
  vec4 normal_first=texture(normal_texture,vec2((uv.x+a)/8.0,uv.y));
  vec4 normal_second=texture(normal_texture,vec2((uv.x+mod(a+1.0,8.0))/8.0,uv.y));
  vec4 encoded=mix(normal_first,normal_second,smoothstep(.15,.85,fract(atlas_view)));
  vec3 object_normal=normalize(encoded.rgb/max(encoded.a,.0001)*2.0-1.0);
  NORMAL=normalize(mat3(VIEW_MATRIX)*(object_x*object_normal.x+object_y*object_normal.y+object_z*object_normal.z));
 }
 ROUGHNESS=.90;
 SPECULAR=.18;
}
