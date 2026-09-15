shader_type spatial;
render_mode cull_disabled, skip_vertex_transform;

// Isolated asset-review prototype. The eight-view atlas has transparent black
// texels: filtering associates RGB with coverage, which is removed below.
uniform sampler2D color_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_atlas : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D canopy_atlas : filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 crown_bounds = vec4(0.0, 5.0, 0.0, 5.0);
uniform bool fade_enabled = false;
uniform float near_distance = 12.0;
uniform float far_distance = 64.0;
uniform float feather = 5.0;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.35;
varying float atlas_view;
varying float coverage;
varying vec3 object_x;
varying vec3 object_y;
varying vec3 object_z;

float screen_threshold(vec2 pixel) {
	return fract(52.9829189 * fract(dot(floor(pixel), vec2(0.06711056, 0.00583715))));
}

void vertex() {
	object_x = normalize(MODEL_MATRIX[0].xyz);
	object_y = normalize(MODEL_MATRIX[1].xyz);
	object_z = normalize(MODEL_MATRIX[2].xyz);
	vec3 anchor = MODEL_MATRIX[3].xyz;
	vec3 camera = MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
	vec3 crown = (MODEL_MATRIX * vec4(crown_bounds.xyz, 1.0)).xyz;
	float scale = max(length(MODEL_MATRIX[0].xyz), max(length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz)));
	float distance_m = max(0.0, distance(camera, crown) - crown_bounds.w * scale);
	coverage = fade_enabled ? smoothstep(far_distance - feather, far_distance + feather, distance_m) : 1.0;
	vec3 toward_camera = camera - anchor;
	toward_camera.y = 0.0;
	toward_camera = normalize(toward_camera + vec3(0.0, 0.0, 0.000001));
	vec2 local_direction = vec2(dot(toward_camera, object_x), dot(toward_camera, object_z));
	atlas_view = mod(atan(local_direction.x, local_direction.y) + 6.283185307, 6.283185307) * 1.273239545;
	vec3 right = vec3(toward_camera.z, 0.0, -toward_camera.x);
	vec3 world_position = anchor + right * VERTEX.x * length(MODEL_MATRIX[0].xyz)
		+ vec3(0.0, VERTEX.y * length(MODEL_MATRIX[1].xyz), 0.0);
	VERTEX = (VIEW_MATRIX * vec4(world_position, 1.0)).xyz;
	NORMAL = normalize(mat3(VIEW_MATRIX) * toward_camera);
}

void fragment() {
	if (coverage < screen_threshold(FRAGCOORD.xy)) discard;
	float first_view = floor(atlas_view);
	float blend = smoothstep(0.0, 1.0, fract(atlas_view));
	// Half-texel tile inset prevents the neighbouring azimuth bleeding into UV.
	vec2 tile_uv = clamp(UV, vec2(0.5 / 512.0), vec2(1.0 - 0.5 / 512.0));
	vec2 uv0 = vec2((tile_uv.x + first_view) / 8.0, tile_uv.y);
	vec2 uv1 = vec2((tile_uv.x + mod(first_view + 1.0, 8.0)) / 8.0, tile_uv.y);
	vec4 color0 = texture(color_atlas, uv0);
	vec4 color1 = texture(color_atlas, uv1);
	float alpha = mix(color0.a, color1.a, blend);
	// Keep the filtered silhouette stable outside the LOD fade band. A random
	// edge threshold retains isolated low-coverage mip texels as a dotted halo.
	// The complementary LOD dither above remains independent of this cutout.
	if (alpha < alpha_cutoff) discard;
	ALBEDO = clamp(mix(color0.rgb, color1.rgb, blend) / max(alpha, 0.0001), vec3(0.0), vec3(1.0));
	vec4 normal0 = texture(normal_atlas, uv0);
	vec4 normal1 = texture(normal_atlas, uv1);
	vec3 direction0 = normal0.rgb / max(normal0.a, 0.0001) * 2.0 - 1.0;
	vec3 direction1 = normal1.rgb / max(normal1.a, 0.0001) * 2.0 - 1.0;
	vec3 direction = normalize(mix(direction0 * color0.a, direction1 * color1.a, blend) + vec3(0.0, 0.000001, 0.0));
	vec3 world_normal = normalize(object_x * direction.x + object_y * direction.y + object_z * direction.z);
	NORMAL = normalize(mat3(VIEW_MATRIX) * world_normal);
	float canopy = clamp(mix(texture(canopy_atlas, uv0).r, texture(canopy_atlas, uv1).r, blend) / max(alpha, 0.0001), 0.0, 1.0);
	ROUGHNESS = mix(0.94, 0.89, canopy);
	SPECULAR = 0.14;
}
