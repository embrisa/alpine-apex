// Opaque complementary coverage avoids drawing two alpha-blended crowns.
instance uniform vec4 pc_lod_ranges : instance_index(0) = vec4(0.0);
instance uniform vec3 pc_lod_center : instance_index(1) = vec3(0.0);
instance uniform bool pc_lod_individual : instance_index(2) = false;
// Local crown sphere shared by each asset batch. Zero retains bare-tree policy.
instance uniform vec4 pc_crown_bounds : instance_index(3) = vec4(0.0);
instance uniform bool pc_streamed : instance_index(4) = false;
uniform sampler2D pc_detail_residency : filter_nearest, repeat_disable;
float pc_lod_coverage(vec3 camera, vec3 anchor, mat4 model) {
 if (pc_lod_ranges.z<=0.0) return 1.0;
 float distance_m=distance(camera,pc_lod_individual ? anchor : pc_lod_center);
 float detail_m=distance_m;
 if(pc_lod_individual && pc_crown_bounds.w>0.0) {
  vec3 center=(model*vec4(pc_crown_bounds.xyz,1.0)).xyz;
  float scale=max(length(model[0].xyz),max(length(model[1].xyz),length(model[2].xyz)));
  detail_m=max(0.0,distance(camera,center)-pc_crown_bounds.w*scale);
 }
 float near_part=pc_lod_ranges.x<=0.0 ? 1.0 : smoothstep(pc_lod_ranges.x-pc_lod_ranges.z,pc_lod_ranges.x+pc_lod_ranges.z,detail_m);
 if (pc_streamed && pc_lod_ranges.w==2.0) {
  // Retain silhouettes after a teleport until local geometry has uploaded.
  vec2 uv=(anchor.xz+vec2(3072.0))/6144.0;
  float detailed=textureLod(pc_detail_residency,uv,0.0).r;
  near_part=mix(1.0,near_part,detailed);
 }
 float far_part=1.0-smoothstep(pc_lod_ranges.y-pc_lod_ranges.z,pc_lod_ranges.y+pc_lod_ranges.z,pc_lod_ranges.w<1.5 ? detail_m : distance_m);
 return near_part*far_part;
}
float pc_lod_threshold(vec2 pixel) {
 return fract(52.9829189*fract(dot(floor(pixel),vec2(.06711056,.00583715))));
}
