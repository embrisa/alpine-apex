shader_type spatial;
render_mode cull_disabled;
#include "res://assets/cloud_light.gdshaderinc"
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float wind_time = 0.0;
uniform vec2 wind_direction = vec2(1,0);
uniform float wind_strength = 0.0;
void vertex() {
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 // Centimetres of needle movement; trunks and physical obstacles never move.
 VERTEX.xz+=wind_direction*sin(wind_time*1.4+p.x*.71+p.z*.35)*wind_strength*.012*UV.y;
 cloud_direct_transmission=sample_cloud_light(p);
}
void fragment() {
 vec4 tex=texture(albedo_texture,UV);
 if(tex.a<.42) discard; // Former ALPHA_SCISSOR_THRESHOLD .42, one test.
 ALBEDO=tex.rgb;
 ROUGHNESS=.91;
 SPECULAR=.18;
 if(!FRONT_FACING) NORMAL=-NORMAL;
}
