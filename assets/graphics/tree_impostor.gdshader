shader_type spatial;
render_mode cull_disabled,skip_vertex_transform;
#include "res://assets/cloud_light.gdshaderinc"
uniform sampler2D albedo_texture : source_color,filter_linear_mipmap_anisotropic;
uniform bool foliage_tint = true;
void vertex() {
 vec3 center=MODEL_MATRIX[3].xyz;
 vec2 direction=normalize(INV_VIEW_MATRIX[3].xz-center.xz);
 vec3 right=vec3(direction.y,0,-direction.x);
 vec3 p=center+right*VERTEX.x*length(MODEL_MATRIX[0].xyz)+vec3(0,VERTEX.y*length(MODEL_MATRIX[1].xyz),0);
 VERTEX=(VIEW_MATRIX*vec4(p,1)).xyz;
 NORMAL=normalize(mat3(VIEW_MATRIX)*vec3(direction.x,.6,direction.y));
 cloud_direct_transmission=sample_cloud_light(p);
}
void fragment() {
 vec4 tex=texture(albedo_texture,UV);
 if(tex.a<.42) discard; // Former ALPHA_SCISSOR_THRESHOLD .42, before the grading.
 float saturation=max(max(tex.r,tex.g),tex.b)-min(min(tex.r,tex.g),tex.b);
 float needles=smoothstep(.025,.16,saturation)*step(tex.r*.95,tex.g);
 ALBEDO=tex.rgb*(foliage_tint?mix(vec3(1),vec3(.4,.65,.55),needles):vec3(1));
 ROUGHNESS=.91;
 SPECULAR=.18;
}
