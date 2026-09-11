shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D mineral_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 rock_tint : source_color = vec3(0.83, 0.85, 0.87);
uniform float color_saturation = 0.65;
uniform float detail_scale = 1.2;
uniform float detail_depth = 0.009;
uniform float moss_coverage : hint_range(0.0, 1.0) = 0.0;
uniform bool glacier = false;
varying vec3 local_position;
varying vec3 local_normal;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i+vec3(1,0,0)), f.x),
		mix(hash3(i+vec3(0,1,0)), hash3(i+vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(i+vec3(0,0,1)), hash3(i+vec3(1,0,1)), f.x),
		mix(hash3(i+vec3(0,1,1)), hash3(i+vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 albedo = texture(albedo_map, UV).rgb;
	vec2 normal_xy = texture(normal_map, UV).xy * 2.0 - 1.0;
	vec3 tangent_normal = vec3(normal_xy, sqrt(max(0.0, 1.0-dot(normal_xy, normal_xy))));
	vec3 mapped_normal = normalize(TANGENT*tangent_normal.x + BINORMAL*tangent_normal.y + NORMAL*tangent_normal.z);
	float roughness = texture(roughness_map, UV).g;
	if (!glacier) {
		albedo = mix(vec3(dot(albedo,vec3(.2126,.7152,.0722))), albedo, color_saturation);
		// Metre-scale detail remains sharp on a 220 m cliff. The unique UV bake
		// carries the formation's shape, large cracks and source material layers.
		vec3 weights = pow(abs(normalize(local_normal)), vec3(5.0));
		weights /= max(dot(weights, vec3(1.0)), 0.0001);
		vec3 p = local_position * detail_scale;
		vec3 tile = texture(mineral_detail, p.zy).rgb * weights.x
			+ texture(mineral_detail, p.xz).rgb * weights.y
			+ texture(mineral_detail, p.xy).rgb * weights.z;
		float height = dot(tile, vec3(0.2126,0.7152,0.0722));
		albedo *= rock_tint * (0.82 + 0.70*height);
		// Surface derivatives give the triplanar grain a consistent normal frame.
		vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
		vec3 r1 = cross(dy, NORMAL), r2 = cross(NORMAL, dx);
		float determinant = dot(dx, r1);
		vec3 gradient = (r1*dFdx(height) + r2*dFdy(height)) * sign(determinant) / max(abs(determinant), 0.00001);
		mapped_normal = normalize(mapped_normal - detail_depth*gradient);
		roughness = clamp(roughness, .55, .96);
		if (moss_coverage > .001) {
			float patch = noise3(local_position*.95) * .72 + noise3(local_position*3.2) * .28;
			float up = smoothstep(.42, .90, normalize(local_normal).y);
			float moss = smoothstep(.66, .82, patch + moss_coverage*.25) * up * moss_coverage;
			vec3 moss_color = mix(vec3(.017,.027,.006), vec3(.08,.115,.019), noise3(local_position*19.0));
			albedo = mix(albedo, moss_color, moss);
			roughness = mix(roughness, .98, moss);
		}
	}
	ALBEDO = albedo;
	NORMAL = mapped_normal;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = .3;
}
