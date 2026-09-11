shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 beam_color : source_color = vec4(0.76,0.91,0.42,1.0);
uniform float visual_time = 0.0;
uniform float vfx_strength = 1.0;

void fragment() {
	vec2 p = (UV-0.5)*20.0;
	float radius = length(p);
	float angle = atan(p.y,p.x);
	float phase = angle-visual_time*0.24;
	float detail = vfx_strength*(1.0-smoothstep(80.0,250.0,length(VERTEX)));
	// Broad hazy spill plus three soft arcs rotating around the snow-fitted base.
	float halo = exp(-pow((radius-6.5)/1.25,2.0));
	float ring = exp(-pow((radius-6.5)/0.18,2.0));
	float arcs = pow(0.5+0.5*sin(phase*3.0),5.0);
	float wisps = pow(0.5+0.5*sin(phase*5.0+radius*2.5-visual_time*0.3),3.0);
	float sparkle = pow(0.5+0.5*sin(phase*13.0),24.0)*ring;
	float near_fade = smoothstep(0.6,3.0,length(VERTEX));
	ALBEDO = mix(beam_color.rgb,vec3(1.0),sparkle*0.5*detail)*1.15;
	ALPHA = (halo*(0.045+wisps*0.12*detail)+ring*(0.06+arcs*0.38*detail)+sparkle*0.2*detail)*near_fade;
}
