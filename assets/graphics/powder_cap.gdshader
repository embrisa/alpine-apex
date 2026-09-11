shader_type spatial;
render_mode cull_back;
#include "res://assets/graphics/snow_crystals.gdshaderinc"
#define ALPINE_SNOW_TRANSMISSION
varying vec3 snow_transmission;
#include "res://assets/cloud_light.gdshaderinc"
varying vec3 cap_world;
varying vec3 cap_normal;
void vertex() {
 cap_world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 cap_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 cloud_direct_transmission=sample_cloud_light(cap_world);
}
void fragment() {
 float distance_m=length(VERTEX);
 float detail=1.0-smoothstep(8.0,65.0,distance_m);
 vec3 n=normalize(cap_normal);
 vec2 grain=vec2(sin(cap_world.x*41.0+cap_world.z*23.0),sin(cap_world.z*47.0-cap_world.x*31.0));
 float footprint=max(length(dFdx(cap_world)),length(dFdy(cap_world)));
 float fine=1.0-smoothstep(.025,.08,footprint);
 // Match the terrain's 35% softer grain normal and halved micro-roughness.
 vec3 bump=vec3(grain.x,0,grain.y)*.02925*detail*fine;
 n=normalize(n+bump-n*dot(n,bump));
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0)).xyz);
 ALBEDO=mix(vec3(.74,.84,.93),vec3(.93,.965,.99),smoothstep(-.2,.7,n.y));
 ROUGHNESS=.83+grain.x*.0175*fine;
 SPECULAR=.38;
 snow_transmission=vec3(.17,.23,.30);
 vec4 crystals=sample_crystals(cap_world,n,1.0,distance_m);
 snow_glints=crystals.w;
 snow_facet_normal=normalize((VIEW_MATRIX*vec4(crystals.xyz,0)).xyz);
 vec4 large_crystals=sample_large_crystals(cap_world,n,1.0,distance_m);
 snow_large_glints=large_crystals.w;
 snow_large_facet_normal=normalize((VIEW_MATRIX*vec4(large_crystals.xyz,0)).xyz);
 snow_sheen=.80;
}
