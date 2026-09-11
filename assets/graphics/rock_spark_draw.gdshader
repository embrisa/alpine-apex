shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
void vertex() {
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment() {
 float glow=1.0-smoothstep(.1,1.0,length(UV*2.0-1.0));
 ALBEDO=COLOR.rgb*3.0;
 ALPHA=COLOR.a*glow;
}
