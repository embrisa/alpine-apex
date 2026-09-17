shader_type spatial;
render_mode cull_back;
#include "res://assets/cloud_light.gdshaderinc"
uniform vec4 ghost_tint : source_color = vec4(.2,.8,1.,1.);
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
uniform bool has_metallic = false;
uniform sampler2D metallic_texture : filter_linear_mipmap_anisotropic;
uniform vec4 metallic_channel = vec4(0,0,1,0);
void vertex() {
 cloud_direct_transmission=sample_cloud_light((MODEL_MATRIX*vec4(VERTEX,1)).xyz);
}
void fragment() {
 vec3 texel=has_albedo?texture(albedo_texture,UV).rgb:vec3(1.0);
 // SkierV7Clothing contains both the orange jacket and charcoal trousers.
 // Restrict recoloring to warm saturated jacket fabric in the unchanged atlas.
 float jacket=smoothstep(.02,.10,texel.r-max(texel.g,texel.b));
 ALBEDO=base_color.rgb*mix(texel,ghost_tint.rgb*texel.r,jacket);
 ROUGHNESS=has_roughness?dot(texture(roughness_texture,UV),roughness_channel):surface_roughness;
 METALLIC=surface_metallic;
 if(has_metallic) METALLIC=dot(texture(metallic_texture,UV),metallic_channel)*surface_metallic;
 if(has_orm) { vec3 orm=texture(orm_texture,UV).rgb; AO=orm.r; ROUGHNESS=orm.g; METALLIC=orm.b; }
 if(has_normal) { NORMAL_MAP=texture(normal_texture,UV).rgb; NORMAL_MAP_DEPTH=normal_strength; }
 SPECULAR=material_specular;
}
