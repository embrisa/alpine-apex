shader_type spatial;
render_mode cull_back;
#include "res://assets/cloud_light.gdshaderinc"
varying vec3 world_pos;
varying vec3 world_normal;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453123); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	cloud_direct_transmission = sample_cloud_light(world_pos);
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL,0.0)).xyz);
}
void fragment() {
	float grain = noise(world_pos.xz * 1.9);
	float strata = noise(world_pos.xz * .027) * .5 + noise(world_pos.xz * .16) * .22;
	float rock = 1.0-smoothstep(.68,.88,world_normal.y + (strata-.30)*.24);
	// Metre-scale wind ripples and shallow drifts supply readable ground flow.
	float drift = noise(world_pos.xz * .22 + vec2(noise(world_pos.xz*.035)*3.0));
	float ripple = sin(world_pos.x*.75 + world_pos.z*3.1 + drift*4.0)*.5+.5;
	vec3 snow = mix(vec3(.47,.59,.72),vec3(.86,.90,.93),.56+grain*.15+drift*.18);
	snow *= .90 + ripple*.07 + drift*.03;
	vec3 stone = mix(vec3(.12,.15,.19),vec3(.30,.31,.32),strata+grain*.12);
	ALBEDO = mix(snow,stone,rock);
	ROUGHNESS = mix(.79,.94,rock);
	SPECULAR = .24;
}
