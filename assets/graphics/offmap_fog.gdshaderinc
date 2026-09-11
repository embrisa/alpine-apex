// FOG replaces automatic depth fog in Godot. Compose its exponential depth
// component explicitly with the added valley layer; never change Environment.
uniform vec4 offmap_bounds = vec4(-3072.0,-3072.0,3072.0,3072.0);
uniform vec4 offmap_footprint = vec4(3032.0,42.0,24.0,18.0);
uniform float offmap_valley_height = 1600.0;
uniform vec3 offmap_fog_color = vec3(.45,.55,.65);
uniform vec3 offmap_sun_color = vec3(0.0);
uniform vec3 offmap_sun_direction = vec3(0.0,1.0,0.0);
uniform float offmap_depth_density = .000065;
uniform float offmap_valley_density = .000045;
uniform float offmap_fog_scatter = 0.0;

float offmap_edge_distance(vec2 p) {
 float angle=atan(p.x,p.y);
 float radius=offmap_footprint.x+offmap_footprint.y*sin(angle*3.0)+offmap_footprint.z*sin(angle*5.0)+offmap_footprint.w*sin(angle*2.0);
 return max(0.0,length(p)-radius-24.0);
}
vec4 offmap_fog(vec3 p,vec3 camera) {
 float d=distance(p,camera);
 vec3 color=offmap_fog_color+offmap_sun_color*offmap_fog_scatter*pow(max(dot(normalize(p-camera),offmap_sun_direction),0.0),8.0);
 float base=1.0-exp(-d*offmap_depth_density);
 float boundary=smoothstep(192.0,900.0,offmap_edge_distance(p.xz));
 float patches=.80+.20*sin(p.x*.00057+sin(p.z*.00083));
 float valley=1.0-smoothstep(offmap_valley_height+180.0,offmap_valley_height+1350.0,p.y);
 float extra=1.0-exp(-max(d-1000.0,0.0)*offmap_valley_density*valley*patches*boundary);
 return vec4(color,1.0-(1.0-base)*(1.0-extra));
}
