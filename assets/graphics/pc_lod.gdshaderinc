// Opaque complementary coverage avoids drawing two alpha-blended crowns.
instance uniform vec4 pc_lod_ranges : instance_index(0) = vec4(0.0);
instance uniform vec3 pc_lod_center : instance_index(1) = vec3(0.0);
float pc_lod_coverage(vec3 camera) {
 if (pc_lod_ranges.z<=0.0) return 1.0;
 float distance_m=distance(camera,pc_lod_center);
 float near_part=pc_lod_ranges.x<=0.0 ? 1.0 : smoothstep(pc_lod_ranges.x-pc_lod_ranges.z,pc_lod_ranges.x+pc_lod_ranges.z,distance_m);
 float far_part=1.0-smoothstep(pc_lod_ranges.y-pc_lod_ranges.z,pc_lod_ranges.y+pc_lod_ranges.z,distance_m);
 return near_part*far_part;
}
float pc_lod_threshold(vec2 pixel) {
 return fract(52.9829189*fract(dot(floor(pixel),vec2(.06711056,.00583715))));
}
