extends RefCounted
## Import-independent compute source, compiled lazily on the render thread.
const BLUR = """
#version 450
layout(local_size_x=8, local_size_y=8, local_size_z=1) in;
layout(set=0,binding=0) uniform sampler2D scene_color;
layout(set=0,binding=1) uniform sampler2D scene_depth;
layout(set=0,binding=2) uniform sampler2D scene_velocity;
layout(rgba16f,set=0,binding=3) uniform restrict writeonly image2D blurred_color;
layout(push_constant,std430) uniform Params {
    mat4 reprojection;
    vec4 extent; // internal width/height, exposure / rendered dt, maximum path pixels
    vec4 lens; // near, far, unused, unused
} p;
float distance_at(float d) {
    return p.lens.x*p.lens.y / max(p.lens.x+d*(p.lens.y-p.lens.x),0.000001);
}
vec2 velocity_at(ivec2 pixel,vec2 uv,float depth) {
    vec2 velocity=texelFetch(scene_velocity,pixel,0).xy;
    // Forward+ with temporal reconstruction marks static surfaces (-1,-1).
    // Native sky has zero velocity; camera rotation still moves its direction.
    if (all(lessThanEqual(velocity,vec2(-1.0))) || depth<=0.0000001) {
        vec4 previous=p.reprojection*vec4(uv*2.0-1.0,depth*2.0-1.0,1.0);
        if (abs(previous.w)<0.000001) return vec2(0.0);
        velocity=0.5+previous.xy/previous.w*0.5-uv;
    }
    if (any(isnan(velocity)) || any(isinf(velocity))) return vec2(0.0);
    return velocity;
}
void main() {
    ivec2 pixel=ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(pixel,ivec2(p.extent.xy)))) return;
    vec2 uv=(vec2(pixel)+0.5)/p.extent.xy;
    vec4 original=texelFetch(scene_color,pixel,0);
    float depth=texelFetch(scene_depth,pixel,0).r;
    vec2 path=velocity_at(pixel,uv,depth)*p.extent.xy*p.extent.z;
    float path_length=length(path);
    if (path_length<0.5) { imageStore(blurred_color,pixel,original); return; }
    path*=min(1.0,p.extent.w/max(path_length,0.000001));
    vec2 step_uv=path/p.extent.xy/12.0;
    float center_distance=distance_at(depth);
    vec3 sum=original.rgb;
    float total=1.0;
    // Single-frame symmetric exposure. Stop each side at a depth discontinuity
    // so a later tap cannot cross a thin foreground tree, gate, ski or pole.
    for (int side=-1;side<=1;side+=2) {
        for (int tap=1;tap<=6;tap++) {
            vec2 sample_uv=uv+step_uv*float(side*tap);
            if (any(lessThan(sample_uv,vec2(0.0))) || any(greaterThanEqual(sample_uv,vec2(1.0)))) break;
            float sample_depth=textureLod(scene_depth,sample_uv,0.0).r;
            if ((depth<=0.0000001)!=(sample_depth<=0.0000001)) break;
            float relative=abs(distance_at(sample_depth)-center_distance)/max(center_distance,0.1);
            if (relative>0.025) break;
            float weight=(1.0-float(tap)/8.0)*(1.0-smoothstep(0.01,0.025,relative));
            sum+=textureLod(scene_color,sample_uv,0.0).rgb*weight;
            total+=weight;
        }
    }
    // Alpha carries the renderer's reactive mask. Preserve it at this pixel.
    imageStore(blurred_color,pixel,vec4(sum/total,original.a));
}
"""
const COPY = """
#version 450
layout(local_size_x=8, local_size_y=8, local_size_z=1) in;
layout(rgba16f,set=0,binding=0) uniform restrict readonly image2D blurred_color;
layout(rgba16f,set=0,binding=1) uniform restrict writeonly image2D scene_color;
void main() {
    ivec2 pixel=ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(pixel,imageSize(scene_color)))) return;
    imageStore(scene_color,pixel,imageLoad(blurred_color,pixel));
}
"""
