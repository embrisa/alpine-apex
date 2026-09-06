shader_type spatial;
render_mode cull_back;
#include "res://assets/graphics/alpine_surface_uniforms.gdshaderinc"
void vertex() {
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 world_n=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 cloud_direct_transmission=sample_cloud_light(world_pos);
}
#include "res://assets/graphics/alpine_surface_fragment.gdshaderinc"
