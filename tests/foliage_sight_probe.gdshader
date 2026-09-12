shader_type canvas_item;
render_mode unshaded;
#include "res://assets/graphics/foliage_sight.gdshaderinc"
uniform float probe_depth = 5.0;
void fragment() {
 if(foliage_sight_removal(probe_depth)>foliage_sight_threshold(FRAGCOORD.xy)) discard;
 COLOR=vec4(1.0);
}
