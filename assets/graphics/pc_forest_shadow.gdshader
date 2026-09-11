shader_type spatial;
render_mode cull_disabled,unshaded;
#include "res://assets/graphics/pc_lod.gdshaderinc"
varying flat float coverage;
void vertex() {
 coverage=pc_lod_coverage(MAIN_CAM_INV_VIEW_MATRIX[3].xyz,MODEL_MATRIX[3].xyz,MODEL_MATRIX);
 if(pc_lod_individual && coverage<=0.0) VERTEX=vec3(0.0);
}
void fragment() {
 if(coverage<pc_lod_threshold(FRAGCOORD.xy)) discard;
 ALBEDO=vec3(0.0);
}
