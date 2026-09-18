// Linear, energy-normalized weather colours; zero alpha until a world publishes.
global uniform vec4 snow_ambient_top;
global uniform vec4 snow_ambient_horizon;
vec4 snow_sky_ambient(vec3 world_normal, float snow_weight) {
 // Broad diffuse hemisphere: up-facing snow sees more zenith, banks more horizon.
 float top_weight=.35+.40*clamp(world_normal.y,0.0,1.0);
 return vec4(mix(snow_ambient_horizon.rgb,snow_ambient_top.rgb,top_weight),
             snow_ambient_top.a*clamp(snow_weight,0.0,1.0));
}
