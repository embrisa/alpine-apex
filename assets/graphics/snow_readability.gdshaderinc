// Artistic shape contrast from real terrain concavity, shared by the terrain,
// replacement powder patch and tracks. No normal/displacement/collision edits.
uniform bool snow_hollows_enabled = false;
uniform sampler2D snow_hollows : filter_linear_mipmap, repeat_disable;
uniform vec2 snow_hollows_origin;
uniform vec2 snow_hollows_size = vec2(1.0);
uniform float snow_hollows_cell_m = 4.0;
uniform float snow_hollows_strength : hint_range(0.0,1.0) = 1.0;

vec3 snow_shape_tint(vec2 world_xz, float distance_m) {
	if (!snow_hollows_enabled || snow_hollows_strength<=0.0) return vec3(1.0);
	vec2 grid = (world_xz-snow_hollows_origin)/snow_hollows_cell_m;
	vec2 uv = (grid+.5)/snow_hollows_size;
	// Derivatives precede pixel-varying bounds/distance branches so partial
	// screen quads still select a stable mip level at the edge of the treatment.
	vec2 dx = dFdx(uv); vec2 dy = dFdy(uv);
	float weight = snow_hollows_strength * smoothstep(0.0,.16,cloud_sun_direction.y)
		* (1.0-smoothstep(80.0,160.0,distance_m));
	if (weight<=0.0) return vec3(1.0);
	if (any(lessThan(grid,vec2(0.0))) || any(greaterThan(grid,snow_hollows_size-1.0))) return vec3(1.0);
	// Grid vertices address texel centres on every receiver; mip filtering and
	// the distance fade prevent crawling edges in temporal upscalers.
	float hollow = textureGrad(snow_hollows,uv,dx,dy).r;
	// Linear-light luminance reduction at maximum weight: 13.98%. No brightening,
	// emission or extra blue light; the existing reflected sky remains intact.
	return mix(vec3(1.0),vec3(.804,.8698,.93),clamp(hollow*weight,0.0,1.0));
}
