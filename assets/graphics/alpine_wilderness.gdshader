shader_type spatial;
render_mode diffuse_lambert, specular_disabled, shadows_disabled;
#include "res://assets/graphics/offmap_surface.gdshaderinc"
#include "res://assets/graphics/offmap_fog.gdshaderinc"
#include "res://assets/graphics/offmap_horizon.gdshaderinc"
varying vec3 landscape_pos;
varying vec3 landscape_normal;

void vertex() {
	offmap_masks = COLOR;
	landscape_pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	landscape_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment() {
	// Shared biome masks and filtered terrain textures. Godot supplies sun/moon,
	// ambient light and atmospheric fog; no transparent layers.
	vec3 snow_normal = normalize(landscape_normal);
	ALBEDO = offmap_color(landscape_pos,snow_normal,offmap_masks,length(VERTEX));
	NORMAL = normalize((VIEW_MATRIX*vec4(snow_normal,0.0)).xyz);
	offmap_snow_coverage = offmap_snow_amount(normalize(landscape_normal),offmap_masks);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = offmap_fog(landscape_pos,CAMERA_POSITION_WORLD);
}

void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR * offmap_diffuse(dot(NORMAL,LIGHT),offmap_snow_coverage) * cloud_shade * (LIGHT_IS_DIRECTIONAL ? offmap_horizon_visibility(landscape_pos) : 1.0) / PI;
}
