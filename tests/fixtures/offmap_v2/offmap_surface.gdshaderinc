// Shared opaque distant material: one filtered texture read, no normal/PBR maps.
uniform sampler2D offmap_rock : source_color, filter_linear_mipmap, repeat_enable;
uniform float offmap_detail = 0.18;
uniform float cloud_shade = 1.0;
varying vec4 offmap_masks;
varying float offmap_blend;

vec3 offmap_color(vec3 p, vec3 n, vec4 mask, float distance_m) {
 vec2 uv=(p.xz+vec2(p.y*.43,-p.y*.29))*.004;
 vec3 texture_color=texture(offmap_rock,uv).rgb;
 float stone_value=dot(texture_color,vec3(.2126,.7152,.0722));
 float detail_weight=offmap_detail*(1.0-smoothstep(5000.0,14000.0,distance_m));
 float breakup=(stone_value-.3)*detail_weight;
 float snow=mask.r*smoothstep(.68,.96,n.y+breakup+(mask.a-.5)*.22);
 vec3 stone=mix(vec3(.065,.077,.093),vec3(.16,.18,.20),mask.b);
 stone*=.88+stone_value*.4;
 vec3 forest=mix(vec3(.018,.032,.026),vec3(.036,.058,.037),mask.b);
 stone=mix(stone,forest,mask.g*(1.0-snow));
 vec3 snow_color=vec3(.80,.86,.91)*(1.0+breakup*.35);
 return mix(stone,snow_color,clamp(snow+breakup,0.0,1.0));
}
