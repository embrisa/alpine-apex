shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec4 beam_color : source_color = vec4(0.76,0.91,0.42,1.0);
uniform float brightness = 1.0;
uniform float visual_time = 0.0;
uniform float vfx_strength = 1.0;
varying vec3 world_position;
varying vec3 radial_normal;
varying float height_m;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	radial_normal = mat3(MODEL_MATRIX) * NORMAL;
	height_m = VERTEX.y + 396.0; // 800 m above the anchor, 8 m buried in snow.
}

float cell_random(vec2 cell) {
	return fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
}

void fragment() {
	// Horizontal facing keeps the core equally legible from chase and survey views.
	vec2 toward_camera = CAMERA_POSITION_WORLD.xz - world_position.xz;
	float facing = max(0.0,dot(normalize(radial_normal.xz),toward_camera / max(length(toward_camera),0.001)));
	float halo = pow(facing,2.0);
	float core = pow(facing,12.0);
	float top_fade = 1.0 - smoothstep(600.0,800.0,height_m);
	float base_fade = smoothstep(-8.0,0.0,height_m);
	float distance_m = length(VERTEX);
	float near_fade = smoothstep(2.0,12.0,distance_m);
	float angle = atan(radial_normal.z,radial_normal.x);
	// Three soft helical ribbons drift upward through the broad translucent shaft.
	float ribbon_phase = angle*3.0-height_m*0.19+visual_time*1.3;
	float ribbons = pow(0.5+0.5*sin(ribbon_phase),12.0);
	float flow = 0.5+0.5*sin(height_m*0.065-visual_time*0.55);
	// Procedural light flecks ascend at 7 m/s. Whole circumferential turns keep
	// the seam continuous; fade small detail before it becomes subpixel noise.
	vec2 grid = vec2((angle/6.28318530718+0.5)*24.0,(height_m-visual_time*7.0)*0.4);
	vec2 cell = floor(grid);
	cell.x = mod(cell.x,24.0);
	float seed = cell_random(cell);
	vec2 center = vec2(0.25+0.5*seed,0.35+0.3*cell_random(cell+19.0));
	vec2 mote = (fract(grid)-center)/vec2(0.085,0.26);
	float flecks = exp(-dot(mote,mote)*2.0)*step(0.84,seed);
	float detail_fade = 1.0-smoothstep(100.0,350.0,distance_m);
	// Slowly rotating folds of mist collect at the base, then dissolve upward.
	vec2 swirl = vec2(cos(angle-visual_time*0.24),sin(angle-visual_time*0.24));
	float mist_height = height_m*0.21-visual_time*0.6;
	float mist = 0.5+0.5*sin(swirl.x*4.1+mist_height)*sin(swirl.y*3.2-mist_height*0.7);
	mist *= 0.65+0.35*sin(swirl.y*7.0+height_m*0.6-visual_time*0.85);
	float base_mist = mist*(1.0-smoothstep(5.0,30.0,height_m));
	float shimmer = 0.5+0.5*sin(height_m*1.9+angle*8.0-visual_time*1.8);
	float energy = vfx_strength*(ribbons*(0.08+0.10*flow)+flecks*0.8*detail_fade+shimmer*0.035*detail_fade);
	float opacity = halo*0.18+core*0.22+halo*energy+pow(facing,1.2)*base_mist*0.24*vfx_strength;
	ALBEDO = mix(beam_color.rgb,vec3(1.0),clamp(core*0.18+energy*0.65,0.0,0.7))*brightness;
	ALPHA = min(opacity,0.72)*top_fade*base_fade*near_fade;
}
