// Used by native geometry, its offline atlas bake and distant geometry.
uniform bool source_textured = true;
uniform vec3 autumn_color : source_color = vec3(1.0);
uniform float autumn_amount = 0.0;
uniform float snow_dusting = 0.0;
vec3 season_color(vec3 color, vec3 normal) {
 float brightness=dot(color,vec3(.2126,.7152,.0722));
 float leaf=smoothstep(.025,.16,(color.g-max(color.r,color.b))/max(brightness,.02));
 color=mix(color,autumn_color*brightness*2.3,leaf*autumn_amount);
 return mix(color,vec3(.86,.91,.96),snow_dusting*smoothstep(.25,.85,normal.y));
}
