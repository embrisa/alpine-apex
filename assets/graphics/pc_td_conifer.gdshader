shader_type spatial;
render_mode cull_disabled;
#define ALPINE_NEEDLE_TRANSMISSION
varying float needle_transmission;
#include "res://assets/cloud_light.gdshaderinc"
#include "res://assets/graphics/pc_lod.gdshaderinc"
uniform sampler2D bark_texture : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D needle_mask : filter_linear_mipmap_anisotropic,repeat_disable;
uniform float wind_time = 0.0;
uniform float wind_strength = 0.0;
uniform vec2 wind_direction = vec2(1.0,0.0);
uniform vec4 contact_anchors[4];
uniform vec4 contact_angles[48];
uniform bool contact_active=true;
varying flat float lod_coverage;
varying vec3 world_normal;

// Rotation by precomputed sines/cosines; the caller evaluates them once per
// vertex and reuses them for position, normal and tangent frame.
vec3 bend(vec3 p,vec3 s,vec3 c) {
 vec3 q=vec3(p.x*c.z-p.y*s.z,p.x*s.z+p.y*c.z,p.z);
 q=vec3(q.x,q.y*c.x-q.z*s.x,q.y*s.x+q.z*c.x);
 return vec3(q.x*c.y+q.z*s.y,q.y,-q.x*s.y+q.z*c.y);
}
void vertex() {
 lod_coverage=pc_lod_coverage(MAIN_CAM_INV_VIEW_MATRIX[3].xyz,MODEL_MATRIX[3].xyz,MODEL_MATRIX);
 vec3 anchor=MODEL_MATRIX[3].xyz;
 int cluster=clamp(int(round(UV2.x*16.0)),0,11);
 float pivot_y=UV2.y*12.0;
 float flex=smoothstep(.18,1.7,length(VERTEX.xz))*smoothstep(.3,1.4,VERTEX.y);
 float nearby=1.0-smoothstep(75.0,170.0,distance(MAIN_CAM_INV_VIEW_MATRIX[3].xyz,anchor));
 vec2 local_wind=vec2(dot(vec3(wind_direction.x,0.0,wind_direction.y),normalize(MODEL_MATRIX[0].xyz)),dot(vec3(wind_direction.x,0.0,wind_direction.y),normalize(MODEL_MATRIX[2].xyz)));
 float phase=wind_time*1.7+float(cluster)*1.83+anchor.x*.13+anchor.z*.19;
 vec3 angle=vec3(local_wind.y,0.0,-local_wind.x)*wind_strength*.007*(sin(phase)+.35*sin(phase*.47));
 if(contact_active) for(int slot=0;slot<4;slot++) {
  if(contact_anchors[slot].w>.5 && distance(anchor,contact_anchors[slot].xyz)<.05) angle+=contact_angles[slot*12+cluster].xyz;
 }
 angle*=flex*nearby;
 vec3 offset=VERTEX-vec3(0.0,pivot_y,0.0);
 // One sine/cosine per axis serves both the position and the normal.
 vec3 s=sin(angle),c=cos(angle);
 offset=bend(offset,s,c);
 NORMAL=bend(NORMAL,s,c);
 VERTEX=offset+vec3(0.0,pivot_y,0.0);
 // A small elastic crown sway leaves the collidable base stationary.
 VERTEX.xz+=local_wind*wind_strength*.009*pow(clamp(VERTEX.y/10.5,0.0,1.0),2.0)*nearby*sin(wind_time*.9+anchor.x*.2);
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 cloud_direct_transmission=sample_cloud_light(anchor);
}
void fragment() {
 float threshold=pc_lod_threshold(FRAGCOORD.xy);
 if(pc_lod_ranges.w==1.0) threshold=1.0-threshold;
 if(lod_coverage<threshold) discard;
 float wood=1.0-step(.25,COLOR.a);
 float cap=step(.8,COLOR.a);
 if(wood<.5 && cap<.5 && texture(needle_mask,UV).a<.35) discard;
 vec3 tint=COLOR.rgb;
 float dust=smoothstep(.45,.95,world_normal.y)*.12*(1.0-cap);
 tint=mix(tint,vec3(.73,.81,.88),dust);
 ALBEDO=mix(tint,texture(bark_texture,UV).rgb,wood);
 ROUGHNESS=mix(.86,.77,cap);
 SPECULAR=.25;
 needle_transmission=(1.0-wood)*(1.0-cap)*.13;
 if(!FRONT_FACING) NORMAL=-NORMAL;
}
