shader_type spatial;
render_mode cull_disabled;
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
uniform float wind_time=0.0;
uniform float wind_strength=0.0;
uniform vec2 wind_direction=vec2(1.0,0.0);
uniform float snow_coverage : hint_range(0.0,1.0)=1.0;
uniform vec4 contact_anchors[4];
uniform vec4 contact_angles[48];
varying flat float lod_coverage;
varying vec3 world_normal;
varying vec3 local_position;
vec3 bend(vec3 p,vec3 a) {
 float sx=sin(a.x),cx=cos(a.x),sy=sin(a.y),cy=cos(a.y),sz=sin(a.z),cz=cos(a.z);
 vec3 q=vec3(p.x*cz-p.y*sz,p.x*sz+p.y*cz,p.z);
 q=vec3(q.x,q.y*cx-q.z*sx,q.y*sx+q.z*cx);
 return vec3(q.x*cy+q.z*sy,q.y,-q.x*sy+q.z*cy);
}
void vertex() {
 local_position=VERTEX;
 lod_coverage=pc_lod_coverage(MAIN_CAM_INV_VIEW_MATRIX[3].xyz,MODEL_MATRIX[3].xyz,MODEL_MATRIX);
 // Per-tree distance can hide part of a regional batch. Collapse those
 // triangles before rasterization and avoid invisible branch/wind work.
 if(pc_lod_individual && lod_coverage<=0.0) {
  VERTEX=vec3(0.0);
  world_normal=vec3(0.0,1.0,0.0);
  cloud_direct_transmission=1.0;
 } else {
 vec3 anchor=MODEL_MATRIX[3].xyz;
 int cluster=clamp(int(round(UV2.x*16.0)),0,11);
 float pivot_y=UV2.y*32.0;
 float flex=smoothstep(.12,1.1,length(VERTEX.xz))*smoothstep(.3,1.8,VERTEX.y);
 float nearby=1.0-smoothstep(75.0,170.0,distance(MAIN_CAM_INV_VIEW_MATRIX[3].xyz,anchor));
 vec2 local_wind=vec2(dot(vec3(wind_direction.x,0.0,wind_direction.y),normalize(MODEL_MATRIX[0].xyz)),dot(vec3(wind_direction.x,0.0,wind_direction.y),normalize(MODEL_MATRIX[2].xyz)));
 float phase=wind_time*1.6+float(cluster)*1.83+anchor.x*.13+anchor.z*.19;
 vec3 angle=vec3(local_wind.y,0.0,-local_wind.x)*wind_strength*.005*(sin(phase)+.35*sin(phase*.47));
 for(int slot=0;slot<4;slot++) {
  if(contact_anchors[slot].w>.5 && dot(anchor-contact_anchors[slot].xyz,anchor-contact_anchors[slot].xyz)<.0025) angle+=contact_angles[slot*12+cluster].xyz;
 }
 // Dead stems remain stiff; their fine branches retain a little motion.
 float stiffness=((COLOR.a>.05 && COLOR.a<.16) || (COLOR.a>.25 && COLOR.a<.36)) ? .28 : 1.0;
 angle*=flex*nearby*stiffness;
 VERTEX=bend(VERTEX-vec3(0.0,pivot_y,0.0),angle)+vec3(0.0,pivot_y,0.0);
 NORMAL=bend(NORMAL,angle);
 TANGENT=bend(TANGENT,angle); BINORMAL=bend(BINORMAL,angle);
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 cloud_direct_transmission=sample_cloud_light(anchor);
 }
}
void fragment() {
 float threshold=pc_lod_threshold(FRAGCOORD.xy);
 if(pc_lod_ranges.w==1.0) threshold=1.0-threshold;
 if(lod_coverage<threshold) discard;
 float mask=COLOR.a;
 bool wood=mask<.4;
 bool snow=mask>.9;
 if(!wood && foliage_sight_parameters.x>0.0 && !IN_SHADOW_PASS) {
  if(foliage_sight_removal(SCREEN_UV,-VERTEX.z)>foliage_sight_threshold(FRAGCOORD.xy)) discard;
 }
 if(snow && snow_coverage<.5) discard;
 vec3 tint=COLOR.rgb;
 ALPHA=1.0;
 ALPHA_SCISSOR_THRESHOLD=.5;
 if(mask>.65 && mask<.8) {
  vec4 needles=texture(foliage_texture,UV);
  if(needles.a<.5) discard;
  ALPHA=needles.a;
  tint*=needles.rgb*foliage_color_grade;
  vec4 detail=texture(foliage_normal_ao,UV);
  NORMAL_MAP=detail.rgb;
  NORMAL_MAP_DEPTH=.4;
  AO=mix(.60,1.0,detail.a);
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
  NORMAL_MAP=texture(bark_normal,UV).rgb;
  NORMAL_MAP_DEPTH=mask>.25?.08:.55;
 }
 float dust=smoothstep(.72,.97,world_normal.y)*snow_coverage*.08;
 if(mask>.65 && mask<.8) dust*=.15;
 ALBEDO=mix(tint,vec3(.75,.81,.86),dust*(snow?0.0:1.0));
 ROUGHNESS=snow?.83:.91;
 SPECULAR=.16;
 needle_transmission=(!wood && !snow)?.12:0.0;
 if(!FRONT_FACING) NORMAL=-NORMAL;
}
