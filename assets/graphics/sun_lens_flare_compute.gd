extends RefCounted
## One tiny visibility dispatch and an in-place, bounded HDR additive pass.
const HEADER = """
#version 450
layout(push_constant,std430) uniform Params {
    vec4 extent; // internal size, dt, reset
    vec4 sun; // screen UV, intensity, sampled sun radius in pixels
    vec4 tint;
    vec4 camera;
    vec4 direction; // xyz toward sun, weather sky enabled
    vec4 cloud; // offset xy, coverage, layer height
    vec4 bounds; // pixel origin xy, pixel extent zw
    vec4 options; // high wisps, unused
} lens_params;
"""

static func visibility_source() -> String:
	# Share the sky's actual cloud field instead of a second cloud approximation.
	var cloud = FileAccess.get_file_as_string("res://assets/cloud_field.gdshaderinc")
	cloud = cloud.substr(cloud.find("const float CLOUD_SCALE_PER_M"))
	return HEADER+"""
layout(local_size_x=1,local_size_y=1,local_size_z=1) in;
layout(set=0,binding=0) uniform sampler2D scene_depth;
layout(rg32f,set=0,binding=1) uniform image2D visibility;
#define cloud_params lens_params.cloud
#define cloud_sun_direction lens_params.direction.xyz
#define cloud_layer_height_m lens_params.cloud.w
"""+cloud+"""
void main() {
    float visible=0.0, total=0.0;
    for(int y=-3;y<=3;y++) for(int x=-3;x<=3;x++) {
        vec2 offset=vec2(x,y)/3.0;
        float weight=max(0.0,1.05-dot(offset,offset));
        vec2 uv=lens_params.sun.xy+offset*lens_params.sun.w/lens_params.extent.xy;
        float depth=textureLod(scene_depth,clamp(uv,vec2(0.0),vec2(1.0)),0.0).r;
        visible+=weight*(depth<=0.00000001 ? 1.0:0.0);
        total+=weight;
    }
    float raw=visible/max(total,0.001);
    if(lens_params.direction.w>0.5) {
        float height=max(lens_params.cloud.w-lens_params.camera.y,0.0);
        vec2 projected=lens_params.camera.xz+lens_params.direction.xz*height/max(lens_params.direction.y,0.035);
        float density=cloud_density(projected)*smoothstep(0.0,0.08,lens_params.direction.y);
        if(lens_params.options.x>0.5) {
            vec2 wp=projected*vec2(0.0007,0.0036)-lens_params.cloud.xy*0.0005;
            float wisp=smoothstep(0.58,0.85,cloud_noise(wp))*0.10*smoothstep(0.05,0.3,lens_params.direction.y);
            density+= (1.0-density)*wisp;
        }
        raw*=1.0-density;
    }
    float previous=lens_params.extent.w>0.5 ? 0.0:imageLoad(visibility,ivec2(0)).r;
    float smooth_visibility=mix(previous,raw,1.0-exp(-lens_params.extent.z*(raw<previous?35.0:10.0)));
    // Completely hidden sun never leaks a lingering ghost through the blocker.
    imageStore(visibility,ivec2(0),vec4(smooth_visibility,raw,0.0,0.0));
}
"""

const DRAW = HEADER+"""
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(rgba16f,set=0,binding=0) uniform image2D scene_color;
layout(rg32f,set=0,binding=1) uniform readonly image2D visibility;
float disc(vec2 q,float radius) {
    float r=length(q)/radius;
    return r>=1.0 ? 0.0:exp(-r*r*5.0)*(1.0-smoothstep(0.7,1.0,r));
}
void main() {
    ivec2 local=ivec2(gl_GlobalInvocationID.xy);
    if(any(greaterThanEqual(local,ivec2(lens_params.bounds.zw)))) return;
    ivec2 pixel=ivec2(lens_params.bounds.xy)+local;
    vec2 visibility_pair=imageLoad(visibility,ivec2(0)).rg;
    float visibility_amount=min(visibility_pair.r,visibility_pair.g);
    if(visibility_amount<0.0001) return;
    vec2 uv=(vec2(pixel)+0.5)/lens_params.extent.xy;
    vec2 aspect=vec2(lens_params.extent.x/lens_params.extent.y,1.0);
    vec2 axis=lens_params.sun.xy-0.5;
    vec2 q=(uv-lens_params.sun.xy)*aspect;
    vec3 flare=lens_params.tint.rgb*(disc(q,0.075)*0.28+disc(q,0.018)*0.35);
    // Three restrained ghosts; no full-frame wash, streak or rotating pattern.
    flare+=vec3(1.0,0.70,0.36)*disc((uv-(0.5+axis*0.25))*aspect,0.024)*0.24;
    flare+=vec3(0.47,0.69,0.62)*disc((uv-(0.5-axis*0.25))*aspect,0.040)*0.15;
    vec2 ghost=(uv-(0.5-axis*0.55))*aspect;
    float rim=exp(-pow((length(ghost)/0.055-0.72)*10.0,2.0));
    flare+=vec3(1.0,0.61,0.29)*(disc(ghost,0.055)*0.22+rim*0.035);
    if(dot(flare,flare)<0.00000001) return;
    vec4 original=imageLoad(scene_color,pixel);
    imageStore(scene_color,pixel,vec4(original.rgb+flare*lens_params.sun.z*visibility_amount,original.a));
}
"""
