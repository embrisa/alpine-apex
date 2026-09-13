void fragment() {
#ifdef ALPINE_OFFMAP
 FOG=offmap_fog(world_pos,CAMERA_POSITION_WORLD);
 vec3 distant_normal=normalize(world_n);
 vec3 distant_color=offmap_color(world_pos,distant_normal,offmap_masks,length(VERTEX));
 vec3 distant_view_normal=normalize((VIEW_MATRIX*vec4(distant_normal,0.0)).xyz);
 offmap_snow_coverage=offmap_snow_amount(normalize(world_n),offmap_masks);
 if(offmap_blend>.999) {
  ALBEDO=distant_color; NORMAL=distant_view_normal; ROUGHNESS=1.0; SPECULAR=0.0;
  snow_transmission=vec3(0); snow_glints=0.0; snow_large_glints=0.0; snow_sheen=0.0;
  snow_facet_normal=vec3(0,1,0); snow_large_facet_normal=vec3(0,1,0);
 } else {
#endif
 // Complementary opaque ownership, in the zero-relief collar. No alpha/dither
 // seam, double surface, or intact terrain covering recessed ski impressions.
 if(powder_local_surface) {
  if(!powder_patch_enabled || !powder_replaces(world_pos.xz)) discard;
 } else if(powder_patch_enabled && powder_replaces(world_pos.xz)) discard;
 vec3 n=normalize(world_n);
 // Drop negligible projections before renormalizing to bound triplanar work.
 vec3 w=max(pow(abs(n),vec3(5.0))-vec3(.015),vec3(0));
 w/=max(dot(w,vec3(1.0)),.001);
 float distance_m=length(VERTEX);
 float detail=detail_strength*(1.0-smoothstep(35.0,180.0,distance_m));
 float pbr_detail=1.0-smoothstep(100.0,180.0,distance_m);
 // Nonperiodic, warped fields in metres: broad deposits, smaller broken drifts.
 // Include elevation so steep cliff faces do not inherit vertical color stripes.
 vec2 broad=world_pos.xz+vec2(world_pos.y*.37,-world_pos.y*.23);
 vec2 warp=vec2(value_noise(broad*.006),value_noise(broad*.006+vec2(41.7,19.3)))-.5;
 float macro=value_noise(broad*.013+warp*2.7);
 float drift=value_noise(world_pos.xz*vec2(.065,.115)+warp*3.1);
 float breakup=value_noise(broad*.071+warp*4.3);
 // Gradually expose the decorative mountain faces outside the ski laboratory.
 // Flat shoulders keep snow; this is a material mask, never terrain displacement.
 vec2 outside=max(abs(world_pos.xz-vec2(0,832))-vec2(384,1024),vec2(0));
 float mountain=smoothstep(64.0,320.0,length(outside));
 float mineral_ice=0.0;
 float rock=1.0-smoothstep(.66,.90,n.y-rock_bias-mountain*.12+(macro-.5)*.21+(breakup-.5)*.09);
 vec4 environment = vec4(1.0-rock,rock,0.0,0.5);
 if(use_environment) {
  environment=texture(environment_mask,(world_pos.xz-environment_origin)/environment_extent);
  // Break up existing exposure only: clean snow must not acquire a faint rock
  // layer that needlessly executes the much more expensive triplanar material.
  float exposed=smoothstep(.04,.25,environment.g);
  rock=mix(rock,clamp(environment.g+((macro-.5)*.16+(breakup-.5)*.10)*exposed,0.0,1.0),mix(.45,.20,mountain));
 }
 if(use_feature_exposure) {
  vec2 pixel=(world_pos.xz-feature_origin)/4.0;
  if(all(greaterThanEqual(pixel,vec2(0))) && all(lessThanEqual(pixel,feature_size-vec2(1)))) {
   vec4 feature=texture(feature_exposure,(pixel+vec2(.5))/feature_size);
   rock=mix(rock,feature.r,feature.a);
   mineral_ice=feature.g;
  }
 }
 if(contact_material_enabled) rock=smoothstep(.42,.58,contact_rock(world_pos.xz));
 // Compute derivatives before material branches; tile boundaries never affect LOD.
 vec3 dx=dFdx(world_pos); vec3 dy=dFdy(world_pos);
 vec3 snow=vec3(.92,.95,.98);
 vec3 so=vec3(1,.82,0);
 vec2 sn=vec2(0);
 if(rock<.985) {
  TerrainTiles snow_tiles=terrain_tiles(world_pos.xz*snow_scale,dx.xz*snow_scale,dy.xz*snow_scale,true);
  snow=terrain_color(snow_albedo,snow_tiles);
  if(pbr_detail>.001) so=mix(so,terrain_snow_orm(snow_tiles),pbr_detail);
  // Soften scanned grain without reducing geometric relief or rock detail.
  if(detail>.005) sn=terrain_snow_normal(snow_tiles)*.5;
 }
 vec3 stone=vec3(0); vec3 ro=vec3(0); vec3 rock_bump=vec3(0);
 if(rock>.015) {
  if(w.x>0.0) {
   TerrainLayer layer=terrain_rock_plane(world_pos.zy*rock_scale,dx.zy*rock_scale,dy.zy*rock_scale,detail,pbr_detail);
   stone+=layer.color*w.x; ro+=layer.orm*w.x;
   rock_bump+=vec3(0,layer.bump.y,layer.bump.x)*w.x;
  }
  if(w.y>0.0) {
   TerrainLayer layer=terrain_rock_plane(world_pos.xz*rock_scale,dx.xz*rock_scale,dy.xz*rock_scale,detail,pbr_detail);
   stone+=layer.color*w.y; ro+=layer.orm*w.y;
   rock_bump+=vec3(layer.bump.x,0,layer.bump.y)*w.y;
  }
  if(w.z>0.0) {
   TerrainLayer layer=terrain_rock_plane(world_pos.xy*rock_scale,dx.xy*rock_scale,dy.xy*rock_scale,detail,pbr_detail);
   stone+=layer.color*w.z; ro+=layer.orm*w.z;
   rock_bump+=vec3(layer.bump.x,layer.bump.y,0)*w.z;
  }
 } else {
  stone=vec3(.35); ro=vec3(.9,.85,0);
 }
 // Broad variation remains legible at speed without painting false obstacles.
 snow=mix(vec3(.94,.965,.99),snow,.24);
 snow*=.94+macro*.045+drift*.035;
 snow*=mix(vec3(.94,.97,1.0),vec3(1.0),environment.r);
 // Real terrain hollows remain legible beneath sunlight and broad reflection.
 snow*=snow_shape_tint(world_pos.xz,distance_m);
 // Desaturate the warm source stone into dark charcoal / slate, retaining
 // mineral detail and broad differences between exposed faces.
 float stone_luminance=dot(stone,vec3(.2126,.7152,.0722));
 stone=mix(vec3(stone_luminance),stone,.22);
 stone*=mix(vec3(.31,.35,.40),vec3(.51,.53,.55),macro);
 stone*=.90+breakup*.20;
 ALBEDO=mix(snow,stone,rock);
 ALBEDO=mix(ALBEDO,mix(vec3(.16,.36,.43),snow,.22+drift*.16),mineral_ice);
 // Subsurface fill remains modest; contact shadows and rounded geometry carry
 // the depth, while sunlight keeps fresh deposits bright and cold.
 snow_transmission=vec3(.08,.12,.17)*(1.0-rock);
 if(powder_local_surface) ALBEDO=mix(ALBEDO,vec3(.69,.79,.88),powder_compaction*.20*(1.0-rock));
 ROUGHNESS=mix(clamp(so.g-.045+(drift-.5)*.08,.60,.92),clamp(ro.g-.025,.70,1.0),rock);
 ROUGHNESS=clamp(ROUGHNESS-(1.0-environment.r)*.07,.58,1.0);
 AO=mix(mix(1.0,so.r,.12),mix(1.0,ro.r,.5),rock);
 ROUGHNESS=mix(ROUGHNESS,.40,mineral_ice);
 SPECULAR=.35;
 if(powder_local_surface) ROUGHNESS=mix(ROUGHNESS,.66,powder_compaction*(1.0-rock));
 vec3 bump=mix(vec3(sn.x,0,sn.y),rock_bump,rock);
 // Low, wind-shaped relief in the lighting normal, never the collision mesh.
 // Softer scanned grains and ripples retain broad drifts without etched relief.
 float close_snow=(1.0-rock)*(1.0-smoothstep(12.0,65.0,distance_m));
 float ripple_phase=world_pos.x*.95+world_pos.z*2.6+drift*5.0;
 float ripple=(sin(ripple_phase)*.065+sin(ripple_phase*2.17+macro*8.0)*.023)*.75;
 vec3 relief=vec3(.34,0,.94)*ripple*close_snow;
 vec3 final_n=normalize(n+(bump-n*dot(bump,n))*detail*mix(.468,1.0,rock)+relief-n*dot(relief,n));
 AO*=1.0-close_snow*(.5+.5*cos(ripple_phase))*.03375;
 NORMAL=normalize((VIEW_MATRIX*vec4(final_n,0.0)).xyz);
 // World-locked crystal facets. Filter subpixel grains instead of animating
 // noise: shimmer comes from the view/sun angle and obeys real/cloud shadows.
 float wind_pack=smoothstep(.45,.9,environment.a);
 float density=mix(1.0,.55,wind_pack)*mix(.85,1.0,drift);
 vec4 crystals=sample_crystals(world_pos,final_n,density,distance_m);
 snow_glints=crystals.w*close_snow;
 snow_facet_normal=normalize((VIEW_MATRIX*vec4(crystals.xyz,0)).xyz);
 vec4 large_crystals=sample_large_crystals(world_pos,final_n,density,distance_m);
 snow_large_glints=large_crystals.w*(1.0-rock)*(1.0-mineral_ice);
 snow_large_facet_normal=normalize((VIEW_MATRIX*vec4(large_crystals.xyz,0)).xyz);
 snow_sheen=(1.0-rock)*(1.0-mineral_ice)*mix(.80,1.0,wind_pack);
 if(powder_local_surface) snow_sheen*=mix(1.0,1.20,powder_compaction);
 // Fine clumps add roughness rather than painting grey dots onto bright snow.
 float grain_filter=1.0-smoothstep(.025,.09,max(length(dx),length(dy)));
 float clumps=value_noise(world_pos.xz*19.0);
 ROUGHNESS=clamp(ROUGHNESS+(clumps-.5)*.05*close_snow*grain_filter-wind_pack*.035*(1.0-rock),.58,1.0);
 if(snow_geometry_debug) {
  ALBEDO=vec3(.45,.50,.56); ROUGHNESS=.9; SPECULAR=0.0;
  NORMAL=normalize((VIEW_MATRIX*vec4(n,0)).xyz); snow_glints=0.0; snow_transmission=vec3(0);
  snow_large_glints=0.0; snow_sheen=0.0;
 }
#ifdef ALPINE_OFFMAP
 ALBEDO=mix(ALBEDO,distant_color,offmap_blend);
 NORMAL=normalize(mix(NORMAL,distant_view_normal,offmap_blend));
 ROUGHNESS=mix(ROUGHNESS,1.0,offmap_blend);
 SPECULAR*=1.0-offmap_blend;
 snow_transmission*=1.0-offmap_blend; snow_glints*=1.0-offmap_blend;
 snow_large_glints*=1.0-offmap_blend; snow_sheen*=1.0-offmap_blend;
 }
#endif
}
