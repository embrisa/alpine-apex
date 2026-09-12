// One horizontal cloud layer shared by the sky and all sunlight receivers.
// xy = accumulated wind displacement in metres, z = cover, w = shadow strength.
uniform vec4 cloud_params = vec4(0.0);
uniform vec3 cloud_sun_direction = vec3(-0.775,0.407,0.484);
uniform float cloud_layer_height_m = 2400.0;
const float CLOUD_SCALE_PER_M = 0.003;
float cloud_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7))) * 43758.5453); }
float cloud_noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(cloud_hash(i),cloud_hash(i+vec2(1,0)),f.x),mix(cloud_hash(i+vec2(0,1)),cloud_hash(i+vec2(1,1)),f.x),f.y);
}
float cloud_density(vec2 world_xz) {
	vec2 p = (world_xz-cloud_params.xy)*CLOUD_SCALE_PER_M;
	// Broader masses with restrained small edges, shared by sky and receivers.
	// Keep octaves independent: domain warping serializes this per-surface hot path.
	float n = cloud_noise(p)*0.62 + cloud_noise(p*2.07)*0.26 + cloud_noise(p*4.11)*0.12;
	return smoothstep(0.87-cloud_params.z*0.64,1.05-cloud_params.z*0.64,n);
}
float cloud_light_transmission(vec3 world_position, vec3 light_direction) {
	float height = max(cloud_layer_height_m-world_position.y,0.0);
	vec2 projected = world_position.xz + light_direction.xz*height/max(light_direction.y,0.035);
	return 1.0-cloud_density(projected)*cloud_params.w*step(world_position.y,cloud_layer_height_m);
}
