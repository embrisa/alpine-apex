#include "res://assets/graphics/snow_crystals.gdshaderinc"
#define ALPINE_SNOW_TRANSMISSION
varying vec3 snow_transmission;
varying vec3 world_pos;
varying vec3 world_n;
#ifdef ALPINE_OFFMAP
#include "res://assets/graphics/offmap_horizon.gdshaderinc"
#endif
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
// Wind-drift relief strength. Deposit depths are in metres over three shared
// noise bands; the presentation profile scales the whole set.
uniform float snow_drift_relief : hint_range(0.0,1.5) = 1.0;
const vec2 DRIFT_MID_FREQ = vec2(.065,.115);
const vec2 DRIFT_FINE_FREQ = vec2(.29,.51);
const float DRIFT_BROAD_M = 5.0;
const float DRIFT_MID_M = 1.25;
const float DRIFT_FINE_M = .19;
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
#include "res://assets/graphics/terrain_sampling.gdshaderinc"
// Value noise with its analytic gradient. The four corner hashes serve the
// value and both derivatives, so wind-drift slopes cost arithmetic instead of
// extra taps or finite differences. .x is the value, .yz its noise-domain
// gradient; callers scale that by their own frequency to reach metres.
vec3 value_noise_slope(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p);
 vec2 u=f*f*(3.0-2.0*f); vec2 du=6.0*f*(1.0-f);
 float a=terrain_hash(i).x;
 float b=terrain_hash(i+vec2(1,0)).x;
 float c=terrain_hash(i+vec2(0,1)).x;
 float d=terrain_hash(i+vec2(1,1)).x;
 float kx=b-a; float ky=c-a; float kxy=a-b-c+d;
 return vec3(a+kx*u.x+ky*u.y+kxy*u.x*u.y,du.x*(kx+kxy*u.y),du.y*(ky+kxy*u.x));
}
float value_noise(vec2 p) { return value_noise_slope(p).x; }
