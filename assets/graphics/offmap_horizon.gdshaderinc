// Two filtered samples, four azimuth angles per layer. Off skips both lookups.
uniform bool offmap_horizon_enabled = false;
uniform sampler2DArray offmap_horizon : filter_linear, repeat_disable;
uniform vec4 offmap_horizon_bins = vec4(0.0);
uniform float offmap_horizon_blend = 0.0;
uniform float offmap_light_elevation = 1.5707963;
float offmap_horizon_visibility(vec3 p) {
 if (!offmap_horizon_enabled) return 1.0;
 // The variable mountain and its connector never act as baked occluders.
 // Fade beyond their conservative bound; do not invent seed-specific shadows.
 float coverage = smoothstep(3900.0,4300.0,length(p.xz));
 if (coverage<=0.0) return 1.0;
 vec2 uv = p.xz/36000.0+vec2(.5);
 float a = texture(offmap_horizon,vec3(uv,offmap_horizon_bins.x))[int(offmap_horizon_bins.y)];
 float b = texture(offmap_horizon,vec3(uv,offmap_horizon_bins.z))[int(offmap_horizon_bins.w)];
 float angle = mix(a,b,offmap_horizon_blend);
 return mix(1.0,smoothstep(angle-.015,angle+.015,offmap_light_elevation),coverage);
}
