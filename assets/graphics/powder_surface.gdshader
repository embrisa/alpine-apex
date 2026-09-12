shader_type spatial;
render_mode cull_back;
#include "res://assets/graphics/alpine_surface_uniforms.gdshaderinc"
uniform sampler2D contact_heights : filter_nearest, repeat_disable;
uniform vec2 contact_origin;
uniform ivec2 contact_size;
float contact_height(vec2 world) {
 vec2 grid=clamp((world-contact_origin)/4.0,vec2(0),vec2(contact_size)-1.0);
 ivec2 cell=min(ivec2(floor(grid)),contact_size-ivec2(2)); vec2 f=grid-vec2(cell);
 float a=texelFetch(contact_heights,cell,0).r;
 float b=texelFetch(contact_heights,cell+ivec2(1,0),0).r;
 float c=texelFetch(contact_heights,cell+ivec2(0,1),0).r;
 float d=texelFetch(contact_heights,cell+ivec2(1,1),0).r;
 return f.x+f.y<=1.0 ? a+f.x*(b-a)+f.y*(c-a) : d+(1.0-f.x)*(c-d)+(1.0-f.y)*(b-d);
}
float contact_cloud(vec2 world) {
 // Match the base terrain's vertex-sampled cloud light, then barycentrically
 // interpolate it. Fine-grid resampling otherwise reveals a moving light seam.
 vec2 grid=clamp((world-contact_origin)/4.0,vec2(0),vec2(contact_size)-1.0);
 ivec2 cell=min(ivec2(floor(grid)),contact_size-ivec2(2)); vec2 f=grid-vec2(cell);
 ivec2 corner=cell+(f.x+f.y<=1.0 ? ivec2(0) : ivec2(1));
 vec2 a=contact_origin+vec2(corner)*4.0;
 vec2 b=contact_origin+vec2(cell+ivec2(1,0))*4.0;
 vec2 c=contact_origin+vec2(cell+ivec2(0,1))*4.0;
 float ca=sample_cloud_light(vec3(a.x,texelFetch(contact_heights,corner,0).r,a.y));
 float cb=sample_cloud_light(vec3(b.x,texelFetch(contact_heights,cell+ivec2(1,0),0).r,b.y));
 float cc=sample_cloud_light(vec3(c.x,texelFetch(contact_heights,cell+ivec2(0,1),0).r,c.y));
 return f.x+f.y<=1.0 ? ca+f.x*(cb-ca)+f.y*(cc-ca) : ca+(1.0-f.x)*(cc-ca)+(1.0-f.y)*(cb-ca);
}
void vertex() {
 vec2 world=VERTEX.xz+powder_center;
 vec2 imprint=powder_sample(world);
 float edge=powder_edge(world);
 float h=powder_height(world);
 float texel=powder_extent/float(textureSize(powder_imprints,0).x);
 // Centered slopes shade either side of a cut at the same world location.
 // Forward differences displaced steep groove normals by half a mesh cell.
 float hx=powder_height(world+vec2(texel,0))-powder_height(world-vec2(texel,0));
 float hz=powder_height(world+vec2(0,texel))-powder_height(world-vec2(0,texel));
 // Base heights retain the exact 4 m diagonal; subdivisions never smooth away
 // contact features. Only bounded loose-snow impressions change local height.
 VERTEX.y=contact_height(world)-MODEL_MATRIX[3].y+h;
 VERTEX.xz=world-MODEL_MATRIX[3].xz;
 vec3 base=powder_support(world).xyz;
 world_n=base+vec3(-hx,0,-hz)*base.y/(2.0*texel);
 NORMAL=normalize(world_n);
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 powder_compaction=clamp(-imprint.x*24.0,0.0,1.0)*edge;
 cloud_direct_transmission=contact_cloud(world);
}
#include "res://assets/graphics/alpine_surface_fragment.gdshaderinc"
