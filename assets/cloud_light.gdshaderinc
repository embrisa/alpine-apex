#include "res://assets/cloud_field.gdshaderinc"
uniform float material_specular = 0.5;
varying float cloud_direct_transmission;
float sample_cloud_light(vec3 world_position) {
	// Sun and moon occupy opposite hemispheres and never light together.
	vec3 direction = cloud_sun_direction.y >= 0.0 ? cloud_sun_direction : -cloud_sun_direction;
	return cloud_params.w>0.0 ? cloud_light_transmission(world_position,direction) : 1.0;
}
// Dielectric Burley diffuse / GGX specular, retaining Godot's real shadow
// attenuation. Cloud shade affects direct sunlight, not blue ambient fill.
void light() {
	// Broad cloud shade is sampled per vertex and interpolated across the mesh;
	// the fine geometry shadow and BRDF still evaluate for every lit pixel.
	float cloud = LIGHT_IS_DIRECTIONAL ? cloud_direct_transmission : 1.0;
	float visibility = ATTENUATION * cloud;
	float nl = max(dot(NORMAL,LIGHT),0.0);
	float nv = max(dot(NORMAL,VIEW),0.0001);
	vec3 halfway = normalize(LIGHT+VIEW);
	float nh = max(dot(NORMAL,halfway),0.0);
	float lh = max(dot(LIGHT,halfway),0.0);
	float fd90 = 0.5+2.0*ROUGHNESS*lh*lh;
	float diffuse = (1.0+(fd90-1.0)*pow(1.0-nl,5.0))*(1.0+(fd90-1.0)*pow(1.0-nv,5.0));
	DIFFUSE_LIGHT += LIGHT_COLOR * visibility * nl * diffuse * (1.0-METALLIC) / PI;
#ifdef ALPINE_NEEDLE_TRANSMISSION
	// Restrained needle transmission still obeys tree/terrain and cloud shadows.
	DIFFUSE_LIGHT += LIGHT_COLOR*visibility*max(-dot(NORMAL,LIGHT),0.0)*needle_transmission/PI;
#endif
	float a2 = max(pow(ROUGHNESS,4.0),0.0001);
	float denominator = nh*nh*(a2-1.0)+1.0;
	float distribution = a2/(PI*denominator*denominator);
	float masking = 0.5/max(nl*sqrt(nv*nv*(1.0-a2)+a2)+nv*sqrt(nl*nl*(1.0-a2)+a2),0.0001);
	vec3 f0 = mix(vec3(0.08*material_specular),ALBEDO,METALLIC);
	vec3 fresnel = f0+(vec3(1.0)-f0)*pow(1.0-lh,5.0);
	SPECULAR_LIGHT += LIGHT_COLOR * visibility * nl * distribution * masking * fresnel * SPECULAR_AMOUNT;
#ifdef ALPINE_SNOW_SPARKLE
	if (LIGHT_IS_DIRECTIONAL && cloud_sun_direction.y>0.0) {
		float crystal=pow(max(dot(snow_facet_normal,halfway),0.0),64.0)*snow_glints;
		SPECULAR_LIGHT += LIGHT_COLOR*visibility*nl*crystal*snow_sparkle_strength;
	}
#endif
}
