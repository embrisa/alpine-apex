// Shared distant material uses filtered terrain sources, without normal/PBR maps.
#define ALPINE_OFFMAP_V3
uniform sampler2D offmap_rock : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D offmap_snow : source_color, filter_linear_mipmap, repeat_enable;
uniform float offmap_detail = 0.18;
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
 return mix(max(nl,0.0),max(nl+.24,0.0)/1.24,snow*.65);
}

vec3 offmap_color(vec3 p, vec3 n, vec4 mask, float distance_m) {
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
 // Canopy remains visible above a snowy forest floor beyond the prop range.
 return mix(mix(stone,snow_color,snow),forest,mask.g*.62);
}
