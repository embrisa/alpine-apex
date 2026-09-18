shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
#include "res://assets/graphics/snow_crystals.gdshaderinc"
#include "res://assets/graphics/snow_ambient.gdshaderinc"
#include "res://assets/cloud_light.gdshaderinc"
#include "res://assets/graphics/snow_readability.gdshaderinc"
#include "res://assets/graphics/powder_surface.gdshaderinc"
uniform bool relief_enabled = true;
uniform bool exact_surface = false;
uniform sampler2D surface_heights : filter_nearest, repeat_disable;
uniform vec2 surface_origin;
uniform ivec2 surface_size = ivec2(2);
varying vec3 track_across;
varying vec3 track_up;
varying float imprint_depth;
varying float track_distance;
varying vec3 imprint_world;
varying float imprint_slip;
varying float imprint_width;
varying float crystal_density;
varying vec2 live_cap;
float snow_grain(vec2 p) {
 return sin(p.x*17.0+p.y*9.0)*sin(p.x*23.0-p.y*11.0);
}
float surface_height(vec2 world) {
 vec2 grid=clamp((world-surface_origin)/4.0,vec2(0),vec2(surface_size)-1.001);
 ivec2 cell=ivec2(floor(grid)); vec2 f=fract(grid);
 float a=texelFetch(surface_heights,cell,0).r;
 float b=texelFetch(surface_heights,cell+ivec2(1,0),0).r;
 float c=texelFetch(surface_heights,cell+ivec2(0,1),0).r;
 float d=texelFetch(surface_heights,cell+ivec2(1,1),0).r;
 return f.x+f.y<=1.0 ? a+f.x*(b-a)+f.y*(c-a) : d+(1.0-f.x)*(c-d)+(1.0-f.y)*(b-d);
}
void vertex() {
 vec2 t=VERTEX.xz+0.5;
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 float irregular=snow_grain(world.xz);
 float h=mix(mix(INSTANCE_CUSTOM.r,INSTANCE_CUSTOM.g,t.x),mix(INSTANCE_CUSTOM.b,INSTANCE_CUSTOM.a,t.x),t.y);
	if(exact_surface) h=surface_height(world.xz)-MODEL_MATRIX[3].y;
 float x=VERTEX.x*2.0;
 imprint_depth=COLOR.r;
 live_cap=vec2(COLOR.g<0.0 ? 1.0 : 0.0,t.y);
 imprint_slip=COLOR.g<0.0 ? -COLOR.g-1.0 : COLOR.g;
 // Vertex-only packing: keeping this local avoids exceeding Metal's varying limit.
 float berm_side=COLOR.b*2.0-1.0;
 crystal_density=COLOR.a;
 imprint_width=length(MODEL_MATRIX[0].xyz);
 float spread=max(imprint_width*.14,.12);
 float berm=exp(-pow((abs(x)-.70+irregular*.02)*imprint_width*.5/spread,2.0));
 float sided=mix(.55,1.45,smoothstep(-.3,.3,x*berm_side));
 // Follow the same local impression surface, retaining the readable packed
 // ribbon over High's shallow geometry. Previously the patch hid this ribbon
 // entirely; its filtered narrow grooves could then disappear from chase view.
 float local_height=powder_patch_enabled ? powder_height(world.xz) : 0.0;
 float end_cap=live_cap.x>0.5 ? smoothstep(0.0,.08,t.y)*(1.0-smoothstep(.88,1.0,t.y)) : 1.0;
 VERTEX.y=h+local_height+0.009+berm*min(imprint_depth*.55,spread*.50)*(1.0+irregular*.06)*sided*end_cap;
 imprint_world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 vec3 along=normalize(vec3(MODEL_MATRIX[2].x,(INSTANCE_CUSTOM.b+INSTANCE_CUSTOM.a-INSTANCE_CUSTOM.r-INSTANCE_CUSTOM.g)*0.5,MODEL_MATRIX[2].z));
 track_across=normalize(vec3(MODEL_MATRIX[0].x,(INSTANCE_CUSTOM.g+INSTANCE_CUSTOM.a-INSTANCE_CUSTOM.r-INSTANCE_CUSTOM.b)*.5,MODEL_MATRIX[0].z));
 track_up=normalize(cross(along,track_across));
 cloud_direct_transmission=sample_cloud_light((MODEL_MATRIX*vec4(VERTEX,1)).xyz);
 track_distance=length((MODELVIEW_MATRIX*vec4(VERTEX,1)).xyz);
}
void fragment() {
 // Beyond the 380 m fade the ribbon is fully transparent: skip its crystal
 // and lighting work instead of blending an invisible fragment.
 if(track_distance>=380.0) discard;
 if(contact_rock(imprint_world.xz)>=.5) discard;
 vec3 view_world=normalize(INV_VIEW_MATRIX[3].xyz-imprint_world);
 float x=UV.x*2.0-1.0;
 float grain=snow_grain(imprint_world.xz);
 // One-step analytic parallax on a bounded groove. Raised lips are geometry;
 // the optical recess leaves the authoritative contact surface intact.
 float parallax=relief_enabled ? clamp(dot(view_world,track_across)/max(dot(view_world,track_up),.24)*imprint_depth/max(imprint_width,.1)*2.0,-.23,.23) : 0.0;
 float broken_x=x+parallax+grain*(.025+imprint_slip*.11);
 float groove=1.0-smoothstep(mix(.26,.50,imprint_slip),.72,abs(broken_x));
 ALBEDO=mix(vec3(.86,.90,.95),vec3(.80,.86,.93),groove*.60);
 ALBEDO*=1.0+grain*(.012+imprint_slip*.03);
 ALBEDO*=snow_shape_tint(imprint_world.xz,length(VERTEX));
 ROUGHNESS=mix(.89,.68+imprint_slip*.13,groove);
 AO=1.0-groove*.10;
 SPECULAR=.45;
 // Optical recess at the unchanged contact surface, with actual raised lips.
 float wall=-sign(broken_x)*exp(-pow((abs(broken_x)-.48)*7.0,2.0))*min(imprint_depth/max(imprint_width,.1)*12.0,1.25);
 wall*=1.0-imprint_slip*.60;
 wall+=grain*(.025+imprint_slip*.14);
 vec3 n=normalize(track_up+track_across*wall);
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0)).xyz);
 IRRADIANCE=snow_sky_ambient(n,1.0);
 // Keep a cheap packed line visible behind the racer; fine relief fades first.
 ALPHA=(1.0-smoothstep(.72,.98,abs(x)))*(1.0-smoothstep(220.0,380.0,track_distance))*.94;
 // The filtered High surface already carries loaded grooves and rounded
 // banks. Its coarse overlay rectangles expose a second set of raised ends.
 // Keep the full packed ribbon for <=12 mm cosmetic marks, which need it for
 // readable continuity, and fade loaded overlays with the local relief area.
 if(powder_patch_enabled) ALPHA*=1.0-powder_edge(imprint_world.xz)*smoothstep(.012,.035,imprint_depth);
 if(live_cap.x>0.5) ALPHA*=smoothstep(0.0,.08,live_cap.y)*(1.0-smoothstep(.88,1.0,live_cap.y));
 vec4 crystals=sample_crystals(imprint_world,n,crystal_density*mix(.45,.7,imprint_slip),track_distance);
 snow_glints=crystals.w;
 snow_facet_normal=normalize((VIEW_MATRIX*vec4(crystals.xyz,0)).xyz);
 vec4 large_crystals=sample_large_crystals(imprint_world,n,crystal_density*mix(.45,.7,imprint_slip),track_distance);
 snow_large_glints=large_crystals.w;
 snow_large_facet_normal=normalize((VIEW_MATRIX*vec4(large_crystals.xyz,0)).xyz);
 snow_sheen=mix(.80,1.0,groove)*(1.0-imprint_slip*.20);
}
