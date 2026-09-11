shader_type spatial;
render_mode diffuse_lambert, specular_disabled, shadows_disabled;
uniform float cloud_shade = 1.0;
varying vec3 land_color;

void vertex() {
	land_color = COLOR.rgb;
}

void fragment() {
	// Baked broad snow, rock and forest colors. Godot supplies sun/moon,
	// ambient light and atmospheric fog; no texture reads or transparent layers.
	ALBEDO = land_color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR * max(dot(NORMAL,LIGHT),0.0) * cloud_shade / PI;
}
