shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
#include "res://assets/cloud_light.gdshaderinc"
uniform vec4 ghost_tint : source_color = vec4(.2,.8,1.,1.);
uniform float ghost_opacity : hint_range(.15,.72) = .15;
uniform vec4 base_color : source_color = vec4(1.);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_texture : filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic;
uniform sampler2D metallic_texture : filter_linear_mipmap_anisotropic;
uniform bool has_albedo = false;
uniform bool has_normal = false;
uniform bool has_orm = false;
uniform bool has_roughness = false;
uniform bool has_metallic = false;
uniform vec4 roughness_channel = vec4(1,0,0,0);
uniform vec4 metallic_channel = vec4(0,0,1,0);
uniform float surface_roughness = .8;
uniform float surface_metallic = 0.;
uniform float normal_strength = .5;
void vertex() {
 cloud_direct_transmission=sample_cloud_light((MODEL_MATRIX*vec4(VERTEX,1)).xyz);
}
void fragment() {
 vec3 texel=has_albedo?texture(albedo_texture,UV).rgb:base_color.rgb;
 // Retain the actual fabric/equipment detail, replacing atlas hue so cyan
 // clothing remains cyan instead of multiplying a red atlas into near-black.
 float detail=clamp(dot(texel,vec3(.2126,.7152,.0722)),.16,1.);
 ALBEDO=ghost_tint.rgb*mix(.34,1.,sqrt(detail));
 ROUGHNESS=has_roughness?dot(texture(roughness_texture,UV),roughness_channel):surface_roughness;
 METALLIC=has_metallic?dot(texture(metallic_texture,UV),metallic_channel)*surface_metallic:surface_metallic;
 if(has_orm) { vec3 orm=texture(orm_texture,UV).rgb; AO=orm.r; ROUGHNESS=orm.g; METALLIC=orm.b; }
 if(has_normal) { NORMAL_MAP=texture(normal_texture,UV).rgb; NORMAL_MAP_DEPTH=normal_strength; }
 SPECULAR=material_specular;
 // One final alpha, independent of texture alpha or GeometryInstance fade.
 ALPHA=clamp(ghost_opacity,.15,.72);
}
