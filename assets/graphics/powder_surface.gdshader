shader_type spatial;
render_mode cull_back;
#include "res://assets/graphics/alpine_surface_uniforms.gdshaderinc"
uniform sampler2D contact_heights : filter_nearest, repeat_disable;
uniform vec2 contact_origin;
uniform ivec2 contact_size;
float contact_height(vec2 world) {
 vec2 grid=clamp((world-contact_origin)/4.0,vec2(0),vec2(contact_size)-1.001);
 ivec2 cell=ivec2(floor(grid)); vec2 f=fract(grid);
 float a=texelFetch(contact_heights,cell,0).r;
 float b=texelFetch(contact_heights,cell+ivec2(1,0),0).r;
 float c=texelFetch(contact_heights,cell+ivec2(0,1),0).r;
 float d=texelFetch(contact_heights,cell+ivec2(1,1),0).r;
 return f.x+f.y<=1.0 ? a+f.x*(b-a)+f.y*(c-a) : d+(1.0-f.x)*(c-d)+(1.0-f.y)*(b-d);
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
 vec3 base=normalize(vec3(contact_height(world-vec2(4,0))-contact_height(world+vec2(4,0)),8.0,contact_height(world-vec2(0,4))-contact_height(world+vec2(0,4))));
 world_n=normalize(base+vec3(-hx,0,-hz)*base.y/(2.0*texel));
 NORMAL=world_n;
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 powder_compaction=clamp(-imprint.x*24.0,0.0,1.0)*edge;
 cloud_direct_transmission=sample_cloud_light(world_pos);
}
#include "res://assets/graphics/alpine_surface_fragment.gdshaderinc"
