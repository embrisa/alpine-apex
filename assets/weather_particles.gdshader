shader_type particles;
render_mode disable_force, disable_velocity, keep_data;
uniform vec3 half_extents = vec3(15.0,10.0,22.0);
uniform vec3 airflow = vec3(0.0,-2.0,0.0);
uniform float clock = 0.0;
uniform bool enabled = true;
float hash(float n) { return fract(sin(n*127.1)*43758.5453); }
void start() {
	if (CUSTOM.z < 0.5) {
		float id = float(NUMBER) + float(RANDOM_SEED % 1000u);
		TRANSFORM = mat4(1.0);
		TRANSFORM[3].xyz = (vec3(hash(id+1.0),hash(id+3.0),hash(id+7.0))*2.0-1.0)*half_extents;
		CUSTOM = vec4(mix(0.65,1.45,hash(id+11.0)),hash(id+13.0),1.0,0.0);
	}
}
void process() {
	if (!enabled) { ACTIVE = false; }
	vec3 drift = vec3(sin(clock*1.3+CUSTOM.y*30.0),0.0,cos(clock+CUSTOM.y*25.0))*0.35;
	VELOCITY = airflow + drift;
	TRANSFORM[3].xyz += VELOCITY * DELTA;
	// Periodic volume fills the view immediately, including at 200+ km/h.
	// The parent translates only; airflow subtracts camera velocity once.
	TRANSFORM[3].xyz = mod(TRANSFORM[3].xyz+half_extents,half_extents*2.0)-half_extents;
}
