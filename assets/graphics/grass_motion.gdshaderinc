uniform float wind_time = 0.0;
uniform vec2 wind_direction = vec2(1.0,0.0);
uniform float wind_strength = 0.0;
uniform vec4 grass_sweep_start[16];
uniform vec4 grass_sweep_end[16];
vec3 grass_displacement(vec3 root, float weight, float height, float phase) {
	float gust = sin(wind_time*2.1+dot(root.xz,vec2(.17,.11))+phase*6.283)*.35+.65;
	vec2 bend = wind_direction*min(wind_strength,7.0)*.018*gust;
	float strongest=0.0; vec2 away=vec2(0.0);
	for(int i=0;i<16;i++) {
		if(grass_sweep_end[i].w<=0.0) continue;
		vec3 a=grass_sweep_start[i].xyz; vec3 b=grass_sweep_end[i].xyz;
		vec2 ab=b.xz-a.xz;
		float t=clamp(dot(root.xz-a.xz,ab)/max(dot(ab,ab),.0001),0.0,1.0);
		vec3 p=mix(a,b,t); vec2 offset=root.xz-p.xz;
		float force=(1.0-smoothstep(.1,1.05,length(offset)))*(1.0-smoothstep(.35,1.2,abs(root.y-p.y)))*smoothstep(0.0,1.0,grass_sweep_end[i].w);
		if(force>strongest) {
			strongest=force;
			away=normalize(offset+normalize(ab+vec2(.0001))*0.12+vec2(.0001));
		}
	}
	bend+=away*strongest*.70;
	return vec3(bend.x,-strongest*.36,bend.y)*height*weight*weight;
}
