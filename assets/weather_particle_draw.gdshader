shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
#include "res://assets/cloud_light.gdshaderinc"
uniform int kind = 0; // 0 snow, 1 rain, 2 spindrift
uniform float opacity = 0.0;
uniform float stretch = 0.0;
uniform vec3 flow = vec3(0.0,-2.0,0.0);
varying float distance_fade;
varying vec3 particle_up;
void vertex() {
	cloud_direct_transmission=sample_cloud_light(MODEL_MATRIX[3].xyz);
	particle_up=normalize((VIEW_MATRIX*vec4(0,1,0,0)).xyz);
	vec2 direction = (VIEW_MATRIX * vec4(flow,0.0)).xy;
	direction = length(direction)>0.01 ? normalize(direction) : vec2(0.0,1.0);
	vec2 across = vec2(direction.y,-direction.x);
	float width = kind==1 ? 0.018 : (kind==2 ? 0.32 : 0.075);
	float extent = kind==1 ? 0.48+stretch*0.85 : (kind==2 ? 1.2 : 0.075+stretch*0.24);
	float scale = kind==2 ? 1.0 : INSTANCE_CUSTOM.x;
	VERTEX.xy = (across*VERTEX.x*width + direction*VERTEX.y*extent)*scale;
	float depth = -MODELVIEW_MATRIX[3].z;
	distance_fade = smoothstep(0.8,2.5,depth)*(1.0-smoothstep(17.0,27.0,depth));
	MODELVIEW_MATRIX = mat4(vec4(1,0,0,0),vec4(0,1,0,0),vec4(0,0,1,0),MODELVIEW_MATRIX[3]);
}
void fragment() {
	vec2 p = UV*2.0-1.0;
	float shape = (1.0-smoothstep(0.1,1.0,abs(p.x)))*(1.0-smoothstep(0.15,1.0,abs(p.y)));
	if (kind==0) shape *= 1.0-smoothstep(0.3,1.0,length(p));
	vec2 center = (SCREEN_UV-vec2(0.5,0.46))*vec2(VIEWPORT_SIZE.x/VIEWPORT_SIZE.y,1.0);
	float route = mix(0.28,1.0,smoothstep(0.12,0.48,length(center)));
	ALBEDO = kind==1 ? vec3(0.71,0.85,0.96) : vec3(0.90,0.96,1.0);
	ROUGHNESS = kind==1 ? 0.32 : 0.82;
	SPECULAR = 0.4;
	NORMAL = normalize(particle_up+vec3(p*.12,.08));
	ALPHA = shape*opacity*distance_fade*route;
}
