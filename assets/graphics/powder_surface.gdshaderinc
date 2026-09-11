// Shared mask: the local mesh replaces the original terrain in this rectangle.
// No second intact surface can cover a recessed groove. Off on backdrop/rocks.
#include "res://assets/graphics/terrain_material.gdshaderinc"
uniform bool powder_patch_enabled = false;
uniform bool powder_local_surface = false;
uniform vec2 powder_center = vec2(0);
uniform float powder_extent = 32.0;
uniform sampler2D powder_imprints : filter_linear, repeat_disable;
varying float powder_compaction;
uniform float powder_loose_depth = .10;
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
 return min(powder_loose_depth*.38,.075)*(.22+pow(broad,1.7)*.62+small*.16);
}

float powder_edge(vec2 world) {
 return 1.0-smoothstep(powder_extent*.5-5.0,powder_extent*.5-1.0,max(abs(world.x-powder_center.x),abs(world.y-powder_center.y)));
}
vec2 powder_sample(vec2 world) {
 return textureLod(powder_imprints,(world-powder_center)/powder_extent+.5,0.0).rg;
}
float powder_height(vec2 world) {
 float imprint=powder_sample(world).x;
 float untouched=1.0-smoothstep(.0005,.010,-imprint);
 return (imprint+powder_fresh_height(world)*untouched)*powder_edge(world)*(1.0-smoothstep(.40,.50,contact_rock(world)));
}
