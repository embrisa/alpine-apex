shader_type canvas_item;
render_mode unshaded;
uniform float reveal_time = 0.0;
uniform bool reduced_motion = false;
uniform bool use_photo = false;
uniform float source_aspect = 1.5;
uniform float viewport_aspect = 1.777778;
uniform vec2 focal_point = vec2(0.5,0.46);
void fragment() {
	vec2 p = UV;
	vec3 night = vec3(0.018,0.043,0.066);
	vec3 blue = vec3(0.10,0.20,0.27);
	float horizon = exp(-pow((p.y-0.47)*3.5,2.0));
	vec3 col = mix(night,blue,horizon*0.8);
	vec2 sun = (p-vec2(0.76,0.31))*vec2(1.8,1.0);
	float glow = exp(-length(sun)*7.0);
	col += vec3(0.24,0.27,0.26)*glow;
	// Broad glacial light, one pass; no bloom, flicker or screen-space lens flare.
	float sweep = reduced_motion ? 0.0 : exp(-pow((p.x+p.y*0.42-(reveal_time*0.66-0.25))*8.0,2.0));
	col += vec3(0.035,0.065,0.075)*sweep*horizon;
	float vignette = smoothstep(0.35,0.82,length((p-0.5)*vec2(0.9,1.0)));
	if (use_photo) {
		vec2 crop = min(vec2(viewport_aspect/source_aspect,source_aspect/viewport_aspect),vec2(1.0));
		float zoom = reduced_motion ? 1.0 : 1.015-0.012*smoothstep(0.0,1.85,reveal_time);
		crop /= zoom;
		vec2 origin = clamp(focal_point-crop*0.5,vec2(0.0),vec2(1.0)-crop);
		vec3 photo = texture(TEXTURE,origin+p*crop).rgb;
		float luma = dot(photo,vec3(0.2126,0.7152,0.0722));
		photo = mix(vec3(luma),photo,0.80)*vec3(0.84,0.92,1.0);
		float centre = exp(-dot((p-0.5)*vec2(1.35,1.0),(p-0.5)*vec2(1.35,1.0))*5.0);
		col = mix(photo,night,0.25+centre*0.24);
		col += vec3(0.015,0.026,0.032)*sweep;
	}
	COLOR = vec4(col*(1.0-vignette*0.55),1.0);
}
