#include "res://assets/graphics/snow_crystals.gdshaderinc"
#define ALPINE_SNOW_TRANSMISSION
varying vec3 snow_transmission;
#include "res://assets/cloud_light.gdshaderinc"
#include "res://assets/graphics/snow_readability.gdshaderinc"
#include "res://assets/graphics/powder_surface.gdshaderinc"
uniform sampler2D snow_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Relief/roughness may blur along the grazing footprint; albedo retains
// anisotropy. This bounds the cost of three blended snow detail samples.
uniform sampler2D snow_normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_orm : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float snow_scale = 0.23;
uniform float rock_scale = 0.075;
uniform float rock_bias = 0.0;
uniform float detail_strength = 0.36;
uniform bool snow_geometry_debug = false;
uniform bool use_environment = false;
uniform vec2 environment_origin = vec2(-4096,-2048);
uniform float environment_extent = 8192.0;
uniform sampler2D environment_mask : filter_linear_mipmap, repeat_disable;
// Fixed terrain-resolution override, enabled only for the showcase terrain.
uniform bool use_feature_exposure = false;
uniform sampler2D feature_exposure : filter_linear, repeat_disable;
uniform vec2 feature_origin;
uniform vec2 feature_size = vec2(1);
varying vec3 world_pos;
varying vec3 world_n;
#include "res://assets/graphics/terrain_sampling.gdshaderinc"
float value_noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(terrain_hash(i).x,terrain_hash(i+vec2(1,0)).x,f.x),mix(terrain_hash(i+vec2(0,1)).x,terrain_hash(i+vec2(1,1)).x,f.x),f.y);
}
