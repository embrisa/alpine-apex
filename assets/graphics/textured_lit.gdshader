shader_type spatial;
render_mode cull_back;
#include "res://assets/cloud_light.gdshaderinc"
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo = false;
uniform bool has_normal = false;
uniform bool has_orm = false;
uniform bool has_roughness = false;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic;
uniform vec4 roughness_channel = vec4(1,0,0,0);
uniform float surface_roughness = 0.8;
uniform float surface_metallic = 0.0;
uniform float normal_strength = 0.5;
uniform bool foliage_tint = false;
uniform bool has_metallic = false;
uniform sampler2D metallic_texture : filter_linear_mipmap_anisotropic;
uniform vec4 metallic_channel = vec4(0,0,1,0);
uniform bool tree_wind = false;
uniform float wind_time = 0.0;
uniform float wind_strength = 0.0;
uniform vec2 wind_direction = vec2(1,0);
void vertex() {
 if(tree_wind && wind_strength>0.01) {
  vec3 p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
  float nearby=1.0-smoothstep(60.0,160.0,length((VIEW_MATRIX*vec4(p,1)).xyz));
  if(nearby>0.0) {
   float crown=pow(clamp((VERTEX.y-1.0)/9.5,0.0,1.0),2.0);
   VERTEX.xz+=wind_direction*wind_strength*.008*crown*nearby*sin(wind_time*1.6+VERTEX.y*.6+MODEL_MATRIX[3].x*.3);
  }
 }
 cloud_direct_transmission=sample_cloud_light((MODEL_MATRIX*vec4(VERTEX,1)).xyz);
}
void fragment() {
 ALBEDO=base_color.rgb*(has_albedo?texture(albedo_texture,UV).rgb:vec3(1.0));
 if(foliage_tint) {
  float saturation=max(max(ALBEDO.r,ALBEDO.g),ALBEDO.b)-min(min(ALBEDO.r,ALBEDO.g),ALBEDO.b);
  float needles=smoothstep(.025,.16,saturation)*step(ALBEDO.r*.95,ALBEDO.g);
  ALBEDO*=mix(vec3(1.0),vec3(.4,.65,.55),needles);
 }
 ROUGHNESS=has_roughness?dot(texture(roughness_texture,UV),roughness_channel):surface_roughness;
 METALLIC=surface_metallic;
 if(has_metallic) METALLIC=dot(texture(metallic_texture,UV),metallic_channel)*surface_metallic;
 if(has_orm) { vec3 orm=texture(orm_texture,UV).rgb; AO=orm.r; ROUGHNESS=orm.g; METALLIC=orm.b; }
 if(has_normal) { NORMAL_MAP=texture(normal_texture,UV).rgb; NORMAL_MAP_DEPTH=normal_strength; }
 SPECULAR=material_specular;
}
