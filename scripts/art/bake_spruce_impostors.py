"""Bake tree albedo silhouettes and export camera-facing far-LOD cards."""
import bpy,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art_source/blender/spruce_library.blend'))
for o in bpy.context.scene.objects:o.hide_render=True
# Bake base color only. Sunlight, cloud shade, fog and daylight remain dynamic.
for m in bpy.data.materials:
 if not m.use_nodes:continue
 p=m.node_tree.nodes.get('Principled BSDF')
 if not p or not p.inputs['Base Color'].links:continue
 texture=p.inputs['Base Color'].links[0].from_socket
 output=next(n for n in m.node_tree.nodes if n.type=='OUTPUT_MATERIAL')
 emit=m.node_tree.nodes.new('ShaderNodeEmission')
 m.node_tree.links.new(texture,emit.inputs['Color']);m.node_tree.links.new(emit.outputs[0],output.inputs['Surface'])
data=bpy.data.cameras.new('Impostor Bake Camera');camera=bpy.data.objects.new('Impostor Bake Camera',data);bpy.context.collection.objects.link(camera)
camera.location=(0,-25,5.25);camera.rotation_euler=(Vector((0,0,5.25))-camera.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=11
scene=bpy.context.scene;scene.camera=camera;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1024;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='Standard'
for i in range(1,4):
 obj=bpy.data.objects[f'Spruce_{i}_LOD0'];obj.hide_render=False;obj.location=(0,0,0)
 scene.render.filepath=str(ROOT/f'assets/graphics/textures/spruce_impostor_{i}.png');bpy.ops.render.render(write_still=True)
 obj.hide_render=True
 mesh=bpy.data.meshes.new(f'Spruce{i}Impostor')
 # Blender Z-up. Exported GLB becomes Godot Y-up with the origin at trunk base.
 mesh.from_pydata([(-5.5,0,-.25),(5.5,0,-.25),(5.5,0,10.75),(-5.5,0,10.75)],[],[(0,1,2),(0,2,3)])
 uv=mesh.uv_layers.new()
 coords=[(0,0),(1,0),(1,1),(0,1)]
 for poly in mesh.polygons:
  for li in poly.loop_indices:uv.data[li].uv=coords[mesh.loops[li].vertex_index]
 card=bpy.data.objects.new(f'Spruce_{i}_LOD2',mesh);bpy.context.collection.objects.link(card)
 mat=bpy.data.materials.new(f'Impostor{i}.Runtime');mat.use_nodes=True;mesh.materials.append(mat)
 bpy.ops.object.select_all(action='DESELECT');card.select_set(True);bpy.context.view_layer.objects.active=card
 bpy.ops.export_scene.gltf(filepath=str(ROOT/f'assets/graphics/models/spruce_{i}_lod2.glb'),export_format='GLB',use_selection=True,export_animations=False)
 card.hide_render=True
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/blender/spruce_impostor_bake.blend'))
for i in range(1,4):
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(ROOT/f'assets/graphics/models/spruce_{i}_lod2.glb'))
 obj=next(o for o in bpy.context.scene.objects if o.type=='MESH');obj.data.calc_loop_triangles()
 assert len(obj.data.loop_triangles)==2 and abs(obj.dimensions.z-11)<.01
(ROOT/'art_source/blender/impostor_qa.json').write_text(json.dumps({'variants':3,'triangles_per_tree':2,'quad_size_m':11,'base_offset_m':-.25,'roundtrip_verified':True,'shading':'Albedo-only bake; runtime cloud/daylight/fog'},indent=2))
