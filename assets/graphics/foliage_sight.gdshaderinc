// Adjustable opening through nearby canopy; 100% covers the entire screen.
// One stationary threshold across layers reveals snow beyond stacked sprays.
uniform vec4 foliage_sight_window = vec4(.5,.5,.44,.44);
uniform vec4 foliage_sight_parameters = vec4(0.0);
float foliage_sight_removal(vec2 uv, float view_depth) {
 float middle=1.0;
 // Full-screen mode bypasses the mask, including all four screen corners.
 if(foliage_sight_window.z<.5) {
  vec2 p=(uv-foliage_sight_window.xy)/foliage_sight_window.zw;
  vec2 squared=p*p;
  middle=1.0-smoothstep(.86,1.0,sqrt(sqrt(dot(squared,squared))));
 }
 float nearby=1.0-smoothstep(foliage_sight_parameters.y,foliage_sight_parameters.z,max(view_depth,0.0));
 return foliage_sight_parameters.x*middle*nearby;
}
float foliage_sight_threshold(vec2 pixel) {
 // Offset from the complementary LOD pattern; no animated random noise.
 return fract(52.9829189*fract(dot(floor(pixel)+vec2(17.0,29.0),vec2(.06711056,.00583715))));
}
