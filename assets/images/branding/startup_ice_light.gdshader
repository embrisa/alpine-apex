shader_type canvas_item;
render_mode unshaded;
uniform float reveal_time = 0.0;
uniform bool reduced_motion = false;
void fragment() {
	vec4 ice = COLOR;
	float plane = UV.x+UV.y*0.32;
	float light = reduced_motion ? 0.0 : exp(-pow((plane-(reveal_time*0.85-0.2))*12.0,2.0));
	vec3 tint = mix(vec3(0.78,0.89,0.96),vec3(1.0),smoothstep(0.0,0.8,reveal_time));
	if (reduced_motion) { tint = vec3(1.0); }
	ice.rgb = min(vec3(1.0),ice.rgb*tint+vec3(0.10,0.13,0.14)*light*ice.a);
	COLOR = ice;
}
