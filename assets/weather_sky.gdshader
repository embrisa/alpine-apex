shader_type sky;
render_mode use_half_res_pass;
#include "res://assets/cloud_field.gdshaderinc"
uniform vec3 sky_top : source_color = vec3(0.27,0.42,0.57);
uniform vec3 sky_horizon : source_color = vec3(0.84,0.81,0.77);
uniform vec3 cloud_color : source_color = vec3(0.9,0.94,0.98);
uniform vec3 sun_color : source_color = vec3(1.0,0.88,0.73);
// Camera parallax never contributes to the ambient/reflection approximation.
// A global avoids invalidating that radiance map whenever the camera moves.
global uniform vec3 cloud_camera_position;
uniform float radiance_cloud_coverage = 0.0;
uniform float sun_glow_strength = 1.0;
uniform float sun_disc_energy = 14.0;
uniform float sun_halo_energy = 1.0;
uniform bool high_wisps = false;
uniform float lightning_flash = 0.0;
uniform float moon_glow_strength = 0.0;
// Fixed direction-space cells, evaluated only by the visible night sky. The
// pixel footprint filters small stars before temporal upscaling; no twinkle,
// camera translation, textures or radiance-map work.
vec3 night_stars(vec3 direction) {
	vec3 magnitude = abs(direction);
	vec2 plane;
	uint face;
	if (magnitude.x >= magnitude.y && magnitude.x >= magnitude.z) {
		plane = direction.yz/magnitude.x;
		face = direction.x > 0.0 ? 0u : 1u;
	} else if (magnitude.y >= magnitude.z) {
		plane = direction.xz/magnitude.y;
		face = direction.y > 0.0 ? 2u : 3u;
	} else {
		plane = direction.xy/magnitude.z;
		face = direction.z > 0.0 ? 4u : 5u;
	}
	vec2 grid = (plane+1.0)*64.0;
	vec2 footprint = fwidth(grid);
	uvec2 cell = uvec2(floor(grid));
	uint seed = cell.x*1664525u+cell.y*1013904223u+face*374761393u;
	seed ^= seed >> 16u; seed *= 2246822519u;
	seed ^= seed >> 13u; seed *= 3266489917u; seed ^= seed >> 16u;
	if ((seed & 1023u) >= 6u) return vec3(0.0);
	vec2 center = 0.25+0.5*vec2(float((seed >> 10u) & 1023u),float((seed >> 20u) & 1023u))/1023.0;
	float brightness = float(seed >> 30u)/3.0;
	float radius = mix(0.055,0.09,brightness);
	float radius_squared = radius*radius;
	float filtered = radius_squared+dot(footprint,footprint)*0.25;
	vec2 delta = fract(grid)-center;
	float star = exp2(-4.0*dot(delta,delta)/filtered)*radius_squared/filtered;
	return mix(vec3(0.82,0.90,1.0),vec3(1.0,0.92,0.80),brightness)*star*mix(0.65,1.45,brightness);
}
void sky() {
	vec3 base = mix(sky_horizon, sky_top, pow(max(EYEDIR.y,0.0),0.45));
	if (AT_CUBEMAP_PASS) {
		// Deliberately cheap ambient approximation: no cloud noise in radiance.
		COLOR = mix(base,cloud_color,radiance_cloud_coverage*0.45);
	} else if (AT_HALF_RES_PASS) {
		float height = max(cloud_layer_height_m-cloud_camera_position.y,0.0);
		vec2 projected = cloud_camera_position.xz + EYEDIR.xz*height/max(EYEDIR.y,0.035);
		float cloud = cloud_density(projected)*smoothstep(0.0,0.08,EYEDIR.y);
		float edge = pow(1.0-cloud,2.0);
		float sunward = max(dot(EYEDIR,normalize(cloud_sun_direction)),0.0);
		COLOR = cloud_color * (0.77+edge*0.27+pow(sunward,8.0)*edge*0.10);
		if (high_wisps) {
			vec2 wisp_p = projected*vec2(0.0007,0.0036)-cloud_params.xy*0.0005;
			float wisp = smoothstep(0.58,0.85,cloud_noise(wisp_p))*0.10*smoothstep(0.05,0.3,EYEDIR.y);
			cloud = cloud+(1.0-cloud)*wisp;
		}
		COLOR += vec3(0.62,0.70,0.88)*lightning_flash;
		ALPHA = cloud;
	} else {
		float alignment = max(dot(EYEDIR,normalize(cloud_sun_direction)),0.0);
		// No bright disc in the radiance branch: preserve stable environment reflections.
		float halo = pow(alignment,600.0)*0.9 + pow(alignment,90.0)*0.45 + pow(alignment,24.0)*0.25;
		float sun = smoothstep(0.99978,0.99992,alignment)*sun_disc_energy + halo*sun_halo_energy;
		base += sun_color * sun * sun_glow_strength;
		float moon_alignment = max(dot(EYEDIR,-normalize(cloud_sun_direction)),0.0);
		float moon = smoothstep(0.99980,0.99993,moon_alignment)*1.4 + pow(moon_alignment,300.0)*0.06;
		base += vec3(0.65,0.77,0.96)*moon*moon_glow_strength;
		float star_visibility = moon_glow_strength*(1.0-smoothstep(0.55,0.93,cloud_params.z));
		if (star_visibility > 0.0) {
			base += night_stars(EYEDIR)*star_visibility*smoothstep(0.08,0.30,EYEDIR.y);
		}
		COLOR = mix(base,HALF_RES_COLOR.rgb,HALF_RES_COLOR.a);
	}
}
