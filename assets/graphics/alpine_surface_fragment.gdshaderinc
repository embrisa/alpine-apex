void fragment() {
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
  }
 }
 // Compute derivatives before material branches; tile boundaries never affect LOD.
 vec3 dx=dFdx(world_pos); vec3 dy=dFdy(world_pos);
 vec3 snow=vec3(.92,.95,.98);
 vec3 so=vec3(1,.82,0);
 vec2 sn=vec2(0);
 if(rock<.985) {
  TerrainTiles snow_tiles=terrain_tiles(world_pos.xz*snow_scale,dx.xz*snow_scale,dy.xz*snow_scale,true);
  snow=terrain_color(snow_albedo,snow_tiles);
  if(pbr_detail>.001) so=mix(so,terrain_snow_orm(snow_tiles),pbr_detail);
  if(detail>.005) sn=terrain_snow_normal(snow_tiles);
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
 snow=mix(vec3(.92,.95,.98),snow,.34);
 snow*=.91+macro*.10+drift*.055;
 snow*=mix(vec3(.94,.97,1.0),vec3(1.0),environment.r);
 // Desaturate the warm source stone into dark charcoal / slate, retaining
 // mineral detail and broad differences between exposed faces.
 float stone_luminance=dot(stone,vec3(.2126,.7152,.0722));
 stone=mix(vec3(stone_luminance),stone,.22);
 stone*=mix(vec3(.25,.29,.35),vec3(.44,.46,.49),macro);
 stone*=.90+breakup*.20;
 ALBEDO=mix(snow,stone,rock);
 ROUGHNESS=mix(clamp(so.g+(drift-.5)*.08,.64,.94),clamp(ro.g,.72,1.0),rock);
 ROUGHNESS=clamp(ROUGHNESS-(1.0-environment.r)*.07,.58,1.0);
 AO=mix(mix(1.0,so.r,.2),mix(1.0,ro.r,.5),rock);
 SPECULAR=.35;
 vec3 bump=mix(vec3(sn.x,0,sn.y),rock_bump,rock);
 // Low, wind-shaped relief in the lighting normal, never the collision mesh.
 // Metre-scale ripples sit beneath the scanned grains and disappear at distance.
 float close_snow=(1.0-rock)*(1.0-smoothstep(12.0,65.0,distance_m));
 float ripple_phase=world_pos.x*.95+world_pos.z*2.6+drift*5.0;
 float ripple=sin(ripple_phase)*.065+sin(ripple_phase*2.17+macro*8.0)*.023;
 vec3 relief=vec3(.34,0,.94)*ripple*close_snow;
 vec3 final_n=normalize(n+(bump-n*dot(bump,n))*detail*mix(1.65,1.0,rock)+relief-n*dot(relief,n));
 AO*=1.0-close_snow*(.5+.5*cos(ripple_phase))*.045;
 NORMAL=normalize((VIEW_MATRIX*vec4(final_n,0.0)).xyz);
 // World-locked crystal facets. Filter subpixel grains instead of animating
 // noise: shimmer comes from the view/sun angle and obeys real/cloud shadows.
 vec2 crystal_uv=world_pos.xz*18.0;
 vec2 cell=floor(crystal_uv);
 vec2 random=terrain_hash(cell+vec2(317.3,91.7)).xy;
 vec2 crystal=fract(crystal_uv)-(.2+random*.6);
 float footprint=max(length(dFdx(crystal_uv)),length(dFdy(crystal_uv)));
 float grain=1.0-smoothstep(.035,.16+min(footprint,.35)*.35,length(crystal));
 snow_glints=grain*smoothstep(.62,.85,random.x)*(1.0-smoothstep(.25,1.1,footprint))*close_snow;
 vec3 facet=vec3((random.x-.5)*1.6,0,(random.y-.5)*1.6);
 snow_facet_normal=normalize((VIEW_MATRIX*vec4(normalize(final_n+facet-n*dot(facet,n)),0)).xyz);
}
