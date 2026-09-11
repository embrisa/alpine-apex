shader_type spatial;
render_mode diffuse_lambert, specular_disabled, shadows_disabled;
#include "res://assets/graphics/offmap_surface.gdshaderinc"
varying vec3 landscape_pos;
varying vec3 landscape_normal;

void vertex() {
	offmap_masks = COLOR;
	landscape_pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	landscape_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment() {
	// Shared biome masks and one filtered rock texture. Godot supplies sun/moon,
	// ambient light and atmospheric fog; no transparent layers.
	ALBEDO = offmap_color(landscape_pos,normalize(landscape_normal),offmap_masks,length(VERTEX));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR * max(dot(NORMAL,LIGHT),0.0) * cloud_shade / PI;
}
