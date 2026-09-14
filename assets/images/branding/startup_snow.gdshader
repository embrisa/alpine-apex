shader_type canvas_item;
render_mode unshaded;
uniform float seconds = 0.0;
uniform float aspect = 1.777778;

vec2 random_cell(vec2 p) {
	return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}

float travel_distance() {
	// Strictly forward: gusts change speed, never angle or direction.
	return seconds*0.19 + 0.028*(1.0-cos(seconds*2.4));
}

float flakes(vec2 uv, float cells, float depth) {
	float travel = travel_distance()*depth;
	vec2 field = (uv+vec2(travel*1.8,-travel))*cells;
	vec2 seed = random_cell(floor(field)+depth*31.0);
	float present = step(0.22,fract(seed.x*17.31+seed.y*11.97));
	vec2 p = fract(field)-mix(vec2(0.20),vec2(0.80),seed);
	// Each near flake carries a short soft streak; distant snow stays fine.
	p = vec2(dot(p,vec2(0.486,0.874))*1.6,dot(p,vec2(-0.874,0.486))*0.65);
	float radius = mix(0.025,0.11,seed.x);
	return present*(1.0-smoothstep(radius*0.48,radius,length(p)))*mix(0.65,1.0,seed.y);
}

void fragment() {
	vec2 uv = UV*vec2(aspect,1.0);
	float gust = pow(0.5+0.5*sin(seconds*2.4-0.8),3.0);
	float far_snow = flakes(uv,62.0,0.35)*0.50;
	float mid_snow = flakes(uv,36.0,0.75)*0.82;
	float near_snow = flakes(uv,19.0,1.5)*0.98;
	float foreground = flakes(uv,9.0,2.7)*0.92;
	// Wind lifts translucent snow sheets through the lower and outer picture.
	vec2 wind_uv = uv+vec2(1.8,-1.0)*travel_distance();
	float band = sin(wind_uv.y*16.0+wind_uv.x*6.0);
	float wisps = pow(max(0.0,band*0.5+0.5),9.0)*gust*0.055;
	float quiet_logo = 1.0-0.70*exp(-dot((UV-vec2(0.5,0.44))*vec2(2.3,3.2),(UV-vec2(0.5,0.44))*vec2(2.3,3.2))*3.0);
	float density = far_snow+mid_snow+near_snow+foreground+wisps;
	COLOR = vec4(vec3(0.99,0.995,1.0),min(0.98,density*quiet_logo));
}
