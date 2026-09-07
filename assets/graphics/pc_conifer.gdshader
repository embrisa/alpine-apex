shader_type spatial;
render_mode cull_disabled;
#define ALPINE_NEEDLE_TRANSMISSION
varying float needle_transmission;
#include "res://assets/cloud_light.gdshaderinc"
#include "res://assets/graphics/pc_lod.gdshaderinc"
uniform sampler2D bark_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wind_time = 0.0;
uniform float wind_strength = 0.0;
uniform vec2 wind_direction = vec2(1,0);
uniform float snow_coverage : hint_range(0.0,1.0) = 0.72;
varying vec3 tree_world_normal;
varying flat float lod_coverage;
void vertex() {
 lod_coverage=pc_lod_coverage(MAIN_CAM_INV_VIEW_MATRIX[3].xyz);
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 float close=1.0-smoothstep(90.0,180.0,length((VIEW_MATRIX*vec4(p,1)).xyz));
 float crown=pow(clamp((VERTEX.y-1.8)/8.7,0.0,1.0),2.0);
 VERTEX.xz+=wind_direction*wind_strength*.0065*crown*close*sin(wind_time*1.5+VERTEX.y*.65+p.x*.29);
 tree_world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 // Clouds vary over hundreds of metres; the trunk anchor is sufficient for
 // one crown and keeps this input uniform across its many needle vertices.
 cloud_direct_transmission=sample_cloud_light(MODEL_MATRIX[3].xyz);
}
void fragment() {
 float coverage=lod_coverage;
 float threshold=pc_lod_threshold(FRAGCOORD.xy);
 if(pc_lod_ranges.w==1.0) threshold=1.0-threshold;
 if(coverage<threshold) discard;
 if(COLOR.a>.55 && COLOR.a<.75) {
  float across=abs(UV.y-.5);
  float needle=fract(UV.x*16.0-across*10.0);
  if(needle>.35 && across>.025) discard;
 }
 float wood=1.0-step(.25,COLOR.a);
 float cap=step(.8,COLOR.a);
 needle_transmission=(1.0-wood)*(1.0-cap)*.12;
 if(cap>.5 && snow_coverage<.01) discard;
 vec3 bark=texture(bark_texture,UV).rgb*.72;
 vec3 foliage=COLOR.rgb;
 float dust=smoothstep(.4,.95,tree_world_normal.y)*snow_coverage*.22;
 foliage=mix(foliage,vec3(.73,.80,.87),dust*(1.0-cap));
 ALBEDO=mix(foliage,bark,wood);
 // Broad dielectric response; matte bark and filtered needle silhouettes.
 ROUGHNESS=mix(mix(.78,.90,wood),.71,cap);
 SPECULAR=.32;
 if(!FRONT_FACING) NORMAL=-NORMAL;
}
