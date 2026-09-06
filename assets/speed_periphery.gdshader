shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float arcade_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float effect_time = 0.0;
float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float streaks(vec2 p, float offset) {
	float angle = atan(p.y, p.x) + 3.14159265;
	float lane = angle * 19.0 + offset;
	float id = floor(lane);
	float random = hash(id + offset * 23.0);
	float width = mix(0.018, 0.055, random);
	float line = 1.0 - smoothstep(width, width + 0.025, abs(fract(lane) - 0.5));
	float radius = length(p);
	float travel = fract(radius * 0.72 - effect_time * (0.9 + random * 1.3) + random);
	float tail = mix(0.035, 0.24, arcade_intensity);
	float dash = smoothstep(0.0, tail * 0.7, travel) * (1.0 - smoothstep(tail * 0.7, tail, travel));
	return line * dash * smoothstep(0.34, 0.85, radius);
}
void fragment() {
	vec2 radial = SCREEN_UV - vec2(0.5, 0.46);
	// Keep the route ahead sharp. A few pixels of peripheral streaking only.
	float periphery = smoothstep(0.24, 0.65, length(radial));
	vec2 offset = radial * periphery * intensity * 0.008;
	vec3 color = texture(screen_texture, SCREEN_UV).rgb * 0.4;
	color += texture(screen_texture, SCREEN_UV-offset).rgb * 0.2;
	color += texture(screen_texture, SCREEN_UV-offset*2.0).rgb * 0.1;
	color += texture(screen_texture, SCREEN_UV+offset).rgb * 0.2;
	color += texture(screen_texture, SCREEN_UV+offset*2.0).rgb * 0.1;
	vec2 p = radial * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float rush = streaks(p, 0.0) + streaks(p * 1.23, 7.4) * 0.5;
	color *= 1.0 - periphery * intensity * 0.10;
	color = mix(color, vec3(0.88, 0.96, 1.0), clamp(rush * arcade_intensity * 0.85, 0.0, 0.65));
	COLOR = vec4(color, 1.0);
}
