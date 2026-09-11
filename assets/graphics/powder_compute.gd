extends RefCounted
## Inline compute source is a preload dependency, so exports retain it without
## requiring editor GLSL imports or export filters for external text files.
const SOURCE = """
#version 450
// Rebuild a bounded local atlas from the retained contact ring. Integer MAX
// makes intersecting strokes deterministic, with cuts taking priority over lips.
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(r32ui,set=0,binding=0) uniform uimage2D imprints;
layout(rg16f,set=0,binding=2) uniform writeonly image2D surface_map;
struct Stroke { vec4 ends; vec4 response; };
layout(std430,set=0,binding=1) readonly buffer Strokes { Stroke strokes[]; };
layout(push_constant,std430) uniform Params { vec4 area; ivec4 command; } p;
vec2 decode_imprint(uint packed) {
    float h=float((packed>>8u)&65535u)*(0.35/65535.0);
    if((packed&0x80000000u)!=0u) h=-h;
    return vec2(h,float(packed&255u)/255.0);
}
void main() {
    int resolution=int(p.area.w);
    if(p.command.y==2) {
        ivec2 pixel=ivec2(gl_GlobalInvocationID.xy);
        if(any(greaterThanEqual(pixel,ivec2(resolution/4)))) return;
        // Area-filter the signed impression to the actual mesh spacing.
        // Point-sampling the finer atlas made deep diagonal grooves alternate
        // between full cut and uncut vertices, producing serrated walls.
        ivec2 source=pixel*4;
        vec2 value=vec2(0);
        for(int y=-2;y<=5;y++) {
            for(int x=-2;x<=5;x++) {
                float weight=(8.0-abs(float(x)*2.0-3.0))*(8.0-abs(float(y)*2.0-3.0));
                ivec2 sample_pixel=clamp(source+ivec2(x,y),ivec2(0),ivec2(resolution-1));
                value+=decode_imprint(imageLoad(imprints,sample_pixel).r)*weight;
            }
        }
        imageStore(surface_map,pixel,vec4(value/1024.0,0,1));
        return;
    }
    if(p.command.y==0) {
        ivec2 pixel=ivec2(gl_GlobalInvocationID.xy);
        if(all(lessThan(pixel,ivec2(resolution)))) imageStore(imprints,pixel,uvec4(0));
        return;
    }
    uint index=gl_WorkGroupID.x;
    if(index>=uint(p.command.x)) return;
    Stroke s=strokes[index];
    if(s.response.y<=0.0001) return;
    vec2 a=s.ends.xy, b=s.ends.zw, direction=b-a;
    float length_m=length(direction);
    if(length_m<0.001) return;
    direction/=length_m;
    // Match Vector3.UP.cross(along) used by ribbons and throw_world.
    vec2 across=vec2(direction.y,-direction.x);
    float half_width=max(s.response.x*0.5,0.04);
    float pixel_m=p.area.z/p.area.w;
    vec2 lo=min(a,b)-vec2(half_width*1.5+0.12);
    vec2 hi=max(a,b)+vec2(half_width*1.5+0.12);
    ivec2 first=max(ivec2(floor((lo-p.area.xy)/pixel_m)),ivec2(0));
    ivec2 last=min(ivec2(ceil((hi-p.area.xy)/pixel_m)),ivec2(resolution-1));
    for(int y=first.y+int(gl_LocalInvocationID.y);y<=last.y;y+=8) {
        for(int x=first.x+int(gl_LocalInvocationID.x);x<=last.x;x+=8) {
            vec2 world=p.area.xy+(vec2(x,y)+0.5)*pixel_m;
            float along=dot(world-a,direction);
            float cap=1.0-smoothstep(0.0,0.14,max(-along,along-length_m));
            if(cap<=0.0) continue;
            float side=dot(world-a,across)/half_width;
            float grain=sin(world.x*21.0+world.y*13.0)*sin(world.x*31.0-world.y*17.0);
            float broken=abs(side+grain*s.response.z*0.065);
            // Bound the geometric aspect ratio as well as loose-snow depth.
            // A ski-width slot cannot resolve a near-vertical 20 cm wall on
            // this mesh; wider ploughs can retain proportionally deeper relief.
            float relief_depth=min(s.response.y,half_width*0.55);
            float cut=(1.0-smoothstep(0.38,0.88,broken))*relief_depth*cap;
            // Resolve a rounded bank over the existing 6.25 cm local mesh.
            // The former tall, sub-cell ridge aliased into a saw-tooth fence
            // when compression produced deeper cuts. No extra tessellation.
            float spread=max(half_width*0.28,0.12);
            float lip=exp(-pow((broken-1.10)*half_width/spread,2.0))
                     *min(relief_depth*0.55,spread*0.50)*cap;
            lip*=mix(0.48,1.5,smoothstep(-0.3,0.3,side*s.response.w));
            lip*=1.0+grain*s.response.z*0.12;
            // A continuous signed profile avoids a height jump where the
            // binary cut-priority switch formerly met a fully raised lip.
            float signed_height=lip-cut;
            bool recess=signed_height<0.0;
            float height_m=abs(signed_height);
            if(height_m<0.0005) continue;
            uint packed=(uint(clamp(height_m/0.35,0.0,1.0)*65535.0)<<8)
                       |uint(clamp(s.response.z,0.0,1.0)*255.0);
            if(recess) packed|=0x80000000u;
            imageAtomicMax(imprints,ivec2(x,y),packed);
        }
    }
}
"""
