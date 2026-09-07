shader_type spatial;
render_mode cull_disabled,skip_vertex_transform;
#include "res://assets/cloud_light.gdshaderinc"
#include "res://assets/graphics/pc_lod.gdshaderinc"
uniform sampler2D albedo_texture : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
varying float atlas_view;
varying flat float lod_coverage;
void vertex() {
 lod_coverage=pc_lod_coverage(MAIN_CAM_INV_VIEW_MATRIX[3].xyz);
 vec3 center=MODEL_MATRIX[3].xyz;
 vec2 direction=normalize(INV_VIEW_MATRIX[3].xz-center.xz);
 vec3 eye=vec3(direction.x,0,direction.y);
 vec2 local=vec2(dot(eye,normalize(MODEL_MATRIX[0].xyz)),dot(eye,normalize(MODEL_MATRIX[2].xyz)));
 atlas_view=mod(atan(local.x,local.y)+6.283185307,6.283185307)*1.273239545;
 vec3 right=vec3(direction.y,0,-direction.x);
 // Crop empty atlas sides without changing the photographed silhouette.
 vec3 p=center+right*VERTEX.x*.64*length(MODEL_MATRIX[0].xyz)+vec3(0,VERTEX.y*length(MODEL_MATRIX[1].xyz),0);
 VERTEX=(VIEW_MATRIX*vec4(p,1)).xyz;
 NORMAL=normalize(mat3(VIEW_MATRIX)*vec3(direction.x,.6,direction.y));
 cloud_direct_transmission=sample_cloud_light(p);
}
void fragment() {
 float coverage=lod_coverage;
 if(coverage<pc_lod_threshold(FRAGCOORD.xy)) discard;
 float a=floor(atlas_view);
 vec2 uv=vec2(mix(.18,.82,UV.x),UV.y);
 vec4 first=texture(albedo_texture,vec2((uv.x+a)/8.0,uv.y));
 vec4 second=texture(albedo_texture,vec2((uv.x+mod(a+1.0,8.0))/8.0,uv.y));
 vec4 tex=mix(first,second,smoothstep(.15,.85,fract(atlas_view)));
 ALBEDO=tex.rgb;
 ALPHA=tex.a;
 ALPHA_SCISSOR_THRESHOLD=.35;
 ROUGHNESS=.90;
 SPECULAR=.18;
}
