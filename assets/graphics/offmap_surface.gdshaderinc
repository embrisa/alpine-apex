// Shared ridge/apron snow. No extra textures, displacement, shadows or PBR maps.
#define ALPINE_OFFMAP_V3
uniform sampler2D offmap_rock : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D offmap_snow : source_color, filter_linear_mipmap, repeat_enable;
uniform float offmap_detail = 0.18;
// Independent opt-in; all presets stay cheap until the separate cost gate.
uniform bool offmap_snow_detail = false;
uniform float cloud_shade = 1.0;
varying vec4 offmap_masks;
varying float offmap_blend;
varying float offmap_snow_coverage;

float offmap_snow_amount(vec3 n, vec4 mask) {
 // The same slope, shelter and exposure mask as the main mountain. Retain
 // solid snow/stone regions instead of a gray intermediate coating.
 return smoothstep(.30,.64,mask.r);
}

float offmap_diffuse(float nl, float snow) {
 // A small snow scattering lobe softens unshadowed background facets. It
 // follows the actual sun/moon energy and never introduces night emission.
 return mix(max(nl,0.0),max(nl+.14,0.0)/1.14,snow*.35);
}

// Smooth value and analytic gradient; world metres, no time or light in albedo.
vec3 offmap_deposit(vec2 p) {
 vec2 cell=floor(p), f=fract(p);
 vec4 h=fract(sin(vec4(dot(cell,vec2(127.1,311.7)),dot(cell+vec2(1,0),vec2(127.1,311.7)),
  dot(cell+vec2(0,1),vec2(127.1,311.7)),dot(cell+vec2(1),vec2(127.1,311.7))))*43758.5453);
 vec2 u=f*f*(3.0-2.0*f), du=6.0*f*(1.0-f);
 return vec3(mix(mix(h.x,h.y,u.x),mix(h.z,h.w,u.x),u.y),
  mix(h.y-h.x,h.w-h.z,u.y)*du.x,mix(h.z-h.x,h.w-h.y,u.x)*du.y);
}

vec3 offmap_color(vec3 p, inout vec3 n, vec4 mask, float distance_m) {
 // Derivatives precede branches; fade unresolved relief before it can shimmer.
 float footprint=max(length(dFdx(p)),length(dFdy(p)));
 vec2 uv=(p.xz+vec2(p.y*.43,-p.y*.29))*.004;
 vec3 texture_color=texture(offmap_rock,uv).rgb;
 float stone_value=dot(texture_color,vec3(.2126,.7152,.0722));
 float detail_weight=offmap_detail*(1.0-smoothstep(5000.0,14000.0,distance_m));
 float breakup=(stone_value-.3)*detail_weight;
 float snow=offmap_snow_amount(n,mask);
 // Match the playable terrain's scanned-mineral desaturation and grading.
 vec3 stone=mix(vec3(stone_value),texture_color,.22);
 stone*=mix(vec3(.31,.35,.40),vec3(.51,.53,.55),mask.b);
 stone*=1.0+breakup;
 vec3 forest=mix(vec3(.018,.032,.026),vec3(.036,.058,.037),mask.b);
 // Filter the canopy grain instead of turning far forests into flat paint.
 float canopy=texture(offmap_rock,p.xz*.021).g;
 forest*=mix(.72,1.34,canopy);
 // Reuse its scanned snow and neutral grading at a filtered distance scale.
 vec3 snow_color=mix(vec3(.94,.965,.99),texture(offmap_snow,p.xz*.23).rgb,.28);
 snow_color*=.97;
 // Authored alpha is .5 + .35 * broad hollow, sampled on baked tiers.
 // A small cool tint only in hollows; no inverted ridge outline or dirt.
 float hollow=smoothstep(.52,.85,mask.a);
 snow_color*=mix(vec3(1),vec3(.963,.980,.995),hollow);
 if(offmap_snow_detail) {
  vec2 broad=p.xz+vec2(p.y*.37,-p.y*.23);
  vec3 deposit=offmap_deposit(broad*.0035);
  vec2 drift_uv=vec2(broad.x*.011+broad.y*.004,-broad.x*.006+broad.y*.019);
  vec3 drift=offmap_deposit(drift_uv+vec2(deposit.x*1.8));
  float broad_filter=1.0-smoothstep(60.0,200.0,footprint);
  float fine_filter=(1.0-smoothstep(8.0,36.0,footprint))*(1.0-smoothstep(5000.0,14000.0,distance_m));
  snow_color*=1.0+(deposit.x-.5)*.075*broad_filter+(drift.x-.5)*.035*fine_filter;
  // Small tangent perturbations follow the actual directional light. Preserve
  // the geometric silhouette and avoid accentuating exposed rock facets.
  vec2 gradient=vec2(drift.y*.58-drift.z*.32,drift.y*.21+drift.z);
  vec3 relief=vec3(gradient.x,0,gradient.y)*.055*fine_filter*snow;
  n=normalize(n-(relief-n*dot(relief,n)));
 }
 // Canopy remains visible above a snowy forest floor beyond the prop range.
 return mix(mix(stone,snow_color,snow),forest,mask.g*.62);
}
