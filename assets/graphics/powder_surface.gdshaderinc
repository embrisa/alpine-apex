// Shared world-locked mapping. Storage stays on the terrain grid while a round
// visual influence follows the rendered rider inside its guaranteed coverage.
#include "res://assets/graphics/terrain_material.gdshaderinc"
uniform bool powder_patch_enabled = false;
uniform bool powder_local_surface = false;
uniform vec2 powder_center = vec2(0);
uniform vec2 powder_visual_center = vec2(0);
uniform float powder_extent = 32.0;
uniform sampler2D powder_imprints : filter_linear, repeat_disable;
uniform sampler2D powder_support_data : filter_nearest, repeat_disable;
uniform vec4 powder_bounds = vec4(-384,-192,384,1856);
uniform bool powder_footprint_enabled = false;
uniform vec4 powder_footprint_shape = vec4(3032,42,24,18);
varying float powder_compaction;
// Fixed terrain vertex normals (xyz) and local loose depth (w), at 4 m knots.
// Do NOT normalize the interpolated normal here: the base terrain normal is
// also linearly interpolated across these exact triangles before fragment().
vec4 powder_support(vec2 world) {
 vec2 grid=clamp((world-powder_center+vec2(powder_extent*.5))/4.0,vec2(0),vec2(7.99999));
 ivec2 cell=ivec2(floor(grid)); vec2 f=fract(grid);
 vec4 b=texelFetch(powder_support_data,cell+ivec2(1,0),0);
 vec4 c=texelFetch(powder_support_data,cell+ivec2(0,1),0);
 if(f.x+f.y<=1.0) {
  vec4 a=texelFetch(powder_support_data,cell,0);
  return a+f.x*(b-a)+f.y*(c-a);
 }
 vec4 d=texelFetch(powder_support_data,cell+ivec2(1,1),0);
 return d+(1.0-f.x)*(c-d)+(1.0-f.y)*(b-d);
}
bool powder_owns_terrain(vec2 world) {
 if(any(lessThan(world,powder_bounds.xy)) || any(greaterThanEqual(world,powder_bounds.zw))) return false;
 if(!powder_footprint_enabled) return true;
 // Same retained 32 m ownership cells as MountainFootprint/terrain preparation.
 vec2 p=floor(world/32.0)*32.0+vec2(16.0);
 float angle=atan(p.x,p.y);
 float radius=powder_footprint_shape.x+powder_footprint_shape.y*sin(angle*3.0)
  +powder_footprint_shape.z*sin(angle*5.0)+powder_footprint_shape.w*sin(angle*2.0);
 return length(p)<=radius;
}
bool powder_replaces(vec2 world) {
 return length(world-powder_visual_center)<13.5 && powder_owns_terrain(world);
}
float powder_noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 vec4 h=fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1),vec2(127.1,311.7))))*43758.5453);
 return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y);
}
float powder_fresh_height(vec2 world) {
 vec2 wind=vec2(world.x*.93+world.y*.37,world.y*.93-world.x*.37);
 float broad=powder_noise(wind*vec2(1.8,.52));
 float small=powder_noise(wind*vec2(5.6,2.0)+vec2(37,91));
 // Centimetre-scale loose crowns above the support surface. Large deposits
 // belong to the physical generator; this detail stays within loose depth.
 return min(powder_support(world).w*.38,.075)*(.22+pow(broad,1.7)*.62+small*.16);
}

float powder_edge(vec2 world) {
 return 1.0-smoothstep(8.0,13.0,length(world-powder_visual_center));
}
vec2 powder_sample(vec2 world) {
 return textureLod(powder_imprints,(world-powder_center)/powder_extent+.5,0.0).rg;
}
float powder_height(vec2 world) {
 float edge=powder_edge(world);
 if(edge<=0.0) return 0.0;
 float imprint=powder_sample(world).x;
 float untouched=1.0-smoothstep(.0005,.010,-imprint);
 return (imprint+powder_fresh_height(world)*untouched)*edge*(1.0-smoothstep(.40,.50,contact_rock(world)));
}
