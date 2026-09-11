shader_type canvas_item;
render_mode unshaded;

// One non-destructive photographic treatment; no invented snow or equipment.
uniform float source_aspect = 1.5;
uniform float viewport_aspect = 1.777778;
uniform vec2 focal_point = vec2(0.5, 0.5);
uniform bool framed = false;
uniform float exposure = 1.0;
uniform float saturation = 0.60;
uniform float shade = 1.0;
// Shared menu/loading atmosphere; owners supply time and reduced-motion state.
uniform bool loading_atmosphere = false;
uniform bool animate_loading = false;
uniform float visual_time = 0.0;
uniform vec2 light_position = vec2(0.8, -0.05);
uniform vec4 light_tint : source_color = vec4(1.0, 0.88, 0.68, 1.0);
uniform float light_strength = 0.0;
uniform float ray_strength = 0.0;

float lens_ring(float distance_from_center, float radius, float width) {
	float rim = (distance_from_center - radius) / width;
	return exp(-rim * rim);
}

vec3 sunlight(vec3 photo, vec2 image_uv) {
	vec2 p = (image_uv - light_position) * vec2(source_aspect, 1.0);
	float radius2 = dot(p, p);
	float phase = visual_time * 0.261799388;
	float variation = animate_loading ? 0.92 + 0.08 * cos(phase) : 1.0;
	float glow = exp(-radius2 * 2.8) * 0.34 + exp(-radius2 * 42.0) * 0.95;
	float angle = atan(p.y, p.x);
	float sway = animate_loading ? sin(phase) * 0.035 : 0.0;
	float rays = pow(max(0.0, sin((angle + sway) * 9.0)), 6.0);
	rays *= exp(-radius2 * 1.9) * smoothstep(0.025, 0.18, radius2) * ray_strength * 0.30;
	// A warm solar halo follows the source, with a broad, soft outer shoulder.
	float halo_radius = 0.29 + (animate_loading ? sin(phase) * 0.020 : 0.0);
	float distance_from_sun = sqrt(radius2);
	float halo = lens_ring(distance_from_sun, halo_radius, 0.020) * 0.70;
	halo += lens_ring(distance_from_sun, halo_radius, 0.060) * 0.16;
	halo *= 0.72 + 0.28 * sin(angle * 2.0 + sway);
	// Sweep along and across the light axis: the rings visibly glide over the
	// photograph rather than following only its small camera drift.
	vec2 axis = vec2(0.5) - light_position;
	vec2 cross_axis = vec2(-axis.y, axis.x);
	vec2 lens_drift = animate_loading ? axis * (sin(phase) * 0.16) + cross_axis * (sin(phase + 0.7) * 0.10) : vec2(0.0);
	vec2 ghost = (image_uv - (light_position + axis * 1.08 + lens_drift)) * vec2(source_aspect, 1.0);
	float ghost_distance = length(ghost);
	float ghost_radius = 0.135 + (animate_loading ? sin(phase + 0.7) * 0.010 : 0.0);
	vec3 lenses = vec3(1.0, 0.66, 0.24) * lens_ring(ghost_distance, ghost_radius + 0.007, 0.013) * 1.10;
	lenses += vec3(0.32, 0.76, 1.0) * lens_ring(ghost_distance, ghost_radius - 0.008, 0.008) * 0.70;
	lenses += vec3(0.48, 0.78, 0.92) * exp(-dot(ghost, ghost) * 65.0) * 0.14;
	vec2 secondary_drift = animate_loading ? axis * (sin(phase + 0.9) * 0.11) - cross_axis * (sin(phase * 2.0 + 0.2) * 0.065) : vec2(0.0);
	ghost = (image_uv - (light_position + axis * 1.56 + secondary_drift)) * vec2(source_aspect, 1.0);
	lenses += vec3(0.54, 0.92, 0.76) * (lens_ring(length(ghost), 0.061, 0.012) * 0.50 + exp(-dot(ghost, ghost) * 150.0) * 0.14);
	vec2 inner_drift = animate_loading ? axis * (sin(phase + 2.0) * 0.09) + cross_axis * (sin(phase - 0.5) * 0.065) : vec2(0.0);
	ghost = (image_uv - (light_position + axis * 0.56 + inner_drift)) * vec2(source_aspect, 1.0);
	lenses += vec3(1.0, 0.78, 0.43) * exp(-dot(ghost, ghost) * 420.0) * 0.40;
	// Per-photo ray strength suppresses colored rings in overcast/monochrome art.
	vec3 light = light_tint.rgb * (glow + rays + halo * ray_strength) + lenses * ray_strength;
	light *= light_strength * variation;
	return photo + (vec3(1.0) - photo) * clamp(light, vec3(0.0), vec3(1.0));
}

vec3 grade(vec3 rgb) {
	rgb *= exposure;
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	rgb = mix(vec3(luma), rgb, saturation);
	// Lift the darkest values and soften whites, keeping natural local detail.
	rgb = rgb * 0.91 + vec3(0.025, 0.035, 0.046);
	float shadow = 1.0 - smoothstep(0.08, 0.78, luma);
	rgb += vec3(-0.014, 0.004, 0.025) * shadow;
	return clamp(rgb, vec3(0.0), vec3(0.95, 0.97, 0.99));
}

void fragment() {
	vec2 crop = min(vec2(viewport_aspect / source_aspect, source_aspect / viewport_aspect), vec2(1.0));
	vec2 focus = focal_point;
	if (animate_loading) {
		float phase = visual_time * 0.261799388;
		float zoom = 1.035 - 0.015 * cos(phase);
		crop /= zoom;
		focus += vec2(sin(phase) * 0.01, sin(phase) * 0.003);
	}
	vec2 origin = clamp(focus - crop * 0.5, vec2(0.0), vec2(1.0) - crop);
	vec2 image_uv = origin + UV * crop;
	vec3 photo = grade(texture(TEXTURE, image_uv).rgb);
	if (loading_atmosphere) photo = sunlight(photo, image_uv);
	vec3 navy = vec3(0.025, 0.052, 0.085);
	if (framed) {
		// Fit the whole photograph to a right-hand print. Portraits retain skis/poles.
		vec2 frame_size = vec2(min(0.46, 0.84 * source_aspect / viewport_aspect), 0.84);
		frame_size.y = frame_size.x * viewport_aspect / source_aspect;
		vec2 frame_origin = vec2(0.73 - frame_size.x * 0.5, 0.5 - frame_size.y * 0.5);
		vec2 print_uv = (UV - frame_origin) / frame_size;
		vec2 edge = min(UV - frame_origin, frame_origin + frame_size - UV);
		bool inside = min(edge.x, edge.y) >= 0.0;
		photo = mix(navy, photo, 0.055);
		if (inside) {
			photo = grade(texture(TEXTURE, print_uv).rgb);
			if (loading_atmosphere) photo = sunlight(photo, print_uv);
			float border = 1.0 - smoothstep(0.0007, 0.0015, min(edge.x, edge.y));
			photo = mix(photo, vec3(0.60, 0.76, 0.84), border * 0.6);
		}
	} else {
		// Readable left rail; keep the athlete and mountain on the right luminous.
		float left = 1.0 - smoothstep(0.10, 0.70, UV.x);
		float bottom = smoothstep(0.60, 1.0, UV.y);
		float top = 1.0 - smoothstep(0.0, 0.30, UV.y);
		float scrim = max(left * 0.90, max(bottom * 0.74, top * 0.28));
		photo = mix(photo, navy, scrim);
	}
	// Static fine grain is subtle and does not animate when reduced motion is on.
	float grain = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	photo += grain * 0.003;
	COLOR = vec4(mix(navy, photo, shade), 1.0);
}
