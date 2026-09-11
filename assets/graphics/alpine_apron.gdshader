shader_type spatial;
render_mode cull_back, shadows_disabled;
#define ALPINE_OFFMAP
#include "res://assets/graphics/offmap_surface.gdshaderinc"
#include "res://assets/graphics/offmap_fog.gdshaderinc"
#include "res://assets/graphics/alpine_surface_uniforms.gdshaderinc"
void vertex() {
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 world_n=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 offmap_masks=COLOR;
 offmap_blend=UV.x;
 cloud_direct_transmission=offmap_blend>.999 ? cloud_shade : sample_cloud_light(world_pos);
}
#include "res://assets/graphics/alpine_surface_fragment.gdshaderinc"
