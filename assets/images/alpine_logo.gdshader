shader_type canvas_item;
render_mode unshaded;
varying vec4 logo_modulate;

void vertex() {
	logo_modulate = COLOR;
}

void fragment() {
	vec4 logo = texture(TEXTURE, UV);
	// Source contains isolated electric-blue/cyan matte contamination.
	// Suppress that fringe without substituting a generated wordmark or alpha.
	float chroma = max(logo.r, max(logo.g, logo.b)) - min(logo.r, min(logo.g, logo.b));
	float contamination = smoothstep(0.46, 0.78, chroma) * (1.0 - smoothstep(0.18, 0.42, logo.r));
	logo.a *= 1.0 - contamination;
	float grey = dot(logo.rgb, vec3(0.2126, 0.7152, 0.0722));
	logo.rgb = mix(vec3(grey), logo.rgb, 0.80);
	COLOR = logo * logo_modulate;
}
