// Three overlapping patches on a triangular lattice. Each lattice vertex owns
// one stable transform, shared across its neighbours and every PBR channel.
// Explicit UV gradients keep random offsets out of mip/anisotropic selection.
struct TerrainTiles {
 vec2 a;
 vec2 b;
 vec2 c;
 mat2 frame_a;
 mat2 frame_b;
 mat2 frame_c;
 vec3 weights;
 vec2 dx;
 vec2 dy;
};

vec3 terrain_hash(vec2 p) {
 vec3 h=fract(vec3(p.xyx)*vec3(.1031,.1030,.0973));
 h+=dot(h,h.yxz+33.33);
 return fract((h.xxy+h.yzz)*h.zyx);
}

void terrain_patch(vec2 uv,vec2 id,bool wind_aligned,out vec2 coord,out mat2 frame) {
 vec3 random=terrain_hash(id);
 // Normalized random directions avoid six trigonometric evaluations per blend.
 // Snow spans approximately +/-52 degrees; rock covers the entire circle.
 vec2 direction=wind_aligned ? normalize(vec2(1,(random.z-.5)*2.52))
                                  : normalize(random.yz-vec2(.5)+vec2(.00001,0));
 frame=mat2(direction,vec2(-direction.y,direction.x))*mix(.85,1.15,random.x);
 vec2 center=vec2(id.x+id.y*.5,id.y*.8660254)/.8;
 coord=frame*(uv-center)+random.xy*7.31;
}

TerrainTiles terrain_tiles(vec2 uv,vec2 dx,vec2 dy,bool wind_aligned) {
 vec2 skew=vec2(uv.x-uv.y*.57735027,uv.y*1.15470054)*.8;
 vec2 cell=floor(skew); vec2 f=fract(skew);
 vec2 a; vec2 b; vec2 c; vec3 weights;
 if(f.x+f.y<1.0) {
  a=cell; b=cell+vec2(1,0); c=cell+vec2(0,1);
  weights=vec3(1.0-f.x-f.y,f.x,f.y);
 } else {
  a=cell+vec2(1,1); b=cell+vec2(0,1); c=cell+vec2(1,0);
  weights=vec3(f.x+f.y-1.0,1.0-f.x,1.0-f.y);
 }
 // Sharper interiors preserve texture contrast; zero edge derivatives hide seams.
 weights=weights*weights*weights;
 TerrainTiles tiles;
 tiles.weights=weights/dot(weights,vec3(1));
 terrain_patch(uv,a,wind_aligned,tiles.a,tiles.frame_a);
 terrain_patch(uv,b,wind_aligned,tiles.b,tiles.frame_b);
 terrain_patch(uv,c,wind_aligned,tiles.c,tiles.frame_c);
 tiles.dx=dx; tiles.dy=dy;
 return tiles;
}

vec3 terrain_color(sampler2D tex,TerrainTiles tiles) {
 return textureGrad(tex,tiles.a,tiles.frame_a*tiles.dx,tiles.frame_a*tiles.dy).rgb*tiles.weights.x
       +textureGrad(tex,tiles.b,tiles.frame_b*tiles.dx,tiles.frame_b*tiles.dy).rgb*tiles.weights.y
       +textureGrad(tex,tiles.c,tiles.frame_c*tiles.dx,tiles.frame_c*tiles.dy).rgb*tiles.weights.z;
}

vec2 terrain_normal(sampler2D tex,TerrainTiles tiles) {
 vec2 a=textureGrad(tex,tiles.a,tiles.frame_a*tiles.dx,tiles.frame_a*tiles.dy).xy*2.0-1.0;
 vec2 b=textureGrad(tex,tiles.b,tiles.frame_b*tiles.dx,tiles.frame_b*tiles.dy).xy*2.0-1.0;
 vec2 c=textureGrad(tex,tiles.c,tiles.frame_c*tiles.dx,tiles.frame_c*tiles.dy).xy*2.0-1.0;
 // Rotate each sampled slope back into its projection plane before blending.
 return transpose(tiles.frame_a)*a*tiles.weights.x
       +transpose(tiles.frame_b)*b*tiles.weights.y
       +transpose(tiles.frame_c)*c*tiles.weights.z;
}

// Godot requires one filtering mode per sampler argument. Keep the snow detail
// samplers explicit so ordinary mip filtering can coexist with anisotropic rock.
vec3 terrain_snow_orm(TerrainTiles tiles) {
 return textureGrad(snow_orm,tiles.a,tiles.frame_a*tiles.dx,tiles.frame_a*tiles.dy).rgb*tiles.weights.x
       +textureGrad(snow_orm,tiles.b,tiles.frame_b*tiles.dx,tiles.frame_b*tiles.dy).rgb*tiles.weights.y
       +textureGrad(snow_orm,tiles.c,tiles.frame_c*tiles.dx,tiles.frame_c*tiles.dy).rgb*tiles.weights.z;
}

vec2 terrain_snow_normal(TerrainTiles tiles) {
 vec2 a=textureGrad(snow_normal_tex,tiles.a,tiles.frame_a*tiles.dx,tiles.frame_a*tiles.dy).xy*2.0-1.0;
 vec2 b=textureGrad(snow_normal_tex,tiles.b,tiles.frame_b*tiles.dx,tiles.frame_b*tiles.dy).xy*2.0-1.0;
 vec2 c=textureGrad(snow_normal_tex,tiles.c,tiles.frame_c*tiles.dx,tiles.frame_c*tiles.dy).xy*2.0-1.0;
 return transpose(tiles.frame_a)*a*tiles.weights.x
       +transpose(tiles.frame_b)*b*tiles.weights.y
       +transpose(tiles.frame_c)*c*tiles.weights.z;
}

struct TerrainLayer {
 vec3 color;
 vec3 orm;
 vec2 bump;
};

TerrainLayer terrain_rock_plane(vec2 uv,vec2 dx,vec2 dy,float detail,float pbr_detail) {
 TerrainTiles tiles=terrain_tiles(uv,dx,dy,false);
 TerrainLayer layer;
 layer.color=terrain_color(rock_albedo,tiles);
 layer.orm=vec3(.9,.85,0);
 layer.bump=vec2(0);
 if(pbr_detail>.001) layer.orm=mix(layer.orm,terrain_color(rock_orm,tiles),pbr_detail);
 if(detail>.005) layer.bump=terrain_normal(rock_normal_tex,tiles);
 return layer;
}
