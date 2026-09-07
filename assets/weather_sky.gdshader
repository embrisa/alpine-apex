shader_type sky;
render_mode use_half_res_pass;
#include "res://assets/cloud_field.gdshaderinc"
uniform vec3 sky_top : source_color = vec3(0.27,0.42,0.57);
uniform vec3 sky_horizon : source_color = vec3(0.84,0.81,0.77);
uniform vec3 cloud_color : source_color = vec3(0.9,0.94,0.98);
uniform vec3 sun_color : source_color = vec3(1.0,0.88,0.73);
uniform vec3 cloud_camera_position = vec3(0.0);
uniform float sun_glow_strength = 1.0;
uniform float sun_disc_energy = 14.0;
uniform float sun_halo_energy = 1.0;
uniform float moon_glow_strength = 0.0;
void sky() {
	vec3 base = mix(sky_horizon, sky_top, pow(max(EYEDIR.y,0.0),0.45));
	if (AT_CUBEMAP_PASS) {
		// Deliberately cheap ambient approximation: no cloud noise in radiance.
		COLOR = mix(base,cloud_color,cloud_params.z*0.45);
	} else if (AT_HALF_RES_PASS) {
		float height = max(cloud_layer_height_m-cloud_camera_position.y,0.0);
		vec2 projected = cloud_camera_position.xz + EYEDIR.xz*height/max(EYEDIR.y,0.035);
		float cloud = cloud_density(projected)*smoothstep(0.0,0.08,EYEDIR.y);
		COLOR = cloud_color * mix(1.05,0.80,cloud);
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
		COLOR = mix(base,HALF_RES_COLOR.rgb,HALF_RES_COLOR.a);
	}
}
