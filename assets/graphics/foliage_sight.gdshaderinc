// Full-screen canopy removal: activation, near/outer depth, normalized strength.
// One stationary threshold across layers reveals snow beyond stacked sprays.
uniform vec4 foliage_sight_parameters = vec4(0.0);
float foliage_sight_removal(float view_depth) {
 float nearby=1.0-smoothstep(foliage_sight_parameters.y,foliage_sight_parameters.z,max(view_depth,0.0));
 return foliage_sight_parameters.x*foliage_sight_parameters.w*nearby;
}
float foliage_sight_threshold(vec2 pixel) {
 // Offset from the complementary LOD pattern; no animated random noise.
 return fract(52.9829189*fract(dot(floor(pixel)+vec2(17.0,29.0),vec2(.06711056,.00583715))));
}
