#define ALPINE_NEEDLE_TRANSMISSION
varying float needle_transmission;
#include "res://assets/cloud_light.gdshaderinc"
#include "res://assets/graphics/pc_lod.gdshaderinc"
#include "res://assets/graphics/foliage_sight.gdshaderinc"
uniform sampler2D bark_texture : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D bark_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D foliage_texture : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D foliage_normal_ao : hint_normal,filter_linear_mipmap_anisotropic,repeat_disable;
uniform vec3 foliage_color_grade = vec3(1.0);
uniform bool broadleaf = false;
uniform sampler2D leaf_roughness : filter_linear_mipmap_anisotropic,repeat_disable;
uniform float wind_time=0.0;
uniform float wind_strength=0.0;
uniform vec2 wind_direction=vec2(1.0,0.0);
uniform float snow_coverage : hint_range(0.0,1.0)=1.0;
uniform vec4 contact_anchors[4];
uniform vec4 contact_angles[48];
uniform bool contact_active=true;
// Connected Meshy crowns need a continuous field across shared branch joints.
// Authored separate boughs retain their exact existing spring/pivot path.
uniform bool continuous_crown=false;
uniform vec3 branch_centers[12];
varying flat float lod_coverage;
varying flat vec3 leaf_variation;
varying vec3 world_normal;
varying vec3 local_position;
// Keep this grading identical to pc_tree_impostor: LODs share the same anchor.
vec3 tree_leaf_variation(vec2 anchor) {
 float a=fract(sin(dot(anchor,vec2(.1031,.11369)))*43758.5453)*2.0-1.0;
 float b=fract(sin(dot(anchor,vec2(.0717,.0973)))*22578.1459)*2.0-1.0;
 return vec3(1.0+.055*a+.025*b,1.0+.055*a,1.0+.055*a-.025*b);
}
// Rotation by precomputed sines/cosines; the caller evaluates them once per
// vertex and reuses them for position, normal and tangent frame.
vec3 bend(vec3 p,vec3 s,vec3 c) {
 vec3 q=vec3(p.x*c.z-p.y*s.z,p.x*s.z+p.y*c.z,p.z);
 q=vec3(q.x,q.y*c.x-q.z*s.x,q.y*s.x+q.z*c.x);
 return vec3(q.x*c.y+q.z*s.y,q.y,-q.x*s.y+q.z*c.y);
}
void vertex() {
 local_position=VERTEX;
 lod_coverage=pc_lod_coverage(MAIN_CAM_INV_VIEW_MATRIX[3].xyz,MODEL_MATRIX[3].xyz,MODEL_MATRIX);
 // Per-tree distance can hide part of a regional batch. Collapse those
 // triangles before rasterization and avoid invisible branch/wind work.
 if(pc_lod_individual && lod_coverage<=0.0) {
  leaf_variation=vec3(1.0);
  VERTEX=vec3(0.0);
  world_normal=vec3(0.0,1.0,0.0);
  cloud_direct_transmission=1.0;
 } else {
 leaf_variation=tree_leaf_variation(MODEL_MATRIX[3].xz);
 vec3 anchor=MODEL_MATRIX[3].xyz;
 int cluster=clamp(int(round(UV2.x*16.0)),0,11);
 float pivot_y=continuous_crown?0.0:UV2.y*32.0;
 float flex=smoothstep(.12,1.1,length(VERTEX.xz))*smoothstep(.3,1.8,VERTEX.y);
 float nearby=1.0-smoothstep(75.0,170.0,distance(MAIN_CAM_INV_VIEW_MATRIX[3].xyz,anchor));
 vec2 local_wind=vec2(dot(vec3(wind_direction.x,0.0,wind_direction.y),normalize(MODEL_MATRIX[0].xyz)),dot(vec3(wind_direction.x,0.0,wind_direction.y),normalize(MODEL_MATRIX[2].xyz)));
 float phase=wind_time*1.6+(continuous_crown?VERTEX.y*.4:float(cluster)*1.83)+anchor.x*.13+anchor.z*.19;
 vec3 angle=vec3(local_wind.y,0.0,-local_wind.x)*wind_strength*.005*(sin(phase)+.35*sin(phase*.47));
 if(contact_active) for(int slot=0;slot<4;slot++) {
  if(contact_anchors[slot].w>.5 && dot(anchor-contact_anchors[slot].xyz,anchor-contact_anchors[slot].xyz)<.0025) {
   if(continuous_crown) {
    vec3 response=vec3(0.0); float total=0.0;
    for(int branch=0;branch<12;branch++) {
     vec3 delta=VERTEX-branch_centers[branch];
     float weight=1.0/pow(.2+dot(delta,delta),2.0);
     response+=contact_angles[slot*12+branch].xyz*weight; total+=weight;
    }
    angle+=response/max(total,.00001);
   } else angle+=contact_angles[slot*12+cluster].xyz;
  }
 }
 // Dead stems remain stiff; their fine branches retain a little motion.
 float stiffness=((COLOR.a>.05 && COLOR.a<.16) || (COLOR.a>.25 && COLOR.a<.36)) ? .28 : 1.0;
 angle*=flex*nearby*stiffness;
 vec3 offset=VERTEX-vec3(0.0,pivot_y,0.0);
 // One sine/cosine per axis serves position, normal and tangent frame.
 vec3 s=sin(angle),c=cos(angle);
 offset=bend(offset,s,c);
 NORMAL=bend(NORMAL,s,c);
#if !defined(ALPINE_FOREST_MID) || defined(ALPINE_MESHY_NORMALS)
 TANGENT=bend(TANGENT,s,c); BINORMAL=bend(BINORMAL,s,c);
#endif
 VERTEX=offset+vec3(0.0,pivot_y,0.0);
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 cloud_direct_transmission=sample_cloud_light(anchor);
 }
}
