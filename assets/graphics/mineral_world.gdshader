shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D mineral_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 rock_tint : source_color = vec3(0.46, 0.49, 0.52);
uniform float color_saturation = 0.65;
uniform float detail_scale = 1.2;
uniform float detail_depth = 0.009;
uniform float moss_coverage : hint_range(0.0, 1.0) = 0.0;
uniform bool glacier = false;
#include "res://assets/cloud_field.gdshaderinc"
uniform sampler2D snow_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D support_height : filter_nearest, repeat_disable;
uniform sampler2D support_exposure : filter_linear, repeat_disable;
uniform sampler2D terrain_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 support_origin;
uniform vec2 support_size = vec2(1537.0);
#include "res://assets/cloud_light.gdshaderinc"
varying vec3 world_position;
varying vec3 world_normal;
varying vec4 mineral_instance;
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
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
	mineral_instance = INSTANCE_CUSTOM;
	cloud_direct_transmission = sample_cloud_light(world_position);
	local_position = VERTEX*length(MODEL_MATRIX[0].xyz);
	local_normal = NORMAL;
}

void fragment() {
	vec3 albedo = texture(albedo_map, UV).rgb;
	vec2 normal_xy = texture(normal_map, UV).xy * 2.0 - 1.0;
	vec3 tangent_normal = vec3(normal_xy, sqrt(max(0.0, 1.0-dot(normal_xy, normal_xy))));
	vec3 mapped_normal = normalize(TANGENT*tangent_normal.x + BINORMAL*tangent_normal.y + NORMAL*tangent_normal.z);
	float roughness = texture(roughness_map, UV).g;
	if (glacier) {
		// Weathered outer ice shares the muted blue-grey of the continuous
		// terrain apron; the unique bake still carries darker blue fractures.
		float ice_value = dot(albedo,vec3(.2126,.7152,.0722));
		albedo = mix(vec3(ice_value),albedo,.42);
		albedo = mix(albedo,vec3(.62,.73,.79),.22);
		roughness = max(roughness,.48);
	}
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
		float effective_moss = mineral_instance.g;
		if (effective_moss > .001) {
			float patch = noise3(local_position*.95) * .72 + noise3(local_position*3.2) * .28;
			float up = smoothstep(.42, .90, normalize(world_normal).y);
			float moss = smoothstep(.66, .82, patch + effective_moss*.25) * up * effective_moss;
			vec3 moss_color = mix(vec3(.017,.027,.006), vec3(.08,.115,.019), noise3(local_position*19.0));
			albedo = mix(albedo, moss_color, moss);
			roughness = mix(roughness, .98, moss);
		}
	}
	// Snow follows world-up after placement; the unique baked strata stay below.
	float patch = noise3(world_position*.16)*.65+noise3(world_position*.73)*.35;
	float up = smoothstep(.48,.89,world_normal.y);
	float snow = smoothstep(.27,.65,up*mineral_instance.r+patch*.24-.12);
	if (glacier) snow *= .45;
	if (snow>.001) {
		vec3 color = texture(snow_albedo,world_position.xz*.115).rgb;
		vec2 bump = texture(snow_normal,world_position.xz*.115).xy*2.0-1.0;
		albedo = mix(albedo,color,snow);
		vec3 snow_n=normalize(NORMAL+vec3(bump.x*.16,bump.y*.16,0));
		mapped_normal=normalize(mix(mapped_normal,snow_n,snow));
		roughness=mix(roughness,.76,snow);
	}
	// Exact 4 m triangle height only shades the shallow contact transition.
	// It never displaces the mesh or changes skiing support.
	vec2 grid=clamp((world_position.xz-support_origin)/4.0,vec2(0),support_size-vec2(1.001));
	ivec2 cell=ivec2(floor(grid)); vec2 f=fract(grid);
	float h00=texelFetch(support_height,cell,0).r;
	float h10=texelFetch(support_height,cell+ivec2(1,0),0).r;
	float h01=texelFetch(support_height,cell+ivec2(0,1),0).r;
	float h11=texelFetch(support_height,cell+ivec2(1,1),0).r;
	float height=f.x+f.y<=1.0 ? h00+(h10-h00)*f.x+(h01-h00)*f.y : h11+(h01-h11)*(1.0-f.x)+(h10-h11)*(1.0-f.y);
	float seam=(1.0-smoothstep(.03,1.5,world_position.y-height))*(1.0-float(glacier));
	if(seam>.001) {
		vec4 exposure=texture(support_exposure,(grid+vec2(.5))/support_size);
		vec3 base_stone=texture(terrain_rock,world_position.xz*.075).rgb;
		base_stone=mix(vec3(dot(base_stone,vec3(.2126,.7152,.0722))),base_stone,.22)*vec3(.42,.44,.47);
		vec3 base_snow=texture(snow_albedo,world_position.xz*.115).rgb;
		base_snow=mix(vec3(.94,.965,.99),base_snow,.28);
		float settled=smoothstep(.55,.85,world_normal.y)*(1.0-exposure.r);
		albedo=mix(albedo,mix(base_stone,base_snow,settled),seam*.82);
	}
	ALBEDO = albedo;
	NORMAL = mapped_normal;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = .3;
}
