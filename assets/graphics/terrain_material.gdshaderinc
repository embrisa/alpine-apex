// Shared, fixed 4 m material data. Never affected by LOD, camera or powder relief.
uniform bool contact_material_enabled = false;
uniform sampler2D contact_material : filter_linear, repeat_disable;
uniform vec2 contact_material_origin;
uniform vec2 contact_material_size = vec2(2);
float contact_rock(vec2 world) {
 if(!contact_material_enabled) return 0.0;
 vec2 pixel=clamp((world-contact_material_origin)/4.0,vec2(0),contact_material_size-vec2(1.001));
 return textureLod(contact_material,(pixel+vec2(.5))/contact_material_size,0.0).r;
}
