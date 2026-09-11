#define ALPINE_SNOW_SPARKLE
uniform float snow_sparkle_strength : hint_range(0.0,12.0) = 9.0;
uniform float snow_crystal_density : hint_range(0.0,2.5) = 1.75;
uniform float snow_sheen_strength : hint_range(0.0,1.0) = .1584;
varying float snow_glints;
varying vec3 snow_facet_normal;
varying float snow_large_glints;
varying vec3 snow_large_facet_normal;
varying float snow_sheen;
vec3 crystal_hash(vec2 p) {
 vec3 h=fract(vec3(p.xyx)*vec3(.1031,.1030,.0973));
 h+=dot(h,h.yxz+33.33);
 return fract((h.xxy+h.yzz)*h.zyx);
}
// Fragment-only. World-locked grain location and facet tilt are independent.
// Integrate the footprint and then remove resolved glints before undersampling.
// Unresolved snow retains the material's ordinary broad dielectric reflection.
vec4 sample_crystal_layer(vec3 position,vec3 normal,float density,float distance_m,float scale_m,vec2 fade_m,vec2 seed,float radius) {
 vec2 uv=position.xz*scale_m;
 vec2 cell=floor(uv);
 vec3 random=crystal_hash(cell+vec2(317.3,91.7)+seed);
 vec3 orientation=crystal_hash(cell+vec2(41.1,653.7)+seed);
 vec2 delta=fract(uv)-(.25+random.xy*.50);
 float footprint=max(length(dFdx(uv)),length(dFdy(uv)));
 float width=radius+min(footprint,.35)*.32;
 float grain=1.0-smoothstep(radius*.55,width,length(delta));
 // Increasing occupancy reveals more independently oriented facets; it does
 // not merely multiply the brightness of the original sparse grains.
 float coverage=grain*smoothstep(.40,.85,random.z*snow_crystal_density)*density;
 coverage*=1.0-smoothstep(.22,.85,footprint);
 coverage*=1.0-smoothstep(fade_m.x,fade_m.y,distance_m);
 vec3 facet=vec3(orientation.x-.5,0,orientation.y-.5)*1.35;
 facet=normalize(normal+facet-normal*dot(facet,normal));
 return vec4(facet,coverage);
}
vec4 sample_crystals(vec3 position,vec3 normal,float density,float distance_m) {
 if(snow_sparkle_strength<=0.0) return vec4(normal,0.0);
 return sample_crystal_layer(position,normal,density,distance_m,24.0,vec2(10,32),vec2(0),.045);
}
vec4 sample_large_crystals(vec3 position,vec3 normal,float density,float distance_m) {
 if(snow_sparkle_strength<=0.0) return vec4(normal,0.0);
 return sample_crystal_layer(position,normal,density,distance_m,8.0,vec2(20,60),vec2(173.1,527.7),.085);
}
